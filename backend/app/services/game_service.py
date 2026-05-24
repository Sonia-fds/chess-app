import os
import random
import uuid
from datetime import datetime, timezone
from typing import Optional

import chess
import chess.engine
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models import (
    DifficultyLevel,
    Game,
    GameResult,
    GameStatus,
    Move,
    User,
)
from app.schemas import HintResponse, MoveResponse, MoveWithAIResponse


# ─────────────────────────────────────────────
# CONFIG STOCKFISH
# ─────────────────────────────────────────────

STOCKFISH_PATH = os.getenv("STOCKFISH_PATH", "/usr/games/stockfish")

DEPTH_MAP = {
    DifficultyLevel.EASY: 3,
    DifficultyLevel.MEDIUM: 10,
    DifficultyLevel.HARD: 18,
    DifficultyLevel.MASTER: 24,
}


# ─────────────────────────────────────────────
# UTILS
# ─────────────────────────────────────────────

def utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ─────────────────────────────────────────────
# STOCKFISH HELPERS
# ─────────────────────────────────────────────

def _get_engine() -> chess.engine.SimpleEngine:
    try:
        return chess.engine.SimpleEngine.popen_uci(STOCKFISH_PATH)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Moteur Stockfish indisponible",
        )


def _analyze(fen: str, depth: int) -> chess.engine.InfoDict:
    board = chess.Board(fen)

    with _get_engine() as engine:
        return engine.analyse(board, chess.engine.Limit(depth=depth))


def _best_move(fen: str, depth: int) -> chess.Move:
    board = chess.Board(fen)

    if board.is_game_over(claim_draw=True):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucun coup disponible : la partie est terminée",
        )

    with _get_engine() as engine:
        result = engine.play(board, chess.engine.Limit(depth=depth))

    if result.move is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Aucun coup IA disponible",
        )

    return result.move


# ─────────────────────────────────────────────
# ELO CALCULATOR
# ─────────────────────────────────────────────

def _k_factor(elo: int) -> int:
    if elo < 1200:
        return 40

    if elo < 2000:
        return 20

    return 10


def _expected_score(elo_a: int, elo_b: int) -> float:
    return 1 / (1 + 10 ** ((elo_b - elo_a) / 400))


def _new_elo(elo: int, opponent_elo: int, result: float) -> int:
    k = _k_factor(elo)
    expected = _expected_score(elo, opponent_elo)

    return round(elo + k * (result - expected))


# ─────────────────────────────────────────────
# GAME SERVICE
# ─────────────────────────────────────────────

