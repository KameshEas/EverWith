import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/auth_result.dart';
import '../core/auth/auth_service.dart';
import '../core/constants/app_spacing.dart';
import '../core/models/user_profile.dart';
import '../core/services/firestore_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_primary_button.dart';
import '../widgets/google_sign_in_button.dart';
import 'caregiver/caregiver_home_screen.dart';
import 'caregiver/caregiver_pairing_screen.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';
import 'signup_screen.dart';

/// Login screen for EverWith.
///
/// Design principles:
/// - Large, readable typography (WCAG AA)
/// - Spacious 60 px+ input fields
/// - Inline validation with clear error messages
/// - Single-column, scroll-safe layout for accessibility
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.wakeWordNotLoggedIn = false});

  final bool wakeWordNotLoggedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  String? _emailError;
  String? _passwordError;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.wakeWordNotLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Please sign in to use voice commands.',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: const Color(0xFFF59E0B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────
  bool _validate() {
    bool valid = true;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() {
      if (email.isEmpty) {
        _emailError = 'Please enter your email';
        valid = false;
      } else if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$').hasMatch(email)) {
        _emailError = 'Invalid email address';
        valid = false;
      } else {
        _emailError = null;
      }

      if (password.isEmpty) {
        _passwordError = 'Please enter your password';
        valid = false;
      } else if (password.length < 6) {
        _passwordError = 'Password is too short';
        valid = false;
      } else {
        _passwordError = null;
      }
    });

    return valid;
  }

  Future<void> _onLogin() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);
    final result = await AuthService.instance.signInWithEmail(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    switch (result) {
      case AuthSuccess(:final user):
        await _routeByRole(user.uid, user.displayName);
      case AuthFailure(:final message, :final code):
        // If no account exists for this email, push to Signup with email pre-filled
        if (code == 'user-not-found' || code == 'invalid-credential') {
          _goToSignupWithEmail(_emailCtrl.text.trim());
        } else {
          _showError(message);
        }
    }
  }

  Future<void> _onGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    switch (result) {
      case AuthSuccess(:final user):
        if (!mounted) return;
        // Try to check/create Firestore profile
        UserProfile? profile;
        try {
          profile =
              await FirestoreService.instance.getUserProfile(user.uid);
          if (!mounted) return;

          // New Google user — create Firestore profile
          if (profile == null) {
            final prefs = await SharedPreferences.getInstance();
            final roleName = prefs.getString('user_role');
            final role =
                roleName == 'caregiver' ? UserRole.caregiver : UserRole.elder;
            profile = UserProfile(
              uid: user.uid,
              name: user.displayName ?? '',
              email: user.email,
              role: role,
              photoUrl: user.photoUrl,
              createdAt: DateTime.now(),
            );
            await FirestoreService.instance.createUserProfile(profile);
            if (!mounted) return;
          }
        } catch (e) {
          debugPrint('[Login] Firestore Google profile sync failed: $e');
        }
        if (!mounted) return;

        if (profile != null && profile.role == UserRole.caregiver) {
          _navigateToCaregiverHome(
            user.uid,
            user.displayName ?? profile.name,
            profile.linkedElderUid,
          );
          return;
        }
        // Elder or fallback — regular flow
        final needsProfile =
            user.displayName == null || user.displayName!.trim().isEmpty;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (_, animation, __) => needsProfile
                ? ProfileSetupScreen(
                    prefillName: user.displayName,
                    prefillEmail: user.email,
                  )
                : HomeScreen(userName: user.displayName!),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      case AuthFailure(:final message):
        _showError(message);
    }
  }

  Future<void> _routeByRole(String uid, String? displayName) async {
    try {
      final profile = await FirestoreService.instance.getUserProfile(uid);
      if (!mounted) return;
      if (profile != null && profile.role == UserRole.caregiver) {
        _navigateToCaregiverHome(uid, displayName ?? profile.name, profile.linkedElderUid);
        return;
      }
    } catch (e) {
      debugPrint('[Login] Firestore role check failed: $e');
    }
    if (!mounted) return;
    _navigateToHome();
  }

  void _navigateToCaregiverHome(
      String uid, String name, String? elderUid) {
    final Widget dest = elderUid != null
        ? CaregiverHomeScreen(caregiverName: name, elderUid: elderUid)
        : CaregiverPairingScreen(caregiverUid: uid, caregiverName: name);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dest),
      (_) => false,
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
  }

  void _onForgotPassword() {
    showDialog<void>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(
        initialEmail: _emailCtrl.text,
        onSend: (email) async {
          final result =
              await AuthService.instance.sendPasswordResetEmail(email);
          if (!mounted) return;
          Navigator.of(context).pop();
          final AuthResult authResult = result;
          final msg = switch (authResult) {
            AuthSuccess() => 'A reset link has been sent to $email',
            AuthFailure(:final message) => message,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(fontSize: 16)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  void _goToSignup() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const SignupScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _goToSignupWithEmail(String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No account found for $email. Please sign up.',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: AppColors.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
      ),
    );
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => SignupScreen(prefillEmail: email),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const _LoginHeader(),
                const SizedBox(height: AppSpacing.xxl + AppSpacing.md),
                const _WelcomeText(),
                const SizedBox(height: AppSpacing.xl),
                _EmailField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) setState(() => _emailError = null);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _PasswordField(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  errorText: _passwordError,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _ForgotPasswordButton(onTap: _onForgotPassword),
                const SizedBox(height: AppSpacing.xl),
                _LoginButton(isLoading: _isLoading, onTap: _onLogin),
                const SizedBox(height: AppSpacing.lg),
                const _OrDivider(),
                const SizedBox(height: AppSpacing.lg),
                GoogleSignInButton(
                  isLoading: _isGoogleLoading,
                  onTap: _onGoogleSignIn,
                ),
                const SizedBox(height: AppSpacing.xl),
                _SwitchToSignup(onTap: _goToSignup),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          label: 'Go back',
          button: true,
          child: GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: AppSpacing.minTouchTarget,
              height: AppSpacing.minTouchTarget,
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textDark,
                size: 18,
              ),
            ),
          ),
        ),
        const Spacer(),
        const AppLogo(iconSize: 26),
      ],
    );
  }
}

