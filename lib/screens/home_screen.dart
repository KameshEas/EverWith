import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/auth/auth_service.dart';
import '../core/constants/app_languages.dart';
import '../core/constants/app_spacing.dart';
import '../core/services/caregiver_alert_service.dart';
import '../core/services/family_service.dart';
import '../core/services/wake_word_service.dart';
import '../core/settings/accessibility_settings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'family_screen.dart';
import 'medicines_screen.dart';
import 'settings_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HomeScreen  — main shell with bottom nav + centre mic FAB
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.userName = 'Friend',
    this.autoListen = false,
  });

  final String userName;
  final bool autoListen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Bottom nav index ────────────────────────────────────────────────────
  int _selectedIndex = 0;

  // ── Pulse animation for mic ─────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── STT ─────────────────────────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;
  String _recognizedText = '';

  // ── Silence-detection for continuous listening ──────────────────────────
  // When STT stops mid-utterance (Android server timeout) we restart it
  // automatically until a real silence of [_silenceGap] elapses.
  static const _silenceGap = Duration(seconds: 6);
  DateTime? _lastWordTime;
  bool _autoRelistening = false;

  // ── Profile photo (local cache) ─────────────────────────────────────────
  File? _profilePhoto;

  // ── Text-to-speech ──────────────────────────────────────────────────────
  final _tts = TtsService.instance;
  bool get _isSpeaking => _tts.isSpeaking;
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

    WidgetsBinding.instance.addObserver(this);
    _initSpeech();
    _subscribeToWakeWord();
    _loadProfilePhoto();

    if (widget.autoListen) {
      Future.delayed(const Duration(milliseconds: 800), _activateMic);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final autoListen = await WakeWordService.instance.getAutoListen();
        if (autoListen && mounted) {
          Future.delayed(const Duration(milliseconds: 900), _activateMic);
        }
      } catch (_) {}
    });
  }

  // ── TTS helpers ─────────────────────────────────────────────────────────

  /// Speaks a random greeting and calls [onDone] when TTS finishes.
  Future<void> _speakGreeting({required VoidCallback onDone}) async {
    if (!mounted) return;
    final name = widget.userName.isNotEmpty ? widget.userName : 'there';
    const greetings = [
      'Hey {name}! What can I help you with today?',
      'Hello {name}, how can I assist you right now?',
      'Hi {name}! I am listening. What do you need?',
    ];
    final text = greetings[Random().nextInt(greetings.length)]
        .replaceAll('{name}', name);

    await _tts.speak(
      text,
      onDone: () { if (mounted) onDone(); },
      onError: (_) { if (mounted) onDone(); },
    );
  }

  /// Speaks greeting then immediately starts listen cycle.
  Future<void> _speakGreetingThenListen() async {
    await _speakGreeting(onDone: () {
      if (mounted && _autoRelistening) _restartListenCycle();
    });
  }

  Future<void> _loadProfilePhoto() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/profile_photo.jpg');
      if (await file.exists() && mounted) {
        setState(() => _profilePhoto = file);
      }
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onError: (e) => _onSpeechError(e.errorMsg),
      onStatus: (status) {
        if (status == stt.SpeechToText.notListeningStatus) {
          if (!mounted) return;
          if (_autoRelistening) {
            // Mid-speech restart — check if real silence has elapsed
            final sinceLastWord = _lastWordTime == null
                ? _silenceGap
                : DateTime.now().difference(_lastWordTime!);
            if (sinceLastWord < _silenceGap) {
              // User is still speaking (just an Android recognizer timeout)
              // — restart immediately and keep accumulating words
              _restartListenCycle();
              return;
            }
          }
          // Real silence — finalise
          _autoRelistening = false;
          _lastWordTime = null;
          setState(() => _isListening = false);
          try { WakeWordService.instance.resume(); } catch (_) {}
        }
      },
    );
    if (mounted) setState(() {});
  }

  /// Restarts a single STT cycle during continuous listening.
  Future<void> _restartListenCycle() async {
    if (!mounted || !_autoRelistening) return;
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        if (result.recognizedWords.isNotEmpty) {
          _lastWordTime = DateTime.now();
          setState(() => _recognizedText = result.recognizedWords);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: _silenceGap,
      localeId: 'en_US',
      cancelOnError: false,
    );
  }

  Future<void> _subscribeToWakeWord() async {
    try {
      WakeWordService.instance.onWakeWordDetected.listen((phrase) {
        if (!mounted) return;
        setState(() => _recognizedText = '');
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
    if (!_speechAvailable || _isListening || _isSpeaking) return;
    // Release the mic from wake-word detection first
    try { await WakeWordService.instance.pause(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _lastWordTime = null;
    _autoRelistening = true;
    setState(() {
      _isListening = true;
      _recognizedText = '';
    });
    // Speak greeting first; STT starts only after greeting finishes
    await _speakGreetingThenListen();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App going to background — stop STT and hand mic back to wake word service
      if (_isSpeaking) {
        _tts.stop();
      }
      if (_isListening) {
        _autoRelistening = false;
        _lastWordTime = null;
        _speech.cancel();
        setState(() => _isListening = false);
      }
      try { WakeWordService.instance.resume(); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _autoRelistening = false;
    WidgetsBinding.instance.removeObserver(this);
    _pulseCtrl.dispose();
    _speech.cancel();
    _tts.stop();
    _tts.dispose();
    try { WakeWordService.instance.resume(); } catch (_) {}
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
      _autoRelistening = false;
      _lastWordTime = null;
      await _speech.stop();
      setState(() => _isListening = false);
      // Give back the mic to wake-word detection
      try { await WakeWordService.instance.resume(); } catch (_) {}
    } else {
      // Release the mic from wake-word detection first
      try { await WakeWordService.instance.pause(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
      _lastWordTime = null;
      _autoRelistening = true;
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
      await _restartListenCycle();
    }
  }

  void _onSpeechError(String error) {
    if (!mounted) return;
    // Non-fatal errors (no match, timeout) may fire mid-speech — only stop if
    // we are not in the middle of a continuous re-listen cycle.
    if (_autoRelistening) {
      final sinceLastWord = _lastWordTime == null
          ? _silenceGap
          : DateTime.now().difference(_lastWordTime!);
      if (sinceLastWord < _silenceGap) {
        // User was still speaking — restarting happens via onStatus callback;
        // don't kill the UI state here.
        return;
      }
    }
    _autoRelistening = false;
    _lastWordTime = null;
    setState(() => _isListening = false);
    // Resume wake-word detection after any error
    try { WakeWordService.instance.resume(); } catch (_) {}
  }

  // ===== Emergency SOS =======================================================

  Future<void> _triggerEmergency() async {
    final caregiver = FamilyService.instance.caregiver;
    if (caregiver == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No caregiver set. Go to Family and mark someone as your caregiver.',
            style: TextStyle(fontSize: 15),
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );
      return;
    }

    final userName = widget.userName.isNotEmpty ? widget.userName : 'Your loved one';
    final sent = await CaregiverAlertService.instance.alertEmergency(
      userName: userName,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Emergency alert sent to ${caregiver.name}!'
              : 'Could not send alert. Check SMS permission.',
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor: sent ? const Color(0xFF059669) : AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }

  // ===== Navigation =========================================================

  void _onNavTap(int index) {
    if (index == 2) return; // centre slot — FAB handles it
    setState(() => _selectedIndex = index);
  }

  Widget _buildTabBody() {
    switch (_selectedIndex) {
      case 1:
        return const MedicinesScreen();
      case 3:
        return const FamilyScreen();
      case 4:
        return const SettingsScreen();
      default:
        return _HomeBody(
          userName: widget.userName,
          profilePhoto: _profilePhoto,
          isListening: _isListening,
          recognizedText: _recognizedText,
          onNavigate: _onNavTap,
          onEmergency: _triggerEmergency,
        );
    }
  }

  // ===== Build ==============================================================

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
      body: _buildTabBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _MicFAB(
        isListening: _isListening,
        pulseAnim: _pulseAnim,
        onTap: _onMicPressed,
      ),
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onNavTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MicFAB  — centre docked floating mic button
// ─────────────────────────────────────────────────────────────────────────────
class _MicFAB extends StatelessWidget {
  const _MicFAB({
    required this.isListening,
    required this.pulseAnim,
    required this.onTap,
  });

  final bool isListening;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isListening ? const Color(0xFF059669) : AppColors.primaryBlue;
    return ScaleTransition(
      scale: pulseAnim,
      child: Semantics(
        button: true,
        label: isListening ? 'Stop listening' : 'Tap to speak',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(110),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _BottomNavBar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: Colors.white,
      elevation: 12,
      shadowColor: AppColors.shadow.withAlpha(60),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            _NavItem(
                index: 0,
                icon: Icons.home_rounded,
                label: 'Home',
                selected: selectedIndex == 0,
                onTap: onTap),
            _NavItem(
                index: 1,
                icon: Icons.medication_rounded,
                label: 'Medicines',
                selected: selectedIndex == 1,
                onTap: onTap),
            // Centre slot — label below FAB notch
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'TAP TO\nSPEAK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            _NavItem(
                index: 3,
                icon: Icons.group_rounded,
                label: 'Family',
                selected: selectedIndex == 3,
                onTap: onTap),
            _NavItem(
                index: 4,
                icon: Icons.settings_rounded,
                label: 'Settings',
                selected: selectedIndex == 4,
                onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBlue : AppColors.iconMuted;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HomeBody  — Home tab content
// ─────────────────────────────────────────────────────────────────────────────
class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.userName,
    required this.profilePhoto,
    required this.isListening,
    required this.recognizedText,
    required this.onNavigate,
    required this.onEmergency,
  });

  final String userName;
  final File? profilePhoto;
  final bool isListening;
  final String recognizedText;
  final void Function(int) onNavigate;
  final VoidCallback onEmergency;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = AuthService.instance.currentUser?.photoUrl;
    ImageProvider? avatarImage;
    if (profilePhoto != null) {
      avatarImage = FileImage(profilePhoto!);
    } else if (photoUrl != null) {
      avatarImage = NetworkImage(photoUrl);
    }

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Top bar ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryBlueLight,
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? const Icon(Icons.person_rounded,
                              size: 28, color: Colors.white)
                          : null,
                    ),
                    _LanguageButton(
                      languageCode:
                          AccessibilitySettings.instance.languageCode,
                      onTap: () => _showLanguageSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                // ── Greeting ────────────────────────────────────────────
                Text(
                  _greeting,
                  style: AppTextStyles.heading.copyWith(fontSize: 36),
                ),
                const SizedBox(height: 6),
                Text(
                  isListening ? 'Listening…' : 'Ready to help you today.',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 17,
                    color: isListening
                        ? const Color(0xFF059669)
                        : AppColors.textGray,
                  ),
                ),
                // ── Recognized text bubble ───────────────────────────────
                if (recognizedText.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.shadow.withAlpha(25),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Text(recognizedText,
                        style: AppTextStyles.body
                            .copyWith(fontSize: 17, color: AppColors.textDark)),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl + 4),
                // ── Action cards ─────────────────────────────────────────
                _ActionCard(
                  icon: Icons.family_restroom_rounded,
                  label: 'Call Family',
                  subtitle: 'Connect with loved ones',
                  iconColor: AppColors.primaryBlue,
                  iconBg: const Color(0xFFEFF6FF),
                  onTap: () => onNavigate(3),
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionCard(
                  icon: Icons.medication_rounded,
                  label: 'Medicines',
                  subtitle: 'Check your daily schedule',
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFF0FDF4),
                  onTap: () => onNavigate(1),
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionCard(
                  icon: Icons.music_note_rounded,
                  label: 'Music',
                  subtitle: 'Play your favorite tunes',
                  iconColor: const Color(0xFF60A5FA),
                  iconBg: const Color(0xFFEFF6FF),
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionCard(
                  icon: Icons.sos_rounded,
                  label: 'Emergency',
                  subtitle: 'Alert your caregiver now',
                  iconColor: AppColors.errorRed,
                  iconBg: const Color(0xFFFEE2E2),
                  cardBg: const Color(0xFFFFF5F5),
                  labelColor: AppColors.errorRed,
                  chevronColor: AppColors.errorRed,
                  onTap: onEmergency,
                ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ActionCard
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    required this.iconBg,
    this.cardBg,
    this.labelColor,
    this.chevronColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final Color? cardBg;
  final Color? labelColor;
  final Color? chevronColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg ?? AppColors.cardWhite,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        enableFeedback: onTap != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md + 2),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: labelColor ?? AppColors.textDark,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textGray,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: chevronColor ?? AppColors.iconMuted, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Language helpers
// ─────────────────────────────────────────────────────────────────────────────
void _showLanguageSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _LanguageSheet(ctx),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LanguageButton  — top-right chip showing current language
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageButton extends StatelessWidget {
  const _LanguageButton({required this.languageCode, required this.onTap});

  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lang = appLanguageByCode(languageCode);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(38),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              lang.code.toUpperCase(),
              style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 16, color: AppColors.iconMuted),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LanguageSheet  — bottom sheet language picker
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet(this.parentCtx);
  final BuildContext parentCtx;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String _selected = AccessibilitySettings.instance.languageCode;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.inputBorder,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Language',
                style: AppTextStyles.heading.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('Choose your preferred language',
                style: AppTextStyles.body
                    .copyWith(fontSize: 14, color: AppColors.textGray)),
            const SizedBox(height: AppSpacing.lg),
            // Language grid
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: kAppLanguages.map((lang) {
                final isSelected = lang.code == _selected;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _selected = lang.code);
                    await AccessibilitySettings.instance
                        .setLanguage(lang.code);
                    if (!mounted) return;
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.inputBackground,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(lang.flag,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          lang.name,
                          style: AppTextStyles.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}