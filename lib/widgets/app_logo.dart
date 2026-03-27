import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppLogo
//  Horizontal lockup: sound-wave icon + "EverWith" word mark.
//  Reused in the header, splash screen, and any branded surface.
// ─────────────────────────────────────────────────────────────────────────────
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.iconSize = 28.0});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SoundWaveIcon(color: AppColors.primaryBlue, size: iconSize),
        const SizedBox(width: AppSpacing.sm),
        const Text('EverWith', style: AppTextStyles.appBarTitle),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _SoundWaveIcon  (private to this file — only used by AppLogo)
// ─────────────────────────────────────────────────────────────────────────────
class _SoundWaveIcon extends StatelessWidget {
  const _SoundWaveIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SoundWavePainter(color: color),
    );
  }
}

class _SoundWavePainter extends CustomPainter {
  const _SoundWavePainter({required this.color});

  final Color color;

  static const List<double> _barRatios = [0.28, 0.54, 1.0, 0.54, 0.28];

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.height / 2;
    final double spacing = size.width / 6;
    final double maxH = size.height * 0.82;
    final double barW = spacing * 0.55;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < _barRatios.length; i++) {
      final double x = spacing * (i + 0.9);
      final double halfH = (maxH * _barRatios[i]) / 2;
      canvas.drawLine(Offset(x, cx - halfH), Offset(x, cx + halfH), paint);
    }
  }

  @override
  bool shouldRepaint(_SoundWavePainter old) => old.color != color;
}
