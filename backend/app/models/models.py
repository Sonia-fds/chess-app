import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SAEnum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


# ─────────────────────────────────────────────
# UTILS
# ─────────────────────────────────────────────

def generate_uuid() -> str:
    return str(uuid.uuid4())


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ─────────────────────────────────────────────
# ENUMS
# ─────────────────────────────────────────────

class GameStatus(str, enum.Enum):
    WAITING = "WAITING"
    IN_PROGRESS = "IN_PROGRESS"
    FINISHED = "FINISHED"
    ABANDONED = "ABANDONED"


class GameResult(str, enum.Enum):
    WHITE_WINS = "WHITE_WINS"
    BLACK_WINS = "BLACK_WINS"
    DRAW = "DRAW"


class DifficultyLevel(str, enum.Enum):
    EASY = "EASY"
    MEDIUM = "MEDIUM"
    HARD = "HARD"
    MASTER = "MASTER"


# ─────────────────────────────────────────────
# USER
# ─────────────────────────────────────────────

class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=generate_uuid,
    )

    email: Mapped[str] = mapped_column(
        String(255),
        unique=True,
        nullable=False,
        index=True,
    )

    username: Mapped[str] = mapped_column(
        String(80),
        unique=True,
        nullable=False,
        index=True,
    )

    hashed_password: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

    elo_rating: Mapped[int] = mapped_column(
        Integer,
        default=1200,
        nullable=False,
    )

    email_verified: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    verify_token: Mapped[str | None] = mapped_column(
        String(255),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    games_as_white: Mapped[list["Game"]] = relationship(
        "Game",
        foreign_keys="Game.white_player_id",
        back_populates="white_player",
    )

    games_as_black: Mapped[list["Game"]] = relationship(
        "Game",
        foreign_keys="Game.black_player_id",
        back_populates="black_player",
    )

    def __repr__(self) -> str:
        return f"<User username={self.username} elo={self.elo_rating}>"


# ─────────────────────────────────────────────
# GAME
# ─────────────────────────────────────────────

class Game(Base):
    __tablename__ = "games"

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=generate_uuid,
    )

    status: Mapped[GameStatus] = mapped_column(
        SAEnum(GameStatus, native_enum=False),
        default=GameStatus.WAITING,
        nullable=False,
    )

    result: Mapped[GameResult | None] = mapped_column(
        SAEnum(GameResult, native_enum=False),
        nullable=True,
    )

    white_player_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("users.id"),
        nullable=False,
        index=True,
    )

    black_player_id: Mapped[str | None] = mapped_column(
        String,
        ForeignKey("users.id"),
        nullable=True,
        index=True,
    )

    is_vs_ai: Mapped[bool] = mapped_column(
        Boolean,
        default=False,
        nullable=False,
    )

    ai_difficulty: Mapped[DifficultyLevel | None] = mapped_column(
        SAEnum(DifficultyLevel, native_enum=False),
        nullable=True,
    )

    current_fen: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
        default="rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    )

    pgn: Mapped[str] = mapped_column(
        Text,
        default="",
        nullable=False,
    )

    time_control: Mapped[str] = mapped_column(
        String(20),
        default="10+0",
        nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    started_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    ended_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    white_player: Mapped["User"] = relationship(
        "User",
        foreign_keys=[white_player_id],
        back_populates="games_as_white",
    )

    black_player: Mapped["User | None"] = relationship(
        "User",
        foreign_keys=[black_player_id],
        back_populates="games_as_black",
    )

    moves: Mapped[list["Move"]] = relationship(
        "Move",
        back_populates="game",
        order_by="Move.move_number",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Game id={self.id[:8]} status={self.status.value}>"


# ─────────────────────────────────────────────
# MOVE
# ─────────────────────────────────────────────

class Move(Base):
    __tablename__ = "moves"

    __table_args__ = (
        UniqueConstraint(
            "game_id",
            "move_number",
            "is_white",
            name="uq_move_per_turn",
        ),
    )

    id: Mapped[str] = mapped_column(
        String,
        primary_key=True,
        default=generate_uuid,
    )

    game_id: Mapped[str] = mapped_column(
        String,
        ForeignKey("games.id"),
        nullable=False,
        index=True,
    )

    move_number: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
    )

    san: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
    )

    uci: Mapped[str] = mapped_column(
        String(10),
        nullable=False,
    )

    fen_after: Mapped[str] = mapped_column(
        String(120),
        nullable=False,
    )

    is_white: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
    )

    evaluation: Mapped[float | None] = mapped_column(
        Float,
        nullable=True,
    )

    played_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    game: Mapped["Game"] = relationship(
        "Game",
        back_populates="moves",
    )

    def __repr__(self) -> str:
        color = "White" if self.is_white else "Black"
        return f"<Move #{self.move_number} {color} {self.san}>"