class GameService:
    # ── CRÉER UNE PARTIE ────────────────────

    @staticmethod
    def create_game(
        user: User,
        is_vs_ai: bool,
        ai_difficulty: Optional[DifficultyLevel],
        player_color: str,
        time_control: str,
        db: Session,
    ) -> Game:
        if player_color == "random":
            player_color = random.choice(["white", "black"])

        if player_color not in ("white", "black"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Couleur invalide",
            )

        white_player_id = user.id if player_color == "white" else None
        black_player_id = user.id if player_color == "black" else None

        if not is_vs_ai and black_player_id is None:
            # MVP : pour une partie humain vs humain, on crée d'abord une partie
            # en attente avec le joueur connecté côté blanc.
            white_player_id = user.id
            black_player_id = None

        game = Game(
            id=str(uuid.uuid4()),
            status=GameStatus.IN_PROGRESS if is_vs_ai else GameStatus.WAITING,
            white_player_id=white_player_id,
            black_player_id=black_player_id,
            is_vs_ai=is_vs_ai,
            ai_difficulty=ai_difficulty if is_vs_ai else None,
            time_control=time_control,
            started_at=utc_now() if is_vs_ai else None,
            current_fen=chess.STARTING_FEN,
            pgn="",
        )

        db.add(game)

        if is_vs_ai:
            board = chess.Board(game.current_fen)

            # Si le joueur est noir, l'IA joue le premier coup des blancs.
            if player_color == "black":
                GameService._ai_move(game=game, board=board, db=db)

        db.commit()
        db.refresh(game)

        return game

    # ── JOUER UN COUP ───────────────────────

    @staticmethod
    def make_move(
        game_id: str,
        uci: str,
        user: User,
        db: Session,
    ) -> MoveWithAIResponse:
        game = GameService._get_active_game(game_id, db)
        GameService._assert_user_can_play(game, user)

        board = chess.Board(game.current_fen)
        GameService._check_player_turn(game, user, board)

        move = GameService._parse_legal_move(uci, board)

        player_response = GameService._apply_and_save_move(
            game=game,
            board=board,
            move=move,
            db=db,
        )

        if board.is_game_over(claim_draw=True):
            GameService._end_game(game, board, db)
            db.commit()
            return MoveWithAIResponse(**player_response.model_dump())

        ai_response = None

        if game.is_vs_ai:
            ai_response = GameService._ai_move(game=game, board=board, db=db)

            if board.is_game_over(claim_draw=True):
                GameService._end_game(game, board, db)

        db.commit()

        return MoveWithAIResponse(
            **player_response.model_dump(),
            ai_move=ai_response,
        )

    # ── COUP DE L'IA ────────────────────────

    @staticmethod
    def _ai_move(
        game: Game,
        board: chess.Board,
        db: Session,
    ) -> Optional[MoveResponse]:
        if board.is_game_over(claim_draw=True):
            return None

        depth = DEPTH_MAP.get(
            game.ai_difficulty or DifficultyLevel.MEDIUM,
            10,
        )

        ai_move = _best_move(board.fen(), depth)

        return GameService._apply_and_save_move(
            game=game,
            board=board,
            move=ai_move,
            db=db,
        )

    # ── CONSEIL STOCKFISH ───────────────────

    @staticmethod
    def get_hint(
        game_id: str,
        depth: int,
        db: Session,
    ) -> HintResponse:
        game = db.query(Game).filter(Game.id == game_id).first()

        if not game:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Partie introuvable",
            )

        board = chess.Board(game.current_fen)

        if board.is_game_over(claim_draw=True):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La partie est déjà terminée",
            )

        info = _analyze(game.current_fen, depth)

        best_move = info.get("pv", [None])[0]

        if not best_move:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Aucun coup disponible",
            )

        score = info.get("score")
        evaluation = 0.0

        if score:
            cp = score.relative.score(mate_score=10000)
            evaluation = cp / 100 if cp is not None else 0.0

        best_line = [move.uci() for move in info.get("pv", [])[:5]]

        return HintResponse(
            best_move=best_move.uci(),
            evaluation=evaluation,
            depth=depth,
            best_line=best_line,
        )

    # ── HELPERS — GAME ──────────────────────

    @staticmethod
    def _get_active_game(game_id: str, db: Session) -> Game:
        game = db.query(Game).filter(Game.id == game_id).first()

        if not game:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Partie introuvable",
            )

        if game.status != GameStatus.IN_PROGRESS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Partie non active",
            )

        return game

    @staticmethod
    def _assert_user_can_play(game: Game, user: User) -> None:
        if game.white_player_id != user.id and game.black_player_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Accès interdit à cette partie",
            )

    @staticmethod
    def _check_player_turn(
        game: Game,
        user: User,
        board: chess.Board,
    ) -> None:
        if board.turn == chess.WHITE and game.white_player_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ce n'est pas votre tour",
            )

        if board.turn == chess.BLACK and game.black_player_id != user.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ce n'est pas votre tour",
            )

    @staticmethod
    def _parse_legal_move(
        uci: str,
        board: chess.Board,
    ) -> chess.Move:
        try:
            move = chess.Move.from_uci(uci)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Format UCI invalide",
            )

        if move not in board.legal_moves:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Coup illégal",
            )

        return move

    @staticmethod
    def _apply_and_save_move(
        game: Game,
        board: chess.Board,
        move: chess.Move,
        db: Session,
    ) -> MoveResponse:
        san = board.san(move)
        uci = move.uci()
        move_number = board.fullmove_number
        is_white = board.turn == chess.WHITE

        board.push(move)

        fen_after = board.fen()

        db_move = Move(
            id=str(uuid.uuid4()),
            game_id=game.id,
            move_number=move_number,
            san=san,
            uci=uci,
            fen_after=fen_after,
            is_white=is_white,
        )

        db.add(db_move)

        game.current_fen = fen_after
        game.pgn = f"{game.pgn} {san}".strip()

        return MoveResponse(
            uci=uci,
            san=san,
            fen=fen_after,
            is_check=board.is_check(),
            is_checkmate=board.is_checkmate(),
            is_draw=GameService._is_draw(board),
        )

    @staticmethod
    def _is_draw(board: chess.Board) -> bool:
        return (
            board.is_stalemate()
            or board.is_insufficient_material()
            or board.is_seventyfive_moves()
            or board.is_fivefold_repetition()
            or board.can_claim_draw()
        )

    @staticmethod
    def _end_game(
        game: Game,
        board: chess.Board,
        db: Session,
    ) -> None:
        game.status = GameStatus.FINISHED
        game.ended_at = utc_now()

        if board.is_checkmate():
            winner_is_white = board.turn == chess.BLACK
            game.result = (
                GameResult.WHITE_WINS
                if winner_is_white
                else GameResult.BLACK_WINS
            )
        else:
            game.result = GameResult.DRAW

        GameService._update_elo_if_needed(game, db)

    @staticmethod
    def _update_elo_if_needed(
        game: Game,
        db: Session,
    ) -> None:
        if game.is_vs_ai:
            return

        if not game.white_player_id or not game.black_player_id:
            return

        white = db.query(User).filter(User.id == game.white_player_id).first()
        black = db.query(User).filter(User.id == game.black_player_id).first()

        if not white or not black:
            return

        old_white_elo = white.elo_rating
        old_black_elo = black.elo_rating

        if game.result == GameResult.WHITE_WINS:
            white_result, black_result = 1.0, 0.0
        elif game.result == GameResult.BLACK_WINS:
            white_result, black_result = 0.0, 1.0
        else:
            white_result, black_result = 0.5, 0.5

        white.elo_rating = _new_elo(
            old_white_elo,
            old_black_elo,
            white_result,
        )

        black.elo_rating = _new_elo(
            old_black_elo,
            old_white_elo,
            black_result,
        )