class _WelcomeText extends StatelessWidget {
  const _WelcomeText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome Back', style: AppTextStyles.authHeading),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Sign in to continue using\nyour voice companion',
          style: AppTextStyles.authSubtext,
        ),
      ],
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: 'Email Address',
      hint: 'Enter your email',
      controller: controller,
      focusNode: focusNode,
      prefixIcon: Icons.mail_outline_rounded,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      errorText: errorText,
      onChanged: onChanged,
      autofillHints: const [AutofillHints.email],
      showMicIcon: true,
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      label: 'Password',
      hint: 'Enter your password',
      controller: controller,
      focusNode: focusNode,
      prefixIcon: Icons.lock_outline_rounded,
      isPassword: true,
      textInputAction: TextInputAction.done,
      errorText: errorText,
      onChanged: onChanged,
      autofillHints: const [AutofillHints.password],
    );
  }
}

class _ForgotPasswordButton extends StatelessWidget {
  const _ForgotPasswordButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        label: 'Forgot Password',
        button: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Text('Forgot Password?', style: AppTextStyles.linkText),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primaryBlue,
                strokeWidth: 3,
              ),
            ),
          )
        : GradientPrimaryButton(
            label: 'Login',
            trailingIcon: Icons.arrow_forward_rounded,
            onTap: onTap,
          );
  }
}

class _SwitchToSignup extends StatelessWidget {
  const _SwitchToSignup({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: AppTextStyles.switchAuthText),
        Semantics(
          label: 'Sign Up',
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: Text('Sign Up', style: AppTextStyles.linkText),
          ),
        ),
      ],
    );
  }
}

// ── Or divider ───────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.divider, thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('or', style: AppTextStyles.switchAuthText),
        ),
        const Expanded(child: Divider(color: AppColors.divider, thickness: 1.5)),
      ],
    );
  }
}

// ── Forgot Password dialog ────────────────────────────────────────────────────

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSend,
  });

  final String initialEmail;
  final Future<void> Function(String email) onSend;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _ctrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      title: Text('Reset Password', style: AppTextStyles.authHeading.copyWith(fontSize: 22)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your email and we will send you a reset link.',
            style: AppTextStyles.authSubtext.copyWith(fontSize: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          AuthTextField(
            label: 'Email Address',
            hint: 'Enter your email',
            controller: _ctrl,
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTextStyles.linkText.copyWith(color: AppColors.textGray)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.cardWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
          ),
          onPressed: _sending
              ? null
              : () async {
                  setState(() => _sending = true);
                  await widget.onSend(_ctrl.text.trim());
                },
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('Send Link', style: AppTextStyles.buttonLabel.copyWith(fontSize: 16)),
        ),
      ],
    );
  }
}
