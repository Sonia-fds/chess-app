from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Game, User
from app.schemas import (
    CreateGameRequest,
    GameResponse,
    HintResponse,
    MakeMoveRequest,
    MoveWithAIResponse,
)
from app.services.auth_service import get_current_user
from app.services.game_service import GameService

router = APIRouter()


@router.post(
    "/create",
    response_model=GameResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer une nouvelle partie",
)
def create_game(
    body: CreateGameRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return GameService.create_game(
        user=current_user,
        is_vs_ai=body.is_vs_ai,
        ai_difficulty=body.ai_difficulty,
        player_color=body.player_color,
        time_control=body.time_control,
        db=db,
    )


@router.get(
    "/{game_id}",
    response_model=GameResponse,
    summary="Récupérer une partie",
)
def get_game(
    game_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    game = db.query(Game).filter(Game.id == game_id).first()

    if not game:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Partie introuvable",
        )

    if game.white_player_id != current_user.id and game.black_player_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès interdit à cette partie",
        )

    return game


@router.post(
    "/{game_id}/move",
    response_model=MoveWithAIResponse,
    summary="Jouer un coup",
)
def make_move(
    game_id: str,
    body: MakeMoveRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return GameService.make_move(
        game_id=game_id,
        uci=body.uci,
        user=current_user,
        db=db,
    )


@router.get(
    "/{game_id}/hint",
    response_model=HintResponse,
    summary="Demander un conseil à Stockfish",
)
def get_hint(
    game_id: str,
    depth: int = Query(default=15, ge=1, le=25),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    game = db.query(Game).filter(Game.id == game_id).first()

    if not game:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Partie introuvable",
        )

    if game.white_player_id != current_user.id and game.black_player_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Accès interdit à cette partie",
        )

    return GameService.get_hint(
        game_id=game_id,
        depth=depth,
        db=db,
    )