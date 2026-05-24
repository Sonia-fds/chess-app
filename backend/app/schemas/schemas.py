from __future__ import annotations

import re
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, EmailStr, field_validator, model_validator

from app.models import DifficultyLevel, GameResult, GameStatus


# ─────────────────────────────────────────────
# AUTH SCHEMAS
# ─────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    username: str
    password: str

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> EmailStr:
        return str(value).lower().strip()

    @field_validator("username")
    @classmethod
    def validate_username(cls, value: str) -> str:
        username = value.strip()

        if len(username) < 3:
            raise ValueError("Minimum 3 caractères")

        if len(username) > 20:
            raise ValueError("Maximum 20 caractères")

        if not re.fullmatch(r"^[A-Za-z0-9_]+$", username):
            raise ValueError("Lettres, chiffres et _ uniquement")

        return username

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        if len(value) < 8:
            raise ValueError("Minimum 8 caractères")

        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: EmailStr) -> EmailStr:
        return str(value).lower().strip()


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    username: str
    elo_rating: int


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: str
    username: str
    elo_rating: int
    email_verified: bool
    created_at: datetime


# ─────────────────────────────────────────────
# GAME SCHEMAS
# ─────────────────────────────────────────────

class CreateGameRequest(BaseModel):
    is_vs_ai: bool = True
    ai_difficulty: Optional[DifficultyLevel] = DifficultyLevel.MEDIUM
    player_color: str = "white"  # white | black | random
    time_control: str = "10+0"

    @field_validator("player_color")
    @classmethod
    def validate_color(cls, value: str) -> str:
        color = value.lower().strip()

        if color not in ("white", "black", "random"):
            raise ValueError("Couleur invalide : white, black ou random")

        return color

    @field_validator("time_control")
    @classmethod
    def validate_time_control(cls, value: str) -> str:
        time_control = value.strip()

        if not re.fullmatch(r"^\d+\+\d+$", time_control):
            raise ValueError("Format time_control invalide. Exemple attendu : 10+0")

        return time_control

    @model_validator(mode="after")
    def validate_ai_difficulty(self) -> "CreateGameRequest":
        if not self.is_vs_ai:
            self.ai_difficulty = None

        if self.is_vs_ai and self.ai_difficulty is None:
            self.ai_difficulty = DifficultyLevel.MEDIUM

        return self


class MakeMoveRequest(BaseModel):
    uci: str  # ex: e2e4, g1f3, e7e8q

    @field_validator("uci")
    @classmethod
    def validate_uci(cls, value: str) -> str:
        uci = value.lower().strip()

        if not re.fullmatch(r"^[a-h][1-8][a-h][1-8][qrbn]?$", uci):
            raise ValueError("Format UCI invalide. Exemple : e2e4, g1f3, e7e8q")

        return uci


class MoveResponse(BaseModel):
    uci: str
    san: str
    fen: str
    evaluation: Optional[float] = None
    is_check: bool = False
    is_checkmate: bool = False
    is_draw: bool = False


class MoveWithAIResponse(MoveResponse):
    ai_move: Optional[MoveResponse] = None


class GameResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    status: GameStatus
    result: Optional[GameResult] = None
    current_fen: str
    pgn: str
    is_vs_ai: bool
    ai_difficulty: Optional[DifficultyLevel] = None
    white_player_id: str
    black_player_id: Optional[str] = None
    time_control: str
    created_at: datetime
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None


class HintResponse(BaseModel):
    best_move: str
    evaluation: float
    depth: int
    best_line: list[str]

    @field_validator("best_move")
    @classmethod
    def validate_best_move(cls, value: str) -> str:
        move = value.lower().strip()

        if not re.fullmatch(r"^[a-h][1-8][a-h][1-8][qrbn]?$", move):
            raise ValueError("Format UCI invalide pour best_move")

        return move