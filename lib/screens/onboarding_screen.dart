import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_assets.dart';
import '../core/constants/app_spacing.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../widgets/app_header_icon_button.dart';
import '../widgets/app_logo.dart';
import '../widgets/gradient_primary_button.dart';
import '../widgets/pill_chip.dart';
import 'login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Supported languages
// ─────────────────────────────────────────────────────────────────────────────
class _Language {
  const _Language({required this.name, required this.flag, required this.code});
  final String name;
  final String flag;
  final String code;
}

const List<_Language> _kLanguages = [
  _Language(name: 'English', flag: '🇺🇸', code: 'en'),
  _Language(name: 'Spanish', flag: '🇪🇸', code: 'es'),
  _Language(name: 'French', flag: '🇫🇷', code: 'fr'),
  _Language(name: 'Hindi', flag: '🇮🇳', code: 'hi'),
  _Language(name: 'Tamil', flag: '🇮🇳', code: 'ta'),
  _Language(name: 'Chinese', flag: '🇨🇳', code: 'zh'),
  _Language(name: 'Arabic', flag: '🇸🇦', code: 'ar'),
  _Language(name: 'Portuguese', flag: '🇧🇷', code: 'pt'),
];

// ─────────────────────────────────────────────────────────────────────────────
//  Font-size presets
// ─────────────────────────────────────────────────────────────────────────────
enum _FontSizePreset { normal, large, extraLarge }

extension _FontSizePresetX on _FontSizePreset {
  double get scale => switch (this) {
        _FontSizePreset.normal => 1.0,
        _FontSizePreset.large => 1.2,
        _FontSizePreset.extraLarge => 1.4,
      };

