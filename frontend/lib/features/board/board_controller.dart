import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────
// MODÈLES
// ─────────────────────────────────────────────

/// Représente une case de l'échiquier.
///
/// Convention utilisée :
/// - col : 0 à 7, de a à h
/// - row : 0 à 7, de rangée 1 à rangée 8
class BoardSquare {
  final int col;
  final int row;

  const BoardSquare(this.col, this.row);

  /// Convertit la case en notation algébrique, par exemple e4.
  String get algebraic {
    const files = 'abcdefgh';

    if (col < 0 || col > 7 || row < 0 || row > 7) {
      throw RangeError('Case invalide : col=$col, row=$row');
    }

    return '${files[col]}${row + 1}';
  }

  @override
  bool operator ==(Object other) {
    return other is BoardSquare && other.col == col && other.row == row;
  }

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => algebraic;
}

/// Représente un coup joué.
class ChessMove {
  final String san;
  final String uci;
  final int moveNumber;
  final bool isWhite;
  final bool isCheck;
  final bool isCheckmate;
  final bool isCapture;
  final bool isCastle;
  final bool isPromotion;

  const ChessMove({
    required this.san,
    required this.uci,
    required this.moveNumber,
    required this.isWhite,
    this.isCheck = false,
    this.isCheckmate = false,
    this.isCapture = false,
    this.isCastle = false,
    this.isPromotion = false,
  });
}

/// Raison de fin de partie.
enum GameEndReason {
  checkmate,
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoveRule,
  draw,
  resignation,
}

/// État de fin de partie.
class GameEndState {
  final GameEndReason reason;

  /// true : les blancs gagnent
  /// false : les noirs gagnent
  /// null : partie nulle
  final bool? whiteWins;

  const GameEndState({
    required this.reason,
    this.whiteWins,
  });

  String get message {
    switch (reason) {
      case GameEndReason.checkmate:
        return whiteWins == true
            ? 'Échec et mat — Blancs gagnent !'
            : 'Échec et mat — Noirs gagnent !';
      case GameEndReason.stalemate:
        return 'Pat — Nulle !';
      case GameEndReason.insufficientMaterial:
        return 'Matériel insuffisant — Nulle !';
      case GameEndReason.threefoldRepetition:
        return 'Répétition triple — Nulle !';
      case GameEndReason.fiftyMoveRule:
        return 'Règle des 50 coups — Nulle !';
      case GameEndReason.draw:
        return 'Nulle acceptée !';
      case GameEndReason.resignation:
        return whiteWins == true
            ? 'Abandon — Blancs gagnent !'
            : 'Abandon — Noirs gagnent !';
    }
  }
}

// ─────────────────────────────────────────────
// BOARD CONTROLLER
// ─────────────────────────────────────────────

class BoardController extends ChangeNotifier {
  final String? _initialFen;
  late ch.Chess _chess;

  BoardSquare? _selectedSquare;
  List<BoardSquare> _legalMoves = [];

  final List<ChessMove> _moveHistory = [];
  GameEndState? _gameEnd;

  BoardSquare? _pendingPromotionFrom;
  BoardSquare? _pendingPromotionTo;
  bool _awaitingPromotion = false;

  BoardController({String? fen}) : _initialFen = fen {
    _chess = fen != null ? ch.Chess.fromFEN(fen) : ch.Chess();
  }

  // ─── GETTERS ────────────────────────────────

  String get fen => _chess.fen;

  bool get isWhiteTurn => _chess.turn == ch.Color.WHITE;

  bool get isInCheck => _chess.in_check;

  bool get isGameOver => _chess.game_over || _gameEnd != null;

  GameEndState? get gameEnd => _gameEnd;

  List<ChessMove> get moveHistory => List.unmodifiable(_moveHistory);

  BoardSquare? get selectedSquare => _selectedSquare;

  List<BoardSquare> get legalMovesForSelected =>
      List.unmodifiable(_legalMoves);

  bool get awaitingPromotion => _awaitingPromotion;

  /// Retourne la pièce sur une case.
  ch.Piece? pieceAt(BoardSquare square) {
    if (!_isValidSquare(square)) return null;
    return _chess.get(square.algebraic);
  }

