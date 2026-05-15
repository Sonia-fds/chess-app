import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/utils/validators.dart';

void main() {
  // ═══════════════════════════════════════════════════
  // EMAIL
  // ═══════════════════════════════════════════════════
  group('AuthValidators.email', () {
    group('cas valides', () {
      const validEmails = [
        'user@example.com',
        'user.name@domain.org',
        'user+tag@sub.domain.com',
        'user123@example.co.uk',
      ];

      for (final email in validEmails) {
        test('accepte "$email"', () {
          expect(AuthValidators.email(email), isNull);
        });
      }
    });

    group('cas invalides', () {
      test('retourne erreur si null', () {
        expect(AuthValidators.email(null), 'Email requis');
      });

      test('retourne erreur si vide', () {
        expect(AuthValidators.email(''), 'Email requis');
      });

      test('retourne erreur si seulement espaces', () {
        expect(AuthValidators.email('   '), 'Email requis');
      });

      test('retourne erreur si sans @', () {
        expect(AuthValidators.email('userexample.com'), 'Email invalide');
      });

      test('retourne erreur si sans domaine', () {
        expect(AuthValidators.email('user@'), 'Email invalide');
      });

      test('retourne erreur si sans extension', () {
        expect(AuthValidators.email('user@domain'), 'Email invalide');
      });

      test('retourne erreur si espaces internes', () {
        expect(AuthValidators.email('user @example.com'), 'Email invalide');
      });

      test('retourne erreur si double @', () {
        expect(AuthValidators.email('user@@example.com'), 'Email invalide');
      });
    });
  });

  // ═══════════════════════════════════════════════════
  // PSEUDO
  // ═══════════════════════════════════════════════════
  group('AuthValidators.username', () {
    group('cas valides', () {
      const validUsernames = [
        'alice',
        'Bob123',
        'grand_maitre',
        'abc',
        'aaaaaaaaaaaaaaaaaaaa',
      ];

      for (final username in validUsernames) {
        test('accepte "$username"', () {
          expect(AuthValidators.username(username), isNull);
        });
      }
    });

    group('cas invalides', () {
      test('retourne erreur si null', () {
        expect(AuthValidators.username(null), 'Pseudo requis');
      });

      test('retourne erreur si vide', () {
        expect(AuthValidators.username(''), 'Pseudo requis');
      });

      test('retourne erreur si seulement espaces', () {
        expect(AuthValidators.username('   '), 'Pseudo requis');
      });

      test('retourne erreur si moins de 3 caractères', () {
        expect(AuthValidators.username('ab'), 'Minimum 3 caractères');
      });

      test('retourne erreur si plus de 20 caractères', () {
        expect(
          AuthValidators.username('aaaaaaaaaaaaaaaaaaaaa'),
          'Maximum 20 caractères',
        );
      });

      test('retourne erreur si contient des espaces', () {
        expect(
          AuthValidators.username('grand maitre'),
          'Lettres, chiffres et _ uniquement',
        );
      });

      test('retourne erreur si contient des caractères spéciaux', () {
        expect(
          AuthValidators.username('alice!'),
          'Lettres, chiffres et _ uniquement',
        );
      });

      test('retourne erreur si contient un tiret', () {
        expect(
          AuthValidators.username('grand-maitre'),
          'Lettres, chiffres et _ uniquement',
        );
      });
    });
  });

  // ═══════════════════════════════════════════════════
  // MOT DE PASSE
  // ═══════════════════════════════════════════════════
  group('AuthValidators.password', () {
    group('cas valides', () {
      const validPasswords = [
        'password',
        'Password1!',
        'abcdefgh',
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ];

      for (final password in validPasswords) {
        test('accepte un mot de passe de ${password.length} caractères', () {
          expect(AuthValidators.password(password), isNull);
        });
      }
    });

    group('cas invalides', () {
      test('retourne erreur si null', () {
        expect(AuthValidators.password(null), 'Mot de passe requis');
      });

      test('retourne erreur si vide', () {
        expect(AuthValidators.password(''), 'Mot de passe requis');
      });

      test('retourne erreur si moins de 8 caractères', () {
        expect(AuthValidators.password('abc123'), 'Minimum 8 caractères');
      });

      test('retourne erreur si exactement 7 caractères', () {
        expect(AuthValidators.password('abcdefg'), 'Minimum 8 caractères');
      });
    });
  });

  // ═══════════════════════════════════════════════════
  // CONFIRMATION MOT DE PASSE
  // ═══════════════════════════════════════════════════
  group('AuthValidators.confirmPassword', () {
    const originalPassword = 'Password1!';
    final validator = AuthValidators.confirmPassword(originalPassword);

    test('retourne null si les mots de passe correspondent', () {
      expect(validator('Password1!'), isNull);
    });

    test('retourne erreur si null', () {
      expect(validator(null), 'Confirmation requise');
    });

    test('retourne erreur si vide', () {
      expect(validator(''), 'Confirmation requise');
    });

    test('retourne erreur si les mots de passe ne correspondent pas', () {
      expect(
        validator('AutreMotDePasse'),
        'Les mots de passe ne correspondent pas',
      );
    });

    test('retourne erreur si différence de casse', () {
      expect(
        validator('password1!'),
        'Les mots de passe ne correspondent pas',
      );
    });

    test('retourne erreur si espace en trop', () {
      expect(
        validator('Password1! '),
        'Les mots de passe ne correspondent pas',
      );
    });
  });

  // ═══════════════════════════════════════════════════
  // FORCE DU MOT DE PASSE
  // ═══════════════════════════════════════════════════
  group('AuthValidators.passwordStrength', () {
    test('retourne 0.0 pour un mot de passe vide', () {
      expect(AuthValidators.passwordStrength(''), 0.0);
    });

    test('retourne 0.0 si moins de 8 caractères, même avec chiffre', () {
      expect(AuthValidators.passwordStrength('1234567'), 0.0);
    });

    test('retourne 0.25 pour 8+ caractères seulement', () {
      expect(AuthValidators.passwordStrength('abcdefgh'), 0.25);
    });

    test('retourne 0.50 pour 8+ car. + majuscule', () {
      expect(AuthValidators.passwordStrength('Abcdefgh'), 0.50);
    });

    test('retourne 0.75 pour 8+ car. + majuscule + chiffre', () {
      expect(AuthValidators.passwordStrength('Abcdefg1'), 0.75);
    });

    test('retourne 1.0 pour mot de passe fort complet', () {
      expect(AuthValidators.passwordStrength('Abcdefg1!'), 1.0);
    });

    test('retourne une valeur entre 0.0 et 1.0', () {
      final passwords = ['', 'abc', 'abcdefgh', 'Abcdefg1', 'Abcdefg1!'];

      for (final password in passwords) {
        final strength = AuthValidators.passwordStrength(password);
        expect(strength, greaterThanOrEqualTo(0.0));
        expect(strength, lessThanOrEqualTo(1.0));
      }
    });
  });
}
