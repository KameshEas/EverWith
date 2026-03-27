import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/constants/app_spacing.dart';

/// A square, card-style icon button used in app bar / header rows.
///
/// Provides a guaranteed [AppSpacing.minTouchTarget] tap area (44×44),
/// a white card background, rounded corners, and a soft drop shadow.
/// Wrap it in `Semantics` at the call site only when a custom label
/// is required beyond [semanticLabel].
class AppHeaderIconButton extends StatelessWidget {
  const AppHeaderIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: AppSpacing.minTouchTarget,
          height: AppSpacing.minTouchTarget,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(38),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: AppColors.iconMuted),
        ),
      ),
    );
  }
}
