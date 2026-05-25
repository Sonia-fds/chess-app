import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# ─────────────────────────────────────────────
# PYTHON PATH
# ─────────────────────────────────────────────

# Permet à pytest de trouver le package local "app"
BACKEND_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_ROOT))


# ─────────────────────────────────────────────
# ENV TEST
# ─────────────────────────────────────────────

# Important : à définir avant d'importer app.database / app.main
os.environ["APP_ENV"] = "test"
os.environ["REQUIRE_EMAIL_VERIFICATION"] = "false"
os.environ["SECRET_KEY"] = "test-secret-key"


from app.database import Base, get_db  # noqa: E402
import app.models  # noqa: F401, E402
from app.main import app  # noqa: E402
from app.models import User  # noqa: E402
from app.services.auth_service import AuthService  # noqa: E402


# ─────────────────────────────────────────────
# DATABASE TEST
# ─────────────────────────────────────────────

TEST_DATABASE_URL = "sqlite:///./test_chess.db"

engine_test = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
)

TestingSessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine_test,
)


def override_get_db():
    db = TestingSessionLocal()

    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(autouse=True)
def setup_db():
    Base.metadata.drop_all(bind=engine_test)
    Base.metadata.create_all(bind=engine_test)

    yield

    Base.metadata.drop_all(bind=engine_test)


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def db():
    db = TestingSessionLocal()

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def verified_user(db):
    user = User(
        email="alice@example.com",
        username="alice",
        hashed_password=AuthService.hash_password("Password1!"),
        elo_rating=1200,
        email_verified=True,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


@pytest.fixture
def auth_token(verified_user):
    return AuthService.create_token(
        user_id=verified_user.id,
        username=verified_user.username,
    )


@pytest.fixture
def auth_headers(auth_token):
    return {
        "Authorization": f"Bearer {auth_token}",
    }