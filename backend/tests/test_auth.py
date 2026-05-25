import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models import User
from app.services.auth_service import AuthService


class TestRegister:
    def test_register_success(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={
                "email": "bob@example.com",
                "username": "bob",
                "password": "Password1!",
            },
        )

        assert response.status_code == 201

        data = response.json()

        assert data["email"] == "bob@example.com"
        assert data["username"] == "bob"
        assert data["elo_rating"] == 1200
        assert data["email_verified"] is True
        assert "id" in data
        assert "hashed_password" not in data

    def test_register_duplicate_email(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/register",
            json={
                "email": "alice@example.com",
                "username": "alice2",
                "password": "Password1!",
            },
        )

        assert response.status_code == 409
        assert "email" in response.json()["detail"].lower()

    def test_register_duplicate_username(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/register",
            json={
                "email": "alice2@example.com",
                "username": "alice",
                "password": "Password1!",
            },
        )

        assert response.status_code == 409
        assert "pseudo" in response.json()["detail"].lower()

    def test_register_invalid_email(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={
                "email": "pas-un-email",
                "username": "user",
                "password": "Password1!",
            },
        )

        assert response.status_code == 422

    def test_register_password_too_short(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={
                "email": "user@example.com",
                "username": "user",
                "password": "abc",
            },
        )

        assert response.status_code == 422

    def test_register_username_too_short(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={
                "email": "user@example.com",
                "username": "ab",
                "password": "Password1!",
            },
        )

        assert response.status_code == 422

    def test_register_username_invalid_chars(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={
                "email": "user@example.com",
                "username": "user!",
                "password": "Password1!",
            },
        )

        assert response.status_code == 422

    def test_register_missing_fields(self, client: TestClient):
        response = client.post(
            "/auth/register",
            json={
                "email": "u@example.com",
            },
        )

        assert response.status_code == 422


class TestLogin:
    def test_login_success(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/login",
            json={
                "email": "alice@example.com",
                "password": "Password1!",
            },
        )

        assert response.status_code == 200

        data = response.json()

        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["username"] == "alice"
        assert data["elo_rating"] == 1200

    def test_login_wrong_password(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/login",
            json={
                "email": "alice@example.com",
                "password": "MauvaisMotDePasse",
            },
        )

        assert response.status_code == 401
        assert response.json()["detail"] == "Identifiants incorrects"

    def test_login_wrong_email(self, client: TestClient):
        response = client.post(
            "/auth/login",
            json={
                "email": "inconnu@example.com",
                "password": "Password1!",
            },
        )

        assert response.status_code == 401
        assert response.json()["detail"] == "Identifiants incorrects"

    def test_login_email_not_verified_allowed_for_mvp(
        self,
        client: TestClient,
        db: Session,
    ):
        user = User(
            email="unverified@example.com",
            username="unverified",
            hashed_password=AuthService.hash_password("Password1!"),
            email_verified=False,
        )

        db.add(user)
        db.commit()

        response = client.post(
            "/auth/login",
            json={
                "email": "unverified@example.com",
                "password": "Password1!",
            },
        )

        assert response.status_code == 200
        assert "access_token" in response.json()

    def test_login_returns_valid_jwt(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/login",
            json={
                "email": "alice@example.com",
                "password": "Password1!",
            },
        )

        token = response.json()["access_token"]
        payload = AuthService.decode_token(token)

        assert payload["sub"] == verified_user.id
        assert payload["username"] == "alice"

    def test_swagger_token_success(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/token",
            data={
                "username": "alice@example.com",
                "password": "Password1!",
            },
        )

        assert response.status_code == 200

        data = response.json()

        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["username"] == "alice"

    def test_swagger_token_wrong_password(
        self,
        client: TestClient,
        verified_user,
    ):
        response = client.post(
            "/auth/token",
            data={
                "username": "alice@example.com",
                "password": "wrong-password",
            },
        )

        assert response.status_code == 401


class TestMe:
    def test_me_authenticated(
        self,
        client: TestClient,
        auth_headers,
        verified_user,
    ):
        response = client.get(
            "/auth/me",
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert response.json()["username"] == "alice"

    def test_me_unauthenticated(self, client: TestClient):
        response = client.get("/auth/me")

        assert response.status_code == 401

    def test_me_invalid_token(self, client: TestClient):
        response = client.get(
            "/auth/me",
            headers={
                "Authorization": "Bearer token-invalide",
            },
        )

        assert response.status_code == 401


class TestAuthService:
    def test_hash_password_is_bcrypt(self):
        hashed = AuthService.hash_password("Password1!")

        assert hashed.startswith("$2b$")

    def test_verify_password_correct(self):
        hashed = AuthService.hash_password("Password1!")

        assert AuthService.verify_password("Password1!", hashed) is True

    def test_verify_password_wrong(self):
        hashed = AuthService.hash_password("Password1!")

        assert AuthService.verify_password("MauvaisMotDePasse", hashed) is False

    def test_two_hashes_are_different(self):
        first_hash = AuthService.hash_password("Password1!")
        second_hash = AuthService.hash_password("Password1!")

        assert first_hash != second_hash

    def test_create_and_decode_token(self):
        token = AuthService.create_token("user-123", "alice")
        payload = AuthService.decode_token(token)

        assert payload["sub"] == "user-123"
        assert payload["username"] == "alice"

    def test_decode_invalid_token_raises(self):
        with pytest.raises(HTTPException) as exc:
            AuthService.decode_token("faux-token")

        assert exc.value.status_code == 401