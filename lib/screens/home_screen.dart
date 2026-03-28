import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../core/auth/auth_service.dart';
import '../core/constants/app_spacing.dart';
import '../core/services/wake_word_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
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
    with SingleTickerProviderStateMixin {
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

  // ── Profile photo (local cache) ─────────────────────────────────────────
  File? _profilePhoto;

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
    if (!_speechAvailable || _isListening) return;
    setState(() {
      _isListening = true;
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
        return const _FamilyPlaceholder();
      case 4:
        return const SettingsScreen();
      default:
        return _HomeBody(
          userName: widget.userName,
          profilePhoto: _profilePhoto,
          isListening: _isListening,
          recognizedText: _recognizedText,
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
  });

  final String userName;
  final File? profilePhoto;
  final bool isListening;
  final String recognizedText;

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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow.withAlpha(38),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.search_rounded,
                          size: 22, color: AppColors.iconMuted),
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
                ),
                const SizedBox(height: AppSpacing.md),
                _ActionCard(
                  icon: Icons.medication_rounded,
                  label: 'Medicines',
                  subtitle: 'Check your daily schedule',
                  iconColor: const Color(0xFF16A34A),
                  iconBg: const Color(0xFFF0FDF4),
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
                  subtitle: 'Get immediate help',
                  iconColor: AppColors.errorRed,
                  iconBg: const Color(0xFFFEE2E2),
                  cardBg: const Color(0xFFFFF5F5),
                  labelColor: AppColors.errorRed,
                  chevronColor: AppColors.errorRed,
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
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final Color iconBg;
  final Color? cardBg;
  final Color? labelColor;
  final Color? chevronColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardBg ?? AppColors.cardWhite,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$label — coming soon!',
                style: const TextStyle(fontSize: 16)),
            duration: const Duration(seconds: 2),
            backgroundColor: iconColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ));
        },
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
//  Placeholder tabs
// ─────────────────────────────────────────────────────────────────────────────
class _MedicinesPlaceholder extends StatelessWidget {
  const _MedicinesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_rounded,
                size: 64, color: AppColors.primaryBlueLight),
            SizedBox(height: AppSpacing.md),
            Text('Medicines',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            SizedBox(height: 8),
            Text('Coming soon',
                style: TextStyle(fontSize: 16, color: AppColors.textGray)),
          ],
        ),
      ),
    );
  }
}

class _FamilyPlaceholder extends StatelessWidget {
  const _FamilyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_rounded,
                size: 64, color: AppColors.primaryBlueLight),
            SizedBox(height: AppSpacing.md),
            Text('Family',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            SizedBox(height: 8),
            Text('Coming soon',
                style: TextStyle(fontSize: 16, color: AppColors.textGray)),
          ],
        ),
      ),
    );
  }
}
