import os
from collections.abc import Generator

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

load_dotenv()


# ─────────────────────────────────────────────
# CONFIGURATION DATABASE
# ─────────────────────────────────────────────

APP_ENV = os.getenv("APP_ENV", "development")

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite:///./dev.db",  # plus simple pour commencer localement
)

TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "sqlite:///./test.db",
)

active_database_url = TEST_DATABASE_URL if APP_ENV == "test" else DATABASE_URL


# ─────────────────────────────────────────────
# SQLALCHEMY BASE
# ─────────────────────────────────────────────

class Base(DeclarativeBase):
    pass


# ─────────────────────────────────────────────
# ENGINE & SESSION
# ─────────────────────────────────────────────

connect_args = {}

if active_database_url.startswith("sqlite"):
    connect_args = {"check_same_thread": False}

engine = create_engine(
    active_database_url,
    pool_pre_ping=True,
    connect_args=connect_args,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)


# ─────────────────────────────────────────────
# DEPENDENCY FASTAPI
# ─────────────────────────────────────────────

def get_db() -> Generator[Session, None, None]:
    """
    Fournit une session de base de données pour une requête FastAPI,
    puis ferme la session après la requête.
    """
    db = SessionLocal()

    try:
        yield db
    finally:
        db.close()