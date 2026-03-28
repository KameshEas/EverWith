import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Shows a styled bottom-sheet confirmation with an icon badge, title,
/// message, and two full-width buttons.
///
/// Returns `true` when the user confirms, `false`/`null` otherwise.
///
/// ```dart
/// final ok = await showConfirmSheet(
///   context,
///   icon: Icons.logout_rounded,
///   iconColor: AppColors.errorRed,
///   iconBackground: AppColors.errorRedLight,
///   title: 'Sign Out?',
///   message: 'Are you sure you want to sign out?',
///   confirmLabel: 'Sign Out',
/// );
/// if (ok == true) { /* proceed */ }
/// ```
Future<bool?> showConfirmSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  Color iconColor = AppColors.errorRed,
  Color iconBackground = AppColors.errorRedLight,
  Color confirmColor = AppColors.errorRed,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.inputBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Icon badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: AppSpacing.md),

            // Title
            Text(title,
                style: AppTextStyles.heading.copyWith(fontSize: 20),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),

            // Message
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(message,
                  style: AppTextStyles.body
                      .copyWith(fontSize: 14, color: AppColors.textGray),
                  textAlign: TextAlign.center),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Confirm button
            _SheetButton(
              label: confirmLabel,
              color: confirmColor,
              textColor: Colors.white,
              onTap: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Cancel button
            _SheetButton(
              label: cancelLabel,
              color: AppColors.inputBackground,
              textColor: AppColors.textDark,
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor)),
      ),
    );
  }
}
