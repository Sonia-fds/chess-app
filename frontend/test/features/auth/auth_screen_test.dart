import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/auth/auth_screen.dart';

Widget makeTestable(Widget widget) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(),
    home: widget,
  );
}

Future<void> pumpAuthScreen(WidgetTester tester) async {
  await tester.pumpWidget(makeTestable(const AuthScreen()));
  await tester.pumpAndSettle();
}

Future<void> goToRegister(WidgetTester tester) async {
  await pumpAuthScreen(tester);
  await tester.tap(find.text('Inscription'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════
  // AUTH SCREEN — NAVIGATION ENTRE ONGLETS
  // ═══════════════════════════════════════════════════
  group('AuthScreen — onglets', () {
    testWidgets('affiche le formulaire de connexion par défaut', (tester) async {
      await pumpAuthScreen(tester);

      expect(find.text('Connexion'), findsOneWidget);
      expect(find.text('Inscription'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('bascule vers le formulaire d inscription au tap', (tester) async {
      await pumpAuthScreen(tester);

      await tester.tap(find.text('Inscription'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('rebascule vers connexion au tap sur l onglet', (tester) async {
      await pumpAuthScreen(tester);

      await tester.tap(find.text('Inscription'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connexion'));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  // ═══════════════════════════════════════════════════
  // LOGIN FORM
  // ═══════════════════════════════════════════════════
  group('LoginForm', () {
    group('validation — champs vides', () {
      testWidgets('affiche les erreurs si soumis vide', (tester) async {
        await pumpAuthScreen(tester);

        await tester.tap(find.text('Se connecter'));
        await tester.pumpAndSettle();

        expect(find.text('Email requis'), findsOneWidget);
        expect(find.text('Mot de passe requis'), findsOneWidget);
      });
    });

    group('validation — email', () {
      testWidgets('affiche erreur pour email invalide', (tester) async {
        await pumpAuthScreen(tester);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'email-invalide',
        );
        await tester.tap(find.text('Se connecter'));
        await tester.pumpAndSettle();

        expect(find.text('Email invalide'), findsOneWidget);
      });

      testWidgets('n affiche pas d erreur pour email valide', (tester) async {
        await pumpAuthScreen(tester);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.tap(find.text('Se connecter'));
        await tester.pumpAndSettle();

        expect(find.text('Email invalide'), findsNothing);
        expect(find.text('Email requis'), findsNothing);
      });
    });

    group('validation — mot de passe', () {
      testWidgets('affiche erreur si mot de passe trop court', (tester) async {
        await pumpAuthScreen(tester);

        await tester.enterText(find.byType(TextFormField).at(1), 'abc');
        await tester.tap(find.text('Se connecter'));
        await tester.pumpAndSettle();

        expect(find.text('Minimum 8 caractères'), findsOneWidget);
      });
    });

    group('UI — afficher/masquer mot de passe', () {
      testWidgets('toggle visibilité du mot de passe', (tester) async {
        await pumpAuthScreen(tester);

        expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.visibility_off_outlined));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      });
    });

    group('UI — boutons OAuth', () {
      testWidgets('affiche les boutons Google et GitHub', (tester) async {
        await pumpAuthScreen(tester);

        expect(find.text('Google'), findsOneWidget);
        expect(find.text('GitHub'), findsOneWidget);
      });
    });

    group('UI — mot de passe oublié', () {
      testWidgets('ouvre le bottom sheet au tap', (tester) async {
        await pumpAuthScreen(tester);

        await tester.tap(find.text('Mot de passe oublié ?'));
        await tester.pumpAndSettle();

        expect(find.text('Mot de passe oublié'), findsOneWidget);
        expect(find.text('Envoyer le lien'), findsOneWidget);
      });

      testWidgets('affiche erreur si email vide dans bottom sheet', (tester) async {
        await pumpAuthScreen(tester);

        await tester.tap(find.text('Mot de passe oublié ?'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Envoyer le lien'));
        await tester.pumpAndSettle();

        expect(find.text('Email requis'), findsOneWidget);
      });
    });
  });

  // ═══════════════════════════════════════════════════
  // REGISTER FORM
  // ═══════════════════════════════════════════════════
  group('RegisterForm', () {
    group('validation — champs vides', () {
      testWidgets('affiche toutes les erreurs si soumis vide', (tester) async {
        await goToRegister(tester);

        await tester.tap(find.text('Créer mon compte'));
        await tester.pumpAndSettle();

        expect(find.text('Email requis'), findsOneWidget);
        expect(find.text('Pseudo requis'), findsOneWidget);
        expect(find.text('Mot de passe requis'), findsOneWidget);
        expect(find.text('Confirmation requise'), findsOneWidget);
      });
    });

    group('validation — pseudo', () {
      testWidgets('affiche erreur si pseudo trop court', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(1), 'ab');
        await tester.tap(find.text('Créer mon compte'));
        await tester.pumpAndSettle();

        expect(find.text('Minimum 3 caractères'), findsOneWidget);
      });

      testWidgets('affiche erreur si pseudo avec caractères spéciaux', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(1), 'user!');
        await tester.tap(find.text('Créer mon compte'));
        await tester.pumpAndSettle();

        expect(
          find.text('Lettres, chiffres et _ uniquement'),
          findsOneWidget,
        );
      });

      testWidgets('accepte un pseudo valide', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(1), 'GrandMaitre42');
        await tester.tap(find.text('Créer mon compte'));
        await tester.pumpAndSettle();

        expect(find.text('Pseudo requis'), findsNothing);
        expect(find.text('Minimum 3 caractères'), findsNothing);
        expect(find.text('Maximum 20 caractères'), findsNothing);
        expect(find.text('Lettres, chiffres et _ uniquement'), findsNothing);
      });
    });

    group('validation — confirmation mot de passe', () {
      testWidgets('affiche erreur si mots de passe différents', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
        await tester.enterText(find.byType(TextFormField).at(3), 'AutreMotDePasse');
        await tester.tap(find.text('Créer mon compte'));
        await tester.pumpAndSettle();

        expect(
          find.text('Les mots de passe ne correspondent pas'),
          findsOneWidget,
        );
      });

      testWidgets('n affiche pas d erreur si mots de passe identiques', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
        await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');
        await tester.tap(find.text('Créer mon compte'));
        await tester.pumpAndSettle();

        expect(
          find.text('Les mots de passe ne correspondent pas'),
          findsNothing,
        );
      });
    });

    group('UI — indicateur de force du mot de passe', () {
      testWidgets('apparaît quand le champ mot de passe n est pas vide', (tester) async {
        await goToRegister(tester);

        expect(find.byType(LinearProgressIndicator), findsNothing);

        await tester.enterText(find.byType(TextFormField).at(2), 'abc');
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('affiche Très faible pour mot de passe court', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(2), 'abc');
        await tester.pumpAndSettle();

        expect(find.text('Très faible'), findsOneWidget);
      });

      testWidgets('affiche Fort pour mot de passe complet', (tester) async {
        await goToRegister(tester);

        await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
        await tester.pumpAndSettle();

        expect(find.text('Fort'), findsOneWidget);
      });
    });

    group('UI — conditions d utilisation', () {
      testWidgets('affiche snackbar si conditions non acceptées', (tester) async {
        await goToRegister(tester);

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'GrandMaitre');
        await tester.enterText(find.byType(TextFormField).at(2), 'Password1!');
        await tester.enterText(find.byType(TextFormField).at(3), 'Password1!');

        await tester.tap(find.text('Créer mon compte'));
        await tester.pump();

        expect(
          find.text("Veuillez accepter les conditions d'utilisation"),
          findsOneWidget,
        );
      });
    });
  });
}
