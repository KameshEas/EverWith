import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/auth/auth_result.dart';
import '../core/auth/auth_service.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_primary_button.dart';
import '../widgets/google_sign_in_button.dart';
import 'home_screen.dart';
import 'permissions_screen.dart';
import 'profile_setup_screen.dart';

/// Signup screen for EverWith.
///
/// Design principles:
/// - Large, readable typography (WCAG AA)
/// - Spacious 60 px+ input fields
/// - Country-code prefix widget on phone field
/// - All five fields validated with clear inline messages
/// - Password strength indicator
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.prefillEmail});

  /// Email pre-filled when redirected from Login (account not found).
  final String? prefillEmail;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) {
      _emailCtrl.text = widget.prefillEmail!;
    }
  }

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  // ── Country code ─────────────────────────────────────────────────────────
  String _countryCode = '+1';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────
  bool _validate() {
    bool valid = true;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmPasswordCtrl.text;

    setState(() {
      // Name
      if (name.isEmpty) {
        _nameError = 'Please enter your name';
        valid = false;
      } else if (name.length < 2) {
        _nameError = 'Name is too short';
        valid = false;
      } else {
        _nameError = null;
      }

      // Email
      if (email.isEmpty) {
        _emailError = 'Please enter your email';
        valid = false;
      } else if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.\w{2,}$').hasMatch(email)) {
        _emailError = 'Invalid email address';
        valid = false;
      } else {
        _emailError = null;
      }

      // Phone (optional but validated if provided)
      if (phone.isNotEmpty && !RegExp(r'^\d{7,15}$').hasMatch(phone)) {
        _phoneError = 'Enter a valid phone number';
        valid = false;
      } else {
        _phoneError = null;
      }

      // Password
      if (password.isEmpty) {
        _passwordError = 'Please create a password';
        valid = false;
      } else if (password.length < 8) {
        _passwordError = 'Password must be at least 8 characters';
        valid = false;
      } else {
        _passwordError = null;
      }

      // Confirm password
      if (confirm.isEmpty) {
        _confirmPasswordError = 'Please confirm your password';
        valid = false;
      } else if (confirm != password) {
        _confirmPasswordError = 'Passwords do not match';
        valid = false;
      } else {
        _confirmPasswordError = null;
      }
    });

    return valid;
  }

  Future<void> _onSignup() async {
    // Guard: mic permission required
    if (!await _checkMicPermission()) return;
    if (!_validate()) return;
    setState(() => _isLoading = true);
    final result = await AuthService.instance.createAccountWithEmail(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    switch (result) {
      case AuthSuccess():
        _navigateToHome();
      case AuthFailure(:final message):
        _showError(message);
    }
  }

  Future<bool> _checkMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
            'Microphone permission is required to create an account.'),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        action: SnackBarAction(
          label: 'Grant',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                  builder: (_) => const PermissionsScreen()),
            );
          },
        ),
      ),
    );
    return false;
  }

  Future<void> _onGoogleSignIn() async {
    // Guard: mic permission required
    if (!await _checkMicPermission()) return;
    setState(() => _isGoogleLoading = true);
    final result = await AuthService.instance.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    switch (result) {
      case AuthSuccess(:final user):
        if (!mounted) return;
        // If the user already has a display name, skip profile setup
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

  void _goToLogin() => Navigator.of(context).maybePop();

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const _SignupHeader(),
              const SizedBox(height: AppSpacing.xl),
              const _SignupWelcomeText(),
              const SizedBox(height: AppSpacing.xl),

              // Name
              AuthTextField(
                label: 'Full Name',
                hint: 'Enter your name',
                controller: _nameCtrl,
                focusNode: _nameFocus,
                prefixIcon: Icons.person_outline_rounded,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                errorText: _nameError,
                showMicIcon: true,
                autofillHints: const [AutofillHints.name],
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Email
              AuthTextField(
                label: 'Email Address',
                hint: 'Enter your email',
                controller: _emailCtrl,
                focusNode: _emailFocus,
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _emailError,
                showMicIcon: true,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Phone with country code
              AuthTextField(
                label: 'Phone Number',
                hint: 'Enter your phone number',
                controller: _phoneCtrl,
                focusNode: _phoneFocus,
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                errorText: _phoneError,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.telephoneNumber],
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                suffixWidget: _CountryCodeButton(
                  code: _countryCode,
                  onTap: () => _showCountryCodePicker(context),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Password
              AuthTextField(
                label: 'Password',
                hint: 'Create a password',
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.next,
                errorText: _passwordError,
                autofillHints: const [AutofillHints.newPassword],
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() => _passwordError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              _PasswordStrengthBar(password: _passwordCtrl.text),
              const SizedBox(height: AppSpacing.lg),

              // Confirm Password
              AuthTextField(
                label: 'Confirm Password',
                hint: 'Confirm your password',
                controller: _confirmPasswordCtrl,
                focusNode: _confirmPasswordFocus,
                prefixIcon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                errorText: _confirmPasswordError,
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() => _confirmPasswordError = null);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              _SignupButton(isLoading: _isLoading, onTap: _onSignup),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.divider, thickness: 1.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Text('or', style: AppTextStyles.switchAuthText),
                  ),
                  const Expanded(child: Divider(color: AppColors.divider, thickness: 1.5)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              GoogleSignInButton(
                isLoading: _isGoogleLoading,
                onTap: _onGoogleSignIn,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SwitchToLogin(onTap: _goToLogin),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showCountryCodePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryCodeSheet(
        selected: _countryCode,
        onSelected: (code) {
          setState(() => _countryCode = code);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SignupHeader extends StatelessWidget {
  const _SignupHeader();

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

class _SignupWelcomeText extends StatelessWidget {
  const _SignupWelcomeText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create Account', style: AppTextStyles.authHeading),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Join EverWith and stay connected\nwith care',
          style: AppTextStyles.authSubtext,
        ),
      ],
    );
  }
}

class _CountryCodeButton extends StatelessWidget {
  const _CountryCodeButton({required this.code, required this.onTap});

  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Country code $code. Tap to change',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: AppTextStyles.inputText.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated password strength bar — 4 segments, red → orange → yellow → green.
class _PasswordStrengthBar extends StatelessWidget {
  const _PasswordStrengthBar({required this.password});

  final String password;

  int _strength() {
    if (password.isEmpty) return 0;
    int s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'\d').hasMatch(password)) s++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) s++;
    return s;
  }

  static const _colors = [
    AppColors.errorRed,
    Color(0xFFF97316), // orange
    Color(0xFFEAB308), // yellow
    AppColors.successGreen,
  ];

  static const _labels = ['Weak', 'Fair', 'Good', 'Strong'];

  @override
  Widget build(BuildContext context) {
    final s = _strength();
    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < s;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                margin: EdgeInsets.only(right: i < 3 ? AppSpacing.xs : 0),
                decoration: BoxDecoration(
                  color: filled ? _colors[s - 1] : AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Password strength: ${_labels[s - 1]}',
          style: AppTextStyles.inputError.copyWith(color: _colors[s - 1]),
        ),
      ],
    );
  }
}

class _SignupButton extends StatelessWidget {
  const _SignupButton({required this.isLoading, required this.onTap});

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
            label: 'Sign Up',
            trailingIcon: Icons.arrow_forward_rounded,
            onTap: onTap,
          );
  }
}

