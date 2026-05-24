from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User
from app.schemas import LoginRequest, RegisterRequest, TokenResponse, UserResponse
from app.services.auth_service import AuthService, get_current_user
from fastapi.security import OAuth2PasswordRequestForm

router = APIRouter()


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer un compte",
)
def register(
    body: RegisterRequest,
    db: Session = Depends(get_db),
):
    user = AuthService.register(
        email=body.email,
        username=body.username,
        password=body.password,
        db=db,
    )

    return user


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Se connecter",
)
def login(
    body: LoginRequest,
    db: Session = Depends(get_db),
):
    user, token = AuthService.login(
        email=body.email,
        password=body.password,
        db=db,
    )

    return TokenResponse(
        access_token=token,
        user_id=user.id,
        username=user.username,
        elo_rating=user.elo_rating,
    )

@router.post(
    "/token",
    response_model=TokenResponse,
    summary="Se connecter via Swagger OAuth2",
)
def swagger_login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user, token = AuthService.login(
        email=form_data.username,
        password=form_data.password,
        db=db,
    )

    return TokenResponse(
        access_token=token,
        user_id=user.id,
        username=user.username,
        elo_rating=user.elo_rating,
    )
    
@router.get(
    "/verify/{token}",
    summary="Vérifier l'email",
)
def verify_email(
    token: str,
    db: Session = Depends(get_db),
):
    user = AuthService.verify_email(token, db)

    return {
        "message": f"Email de {user.username} vérifié avec succès",
    }


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Profil de l'utilisateur connecté",
)
def me(
    current_user: User = Depends(get_current_user),
):
    return current_user