  String get label => switch (this) {
        _FontSizePreset.normal => 'Normal',
        _FontSizePreset.large => 'Large',
        _FontSizePreset.extraLarge => 'Extra Large',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
//  Onboarding Screen
//  Entry point of the app. Introduces EverWith to new users.
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  // ── User preferences (persisted per session) ─────────────────────────────
  _Language _selectedLanguage = _kLanguages.first;
  _FontSizePreset _fontSizePreset = _FontSizePreset.normal;
  bool _highContrast = false;
  bool _textToSpeech = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Accessibility sheet ──────────────────────────────────────────────────
  void _showAccessibilitySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccessibilitySheet(
        fontSizePreset: _fontSizePreset,
        highContrast: _highContrast,
        textToSpeech: _textToSpeech,
        onFontSizeChanged: (p) => setState(() => _fontSizePreset = p),
        onHighContrastChanged: (v) => setState(() => _highContrast = v),
        onTextToSpeechChanged: (v) => setState(() => _textToSpeech = v),
      ),
    );
  }

  // ── Language picker sheet ─────────────────────────────────────────────────
  void _showLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LanguageSheet(
        selected: _selectedLanguage,
        onSelected: (lang) {
          setState(() => _selectedLanguage = lang);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // ── Mic listening sheet ───────────────────────────────────────────────────
  void _showListeningSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListeningSheet(pulseAnim: _pulseAnim),
    );
  }

  // ── Navigate to Home ─────────────────────────────────────────────────────
  void _onGetStarted() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
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

    return MediaQuery(
      // Apply user's chosen font size scale to the whole screen
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(_fontSizePreset.scale),
      ),
      child: Scaffold(
        backgroundColor: _highContrast ? Colors.white : AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  _OnboardingHeader(
                    selectedLanguage: _selectedLanguage,
                    onAccessibilityTap: _showAccessibilitySheet,
                    onLanguageTap: _showLanguageSheet,
                  ),
                  const SizedBox(height: 28),
                  _HeroCard(pulseAnim: _pulseAnim),
                  const SizedBox(height: AppSpacing.xl),
                  const _OnboardingTextContent(),
                  const SizedBox(height: 36),
                  GradientPrimaryButton(
                    label: 'Get Started',
                    onTap: _onGetStarted,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const _OnboardingFooter(),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _OnboardingHeader
//  Logo centred with accessibility + language buttons on the right.
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.selectedLanguage,
    required this.onAccessibilityTap,
    required this.onLanguageTap,
  });

  final _Language selectedLanguage;
  final VoidCallback onAccessibilityTap;
  final VoidCallback onLanguageTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mirrors width of two icon buttons (44 + 8 + 44) so logo stays centred.
        const SizedBox(width: 96),
        const Expanded(
          child: Center(child: AppLogo()),
        ),
        AppHeaderIconButton(
          icon: Icons.accessibility_new_rounded,
          semanticLabel: 'Accessibility options',
          onTap: onAccessibilityTap,
        ),
        const SizedBox(width: AppSpacing.sm),
        // Language button shows the active language flag as an overlay badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            AppHeaderIconButton(
              icon: Icons.translate_rounded,
              semanticLabel: 'Switch language — ${selectedLanguage.name}',
              onTap: onLanguageTap,
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.cardWhite,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  selectedLanguage.flag,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HeroCard
//  Rounded image card with a bottom scrim and a floating pulsing mic button.
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.pulseAnim});

  final Animation<double> pulseAnim;

  static const double _cardHeight = 340.0;
  static const double _scrimHeight = 110.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _buildImageContainer(),
        _buildBottomScrim(),
        _buildFloatingMicButton(),
      ],
    );
  }

  Widget _buildImageContainer() {
    return Container(
      height: _cardHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(46),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Image.asset(
          AppAssets.elderlyPerson,
          fit: BoxFit.cover,
          width: double.infinity,
          height: _cardHeight,
          semanticLabel: 'Happy elderly person using a tablet',
          errorBuilder: (_, __, ___) => const _WarmGradientPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildBottomScrim() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppSpacing.radiusLg),
          bottomRight: Radius.circular(AppSpacing.radiusLg),
        ),
        child: Container(
          height: _scrimHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withAlpha(64)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMicButton() {
    return Positioned(
      bottom: -20,
      right: 20,
      child: ScaleTransition(
        scale: pulseAnim,
        child: const _MicButton(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _OnboardingTextContent
//  Heading, pill-chip subheading, and description paragraph.
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingTextContent extends StatelessWidget {
  const _OnboardingTextContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Extra top padding clears the floating mic button overhang.
      padding: const EdgeInsets.only(top: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Welcome to EverWith',
            textAlign: TextAlign.center,
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: 12),
          const PillChip(label: 'Your friendly voice companion'),
          const SizedBox(height: AppSpacing.md),
          Text(
            'I can help you call family, remember medicines,\nand get help anytime.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _OnboardingFooter
//  Subtle accessibility badge at the bottom of the screen.
// ─────────────────────────────────────────────────────────────────────────────
class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter();

  @override
  Widget build(BuildContext context) {
    final dimGray = AppColors.textGray.withAlpha(153);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.remove_red_eye_outlined, size: 14, color: dimGray),
        const SizedBox(width: 5),
        Text(
          'Designed for easy viewing & use',
          style: AppTextStyles.caption.copyWith(color: dimGray),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MicButton  (private — onboarding-specific floating action)
// ─────────────────────────────────────────────────────────────────────────────
class _MicButton extends StatelessWidget {
  const _MicButton();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryBlueLight, AppColors.primaryBlue],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withAlpha(102),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withAlpha(77),
              blurRadius: 4,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _WarmGradientPlaceholder  (shown when elderlyperson.png is absent)
// ─────────────────────────────────────────────────────────────────────────────
class _WarmGradientPlaceholder extends StatelessWidget {
  const _WarmGradientPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.placeholderStart,
            AppColors.placeholderMid,
            AppColors.placeholderEnd,
          ],
        ),
      ),
      child: Stack(
        children: [
          _buildDepthCircle(top: -40, right: -40, size: 180,
              color: AppColors.primaryBlueLight.withAlpha(40)),
          _buildDepthCircle(bottom: -20, left: -30, size: 140,
              color: AppColors.primaryBlue.withAlpha(25)),
          Center(child: _PlaceholderCentreContent()),
        ],
      ),
    );
  }

  Widget _buildDepthCircle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _PlaceholderCentreContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(230),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withAlpha(51),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.elderly, size: 64, color: AppColors.primaryBlue),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(200),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: const Text(
            'Your Companion',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AccessibilitySheet
//  Bottom sheet: font-size picker, high-contrast and TTS toggles.
// ─────────────────────────────────────────────────────────────────────────────
class _AccessibilitySheet extends StatelessWidget {
  const _AccessibilitySheet({
    required this.fontSizePreset,
    required this.highContrast,
    required this.textToSpeech,
    required this.onFontSizeChanged,
    required this.onHighContrastChanged,
    required this.onTextToSpeechChanged,
  });

  final _FontSizePreset fontSizePreset;
  final bool highContrast;
  final bool textToSpeech;
  final ValueChanged<_FontSizePreset> onFontSizeChanged;
  final ValueChanged<bool> onHighContrastChanged;
  final ValueChanged<bool> onTextToSpeechChanged;

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: 'Accessibility',
      icon: Icons.accessibility_new_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetSectionLabel(label: 'Text Size'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: _FontSizePreset.values.map((preset) {
              final isSelected = preset == fontSizePreset;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _SelectableTile(
                    label: preset.label,
                    isSelected: isSelected,
                    onTap: () => onFontSizeChanged(preset),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          const _SheetSectionLabel(label: 'Display'),
          const SizedBox(height: AppSpacing.sm),
          _ToggleRow(
            icon: Icons.contrast_rounded,
            label: 'High Contrast Mode',
            subtitle: 'Bolder colours for easier reading',
            value: highContrast,
            onChanged: onHighContrastChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ToggleRow(
            icon: Icons.record_voice_over_rounded,
            label: 'Read Aloud',
            subtitle: 'Speaks on-screen text out loud',
            value: textToSpeech,
            onChanged: onTextToSpeechChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LanguageSheet
//  Bottom sheet: scrollable language list.
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({
    required this.selected,
    required this.onSelected,
  });

  final _Language selected;
  final ValueChanged<_Language> onSelected;

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: 'Choose Language',
      icon: Icons.translate_rounded,
      child: Column(
        children: _kLanguages.map((lang) {
          final isSelected = lang.code == selected.code;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: lang.name,
              child: GestureDetector(
                onTap: () => onSelected(lang),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md - 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.chipBlueLight
                        : AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : AppColors.shadow.withAlpha(50),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          lang.name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.primaryBlue
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ListeningSheet
//  Bottom sheet: animated pulsing mic while the assistant listens.
// ─────────────────────────────────────────────────────────────────────────────
class _ListeningSheet extends StatelessWidget {
  const _ListeningSheet({required this.pulseAnim});

  final Animation<double> pulseAnim;

  @override
  Widget build(BuildContext context) {
    return _BottomSheetShell(
      title: 'Listening\u2026',
      icon: Icons.mic_rounded,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          ScaleTransition(
            scale: pulseAnim,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlueLight, AppColors.primaryBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryBlue.withAlpha(102),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 46),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Say something like:',
            style: AppTextStyles.caption.copyWith(
              fontSize: 15,
              color: AppColors.textGray,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _VoiceHintChip(label: '\u201cCall my daughter\u201d'),
          const SizedBox(height: AppSpacing.sm),
          const _VoiceHintChip(label: '\u201cRemind me to take medicine\u201d'),
          const SizedBox(height: AppSpacing.sm),
          const _VoiceHintChip(label: '\u201cI need help\u201d'),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.stop_rounded, color: AppColors.primaryBlue),
              label: const Text(
                'Stop Listening',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared bottom-sheet composables
// ─────────────────────────────────────────────────────────────────────────────

/// Drag handle + icon title bar wrapping each bottom sheet body.
class _BottomSheetShell extends StatelessWidget {
  const _BottomSheetShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.shadow.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.chipBlueLight,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: AppColors.primaryBlue, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(title, style: AppTextStyles.heading.copyWith(fontSize: 22)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// Section label inside bottom sheets.
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: AppColors.textDark,
      ),
    );
  }
}

/// Segmented selectable tile for the font-size picker row.
class _SelectableTile extends StatelessWidget {
  const _SelectableTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : AppColors.shadow.withAlpha(60),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isSelected ? Colors.white : AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled on/off toggle row used in the accessibility sheet.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textGray,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primaryBlue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Small pill hint chip used inside the listening sheet.
class _VoiceHintChip extends StatelessWidget {
  const _VoiceHintChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(color: AppColors.shadow.withAlpha(60)),
      ),
      child: Text(
        label,
        style: AppTextStyles.body.copyWith(
          fontSize: 15,
          fontStyle: FontStyle.italic,
          color: AppColors.textGray,
        ),
      ),
    );
  }
}
