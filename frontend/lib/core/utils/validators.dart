/// Validators used by the authentication forms.
/// 
class AuthValidators {
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email requis';
    }

    final trimmed = value.trim();

    final emailRegex = RegExp(
      r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmed)) {
      return 'Email invalide';
    }

    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pseudo requis';
    }

    final trimmed = value.trim();

    if (trimmed.length < 3) {
      return 'Minimum 3 caractères';
    }

    if (trimmed.length > 20) {
      return 'Maximum 20 caractères';
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Lettres, chiffres et _ uniquement';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }

    if (value.length < 8) {
      return 'Minimum 8 caractères';
    }

    return null;
  }

  static String? Function(String?) confirmPassword(String originalPassword) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return 'Confirmation requise';
      }

      if (value != originalPassword) {
        return 'Les mots de passe ne correspondent pas';
      }

      return null;
    };
  }

  static double passwordStrength(String password) {
    if (password.length < 8) {
      return 0.0;
    }

    double strength = 0.25;

    if (password.contains(RegExp(r'[A-Z]'))) {
      strength += 0.25;
    }

    if (password.contains(RegExp(r'[0-9]'))) {
      strength += 0.25;
    }

    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      strength += 0.25;
    }

    return strength.clamp(0.0, 1.0);
  }
}