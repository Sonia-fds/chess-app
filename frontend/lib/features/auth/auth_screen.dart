import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/utils/validators.dart';

// ─────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────

class AppColors {
  static const Color background = Color(0xFF0E0E0F);
  static const Color surface = Color(0xFF1A1A1C);
  static const Color surfaceElevated = Color(0xFF242427);
  static const Color inputFill = Color(0xFF1E1E21);
  static const Color border = Color(0xFF2E2E33);
  static const Color gold = Color(0xFFD4A843);
  static const Color goldLight = Color(0xFFE8C06A);
  static const Color goldDim = Color(0xFF8A6B28);
  static const Color textPrimary = Color(0xFFF2F0EB);
  static const Color textSecondary = Color(0xFF9E9B94);
  static const Color textHint = Color(0xFF5A5855);
  static const Color error = Color(0xFFE05252);
  static const Color success = Color(0xFF52A878);
  static const Color white = Color(0xFFFFFFFF);
  static const Color boardLight = Color(0xFFF0D9B5);
  static const Color boardDark = Color(0xFFB58863);
}

// ─────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────

enum AuthMode { login, register }

class AuthFormData {
  String email = '';
  String username = '';
  String password = '';
  String confirmPassword = '';
}

// ─────────────────────────────────────────────
// MAIN AUTH SCREEN
// ─────────────────────────────────────────────

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  AuthMode _mode = AuthMode.login;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOut,
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    if (_mode == mode) return;
    _animController.reset();
    setState(() => _mode = mode);
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            const _ChessboardBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = math.min(
                    440.0,
                    math.max(320.0, constraints.maxWidth - 32.0),
                  );

                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: contentWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AppLogo(compact: _mode == AuthMode.register),
                            SizedBox(
                              height: _mode == AuthMode.register ? 20.0 : 32.0,
                            ),
                            _AuthCard(
                              mode: _mode,
                              fadeAnim: _fadeAnim,
                              slideAnim: _slideAnim,
                              onSwitchMode: _switchMode,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHESS BACKGROUND
// ─────────────────────────────────────────────

class _ChessboardBackground extends StatelessWidget {
  const _ChessboardBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _ChessPatternPainter(),
      ),
    );
  }
}

class _ChessPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 48.0;
    final lightPaint = Paint()..color = const Color(0xFF141416);
    final darkPaint = Paint()..color = const Color(0xFF111113);

    final gradientPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xCC0E0E0F),
          Color(0x880E0E0F),
          Color(0xCC0E0E0F),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final cols = (size.width / tileSize).ceil() + 1;
    final rows = (size.height / tileSize).ceil() + 1;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final isLight = (row + col) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(
            col * tileSize,
            row * tileSize,
            tileSize,
            tileSize,
          ),
          isLight ? lightPaint : darkPaint,
        );
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// APP LOGO
// ─────────────────────────────────────────────

class _AppLogo extends StatelessWidget {
  final bool compact;

