/// 8-pt spacing grid constants for EverWith.
/// Use these instead of raw double literals for all padding / gap values.
abstract final class AppSpacing {
  static const double xs = 4.0;   // 0.5×
  static const double sm = 8.0;   // 1×
  static const double md = 16.0;  // 2×
  static const double lg = 24.0;  // 3×
  static const double xl = 32.0;  // 4×
  static const double xxl = 40.0; // 5×

  // ── Border radii ────────────────────────────────────────────────────────
  static const double radiusSm = 14.0;
  static const double radiusMd = 20.0;
  static const double radiusLg = 28.0;
  static const double radiusPill = 40.0;

  // ── Touch targets ────────────────────────────────────────────────────────
  static const double minTouchTarget = 44.0;
}
