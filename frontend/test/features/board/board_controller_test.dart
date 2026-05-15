import 'package:chess/chess.dart' as ch;
import 'package:chess_app/features/board/board_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ═══════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════
  group('BoardController — initialisation', () {
    test('commence avec la position de départ', () {
      final controller = BoardController();

      expect(
        controller.fen,
        startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR'),
      );
    });

    test('commence avec les blancs au trait', () {
      final controller = BoardController();

      expect(controller.isWhiteTurn, isTrue);
    });

    test('accepte une FEN personnalisée', () {
      const fen = '4k3/8/8/8/8/8/4K3/8 w - - 0 1';
      final controller = BoardController(fen: fen);

      expect(controller.fen, startsWith('4k3/8/8/8/8/8/4K3/8'));
    });

    test('démarre sans sélection', () {
      final controller = BoardController();

      expect(controller.selectedSquare, isNull);
      expect(controller.legalMovesForSelected, isEmpty);
    });

    test('démarre sans historique', () {
      final controller = BoardController();

      expect(controller.moveHistory, isEmpty);
    });

    test('démarre sans fin de partie', () {
      final controller = BoardController();

      expect(controller.gameEnd, isNull);
      expect(controller.isGameOver, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════
  // BOARD SQUARE
  // ═══════════════════════════════════════════════════
  group('BoardSquare', () {
    test('convertit correctement en notation algébrique', () {
      expect(const BoardSquare(0, 0).algebraic, 'a1');
      expect(const BoardSquare(4, 3).algebraic, 'e4');
      expect(const BoardSquare(7, 7).algebraic, 'h8');
      expect(const BoardSquare(4, 7).algebraic, 'e8');
    });

    test('compare correctement deux cases identiques', () {
      expect(const BoardSquare(4, 3), equals(const BoardSquare(4, 3)));
    });

    test('compare correctement deux cases différentes', () {
      expect(const BoardSquare(0, 0), isNot(equals(const BoardSquare(1, 0))));
    });

    test('toString retourne la notation algébrique', () {
      expect(const BoardSquare(4, 3).toString(), 'e4');
    });
  });

  // ═══════════════════════════════════════════════════
  // PIÈCES SUR L'ÉCHIQUIER
  // ═══════════════════════════════════════════════════
  group('BoardController — pièces', () {
    test('retourne les pièces en position initiale', () {
      final controller = BoardController();

      final rookA1 = controller.pieceAt(const BoardSquare(0, 0));
      expect(rookA1, isNotNull);
      expect(rookA1!.type, ch.PieceType.ROOK);
      expect(rookA1.color, ch.Color.WHITE);

      final kingE1 = controller.pieceAt(const BoardSquare(4, 0));
      expect(kingE1, isNotNull);
      expect(kingE1!.type, ch.PieceType.KING);
      expect(kingE1.color, ch.Color.WHITE);

      final queenD8 = controller.pieceAt(const BoardSquare(3, 7));
      expect(queenD8, isNotNull);
      expect(queenD8!.type, ch.PieceType.QUEEN);
      expect(queenD8.color, ch.Color.BLACK);
    });

    test('retourne null pour une case vide', () {
      final controller = BoardController();

      expect(controller.pieceAt(const BoardSquare(4, 3)), isNull);
    });

    test('retourne null pour une case invalide', () {
      final controller = BoardController();

      expect(controller.pieceAt(const BoardSquare(-1, 0)), isNull);
      expect(controller.pieceAt(const BoardSquare(8, 8)), isNull);
    });

    test('allPieces retourne 32 pièces en position initiale', () {
      final controller = BoardController();

      expect(controller.allPieces.length, 32);
    });
  });

  // ═══════════════════════════════════════════════════
  // SÉLECTION
  // ═══════════════════════════════════════════════════
  group('BoardController — sélection', () {
    test('sélectionne une pièce du joueur actif', () {
      final controller = BoardController();
      const e2 = BoardSquare(4, 1);

      controller.onSquareTapped(e2);

      expect(controller.selectedSquare, equals(e2));
      expect(controller.legalMovesForSelected, isNotEmpty);
    });

    test('ne sélectionne pas une pièce adverse', () {
      final controller = BoardController();
      const e7 = BoardSquare(4, 6);

      controller.onSquareTapped(e7);

      expect(controller.selectedSquare, isNull);
    });

    test('désélectionne si on tape sur la même case', () {
      final controller = BoardController();
      const e2 = BoardSquare(4, 1);

      controller.onSquareTapped(e2);
      expect(controller.selectedSquare, equals(e2));

      controller.onSquareTapped(e2);
      expect(controller.selectedSquare, isNull);
      expect(controller.legalMovesForSelected, isEmpty);
    });

    test('change de sélection si on tape sur une autre pièce alliée', () {
      final controller = BoardController();
      const e2 = BoardSquare(4, 1);
      const d2 = BoardSquare(3, 1);

      controller.onSquareTapped(e2);
      expect(controller.selectedSquare, equals(e2));

      controller.onSquareTapped(d2);
      expect(controller.selectedSquare, equals(d2));
    });

    test('désélectionne si on tape sur une destination illégale', () {
      final controller = BoardController();
      const e2 = BoardSquare(4, 1);
      const e6 = BoardSquare(4, 5);

      controller.onSquareTapped(e2);
      controller.onSquareTapped(e6);

      expect(controller.selectedSquare, isNull);
      expect(controller.legalMovesForSelected, isEmpty);
    });

    test('ne fait rien si case vide sélectionnée sans pièce active', () {
      final controller = BoardController();
      const e4 = BoardSquare(4, 3);

      controller.onSquareTapped(e4);

      expect(controller.selectedSquare, isNull);
      expect(controller.legalMovesForSelected, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════
  // COUPS LÉGAUX
  // ═══════════════════════════════════════════════════
  group('BoardController — coups légaux', () {
    test('pion en e2 a e3 et e4 comme coups légaux', () {
      final controller = BoardController();

      controller.onSquareTapped(const BoardSquare(4, 1));

      final moves = controller.legalMovesForSelected;
      expect(moves, contains(const BoardSquare(4, 2)));
      expect(moves, contains(const BoardSquare(4, 3)));
    });

    test('cavalier en g1 a f3 et h3 comme coups légaux', () {
      final controller = BoardController();

      controller.onSquareTapped(const BoardSquare(6, 0));

      final moves = controller.legalMovesForSelected;
      expect(moves, contains(const BoardSquare(5, 2)));
      expect(moves, contains(const BoardSquare(7, 2)));
    });

    test('roi en e1 n a aucun coup légal en position initiale', () {
      final controller = BoardController();

      controller.onSquareTapped(const BoardSquare(4, 0));

      expect(controller.legalMovesForSelected, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════
  // JOUER UN COUP
  // ═══════════════════════════════════════════════════
  group('BoardController — jouer un coup', () {
    test('joue e2-e4 correctement', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');

      expect(controller.pieceAt(const BoardSquare(4, 3)), isNotNull);
      expect(controller.pieceAt(const BoardSquare(4, 1)), isNull);
    });

    test('passe aux noirs après un coup blanc', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');

      expect(controller.isWhiteTurn, isFalse);
    });

    test('ajoute le coup à l historique', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');

      expect(controller.moveHistory.length, 1);
      expect(controller.moveHistory.first.isWhite, isTrue);
      expect(controller.moveHistory.first.moveNumber, 1);
    });

    test('joue deux coups et alterne les tours', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');
      playMove(controller, 'e7', 'e5');

      expect(controller.moveHistory.length, 2);
      expect(controller.moveHistory[0].isWhite, isTrue);
      expect(controller.moveHistory[1].isWhite, isFalse);
      expect(controller.isWhiteTurn, isTrue);
    });

    test('désélectionne après avoir joué', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');

      expect(controller.selectedSquare, isNull);
      expect(controller.legalMovesForSelected, isEmpty);
    });

    test('ne joue pas un coup illégal', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e6');

      expect(controller.pieceAt(const BoardSquare(4, 1)), isNotNull);
      expect(controller.pieceAt(const BoardSquare(4, 5)), isNull);
      expect(controller.moveHistory, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════
  // ROQUE
  // ═══════════════════════════════════════════════════
  group('BoardController — roque', () {
    const fenCastlingReady = 'r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1';

    test('petit roque blanc disponible', () {
      final controller = BoardController(fen: fenCastlingReady);

      controller.onSquareTapped(const BoardSquare(4, 0));

      expect(controller.legalMovesForSelected, contains(const BoardSquare(6, 0)));
    });

    test('grand roque blanc disponible', () {
      final controller = BoardController(fen: fenCastlingReady);

      controller.onSquareTapped(const BoardSquare(4, 0));

      expect(controller.legalMovesForSelected, contains(const BoardSquare(2, 0)));
    });

    test('petit roque déplace le roi en g1', () {
      final controller = BoardController(fen: fenCastlingReady);

      playMove(controller, 'e1', 'g1');

      final king = controller.pieceAt(const BoardSquare(6, 0));
      expect(king, isNotNull);
      expect(king!.type, ch.PieceType.KING);
      expect(king.color, ch.Color.WHITE);
    });
  });

  // ═══════════════════════════════════════════════════
  // EN PASSANT
  // ═══════════════════════════════════════════════════
  group('BoardController — en passant', () {
    test('capture en passant disponible après double-pas adverse', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');
      playMove(controller, 'a7', 'a6');
      playMove(controller, 'e4', 'e5');
      playMove(controller, 'd7', 'd5');

      controller.onSquareTapped(const BoardSquare(4, 4));

      expect(controller.legalMovesForSelected, contains(const BoardSquare(3, 5)));
    });
  });

  // ═══════════════════════════════════════════════════
  // PROMOTION
  // ═══════════════════════════════════════════════════
  group('BoardController — promotion', () {
    const fenPromotion = '7k/P7/8/8/8/8/8/7K w - - 0 1';

    test('déclenche l attente de promotion', () {
      final controller = BoardController(fen: fenPromotion);

      playMove(controller, 'a7', 'a8');

      expect(controller.awaitingPromotion, isTrue);
      expect(controller.moveHistory, isEmpty);
    });

    test('résout la promotion en dame', () {
      final controller = BoardController(fen: fenPromotion);

      playMove(controller, 'a7', 'a8');
      controller.resolvePromotion(ch.PieceType.QUEEN);

      final piece = controller.pieceAt(const BoardSquare(0, 7));
      expect(piece, isNotNull);
      expect(piece!.type, ch.PieceType.QUEEN);
      expect(piece.color, ch.Color.WHITE);
      expect(controller.awaitingPromotion, isFalse);
      expect(controller.moveHistory.length, 1);
    });

    test('résout la promotion en cavalier', () {
      final controller = BoardController(fen: fenPromotion);

      playMove(controller, 'a7', 'a8');
      controller.resolvePromotion(ch.PieceType.KNIGHT);

      final piece = controller.pieceAt(const BoardSquare(0, 7));
      expect(piece, isNotNull);
      expect(piece!.type, ch.PieceType.KNIGHT);
    });
  });

  // ═══════════════════════════════════════════════════
  // ÉCHEC
  // ═══════════════════════════════════════════════════
  group('BoardController — échec', () {
    test('détecte le roi en échec', () {
      const fenCheck = '4k3/8/8/8/8/8/8/4K2q w - - 0 1';
      final controller = BoardController(fen: fenCheck);

      expect(controller.isInCheck, isTrue);
    });

    test('position normale n est pas en échec', () {
      final controller = BoardController();

      expect(controller.isInCheck, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════
  // FIN DE PARTIE
  // ═══════════════════════════════════════════════════
  group('BoardController — fin de partie', () {
    test('détecte un échec et mat avec le mat du sot', () {
      final controller = BoardController();

      playMove(controller, 'f2', 'f3');
      playMove(controller, 'e7', 'e5');
      playMove(controller, 'g2', 'g4');
      playMove(controller, 'd8', 'h4');

      expect(controller.isGameOver, isTrue);
      expect(controller.gameEnd, isNotNull);
      expect(controller.gameEnd!.reason, GameEndReason.checkmate);
      expect(controller.gameEnd!.whiteWins, isFalse);
    });

    test('game_over est false en position normale', () {
      final controller = BoardController();

      expect(controller.isGameOver, isFalse);
    });

    test('declareDraw met fin à la partie', () {
      final controller = BoardController();

      controller.declareDraw();

      expect(controller.isGameOver, isTrue);
      expect(controller.gameEnd, isNotNull);
      expect(controller.gameEnd!.reason, GameEndReason.draw);
      expect(controller.gameEnd!.whiteWins, isNull);
    });

    test('resign met fin à la partie et donne la victoire à l adversaire', () {
      final controller = BoardController();

      controller.resign(whiteResigned: true);

      expect(controller.isGameOver, isTrue);
      expect(controller.gameEnd, isNotNull);
      expect(controller.gameEnd!.reason, GameEndReason.resignation);
      expect(controller.gameEnd!.whiteWins, isFalse);
    });

    test('ne joue pas de coup après fin de partie', () {
      final controller = BoardController();

      controller.declareDraw();
      controller.onSquareTapped(const BoardSquare(4, 1));

      expect(controller.selectedSquare, isNull);
      expect(controller.moveHistory, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════
  // HISTORIQUE
  // ═══════════════════════════════════════════════════
  group('BoardController — historique', () {
   test('historique immutable', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');
      final history = controller.moveHistory;

      const fakeMove = ChessMove(
        san: 'e4',
        uci: 'e2e4',
        moveNumber: 1,
        isWhite: true,
      );

      expect(() => history.add(fakeMove), throwsUnsupportedError);
    });

    test('numéro de coup correct', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');
      playMove(controller, 'e7', 'e5');

      expect(controller.moveHistory[0].moveNumber, 1);
      expect(controller.moveHistory[1].moveNumber, 1);
    });

    test('isWhite correct dans l historique', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');
      playMove(controller, 'e7', 'e5');

      expect(controller.moveHistory[0].isWhite, isTrue);
      expect(controller.moveHistory[1].isWhite, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════
  // RESET
  // ═══════════════════════════════════════════════════
  group('BoardController — reset', () {
    test('reset remet la position de départ', () {
      final controller = BoardController();

      playMove(controller, 'e2', 'e4');
      controller.reset();

      expect(
        controller.fen,
        startsWith('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR'),
      );
      expect(controller.moveHistory, isEmpty);
      expect(controller.selectedSquare, isNull);
      expect(controller.gameEnd, isNull);
      expect(controller.isWhiteTurn, isTrue);
    });

    test('reset conserve la FEN initiale personnalisée', () {
      const fen = '7k/P7/8/8/8/8/8/7K w - - 0 1';
      final controller = BoardController(fen: fen);

      playMove(controller, 'a7', 'a8');
      controller.resolvePromotion(ch.PieceType.QUEEN);
      controller.reset();

      expect(controller.fen, startsWith('7k/P7/8/8/8/8/8/7K'));
      expect(controller.moveHistory, isEmpty);
      expect(controller.awaitingPromotion, isFalse);
    });

    test('reset après fin de partie relance correctement', () {
      final controller = BoardController();

      controller.declareDraw();
      expect(controller.isGameOver, isTrue);

      controller.reset();
      expect(controller.isGameOver, isFalse);
      expect(controller.gameEnd, isNull);
    });
  });
}

// ─────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────

void playMove(BoardController controller, String from, String to) {
  controller.onSquareTapped(square(from));
  controller.onSquareTapped(square(to));
}

BoardSquare square(String algebraic) {
  const files = 'abcdefgh';

  if (algebraic.length != 2) {
    throw ArgumentError('Notation invalide : $algebraic');
  }

  final col = files.indexOf(algebraic[0]);
  final rank = int.tryParse(algebraic[1]);

  if (col < 0 || rank == null || rank < 1 || rank > 8) {
    throw ArgumentError('Notation invalide : $algebraic');
  }

  return BoardSquare(col, rank - 1);
}
