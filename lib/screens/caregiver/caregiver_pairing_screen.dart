import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/gradient_primary_button.dart';
import 'caregiver_home_screen.dart';

/// Shown after a caregiver signs up.
/// They enter a 6-digit pairing code from the elder's device to link accounts.
class CaregiverPairingScreen extends StatefulWidget {
  const CaregiverPairingScreen({
    super.key,
    required this.caregiverUid,
    required this.caregiverName,
  });

  final String caregiverUid;
  final String caregiverName;

  @override
  State<CaregiverPairingScreen> createState() =>
      _CaregiverPairingScreenState();
}

class _CaregiverPairingScreenState extends State<CaregiverPairingScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Please enter a 6-character code');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final elderUid = await FirestoreService.instance.redeemPairingCode(
      code: code,
      caregiverUid: widget.caregiverUid,
    );

    if (!mounted) return;

    if (elderUid == null) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid or expired code. Please try again.';
      });
      return;
    }

    // Success — navigate to caregiver home
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => CaregiverHomeScreen(
          caregiverName: widget.caregiverName,
          elderUid: elderUid,
        ),
      ),
      (_) => false,
    );
  }

  void _skipForNow() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => CaregiverHomeScreen(
          caregiverName: widget.caregiverName,
          elderUid: null,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              const Center(child: AppLogo(iconSize: 28)),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Link to your\nloved one',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ask them to share the 6-digit pairing\ncode from their Settings page.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Code input
              TextField(
                controller: _codeCtrl,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: AppTextStyles.heading.copyWith(
                  fontSize: 36,
                  letterSpacing: 12,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  UpperCaseTextFormatter(),
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '------',
                  hintStyle: AppTextStyles.heading.copyWith(
                    fontSize: 36,
                    letterSpacing: 12,
                    color: AppColors.inputBorder,
                  ),
                  filled: true,
                  fillColor: AppColors.inputBackground,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(
                      color: AppColors.primaryBlue,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.lg,
                    horizontal: AppSpacing.md,
                  ),
                  errorText: _error,
                  errorStyle: AppTextStyles.inputError,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                      ),
                    )
                  : GradientPrimaryButton(
                      label: 'Link Accounts',
                      onTap: _onSubmit,
                    ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: _skipForNow,
                  child: Text(
                    'Skip for now',
                    style: AppTextStyles.linkText.copyWith(
                      color: AppColors.textGray,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Converts typed text to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