  /// Toutes les pièces indexées par case.
  Map<BoardSquare, ch.Piece> get allPieces {
    final pieces = <BoardSquare, ch.Piece>{};

    for (var col = 0; col < 8; col++) {
      for (var row = 0; row < 8; row++) {
        final square = BoardSquare(col, row);
        final piece = _chess.get(square.algebraic);

        if (piece != null) {
          pieces[square] = piece;
        }
      }
    }

    return pieces;
  }

  // ─── INTERACTION AVEC L'ÉCHIQUIER ───────────

  void onSquareTapped(BoardSquare square) {
    if (isGameOver || _awaitingPromotion || !_isValidSquare(square)) return;

    final piece = pieceAt(square);

    if (_selectedSquare == null) {
      if (piece != null && _isPieceOwnedByCurrentPlayer(piece)) {
        _selectSquare(square);
      }
      return;
    }

    if (_selectedSquare == square) {
      _clearSelection();
      return;
    }

    if (piece != null && _isPieceOwnedByCurrentPlayer(piece)) {
      _selectSquare(square);
      return;
    }

    if (_legalMoves.contains(square)) {
      _tryMove(_selectedSquare!, square);
      return;
    }

    _clearSelection();
  }

  void _selectSquare(BoardSquare square) {
    _selectedSquare = square;
    _legalMoves = _getLegalMovesFrom(square);
    notifyListeners();
  }

  void _clearSelection({bool notify = true}) {
    _selectedSquare = null;
    _legalMoves = [];

    if (notify) {
      notifyListeners();
    }
  }

  // ─── JOUER UN COUP ──────────────────────────

  void _tryMove(BoardSquare from, BoardSquare to) {
    final piece = pieceAt(from);

    if (piece != null &&
        piece.type == ch.PieceType.PAWN &&
        _isPromotionDestination(piece, to)) {
      _pendingPromotionFrom = from;
      _pendingPromotionTo = to;
      _awaitingPromotion = true;
      _clearSelection(notify: false);
      notifyListeners();
      return;
    }

    _executeMove(from, to);
  }

  /// Appelé après le choix de la pièce de promotion.
  void resolvePromotion(ch.PieceType promotionPiece) {
    if (!_awaitingPromotion ||
        _pendingPromotionFrom == null ||
        _pendingPromotionTo == null) {
      return;
    }

    final from = _pendingPromotionFrom!;
    final to = _pendingPromotionTo!;

    _pendingPromotionFrom = null;
    _pendingPromotionTo = null;
    _awaitingPromotion = false;

    _executeMove(from, to, promotion: promotionPiece);
  }

  void _executeMove(
    BoardSquare from,
    BoardSquare to, {
    ch.PieceType? promotion,
  }) {
    if (isGameOver) return;

    final legalMove = _findLegalMove(from, to, promotion: promotion);

    if (legalMove == null) {
      _clearSelection();
      return;
    }

    final san = _cleanSan(_chess.move_to_san(legalMove));

    final moveMap = <String, String>{
      'from': from.algebraic,
      'to': to.algebraic,
      if (promotion != null) 'promotion': _pieceTypeToChar(promotion),
    };

    final moveWasPlayed = _chess.move(moveMap);

    if (!moveWasPlayed) {
      _clearSelection();
      return;
    }

    _addMoveToHistory(
      move: legalMove,
      san: san,
      from: from,
      to: to,
    );

    _clearSelection(notify: false);
    _checkGameEnd();
    notifyListeners();
  }

  void _addMoveToHistory({
    required ch.Move move,
    required String san,
    required BoardSquare from,
    required BoardSquare to,
  }) {
    final moveNumber = (_moveHistory.length ~/ 2) + 1;

    _moveHistory.add(
      ChessMove(
        san: san,
        uci: '${from.algebraic}${to.algebraic}',
        moveNumber: moveNumber,
        isWhite: move.color == ch.Color.WHITE,
        isCheck: _chess.in_check,
        isCheckmate: _chess.in_checkmate,
        isCapture: _hasFlag(move, ch.Chess.BITS_CAPTURE) ||
            _hasFlag(move, ch.Chess.BITS_EP_CAPTURE),
        isCastle: _hasFlag(move, ch.Chess.BITS_KSIDE_CASTLE) ||
            _hasFlag(move, ch.Chess.BITS_QSIDE_CASTLE),
        isPromotion: _hasFlag(move, ch.Chess.BITS_PROMOTION),
      ),
    );
  }

  // ─── FIN DE PARTIE ──────────────────────────

