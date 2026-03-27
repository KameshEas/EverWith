import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/gradient_primary_button.dart';
import 'home_screen.dart';

/// Shown after Google Sign-In to collect mandatory profile details.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    super.key,
    this.prefillName,
    this.prefillEmail,
  });

  /// Name pre-filled from the Google account (editable).
  final String? prefillName;

  /// Email pre-filled from the Google account (read-only display).
  final String? prefillEmail;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _nameCtrl;
  final _phoneCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();

  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    String? nameErr;
    String? phoneErr;

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      nameErr = 'Please enter your full name.';
    } else if (name.length < 2) {
      nameErr = 'Name must be at least 2 characters.';
    }

    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      phoneErr = 'Please enter your phone number.';
    } else if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(phone)) {
      phoneErr = 'Enter a valid phone number.';
    }

    setState(() {
      _nameError = nameErr;
      _phoneError = phoneErr;
    });

    return nameErr == null && phoneErr == null;
  }

  void _onContinue() {
    if (!_validate()) return;

    // TODO: persist name & phone to Firestore / user profile
    final name = _nameCtrl.text.trim();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            HomeScreen(userName: name),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: AppLogo()),
                const SizedBox(height: AppSpacing.xl),

                // ── Heading ────────────────────────────────────────────
                Text(
                  'Complete your profile',
                  style: AppTextStyles.authHeading,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'We need a few details to personalise your experience.',
                  style: AppTextStyles.authSubtext,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Google account badge ───────────────────────────────
                if (widget.prefillEmail != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipBlueLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined,
                            color: AppColors.primaryBlue, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.prefillEmail!,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primaryBlueDark,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // ── Full name ──────────────────────────────────────────
                AuthTextField(
                  label: 'Full Name *',
                  hint: 'Enter your full name',
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  keyboardType: TextInputType.name,
                  errorText: _nameError,
                  onChanged: (_) {
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Phone number ───────────────────────────────────────
                AuthTextField(
                  label: 'Phone Number *',
                  hint: '+91 98765 43210',
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  errorText: _phoneError,
                  onChanged: (_) {
                    if (_phoneError != null) {
                      setState(() => _phoneError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Continue button ────────────────────────────────────
                GradientPrimaryButton(
                  label: 'Continue',
                  onTap: _onContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
