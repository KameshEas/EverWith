import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Full-width Google Sign-In button following Google's branding guidelines.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
  });

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Continue with Google',
      button: true,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            border: Border.all(color: AppColors.inputBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleLogo(),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Text(
                      'Continue with Google',
                      style: AppTextStyles.inputLabel.copyWith(
                        color: AppColors.textDark,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Hand-drawn Google "G" logo using canvas — no external assets required.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Draw coloured arc segments
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.195
      ..strokeCap = StrokeCap.butt;

    // Blue (right-bottom)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      -0.25,
      1.85,
      false,
      paint,
    );
    // Green (bottom-left)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      1.6,
      1.1,
      false,
      paint,
    );
    // Yellow (left-top)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      2.7,
      0.9,
      false,
      paint,
    );
    // Red (top-right)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72),
      3.6,
      0.9,
      false,
      paint,
    );

    // Horizontal bar of the "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.195
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * 0.72, cy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
