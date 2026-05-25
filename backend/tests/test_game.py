from unittest.mock import MagicMock, patch

import chess
import pytest
from fastapi.testclient import TestClient

from app.services.game_service import _k_factor, _new_elo


class TestCreateGame:
    def test_create_game_vs_ai_white(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
                "ai_difficulty": "MEDIUM",
                "player_color": "white",
                "time_control": "10+0",
            },
            headers=auth_headers,
        )

        assert response.status_code == 201

        data = response.json()

        assert data["is_vs_ai"] is True
        assert data["status"] == "IN_PROGRESS"
        assert data["ai_difficulty"] == "MEDIUM"

        # Le joueur a choisi les blancs.
        assert data["white_player_id"] is not None
        assert data["black_player_id"] is None

        assert "rnbqkbnr" in data["current_fen"]

    def test_create_game_vs_ai_black_calls_ai_first(
        self,
        client: TestClient,
        auth_headers,
    ):
        with patch("app.services.game_service._best_move") as mock_best_move:
            mock_best_move.return_value = chess.Move.from_uci("e2e4")

            response = client.post(
                "/game/create",
                json={
                    "is_vs_ai": True,
                    "ai_difficulty": "EASY",
                    "player_color": "black",
                    "time_control": "10+0",
                },
                headers=auth_headers,
            )

        assert response.status_code == 201

        data = response.json()

        assert data["is_vs_ai"] is True
        assert data["status"] == "IN_PROGRESS"

        # Le joueur a choisi les noirs, donc l'IA joue les blancs.
        assert data["white_player_id"] is None
        assert data["black_player_id"] is not None

        # Après e2e4, la FEN contient "4P3", pas "e4".
        assert data["current_fen"].startswith(
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b"
        )

        mock_best_move.assert_called_once()

    def test_create_game_unauthenticated(self, client: TestClient):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
            },
        )

        assert response.status_code == 401

    def test_create_game_invalid_color(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
                "player_color": "rouge",
            },
            headers=auth_headers,
        )

        assert response.status_code == 422

    def test_create_game_random_color(
        self,
        client: TestClient,
        auth_headers,
    ):
        with patch("app.services.game_service.random.choice") as mock_choice:
            mock_choice.return_value = "white"

            response = client.post(
                "/game/create",
                json={
                    "is_vs_ai": True,
                    "player_color": "random",
                },
                headers=auth_headers,
            )

        assert response.status_code == 201
        assert response.json()["status"] == "IN_PROGRESS"

    def test_create_game_human_vs_human_waiting(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": False,
                "ai_difficulty": None,
                "player_color": "white",
                "time_control": "10+0",
            },
            headers=auth_headers,
        )

        assert response.status_code == 201

        data = response.json()

        assert data["is_vs_ai"] is False
        assert data["status"] == "WAITING"
        assert data["ai_difficulty"] is None

    def test_create_game_returns_id(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
                "player_color": "white",
            },
            headers=auth_headers,
        )

        assert response.status_code == 201
        assert "id" in response.json()


