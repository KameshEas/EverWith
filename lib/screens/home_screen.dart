import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/services/wake_word_service.dart';
import 'settings_screen.dart';

import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/app_logo.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HomeScreen
//  Main dashboard reached after onboarding. Provides the core voice assistant
//  interface: a prominent mic button and quick-action cards.
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.userName = 'Friend', this.autoListen = false});

  final String userName;
  final bool autoListen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';
  bool _wakeWordActive = false; // banner shown after wake word fires

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initSpeech();
    _subscribeToWakeWord();
    if (widget.autoListen) {
      // Slight delay to let STT initialize
      Future.delayed(const Duration(milliseconds: 800), _activateMic);
    }
    // Also poll via method channel — handles the case where the app was
    // launched cold from the heads-up notification and onResume fires
    // before the EventChannel stream was subscribed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final autoListen = await WakeWordService.instance.getAutoListen();
        if (autoListen && mounted) {
          Future.delayed(const Duration(milliseconds: 900), _activateMic);
        }
      } catch (_) {}
    });
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => _onSpeechError(e.errorMsg),
      onStatus: (status) {
        if (status == stt.SpeechToText.notListeningStatus) {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _subscribeToWakeWord() async {
    try {
      WakeWordService.instance.onWakeWordDetected.listen((phrase) {
        if (!mounted) return;
        // Show a brief banner then auto-start STT
        setState(() {
          _wakeWordActive = true;
          _recognizedText = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${_capitalize(phrase)}" detected — listening!',
              style: const TextStyle(fontSize: 16),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
        Future.delayed(const Duration(milliseconds: 300), _activateMic);
      });
    } catch (_) {
      // Wake word service not available (e.g. iOS/web) — silently ignore
    }
  }

  Future<void> _activateMic() async {
    if (!_speechAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _wakeWordActive = false;
      _recognizedText = '';
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) setState(() => _recognizedText = result.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _speech.cancel();
    super.dispose();
  }

  Future<void> _onMicPressed() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Speech recognition not available on this device.',
              style: TextStyle(fontSize: 16)),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() => _recognizedText = result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        localeId: 'en_US',
      );
    }
  }

  void _onSpeechError(String error) {
    if (!mounted) return;
    setState(() => _isListening = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Speech error: $error', style: const TextStyle(fontSize: 16)),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                _HomeHeader(
                  onSettingsTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                _GreetingBanner(userName: widget.userName),
                const SizedBox(height: AppSpacing.xl + 8),
                _MicSection(
                  pulseAnim: _pulseAnim,
                  isListening: _isListening,
                  onTap: _onMicPressed,
                  recognizedText: _recognizedText,
                ),
                const SizedBox(height: AppSpacing.xl),
                const _QuickActionsGrid(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HomeHeader
// ─────────────────────────────────────────────────────────────────────────────
class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettingsTap});

  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const AppLogo(iconSize: 24),
        Semantics(
          button: true,
          label: 'Open settings',
          child: GestureDetector(
            onTap: onSettingsTap,
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
              child: const Icon(
                Icons.settings_rounded,
                size: 22,
                color: AppColors.iconMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _GreetingBanner
// ─────────────────────────────────────────────────────────────────────────────
class _GreetingBanner extends StatelessWidget {
  const _GreetingBanner({required this.userName});

  final String userName;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$_greeting,',
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(
            fontSize: 20,
            color: AppColors.textGray,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          userName,
          textAlign: TextAlign.center,
          style: AppTextStyles.heading.copyWith(fontSize: 34),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'How can I help you today?',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MicSection  — central mic button with listening state ring
// ─────────────────────────────────────────────────────────────────────────────
class _MicSection extends StatelessWidget {
  const _MicSection({
    required this.pulseAnim,
    required this.isListening,
    required this.onTap,
    required this.recognizedText,
  });

  final Animation<double> pulseAnim;
  final bool isListening;
  final VoidCallback onTap;
  final String recognizedText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ScaleTransition(
          scale: pulseAnim,
          child: Semantics(
            button: true,
            label: isListening ? 'Stop listening' : 'Tap to speak',
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isListening
                        ? [const Color(0xFF34D399), const Color(0xFF059669)]
                        : [AppColors.primaryBlueLight, AppColors.primaryBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isListening
                              ? const Color(0xFF059669)
                              : AppColors.primaryBlue)
                          .withAlpha(128),
                      blurRadius: 32,
                      spreadRadius: 4,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            isListening ? 'Listening…' : 'Tap the mic to speak',
            key: ValueKey(isListening),
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w500,
              color: isListening
                  ? const Color(0xFF059669)
                  : AppColors.textGray,
            ),
          ),
        ),
        if (recognizedText.isNotEmpty) ...
          [
            const SizedBox(height: AppSpacing.lg),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withAlpha(25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                recognizedText,
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                    fontSize: 18, color: AppColors.textDark),
              ),
            ),
          ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _QuickActionsGrid
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  static const List<_QuickAction> _actions = [
    _QuickAction(
      icon: Icons.phone_rounded,
      label: 'Call Family',
      color: Color(0xFF3B82F6),
      bgColor: Color(0xFFEFF6FF),
    ),
    _QuickAction(
      icon: Icons.medication_rounded,
      label: 'Medicines',
      color: Color(0xFF8B5CF6),
      bgColor: Color(0xFFF5F3FF),
    ),
    _QuickAction(
      icon: Icons.emergency_rounded,
      label: 'Emergency',
      color: Color(0xFFEF4444),
      bgColor: Color(0xFFFEF2F2),
    ),
    _QuickAction(
      icon: Icons.calendar_today_rounded,
      label: 'Reminders',
      color: Color(0xFFF59E0B),
      bgColor: Color(0xFFFFFBEB),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: _actions
              .map((a) => _QuickActionCard(action: a))
              .toList(),
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${action.label} — coming soon!',
                style: const TextStyle(fontSize: 16),
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: action.color,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: action.bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: action.color.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  action.label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