  const _AppLogo({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final logoSize = compact ? 54.0 : 72.0;
    final logoIconSize = compact ? 30.0 : 38.0;
    final titleSize = compact ? 18.0 : 22.0;

    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(compact ? 16 : 20),
            border: Border.all(color: AppColors.goldDim, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '♛',
              style: TextStyle(
                fontSize: logoIconSize,
                color: AppColors.gold,
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 10.0 : 16.0),
        Text(
          'CHESS APP',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Jouez. Apprenez. Progressez.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// AUTH CARD
// ─────────────────────────────────────────────

class _AuthCard extends StatelessWidget {
  final AuthMode mode;
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final void Function(AuthMode) onSwitchMode;

  const _AuthCard({
    required this.mode,
    required this.fadeAnim,
    required this.slideAnim,
    required this.onSwitchMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          _AuthTabs(mode: mode, onSwitchMode: onSwitchMode),
          FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: mode == AuthMode.login
                    ? const _LoginForm()
                    : const _RegisterForm(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TABS
// ─────────────────────────────────────────────

class _AuthTabs extends StatelessWidget {
  final AuthMode mode;
  final void Function(AuthMode) onSwitchMode;

  const _AuthTabs({required this.mode, required this.onSwitchMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Connexion',
            selected: mode == AuthMode.login,
            onTap: () => onSwitchMode(AuthMode.login),
            isFirst: true,
          ),
          _Tab(
            label: 'Inscription',
            selected: mode == AuthMode.register,
            onTap: () => onSwitchMode(AuthMode.register),
            isFirst: false,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isFirst;

  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceElevated : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(24) : Radius.zero,
              topRight: !isFirst ? const Radius.circular(24) : Radius.zero,
            ),
            border: selected
                ? const Border(
                    bottom: BorderSide(color: AppColors.gold, width: 2),
                  )
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.gold : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN FORM
// ─────────────────────────────────────────────

class _LoginForm extends StatefulWidget {
  const _LoginForm();

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion réussie !'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const _FieldLabel(label: 'Adresse email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'vous@exemple.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 20),
          const _FieldLabel(label: 'Mot de passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: AuthValidators.password,
          ),
          const SizedBox(height: 12),
           Wrap(
              spacing: 16,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _Checkbox(value: _rememberMe),
                            const SizedBox(width: 8),
                            const Text(
                              'Se souvenir',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showForgotPassword(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mot de passe oublié ?',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showForgotPassword(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Mot de passe oublié ?',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 28),
          _SubmitButton(
            label: 'Se connecter',
            icon: Icons.login_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 24),
          const _Divider(label: 'ou continuer avec'),
          const SizedBox(height: 20),
          const _OAuthButtons(),
        ],
      ),
    );
  }

  void _showForgotPassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ForgotPasswordSheet(),
    );
  }
}

// ─────────────────────────────────────────────
// REGISTER FORM
// ─────────────────────────────────────────────

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _acceptTerms = false;
  double _passwordStrength = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _updatePasswordStrength(String password) {
    setState(() {
      _passwordStrength = AuthValidators.passwordStrength(password);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez accepter les conditions d'utilisation"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé ! Vérifiez votre email.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const _FieldLabel(label: 'Adresse email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'vous@exemple.com',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: AuthValidators.email,
          ),
          const SizedBox(height: 20),
          const _FieldLabel(label: 'Pseudo'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'GrandMaitre42',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: AuthValidators.username,
          ),
          const SizedBox(height: 20),
          const _FieldLabel(label: 'Mot de passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onChanged: _updatePasswordStrength,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: AuthValidators.password,
          ),
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PasswordStrengthIndicator(strength: _passwordStrength),
          ],
          const SizedBox(height: 20),
          const _FieldLabel(label: 'Confirmer le mot de passe'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: AuthValidators.confirmPassword(_passwordController.text),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => setState(() => _acceptTerms = !_acceptTerms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Checkbox(value: _acceptTerms),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(text: "J'accepte les "),
                        TextSpan(
                          text: "conditions d'utilisation",
                          style: TextStyle(
                            color: AppColors.gold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        TextSpan(text: ' et la '),
                        TextSpan(
                          text: 'politique de confidentialité',
                          style: TextStyle(
                            color: AppColors.gold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _SubmitButton(
            label: 'Créer mon compte',
            icon: Icons.person_add_rounded,
            isLoading: _isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: 24),
          const _Divider(label: 'ou continuer avec'),
          const SizedBox(height: 20),
          const _OAuthButtons(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  final bool value;

  const _Checkbox({required this.value});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: value ? AppColors.gold : AppColors.border,
          width: 1.5,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.black)
          : null,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          disabledBackgroundColor: AppColors.goldDim,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black54,
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final String label;

  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _OAuthButtons extends StatelessWidget {
  const _OAuthButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OAuthButton(
            label: 'Google',
            assetIconPath: 'assets/icons/google.png',
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OAuthButton(
            label: 'Apple',
            icon: FontAwesomeIcons.apple,
            iconColor: const Color.fromARGB(15, 0, 0, 0),
            onPressed: () {},
          ),
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  final String label;
  final String? assetIconPath;
  final FaIconData? icon;
  final Color? iconColor;
  final VoidCallback onPressed;

  const _OAuthButton({
    required this.label,
    required this.onPressed,
    this.assetIconPath,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundColor: AppColors.textPrimary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (assetIconPath != null)
            Image.asset(
              assetIconPath!,
              width: 18,
              height: 18,
              fit: BoxFit.contain,
            )
          else if (icon != null)
            FaIcon(
              icon,
              size: 18,
              color: iconColor ?? AppColors.textPrimary,
            ),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PASSWORD STRENGTH INDICATOR
// ─────────────────────────────────────────────

class _PasswordStrengthIndicator extends StatelessWidget {
  final double strength;

  const _PasswordStrengthIndicator({required this.strength});

  Color get _color {
    if (strength <= 0.25) return AppColors.error;
    if (strength <= 0.50) return Colors.orange;
    if (strength <= 0.75) return Colors.amber;
    return AppColors.success;
  }

  String get _label {
    if (strength <= 0.25) return 'Très faible';
    if (strength <= 0.50) return 'Faible';
    if (strength <= 0.75) return 'Moyen';
    return 'Fort';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(_color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
         Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Force : ',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
                Text(
                  _label,
                  style: TextStyle(
                    color: _color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Text(
              '8+ car. · Maj. · Chiffre · Symbole',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textHint,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// MOT DE PASSE OUBLIÉ
// ─────────────────────────────────────────────

class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet();

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _sent = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mot de passe oublié',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _sent
                ? const _SentConfirmation(key: ValueKey('sent'))
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Entrez votre email pour recevoir un lien de réinitialisation.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _controller,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            hintText: 'vous@exemple.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: AuthValidators.email,
                        ),
                        const SizedBox(height: 20),
                        _SubmitButton(
                          label: 'Envoyer le lien',
                          icon: Icons.send_rounded,
                          isLoading: _isLoading,
                          onPressed: _send,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SentConfirmation extends StatelessWidget {
  const _SentConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.success,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Email envoyé !',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vérifiez votre boîte mail et cliquez sur le lien reçu. Il est valable 24h.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
