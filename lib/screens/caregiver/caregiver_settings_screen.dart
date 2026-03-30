import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/auth_result.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/services/firestore_service.dart';
import '../../core/settings/accessibility_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/confirm_bottom_sheet.dart';
import '../login_screen.dart';
import '../../main.dart' show AuthGate;

/// Tab 4 — Caregiver preferences and account management.
class CaregiverSettingsScreen extends StatefulWidget {
  const CaregiverSettingsScreen({super.key, required this.elderUid});

  final String? elderUid;

  @override
  State<CaregiverSettingsScreen> createState() =>
      _CaregiverSettingsScreenState();
}

class _CaregiverSettingsScreenState extends State<CaregiverSettingsScreen> {
  AuthUser? _user;
  File? _localPhoto;
  static const _photoFileName = 'caregiver_profile_photo.jpg';

  // Notification toggles
  bool _notifyMissedMedicine = true;
  bool _notifyEmergency = true;
  bool _notifyDailySummary = false;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser;
    _loadPhoto();
    _loadNotificationPrefs();
  }

  void _refreshUser() =>
      setState(() => _user = AuthService.instance.currentUser);

  Future<void> _loadPhoto() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_photoFileName');
    if (await file.exists() && mounted) {
      setState(() => _localPhoto = file);
    }
  }

  Future<void> _loadNotificationPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifyMissedMedicine =
          prefs.getBool('cg_notify_missed') ?? true;
      _notifyEmergency = prefs.getBool('cg_notify_emergency') ?? true;
      _notifyDailySummary = prefs.getBool('cg_notify_daily') ?? false;
    });
  }

  Future<void> _setNotifyMissedMedicine(bool v) async {
    setState(() => _notifyMissedMedicine = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cg_notify_missed', v);
  }

  Future<void> _setNotifyEmergency(bool v) async {
    setState(() => _notifyEmergency = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cg_notify_emergency', v);
  }

  Future<void> _setNotifyDailySummary(bool v) async {
    setState(() => _notifyDailySummary = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cg_notify_daily', v);
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/$_photoFileName');
    await File(picked.path).copy(dest.path);
    if (mounted) setState(() => _localPhoto = dest);
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: _user?.displayName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Edit Name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Your full name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    AppTextStyles.linkText.copyWith(color: AppColors.textGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Save', style: AppTextStyles.linkText),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    await AuthService.instance.updateDisplayName(name);
    _refreshUser();
  }

  Future<void> _unlinkElder() async {
    final confirmed = await showConfirmSheet(
      context,
      icon: Icons.link_off_rounded,
      title: 'Unlink from Elder?',
      message: 'You will no longer receive alerts or see their medicines.',
      confirmLabel: 'Unlink',
    );
    if (confirmed != true) return;

    if (_user != null && widget.elderUid != null) {
      await FirestoreService.instance.updateUserProfile(
        _user!.uid,
        {'linkedElderUid': null},
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unlinked successfully'),
          backgroundColor: AppColors.primaryBlue,
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showConfirmSheet(
      context,
      icon: Icons.logout_rounded,
      title: 'Sign Out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
    );
    if (confirmed != true) return;
    AuthGate.instance.pause();
    await AuthService.instance.signOut();
    AuthGate.instance.resume();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _user?.photoUrl;
    ImageProvider? bgImage;
    if (_localPhoto != null) {
      bgImage = FileImage(_localPhoto!);
    } else if (photoUrl != null) {
      bgImage = NetworkImage(photoUrl);
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Settings',
            style: AppTextStyles.heading.copyWith(fontSize: 28),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Manage your caregiver preferences',
            style: AppTextStyles.body.copyWith(fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Profile ──────────────────────────────────────────────
          _SectionLabel('Profile'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              GestureDetector(
                onTap: _pickPhoto,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: AppColors.primaryBlueLight,
                  backgroundImage: bgImage,
                  child: bgImage == null
                      ? const Icon(Icons.person_rounded,
                          size: 36, color: AppColors.cardWhite)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _user?.displayName ?? 'No Name',
                            style:
                                AppTextStyles.heading.copyWith(fontSize: 20),
                          ),
                        ),
                        IconButton(
                          onPressed: _editName,
                          icon: const Icon(Icons.edit_rounded,
                              size: 18, color: AppColors.primaryBlue),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _user?.email ?? '',
                      style: AppTextStyles.body.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Notifications ────────────────────────────────────────
          _SectionLabel('Notifications'),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile.adaptive(
            value: _notifyMissedMedicine,
            onChanged: _setNotifyMissedMedicine,
            title: const Text('Missed Medicine Alerts'),
            subtitle: const Text('Get notified when a medicine is missed'),
          ),
          SwitchListTile.adaptive(
            value: _notifyEmergency,
            onChanged: _setNotifyEmergency,
            title: const Text('Emergency Alerts'),
            subtitle: const Text('Get notified on SOS events'),
          ),
          SwitchListTile.adaptive(
            value: _notifyDailySummary,
            onChanged: _setNotifyDailySummary,
            title: const Text('Daily Summary'),
            subtitle: const Text('Receive a daily medicine adherence report'),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Accessibility ────────────────────────────────────────
          _SectionLabel('Accessibility'),
          const SizedBox(height: AppSpacing.md),
          _AccessibilityToggles(),
          const SizedBox(height: AppSpacing.xl),

          // ── Account ──────────────────────────────────────────────
          _SectionLabel('Account'),
          const SizedBox(height: AppSpacing.md),
          if (widget.elderUid != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_off_rounded,
                  color: AppColors.textGray),
              title: Text('Unlink from Elder',
                  style: AppTextStyles.body.copyWith(fontSize: 16)),
              onTap: _unlinkElder,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.logout_rounded, color: AppColors.errorRed),
            title: Text('Sign Out',
                style: AppTextStyles.buttonLabel
                    .copyWith(color: AppColors.errorRed)),
            onTap: _signOut,
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────────────────

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
      ],
    );
  }
}
