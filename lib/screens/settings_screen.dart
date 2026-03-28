import 'package:flutter/material.dart';
import 'package:everwith/core/auth/auth_service.dart';
import 'package:everwith/core/settings/accessibility_settings.dart';
import 'package:everwith/core/auth/auth_result.dart';
import 'package:everwith/core/constants/app_spacing.dart';
import 'package:everwith/core/theme/app_colors.dart';
import 'package:everwith/core/theme/app_text_styles.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textDark),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          const SizedBox(height: AppSpacing.xl),
          _ProfileHeader(user: user),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Accessibility'),
          const SizedBox(height: AppSpacing.md),
          _AccessibilityToggles(),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Account'),
          const SizedBox(height: AppSpacing.md),
          _SignOutTile(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});
  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryBlueLight,
          backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
          child: user?.photoUrl == null
              ? Icon(Icons.person_rounded, size: 38, color: AppColors.cardWhite)
              : null,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? 'No Name',
                style: AppTextStyles.heading.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: AppTextStyles.body.copyWith(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(label, style: AppTextStyles.inputLabel.copyWith(fontSize: 17));
  }
}

class _AccessibilityToggles extends StatefulWidget {
  @override
  State<_AccessibilityToggles> createState() => _AccessibilityTogglesState();
}

class _AccessibilityTogglesState extends State<_AccessibilityToggles> {
  final _settings = AccessibilitySettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: _settings.largeFont,
          onChanged: _settings.setLargeFont,
          title: const Text('Large Font Size'),
        ),
        SwitchListTile.adaptive(
          value: _settings.highContrast,
          onChanged: _settings.setHighContrast,
          title: const Text('High Contrast'),
        ),
        SwitchListTile.adaptive(
          value: _settings.tts,
          onChanged: _settings.setTts,
          title: const Text('Text-to-Speech'),
        ),
      ],
    );
  }
}

class _SignOutTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.logout_rounded, color: AppColors.errorRed),
      title: Text('Sign Out', style: AppTextStyles.buttonLabel.copyWith(color: AppColors.errorRed)),
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            title: const Text('Sign Out?'),
            content: const Text(
              'Are you sure you want to sign out?',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Cancel',
                    style: AppTextStyles.linkText
                        .copyWith(color: AppColors.textGray)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text('Sign Out',
                    style:
                        AppTextStyles.linkText.copyWith(color: AppColors.errorRed)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await AuthService.instance.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      },
    );
  }
}
