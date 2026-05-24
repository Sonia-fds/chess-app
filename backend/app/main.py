from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.database import Base, engine
import app.models  # noqa: F401
from app.routers import auth, game


# ─────────────────────────────────────────────
# LIFESPAN — création des tables au démarrage
# ─────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


# ─────────────────────────────────────────────
# APP
# ─────────────────────────────────────────────

app = FastAPI(
    title="Chess App API",
    version="0.1.0",
    description="Backend FastAPI pour l'application d'échecs",
    lifespan=lifespan,
)


# ─────────────────────────────────────────────
# CORS
# ─────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8080",
        "http://localhost:8081",
        "http://localhost:18368",
        "http://127.0.0.1:18368",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ─────────────────────────────────────────────
# ROUTERS
# ─────────────────────────────────────────────

app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(game.router, prefix="/game", tags=["Game"])


# ─────────────────────────────────────────────
# HEALTH CHECK
# ─────────────────────────────────────────────

@app.get("/health")
def health():
    return {
        "status": "ok",
        "version": "0.1.0",
        "service": "Chess App API",
    }