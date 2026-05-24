import os
import secrets
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User


# ─────────────────────────────────────────────
# CONFIG JWT
# ─────────────────────────────────────────────

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"
TOKEN_EXPIRE_DAYS = int(os.getenv("TOKEN_EXPIRE_DAYS", "7"))

# Pour le MVP, mets REQUIRE_EMAIL_VERIFICATION=false dans .env
REQUIRE_EMAIL_VERIFICATION = (
    os.getenv("REQUIRE_EMAIL_VERIFICATION", "false").lower() == "true"
)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


# ─────────────────────────────────────────────
# AUTH SERVICE
# ─────────────────────────────────────────────

class AuthService:
    # ── MOT DE PASSE ────────────────────────

    @staticmethod
    def hash_password(password: str) -> str:
        salt = bcrypt.gensalt(rounds=12)
        return bcrypt.hashpw(password.encode("utf-8"), salt).decode("utf-8")

    @staticmethod
    def verify_password(password: str, hashed: str) -> bool:
        try:
            return bcrypt.checkpw(
                password.encode("utf-8"),
                hashed.encode("utf-8"),
            )
        except ValueError:
            return False

    # ── JWT ─────────────────────────────────

    @staticmethod
    def create_token(user_id: str, username: str) -> str:
        now = datetime.now(timezone.utc)

        payload = {
            "sub": user_id,
            "username": username,
            "iat": now,
            "exp": now + timedelta(days=TOKEN_EXPIRE_DAYS),
        }

        return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

    @staticmethod
    def decode_token(token: str) -> dict:
        try:
            return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        except JWTError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token invalide ou expiré",
                headers={"WWW-Authenticate": "Bearer"},
            )

    # ── REGISTER ────────────────────────────

    @staticmethod
    def register(
        email: str,
        username: str,
        password: str,
        db: Session,
    ) -> User:
        normalized_email = email.lower().strip()
        normalized_username = username.strip()

        existing_email = (
            db.query(User)
            .filter(User.email == normalized_email)
            .first()
        )

        if existing_email:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Cet email est déjà utilisé",
            )

        existing_username = (
            db.query(User)
            .filter(User.username == normalized_username)
            .first()
        )

        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Ce pseudo est déjà pris",
            )

        verify_token = secrets.token_urlsafe(32)

        user = User(
            id=str(uuid.uuid4()),
            email=normalized_email,
            username=normalized_username,
            hashed_password=AuthService.hash_password(password),
            elo_rating=1200,
            email_verified=not REQUIRE_EMAIL_VERIFICATION,
            verify_token=verify_token if REQUIRE_EMAIL_VERIFICATION else None,
        )

        db.add(user)
        db.commit()
        db.refresh(user)

        return user

    # ── LOGIN ───────────────────────────────

    @staticmethod
    def login(email: str, password: str, db: Session) -> tuple[User, str]:
        normalized_email = email.lower().strip()

        error = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants incorrects",
            headers={"WWW-Authenticate": "Bearer"},
        )

        user = (
            db.query(User)
            .filter(User.email == normalized_email)
            .first()
        )

        if not user:
            raise error

        if not AuthService.verify_password(password, user.hashed_password):
            raise error

        if REQUIRE_EMAIL_VERIFICATION and not user.email_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Email non confirmé — vérifiez votre boîte mail",
            )

        token = AuthService.create_token(user.id, user.username)

        return user, token

    # ── VERIFY EMAIL ────────────────────────

    @staticmethod
    def verify_email(token: str, db: Session) -> User:
        user = (
            db.query(User)
            .filter(User.verify_token == token)
            .first()
        )

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Token de vérification invalide",
            )

        user.email_verified = True
        user.verify_token = None

        db.commit()
        db.refresh(user)

        return user


# ─────────────────────────────────────────────
# DEPENDENCY — UTILISATEUR CONNECTÉ
# ─────────────────────────────────────────────

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    payload = AuthService.decode_token(token)
    user_id = payload.get("sub")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token invalide",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utilisateur introuvable",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user