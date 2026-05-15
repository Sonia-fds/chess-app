import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'board_controller.dart';

// ─────────────────────────────────────────────
// COULEURS
// ─────────────────────────────────────────────

class BoardColors {
  static const Color background = Color(0xFF0E0E0F);
  static const Color surface = Color(0xFF1A1A1C);
  static const Color border = Color(0xFF2E2E33);
  static const Color gold = Color(0xFFD4A843);
  static const Color textPrimary = Color(0xFFF2F0EB);
  static const Color textSecondary = Color(0xFF9E9B94);
  static const Color squareLight = Color(0xFFF0D9B5);
  static const Color squareDark = Color(0xFFB58863);
  static const Color selectedTint = Color(0x9900C853);
  static const Color legalMoveDot = Color(0x6600C853);
  static const Color legalCapture = Color(0x66C80000);
  static const Color lastMoveFrom = Color(0x66F6F669);
  static const Color lastMoveTo = Color(0x99F6F669);
  static const Color checkTint = Color(0xAAC80000);
  static const Color error = Color(0xFFE05252);
  static const Color success = Color(0xFF52A878);
}

// ─────────────────────────────────────────────
// BOARD SCREEN
// ─────────────────────────────────────────────

class BoardScreen extends StatefulWidget {
  final bool playerIsWhite;
  final String? initialFen;

  const BoardScreen({
    super.key,
    this.playerIsWhite = true,
    this.initialFen,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final BoardController _controller;

  bool _promotionDialogOpen = false;
  bool _gameEndDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = BoardController(fen: widget.initialFen);
    _controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;

    setState(() {});

    if (_controller.awaitingPromotion && !_promotionDialogOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPromotionDialog();
      });
    }

