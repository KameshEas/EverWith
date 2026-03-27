import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Centralised text style definitions for EverWith.
/// Consume via `AppTextStyles.heading` etc. — never declare TextStyle inline
/// in widget files for recurring styles.
abstract final class AppTextStyles {
  // ── Display / Headings ──────────────────────────────────────────────────
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: -0.6,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    height: 1.2,
    letterSpacing: -0.6,
  );

  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryBlue,
    letterSpacing: -0.2,
  );

  // ── Body ────────────────────────────────────────────────────────────────
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
    height: 1.65,
    letterSpacing: 0.1,
  );

  // ── Button ─────────────────────────────────────────────────────────────
  static const TextStyle buttonLabel = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  // ── Caption / Footer ────────────────────────────────────────────────────
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
    letterSpacing: 0.2,
  );

  // ── Auth / Form ────────────────────────────────────────────────────────
  static const TextStyle inputLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: 0.1,
  );

  static const TextStyle inputText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
    letterSpacing: 0.1,
  );

  static const TextStyle inputHint = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
  );

  static const TextStyle inputError = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.errorRed,
    letterSpacing: 0.1,
  );

  static const TextStyle authHeading = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle authSubtext = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
    height: 1.5,
  );

  static const TextStyle linkText = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.linkBlue,
  );

  static const TextStyle switchAuthText = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: AppColors.textGray,
  );
}