  void _checkGameEnd() {
    if (_chess.in_checkmate) {
      _gameEnd = GameEndState(
        reason: GameEndReason.checkmate,
        whiteWins: !isWhiteTurn,
      );
      return;
    }

    if (_chess.in_stalemate) {
      _gameEnd = const GameEndState(reason: GameEndReason.stalemate);
      return;
    }

    if (_chess.insufficient_material) {
      _gameEnd = const GameEndState(reason: GameEndReason.insufficientMaterial);
      return;
    }

    if (_chess.in_threefold_repetition) {
      _gameEnd = const GameEndState(reason: GameEndReason.threefoldRepetition);
      return;
    }

    if (_chess.in_draw) {
      _gameEnd = const GameEndState(reason: GameEndReason.draw);
    }
  }

  /// Déclare une nulle manuellement.
  void declareDraw() {
    if (isGameOver) return;

    _gameEnd = const GameEndState(reason: GameEndReason.draw);
    _clearSelection(notify: false);
    notifyListeners();
  }

  /// Déclare un abandon.
  ///
  /// Si `whiteResigned` est null, on considère que le joueur au trait abandonne.
  void resign({bool? whiteResigned}) {
    if (isGameOver) return;

    final resignedWhite = whiteResigned ?? isWhiteTurn;

    _gameEnd = GameEndState(
      reason: GameEndReason.resignation,
      whiteWins: !resignedWhite,
    );

    _clearSelection(notify: false);
    notifyListeners();
  }

  // ─── RESET ──────────────────────────────────

  void reset() {
    _chess = _initialFen != null ? ch.Chess.fromFEN(_initialFen) : ch.Chess();
    _selectedSquare = null;
    _legalMoves = [];
    _moveHistory.clear();
    _gameEnd = null;
    _pendingPromotionFrom = null;
    _pendingPromotionTo = null;
    _awaitingPromotion = false;
    notifyListeners();
  }

  // ─── UTILS ──────────────────────────────────

  bool _isValidSquare(BoardSquare square) {
    return square.col >= 0 &&
        square.col <= 7 &&
        square.row >= 0 &&
        square.row <= 7;
  }

  bool _isPieceOwnedByCurrentPlayer(ch.Piece piece) {
    return (isWhiteTurn && piece.color == ch.Color.WHITE) ||
        (!isWhiteTurn && piece.color == ch.Color.BLACK);
  }

  bool _isPromotionDestination(ch.Piece piece, BoardSquare to) {
    return (piece.color == ch.Color.WHITE && to.row == 7) ||
        (piece.color == ch.Color.BLACK && to.row == 0);
  }

  List<BoardSquare> _getLegalMovesFrom(BoardSquare square) {
    final moves = _chess.generate_moves({
      'square': square.algebraic,
    });

    final legalSquares = <BoardSquare>[];

    for (final move in moves) {
      final destination = _algebraicToSquare(move.toAlgebraic);

      if (destination != null && !legalSquares.contains(destination)) {
        legalSquares.add(destination);
      }
    }

    return legalSquares;
  }

  ch.Move? _findLegalMove(
    BoardSquare from,
    BoardSquare to, {
    ch.PieceType? promotion,
  }) {
    final moves = _chess.generate_moves({
      'square': from.algebraic,
    });

    for (final move in moves) {
      if (move.toAlgebraic != to.algebraic) continue;

      if (promotion == null) {
        return move;
      }

      if (move.promotion == promotion) {
        return move;
      }
    }

    return null;
  }

  BoardSquare? _algebraicToSquare(String algebraic) {
    if (algebraic.length < 2) return null;

    const files = 'abcdefgh';
    final file = algebraic[0].toLowerCase();
    final col = files.indexOf(file);
    final rank = int.tryParse(algebraic[1]);

    if (col < 0 || rank == null || rank < 1 || rank > 8) {
      return null;
    }

    return BoardSquare(col, rank - 1);
  }

  String _pieceTypeToChar(ch.PieceType type) {
    switch (type) {
      case ch.PieceType.QUEEN:
        return 'q';
      case ch.PieceType.ROOK:
        return 'r';
      case ch.PieceType.BISHOP:
        return 'b';
      case ch.PieceType.KNIGHT:
        return 'n';
      default:
        return 'q';
    }
  }

  bool _hasFlag(ch.Move move, int flag) {
    return (move.flags & flag) != 0;
  }

  String _cleanSan(String san) {
    return san.replaceAll('+', '').replaceAll('#', '');
  }
}
