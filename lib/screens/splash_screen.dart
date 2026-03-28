import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SplashScreen
//
//  Shown at app launch. Plays a three-phase animation:
//    1. Logo + tagline fade/scale in (700 ms)
//    2. Hold (600 ms)
//    3. Fade out entire screen (400 ms) → then calls [onComplete]
//
//  The caller passes [onComplete] which performs the actual navigation,
//  so this widget stays decoupled from routing logic.
// ─────────────────────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // ── Animations ────────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _screenFade;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Total timeline: 1900 ms
    // 0–700  : logo scales + fades in
    // 300–700: tagline fades in (overlapping)
    // 700–1300: hold
    // 1300–1700: screen fades out
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.37, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.20, 0.50, curve: Curves.easeIn),
      ),
    );

    _screenFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.70, 0.95, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _screenFade.value,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo ──────────────────────────────────────────────────
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: MediaQuery.of(context).size.width * 0.72,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // ── Tagline ───────────────────────────────────────────────
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Your Voice Companion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textGray.withAlpha(180),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
