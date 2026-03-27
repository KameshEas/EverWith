import 'package:flutter/material.dart';

/// Central color palette for EverWith.
/// All UI layers must reference these tokens — never use raw Color() literals
/// in widget files.
abstract final class AppColors {
  // ── Primary ─────────────────────────────────────────────────────────────
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryBlueDark = Color(0xFF2563EB);
  static const Color primaryBlueLight = Color(0xFF60A5FA);

  // ── Surface / Background ────────────────────────────────────────────────
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color chipBlueLight = Color(0xFFEFF6FF);

  // ── Text ────────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGray = Color(0xFF64748B);

  // ── Utility ─────────────────────────────────────────────────────────────
  static const Color shadow = Color(0xFF94A3B8);
  static const Color iconMuted = Color(0xFF475569);

  // ── Auth / Form ────────────────────────────────────────────────────────
  static const Color inputBackground = Color(0xFFF1F5F9);
  static const Color inputBorder = Color(0xFFCBD5E1);
  static const Color inputBorderFocus = Color(0xFF3B82F6);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorRedLight = Color(0xFFFEF2F2);
  static const Color successGreen = Color(0xFF10B981);
  static const Color divider = Color(0xFFE2E8F0);
  static const Color linkBlue = Color(0xFF2563EB);

  // ── Placeholder gradient ─────────────────────────────────────────────────
  static const Color placeholderStart = Color(0xFFDBEAFF);
  static const Color placeholderMid = Color(0xFFBDD5FF);
  static const Color placeholderEnd = Color(0xFFD6ECFF);
}