    if (_controller.gameEnd != null && !_gameEndDialogOpen) {
      final end = _controller.gameEnd!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameEndDialog(end);
      });
    }
  }

  Future<void> _showPromotionDialog() async {
    if (_promotionDialogOpen || !mounted) return;

    _promotionDialogOpen = true;

    final piece = await showDialog<ch.PieceType>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PromotionDialog(
        isWhite: _controller.isWhiteTurn,
      ),
    );

    _promotionDialogOpen = false;

    if (!mounted) return;

    if (piece != null && _controller.awaitingPromotion) {
      _controller.resolvePromotion(piece);
    }
  }

  Future<void> _showGameEndDialog(GameEndState end) async {
    if (_gameEndDialogOpen || !mounted) return;

    _gameEndDialogOpen = true;

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GameEndDialog(
        gameEnd: end,
        onRematch: () {
          Navigator.of(context).pop();
          _gameEndDialogOpen = false;
          _controller.reset();
        },
        onHome: () {
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      ),
    );
  }

  Future<void> _confirmResign() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: BoardColors.surface,
        title: const Text(
          'Abandonner ?',
          style: TextStyle(color: BoardColors.textPrimary),
        ),
        content: const Text(
          'Es-tu sûr de vouloir abandonner cette partie ?',
          style: TextStyle(color: BoardColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Non',
              style: TextStyle(color: BoardColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: BoardColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // TODO: idéalement, ajoute une méthode _controller.resign(...)
      // dans BoardController. En attendant, on garde declareDraw()
      // pour éviter une erreur de compilation si resign() n'existe pas encore.
      _controller.declareDraw();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: BoardColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                controller: _controller,
                onResign: _confirmResign,
                onOfferDraw: _controller.declareDraw,
              ),
              _PlayerBar(
                name: widget.playerIsWhite ? 'Adversaire' : 'Vous',
                isWhite: !widget.playerIsWhite,
                isActive: _controller.isWhiteTurn != widget.playerIsWhite,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _ChessBoardWidget(
                  controller: _controller,
                  playerIsWhite: widget.playerIsWhite,
                ),
              ),
              const SizedBox(height: 8),
              _PlayerBar(
                name: widget.playerIsWhite ? 'Vous' : 'Adversaire',
                isWhite: widget.playerIsWhite,
                isActive: _controller.isWhiteTurn == widget.playerIsWhite,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _MoveHistoryWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final BoardController controller;
  final VoidCallback onResign;
  final VoidCallback onOfferDraw;

  const _TopBar({
    required this.controller,
    required this.onResign,
    required this.onOfferDraw,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BoardColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: BoardColors.textSecondary,
            ),
          ),
          const Expanded(
            child: Text(
              '♛  Partie en cours',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: BoardColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: BoardColors.surface,
            icon: const Icon(
              Icons.more_vert_rounded,
              color: BoardColors.textSecondary,
            ),
            onSelected: (value) {
              if (value == 'draw') onOfferDraw();
              if (value == 'resign') onResign();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'draw',
                child: Row(
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      color: BoardColors.textSecondary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Proposer nulle',
                      style: TextStyle(color: BoardColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'resign',
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: BoardColors.error,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Abandonner',
                      style: TextStyle(color: BoardColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PLAYER BAR
// ─────────────────────────────────────────────

class _PlayerBar extends StatelessWidget {
  final String name;
  final bool isWhite;
  final bool isActive;

  const _PlayerBar({
    required this.name,
    required this.isWhite,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? BoardColors.gold.withValues(alpha: 0.08)
            : BoardColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? BoardColors.gold : BoardColors.border,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isWhite ? Colors.white : Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: BoardColors.border),
            ),
            child: const Center(
              child: Text(
                '♟',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive ? BoardColors.gold : BoardColors.textPrimary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          if (isActive)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(BoardColors.gold),
                  ),
                ),
                SizedBox(width: 6),
                Text(
                  'À toi',
                  style: TextStyle(
                    color: BoardColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHESSBOARD WIDGET
// ─────────────────────────────────────────────

class _ChessBoardWidget extends StatelessWidget {
  final BoardController controller;
  final bool playerIsWhite;

  const _ChessBoardWidget({
    required this.controller,
    required this.playerIsWhite,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BoardColors.border, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Column(
            children: List.generate(8, (rowIndex) {
              final row = playerIsWhite ? 7 - rowIndex : rowIndex;

              return Expanded(
                child: Row(
                  children: List.generate(8, (colIndex) {
                    final col = playerIsWhite ? colIndex : 7 - colIndex;
                    final square = BoardSquare(col, row);

                    return Expanded(
                      child: _SquareWidget(
                        square: square,
                        controller: controller,
                        colIndex: colIndex,
                        rowIndex: rowIndex,
                        playerIsWhite: playerIsWhite,
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SQUARE WIDGET
// ─────────────────────────────────────────────

class _SquareWidget extends StatelessWidget {
  final BoardSquare square;
  final BoardController controller;
  final int colIndex;
  final int rowIndex;
  final bool playerIsWhite;

  const _SquareWidget({
    required this.square,
    required this.controller,
    required this.colIndex,
    required this.rowIndex,
    required this.playerIsWhite,
  });

  bool get _isLightSquare => (square.col + square.row) % 2 != 0;

  Color get _baseColor =>
      _isLightSquare ? BoardColors.squareLight : BoardColors.squareDark;

  @override
  Widget build(BuildContext context) {
    final piece = controller.pieceAt(square);
    final isSelected = controller.selectedSquare == square;
    final isLegalMove = controller.legalMovesForSelected.contains(square);
    final isLegalCapture = isLegalMove && piece != null;

    final isKingInCheck = controller.isInCheck &&
        piece != null &&
        piece.type == ch.PieceType.KING &&
        ((controller.isWhiteTurn && piece.color == ch.Color.WHITE) ||
            (!controller.isWhiteTurn && piece.color == ch.Color.BLACK));

    return GestureDetector(
      key: ValueKey('square-${square.algebraic}'),
      onTap: () => controller.onSquareTapped(square),
      child: Stack(
        children: [
          Container(
            color: isSelected
                ? BoardColors.selectedTint
                : isKingInCheck
                    ? BoardColors.checkTint
                    : _baseColor,
          ),
          if (isLegalMove && !isLegalCapture)
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.28,
                heightFactor: 0.28,
                child: Container(
                  decoration: const BoxDecoration(
                    color: BoardColors.legalMoveDot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          if (isLegalCapture)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: BoardColors.legalCapture,
                  width: 4,
                ),
              ),
            ),
          if (piece != null)
            Center(
              child: AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Text(
                    _pieceToUnicode(piece),
                    style: TextStyle(
                      fontSize: 36,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (colIndex == 0)
            Positioned(
              top: 2,
              left: 3,
              child: Text(
                '${square.row + 1}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _isLightSquare
                      ? BoardColors.squareDark
                      : BoardColors.squareLight,
                ),
              ),
            ),
          if (rowIndex == 7)
            Positioned(
              bottom: 2,
              right: 3,
              child: Text(
                String.fromCharCode('a'.codeUnitAt(0) + square.col),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: _isLightSquare
                      ? BoardColors.squareDark
                      : BoardColors.squareLight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _pieceToUnicode(ch.Piece piece) {
  final Map<ch.PieceType, String> whiteUnicode = {
    ch.PieceType.KING: '♔',
    ch.PieceType.QUEEN: '♕',
    ch.PieceType.ROOK: '♖',
    ch.PieceType.BISHOP: '♗',
    ch.PieceType.KNIGHT: '♘',
    ch.PieceType.PAWN: '♙',
  };

  final Map<ch.PieceType, String> blackUnicode = {
    ch.PieceType.KING: '♚',
    ch.PieceType.QUEEN: '♛',
    ch.PieceType.ROOK: '♜',
    ch.PieceType.BISHOP: '♝',
    ch.PieceType.KNIGHT: '♞',
    ch.PieceType.PAWN: '♟',
  };

  return piece.color == ch.Color.WHITE
      ? whiteUnicode[piece.type] ?? '?'
      : blackUnicode[piece.type] ?? '?';
}
}

// ─────────────────────────────────────────────
// MOVE HISTORY WIDGET
// ─────────────────────────────────────────────

class _MoveHistoryWidget extends StatelessWidget {
  final BoardController controller;

  const _MoveHistoryWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    final moves = controller.moveHistory;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: BoardColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BoardColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: BoardColors.border)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 16,
                  color: BoardColors.textSecondary,
                ),
                SizedBox(width: 8),
                Text(
                  'Coups joués',
                  style: TextStyle(
                    color: BoardColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: moves.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun coup joué',
                      style: TextStyle(
                        color: BoardColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: (moves.length / 2).ceil(),
                    itemBuilder: (_, index) {
                      final whiteMove = moves[index * 2];
                      final blackMove = index * 2 + 1 < moves.length
                          ? moves[index * 2 + 1]
                          : null;

                      return _MoveRow(
                        moveNumber: index + 1,
                        whiteMove: whiteMove,
                        blackMove: blackMove,
                        isLast: index == (moves.length / 2).ceil() - 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  final int moveNumber;
  final ChessMove whiteMove;
  final ChessMove? blackMove;
  final bool isLast;

  const _MoveRow({
    required this.moveNumber,
    required this.whiteMove,
    this.blackMove,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLast
            ? BoardColors.gold.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$moveNumber.',
              style: const TextStyle(
                color: BoardColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: _MoveChip(move: whiteMove)),
          const SizedBox(width: 8),
          Expanded(
            child: blackMove != null
                ? _MoveChip(move: blackMove!)
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final ChessMove move;

  const _MoveChip({required this.move});

  @override
  Widget build(BuildContext context) {
    return Text(
      move.san + (move.isCheck ? (move.isCheckmate ? '#' : '+') : ''),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: move.isCheckmate
            ? BoardColors.error
            : move.isCheck
                ? BoardColors.gold
                : BoardColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PROMOTION DIALOG
// ─────────────────────────────────────────────

class _PromotionDialog extends StatelessWidget {
  final bool isWhite;

  const _PromotionDialog({required this.isWhite});

  @override
  Widget build(BuildContext context) {
    final pieces = [
      (ch.PieceType.QUEEN, isWhite ? '♕' : '♛', 'Dame'),
      (ch.PieceType.ROOK, isWhite ? '♖' : '♜', 'Tour'),
      (ch.PieceType.BISHOP, isWhite ? '♗' : '♝', 'Fou'),
      (ch.PieceType.KNIGHT, isWhite ? '♘' : '♞', 'Cavalier'),
    ];

    return AlertDialog(
      backgroundColor: BoardColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Promotion du pion',
        textAlign: TextAlign.center,
        style: TextStyle(color: BoardColors.textPrimary, fontSize: 16),
      ),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: pieces.map((piece) {
          final (type, unicode, label) = piece;

          return GestureDetector(
            onTap: () => Navigator.pop(context, type),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: BoardColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: BoardColors.border),
                  ),
                  child: Center(
                    child: Text(
                      unicode,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: BoardColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GAME END DIALOG
// ─────────────────────────────────────────────

class _GameEndDialog extends StatelessWidget {
  final GameEndState gameEnd;
  final VoidCallback onRematch;
  final VoidCallback onHome;

  const _GameEndDialog({
    required this.gameEnd,
    required this.onRematch,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    final isVictory = gameEnd.whiteWins != null;
    final icon = gameEnd.whiteWins == true
        ? '♔'
        : gameEnd.whiteWins == false
            ? '♚'
            : '🤝';

    return AlertDialog(
      backgroundColor: BoardColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            gameEnd.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isVictory ? BoardColors.gold : BoardColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined, size: 16),
                label: const Text('Accueil'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: BoardColors.textSecondary,
                  side: const BorderSide(color: BoardColors.border),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: onRematch,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Rejouer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: BoardColors.gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