class _SwitchToLogin extends StatelessWidget {
  const _SwitchToLogin({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: AppTextStyles.switchAuthText),
        Semantics(
          label: 'Login',
          button: true,
          child: GestureDetector(
            onTap: onTap,
            child: Text('Login', style: AppTextStyles.linkText),
          ),
        ),
      ],
    );
  }
}

// ── Country Code Picker Bottom Sheet ─────────────────────────────────────────

const _kCountryCodes = [
  ('+1', 'US / Canada'),
  ('+44', 'United Kingdom'),
  ('+91', 'India'),
  ('+61', 'Australia'),
  ('+49', 'Germany'),
  ('+33', 'France'),
  ('+81', 'Japan'),
  ('+55', 'Brazil'),
  ('+52', 'Mexico'),
  ('+971', 'UAE'),
  ('+65', 'Singapore'),
  ('+60', 'Malaysia'),
];

class _CountryCodeSheet extends StatelessWidget {
  const _CountryCodeSheet({
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.inputBorder,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Select Country Code',
                style: AppTextStyles.inputLabel.copyWith(fontSize: 18)),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._kCountryCodes.map(
            (entry) => _CountryCodeTile(
              code: entry.$1,
              country: entry.$2,
              isSelected: selected == entry.$1,
              onTap: () => onSelected(entry.$1),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _CountryCodeTile extends StatelessWidget {
  const _CountryCodeTile({
    required this.code,
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final String code;
  final String country;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: '$country $code',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.chipBlueLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                code,
                style: AppTextStyles.inputText.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.primaryBlue
                      : AppColors.textDark,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  country,
                  style: AppTextStyles.inputText.copyWith(
                    color: AppColors.textGray,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
