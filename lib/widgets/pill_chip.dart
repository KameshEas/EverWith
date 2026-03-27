import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';

/// A rounded pill-shaped label chip.
///
/// Used for highlighted sub-labels (e.g. "Your friendly voice companion").
/// Defaults to the app's blue chip palette; override [backgroundColor] and
/// [textStyle] for alternate colour themes.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.backgroundColor = AppColors.chipBlueLight,
    this.textStyle = AppTextStyles.subheading,
  });

  final String label;
  final Color backgroundColor;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 4, // 20px
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Text(label, textAlign: TextAlign.center, style: textStyle),
    );
  }
}
