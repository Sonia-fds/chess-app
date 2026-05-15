import 'package:chess_app/features/board/board_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget makeTestable(Widget widget) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: widget,
  );
}

Future<void> pumpBoardScreen(
  WidgetTester tester, {
  bool playerIsWhite = true,
  String? initialFen,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 930));

  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    makeTestable(
      BoardScreen(
        playerIsWhite: playerIsWhite,
        initialFen: initialFen,
      ),
    ),
  );

  await tester.pump(const Duration(milliseconds: 300));
}

Finder squareFinder(String square) {
  return find.byKey(ValueKey('square-$square'));
}

Future<void> tapSquare(WidgetTester tester, String square) async {
  final finder = squareFinder(square);
  expect(finder, findsOneWidget);

  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> openActionsMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded));

  // On évite pumpAndSettle() parce que l'écran contient
  // un CircularProgressIndicator animé en continu.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1000));
}

Future<void> tapPopupMenuText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsAtLeastNWidgets(1));

  await tester.tap(finder.last, warnIfMissed: false);

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsAtLeastNWidgets(1));

  final target = finder.last;
  await tester.ensureVisible(target);
  await tester.tap(target, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> tapTextButton(WidgetTester tester, String text) async {
  final finder = find.widgetWithText(TextButton, text);
  expect(finder, findsOneWidget);

  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BoardScreen — affichage', () {
    testWidgets('affiche l échiquier', (tester) async {
      await pumpBoardScreen(tester);

      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('affiche 64 cases via les clés publiques', (tester) async {
      await pumpBoardScreen(tester);

      const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

      for (final file in files) {
        for (var rank = 1; rank <= 8; rank++) {
          expect(squareFinder('$file$rank'), findsOneWidget);
        }
      }
    });

    testWidgets('affiche les pièces en position initiale', (tester) async {
      await pumpBoardScreen(tester);

      // Les barres des joueurs peuvent aussi afficher un symbole ♟.
      // On vérifie donc qu'au moins les 8 pions de chaque camp sont visibles.
      expect(find.text('♙'), findsAtLeastNWidgets(8));
      expect(find.text('♟'), findsAtLeastNWidgets(8));
    });

    testWidgets('affiche les coordonnées sur l échiquier', (tester) async {
      await pumpBoardScreen(tester);

      for (var rank = 1; rank <= 8; rank++) {
        expect(find.text('$rank'), findsWidgets);
      }

      for (final file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        expect(find.text(file), findsWidgets);
      }
    });

    testWidgets('affiche les joueurs', (tester) async {
      await pumpBoardScreen(tester);

      expect(find.text('Vous'), findsOneWidget);
      expect(find.text('Adversaire'), findsOneWidget);
    });

    testWidgets('affiche un indicateur de tour actif au départ', (tester) async {
      await pumpBoardScreen(tester, playerIsWhite: true);

      expect(find.text('À toi'), findsOneWidget);
    });

    testWidgets('affiche l historique des coups vide', (tester) async {
      await pumpBoardScreen(tester);

      expect(find.text('Aucun coup joué'), findsOneWidget);
    });

    testWidgets('affiche le titre Partie en cours', (tester) async {
      await pumpBoardScreen(tester);

      expect(find.textContaining('Partie en cours'), findsOneWidget);
    });
  });

  group('BoardScreen — sélection de pièce', () {
    testWidgets('sélection d un pion blanc garde l écran stable',
        (tester) async {
      await pumpBoardScreen(tester, playerIsWhite: true);

      await tapSquare(tester, 'e2');

      expect(squareFinder('e2'), findsOneWidget);
      expect(find.text('Aucun coup joué'), findsOneWidget);
    });

    testWidgets('tap sur case vide ne joue aucun coup', (tester) async {
      await pumpBoardScreen(tester);

      await tapSquare(tester, 'e4');

      expect(find.text('Aucun coup joué'), findsOneWidget);
    });
  });

  group('BoardScreen — jouer un coup', () {
    testWidgets('joue e2-e4 et met à jour l historique', (tester) async {
      await pumpBoardScreen(tester, playerIsWhite: true);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');

      expect(find.text('Aucun coup joué'), findsNothing);
      expect(find.text('1.'), findsOneWidget);
    });

    testWidgets('le tour actif reste affiché après un coup', (tester) async {
      await pumpBoardScreen(tester, playerIsWhite: true);

      await tapSquare(tester, 'e2');
      await tapSquare(tester, 'e4');

      expect(find.text('À toi'), findsOneWidget);
    });
  });

  group('BoardScreen — menu actions', () {
    testWidgets('ouvre le menu avec les options', (tester) async {
      await pumpBoardScreen(tester);

      await openActionsMenu(tester);

      expect(find.text('Proposer nulle'), findsOneWidget);
      expect(find.text('Abandonner'), findsOneWidget);
    });

    testWidgets('abandon ouvre une dialog de confirmation', (tester) async {
      await pumpBoardScreen(tester);

      await openActionsMenu(tester);
      await tapPopupMenuText(tester, 'Abandonner');

      expect(find.text('Abandonner ?'), findsOneWidget);
      expect(find.text('Non'), findsOneWidget);
    });

    testWidgets('annuler l abandon ferme la dialog', (tester) async {
      await pumpBoardScreen(tester);

      await openActionsMenu(tester);
      await tapPopupMenuText(tester, 'Abandonner');

      await tapTextButton(tester, 'Non');

      expect(find.text('Abandonner ?'), findsNothing);
    });
  });

  group('BoardScreen — fin de partie', () {
    testWidgets('affiche la dialog de fin après nulle déclarée',
        (tester) async {
      await pumpBoardScreen(tester);

      await openActionsMenu(tester);
      await tapPopupMenuText(tester, 'Proposer nulle');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Nulle acceptée !'), findsOneWidget);
      expect(find.text('Rejouer'), findsOneWidget);
      expect(find.text('Accueil'), findsOneWidget);
    });

    testWidgets('Rejouer remet l échiquier en position initiale',
        (tester) async {
      await pumpBoardScreen(tester);

      await openActionsMenu(tester);
      await tapPopupMenuText(tester, 'Proposer nulle');

      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 300));

      await tapText(tester, 'Rejouer');

      expect(find.text('Aucun coup joué'), findsOneWidget);
      expect(find.text('À toi'), findsOneWidget);
    });
  });

  group('BoardScreen — promotion', () {
    const fenPromotion = '7k/P7/8/8/8/8/8/7K w - - 0 1';

    testWidgets('affiche la dialog de promotion', (tester) async {
      await pumpBoardScreen(tester, initialFen: fenPromotion);

      await tapSquare(tester, 'a7');
      await tapSquare(tester, 'a8');
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Promotion du pion'), findsOneWidget);
      expect(find.text('Dame'), findsOneWidget);
      expect(find.text('Tour'), findsOneWidget);
      expect(find.text('Fou'), findsOneWidget);
      expect(find.text('Cavalier'), findsOneWidget);
    });

    testWidgets('choisir Dame résout la promotion', (tester) async {
      await pumpBoardScreen(tester, initialFen: fenPromotion);

      await tapSquare(tester, 'a7');
      await tapSquare(tester, 'a8');
      await tester.pump(const Duration(milliseconds: 300));

      await tapText(tester, 'Dame');

      expect(find.text('Promotion du pion'), findsNothing);
      expect(find.text('♕'), findsOneWidget);
    });
  });

  group('BoardScreen — orientation', () {
    testWidgets('affiche correctement quand le joueur est noir', (tester) async {
      await pumpBoardScreen(tester, playerIsWhite: false);

      const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

      for (final file in files) {
        for (var rank = 1; rank <= 8; rank++) {
          expect(squareFinder('$file$rank'), findsOneWidget);
        }
      }
    });
  });
}