class TestGetGame:
    def test_get_existing_game(
        self,
        client: TestClient,
        auth_headers,
    ):
        create_response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
                "player_color": "white",
            },
            headers=auth_headers,
        )

        game_id = create_response.json()["id"]

        response = client.get(
            f"/game/{game_id}",
            headers=auth_headers,
        )

        assert response.status_code == 200
        assert response.json()["id"] == game_id

    def test_get_nonexistent_game(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.get(
            "/game/id-inexistant",
            headers=auth_headers,
        )

        assert response.status_code == 404

    def test_get_game_unauthenticated(self, client: TestClient):
        response = client.get("/game/id-inexistant")

        assert response.status_code == 401


class TestMakeMove:
    @pytest.fixture
    def game_id(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
                "player_color": "white",
                "ai_difficulty": "MEDIUM",
            },
            headers=auth_headers,
        )

        assert response.status_code == 201

        return response.json()["id"]

    def test_make_move_e2e4(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        with patch("app.services.game_service._best_move") as mock_best_move:
            mock_best_move.return_value = chess.Move.from_uci("e7e5")

            response = client.post(
                f"/game/{game_id}/move",
                json={
                    "uci": "e2e4",
                },
                headers=auth_headers,
            )

        assert response.status_code == 200

        data = response.json()

        assert data["uci"] == "e2e4"
        assert data["san"] == "e4"
        assert data["ai_move"] is not None
        assert data["ai_move"]["uci"] == "e7e5"

    def test_make_move_illegal(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        response = client.post(
            f"/game/{game_id}/move",
            json={
                "uci": "e2e5",
            },
            headers=auth_headers,
        )

        assert response.status_code == 400
        assert "illégal" in response.json()["detail"].lower()

    def test_make_move_invalid_uci_format(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        response = client.post(
            f"/game/{game_id}/move",
            json={
                "uci": "xyz",
            },
            headers=auth_headers,
        )

        assert response.status_code == 422

    def test_make_move_game_not_found(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/id-inexistant/move",
            json={
                "uci": "e2e4",
            },
            headers=auth_headers,
        )

        assert response.status_code == 404

    def test_make_move_unauthenticated(
        self,
        client: TestClient,
        game_id,
    ):
        response = client.post(
            f"/game/{game_id}/move",
            json={
                "uci": "e2e4",
            },
        )

        assert response.status_code == 401

    def test_move_sequence(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        player_moves = ["e2e4", "d2d4", "g1f3"]
        ai_moves = ["e7e5", "d7d5", "g8f6"]

        for player_uci, ai_uci in zip(player_moves, ai_moves):
            with patch("app.services.game_service._best_move") as mock_best_move:
                mock_best_move.return_value = chess.Move.from_uci(ai_uci)

                response = client.post(
                    f"/game/{game_id}/move",
                    json={
                        "uci": player_uci,
                    },
                    headers=auth_headers,
                )

            assert response.status_code == 200

    def test_make_move_without_stockfish_returns_503(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        with patch("app.services.game_service._best_move") as mock_best_move:
            from fastapi import HTTPException, status

            mock_best_move.side_effect = HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Moteur Stockfish indisponible",
            )

            response = client.post(
                f"/game/{game_id}/move",
                json={
                    "uci": "e2e4",
                },
                headers=auth_headers,
            )

        assert response.status_code == 503
        assert "stockfish" in response.json()["detail"].lower()


class TestHint:
    @pytest.fixture
    def game_id(
        self,
        client: TestClient,
        auth_headers,
    ):
        response = client.post(
            "/game/create",
            json={
                "is_vs_ai": True,
                "player_color": "white",
                "ai_difficulty": "MEDIUM",
            },
            headers=auth_headers,
        )

        assert response.status_code == 201

        return response.json()["id"]

    def test_get_hint(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        with patch("app.services.game_service._analyze") as mock_analyze:
            mock_info = {
                "pv": [chess.Move.from_uci("e2e4")],
                "score": MagicMock(
                    relative=MagicMock(
                        score=MagicMock(return_value=30),
                    ),
                ),
            }

            mock_analyze.return_value = mock_info

            response = client.get(
                f"/game/{game_id}/hint",
                headers=auth_headers,
            )

        assert response.status_code == 200

        data = response.json()

        assert data["best_move"] == "e2e4"
        assert data["evaluation"] == 0.3
        assert data["best_line"] == ["e2e4"]

    def test_get_hint_custom_depth(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        with patch("app.services.game_service._analyze") as mock_analyze:
            mock_analyze.return_value = {
                "pv": [chess.Move.from_uci("e2e4")],
                "score": MagicMock(
                    relative=MagicMock(
                        score=MagicMock(return_value=0),
                    ),
                ),
            }

            response = client.get(
                f"/game/{game_id}/hint?depth=20",
                headers=auth_headers,
            )

        assert response.status_code == 200

    def test_get_hint_depth_too_high(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        response = client.get(
            f"/game/{game_id}/hint?depth=99",
            headers=auth_headers,
        )

        assert response.status_code == 422

    def test_get_hint_unauthenticated(
        self,
        client: TestClient,
        game_id,
    ):
        response = client.get(f"/game/{game_id}/hint")

        assert response.status_code == 401

    def test_get_hint_stockfish_unavailable(
        self,
        client: TestClient,
        auth_headers,
        game_id,
    ):
        with patch("app.services.game_service._analyze") as mock_analyze:
            from fastapi import HTTPException, status

            mock_analyze.side_effect = HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Moteur Stockfish indisponible",
            )

            response = client.get(
                f"/game/{game_id}/hint",
                headers=auth_headers,
            )

        assert response.status_code == 503
        assert "stockfish" in response.json()["detail"].lower()


class TestEloCalculation:
    def test_elo_victory_equal_players(self):
        result = _new_elo(1200, 1200, 1.0)

        assert result > 1200

    def test_elo_defeat_equal_players(self):
        result = _new_elo(1200, 1200, 0.0)

        assert result < 1200

    def test_elo_draw_equal_players(self):
        result = _new_elo(1200, 1200, 0.5)

        assert result == 1200

    def test_elo_upset_victory(self):
        result = _new_elo(800, 2000, 1.0)

        assert result > 830

    def test_elo_expected_loss(self):
        result = _new_elo(2000, 800, 0.0)

        assert result < 1995

    def test_k_factor_beginner(self):
        assert _k_factor(800) == 40

    def test_k_factor_intermediate(self):
        assert _k_factor(1500) == 20

    def test_k_factor_expert(self):
        assert _k_factor(2200) == 10