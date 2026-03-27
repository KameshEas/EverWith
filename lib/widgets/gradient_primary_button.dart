import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';

/// Full-width primary action button with a blue gradient fill and glow shadow.
///
/// Parameters
/// ----------
/// [label]     — Button text (required).
/// [onTap]     — Callback invoked on press (required).
/// [trailingIcon] — Optional icon shown inside a frosted circle on the right.
///                Defaults to [Icons.arrow_forward_rounded].
class GradientPrimaryButton extends StatelessWidget {
  const GradientPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailingIcon = Icons.arrow_forward_rounded,
  });

  final String label;
  final VoidCallback onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withAlpha(102),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: AppTextStyles.buttonLabel),
              const SizedBox(width: 10),
              _FrostedIconCircle(icon: trailingIcon),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private helper — only used by GradientPrimaryButton ──────────────────────
class _FrostedIconCircle extends StatelessWidget {
  const _FrostedIconCircle({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(51),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
