import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:everwith/core/auth/auth_result.dart';
import 'package:everwith/core/auth/auth_service.dart';
import 'package:everwith/core/constants/app_spacing.dart';
import 'package:everwith/core/settings/accessibility_settings.dart';
import 'package:everwith/core/theme/app_colors.dart';
import 'package:everwith/core/theme/app_text_styles.dart';
import '../main.dart' show AuthGate;
import '../widgets/confirm_bottom_sheet.dart';
import 'help_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AuthUser? _user;

  @override
  void initState() {
    super.initState();
    _user = AuthService.instance.currentUser;
  }

  void _refreshUser() =>
      setState(() => _user = AuthService.instance.currentUser);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          children: [
            // ── Header ────────────────────────────────────────────────
            const SizedBox(height: AppSpacing.sm),
            Text('Settings',
                style: AppTextStyles.heading.copyWith(fontSize: 32)),
            const SizedBox(height: 4),
            Text('Manage your preferences',
                style: AppTextStyles.body.copyWith(fontSize: 15)),
            const SizedBox(height: AppSpacing.xl),
          _EditableProfileHeader(
            user: _user,
            onProfileUpdated: _refreshUser,
          ),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Accessibility'),
          const SizedBox(height: AppSpacing.md),
          _AccessibilityToggles(),
          const SizedBox(height: AppSpacing.xl),
          _SectionLabel('Account'),
          const SizedBox(height: AppSpacing.md),
          _NotificationsTile(),
          const SizedBox(height: AppSpacing.sm),
          if (AuthService.instance.isEmailUser)
            _ChangePasswordTile(email: _user?.email ?? ''),
          _EmergencyContactTile(),
          const SizedBox(height: AppSpacing.md),
          _HelpSupportTile(),
          const SizedBox(height: AppSpacing.md),
          _SignOutTile(),
          const SizedBox(height: AppSpacing.xl),
          const _AppVersionFooter(),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
      ),
    );
  }
}

// ===========================================================================
// Editable Profile Header
// ===========================================================================

class _EditableProfileHeader extends StatefulWidget {
  const _EditableProfileHeader({
    required this.user,
    required this.onProfileUpdated,
  });

  final AuthUser? user;
  final VoidCallback onProfileUpdated;

  @override
  State<_EditableProfileHeader> createState() =>
      _EditableProfileHeaderState();
}

class _EditableProfileHeaderState extends State<_EditableProfileHeader> {
  File? _localPhoto;
  bool _uploadingPhoto = false;
  static const _photoFileName = 'profile_photo.jpg';

  @override
  void initState() {
    super.initState();
    _loadSavedPhoto();
  }

  Future<void> _loadSavedPhoto() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_photoFileName');
    if (await file.exists() && mounted) {
      setState(() => _localPhoto = file);
    }
  }

  // ── Photo options ─────────────────────────────────────────────────────────

  void _showPhotoOptions() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primaryBlue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primaryBlue),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 512,
    );
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/$_photoFileName');
      await File(picked.path).copy(dest.path);
      if (mounted) setState(() => _localPhoto = dest);
      widget.onProfileUpdated();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update photo. Please try again.'),
            backgroundColor: AppColors.errorRed,
          ),
        );
        setState(() => _localPhoto = null);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // ── Name edit ─────────────────────────────────────────────────────────────

  Future<void> _editName() async {
    final ctrl =
        TextEditingController(text: widget.user?.displayName ?? '');
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
                style: AppTextStyles.linkText
                    .copyWith(color: AppColors.textGray)),
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
    widget.onProfileUpdated();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.user?.photoUrl;
    ImageProvider? bgImage;
    if (_localPhoto != null) {
      bgImage = FileImage(_localPhoto!);
    } else if (photoUrl != null) {
      bgImage = NetworkImage(photoUrl);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: _showPhotoOptions,
              child: CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primaryBlueLight,
                backgroundImage: bgImage,
                child: bgImage == null
                    ? const Icon(Icons.person_rounded,
                        size: 40, color: AppColors.cardWhite)
                    : null,
              ),
            ),
            if (_uploadingPhoto)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
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
                      widget.user?.displayName ?? 'No Name',
                      style: AppTextStyles.heading.copyWith(fontSize: 22),
                    ),
                  ),
                  IconButton(
                    onPressed: _editName,
                    icon: const Icon(Icons.edit_rounded,
                        size: 20, color: AppColors.primaryBlue),
                    tooltip: 'Edit Name',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.user?.email ?? '',
                style: AppTextStyles.body.copyWith(fontSize: 15),
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

class _NotificationsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFFDBEAFF),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.notifications_rounded,
            size: 22, color: AppColors.primaryBlue),
      ),
      title: Text('Notifications',
          style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark)),
      subtitle: Text('Medicine, family, emergency alerts',
          style: AppTextStyles.body
              .copyWith(fontSize: 13, color: AppColors.textGray)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.iconMuted),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
    );
  }
}

class _HelpSupportTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Color(0xFFEFF6FF),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.help_outline_rounded,
            size: 22, color: AppColors.primaryBlue),
      ),
      title: Text('Help & Support',
          style: AppTextStyles.body.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark)),
      subtitle: Text('FAQs, contact, and guide',
          style: AppTextStyles.body
              .copyWith(fontSize: 13, color: AppColors.textGray)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.iconMuted),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HelpScreen()),
      ),
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
        final confirmed = await showConfirmSheet(
          context,
          icon: Icons.logout_rounded,
          title: 'Sign Out?',
          message: 'Are you sure you want to sign out?',
          confirmLabel: 'Sign Out',
        );
        if (confirmed != true) return;
        // Pause the auth gate so the listener doesn't also navigate
        AuthGate.instance.pause();
        await AuthService.instance.signOut();
        AuthGate.instance.resume();
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

// ===========================================================================
// Change Password
// ===========================================================================

class _ChangePasswordTile extends StatelessWidget {
  const _ChangePasswordTile({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          const Icon(Icons.lock_reset_rounded, color: AppColors.primaryBlue),
      title: Text('Change Password',
          style: AppTextStyles.body.copyWith(fontSize: 16)),
      subtitle: const Text('A reset link will be sent to your email'),
      onTap: () async {
        if (email.isEmpty) return;
        final result =
            await AuthService.instance.sendPasswordResetEmail(email);
        if (!context.mounted) return;
        final success = result is! Object || result.runtimeType.toString().startsWith('AuthSuccess');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result is AuthFailure
                  ? result.message
                  : 'Reset link sent to $email',
            ),
            backgroundColor: result is AuthFailure
                ? AppColors.errorRed
                : AppColors.primaryBlue,
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Emergency Contact
// ===========================================================================

class _EmergencyContactTile extends StatefulWidget {
  @override
  State<_EmergencyContactTile> createState() => _EmergencyContactTileState();
}

class _EmergencyContactTileState extends State<_EmergencyContactTile> {
  static const _keyName = 'emergency_contact_name';
  static const _keyPhone = 'emergency_contact_phone';

  String _name = '';
  String _phone = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() {
        _name = prefs.getString(_keyName) ?? '';
        _phone = prefs.getString(_keyPhone) ?? '';
      });
    });
  }

  Future<void> _edit() async {
    final nameCtrl = TextEditingController(text: _name);
    final phoneCtrl = TextEditingController(text: _phone);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: const Text('Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Contact Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyPhone, phone);
    if (mounted) setState(() { _name = name; _phone = phone; });
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.emergency_rounded, color: AppColors.errorRed),
      title: Text('Emergency Contact',
          style: AppTextStyles.body.copyWith(fontSize: 16)),
      subtitle: Text(
        _name.isEmpty ? 'Not set — tap to add' : '$_name · $_phone',
        style: AppTextStyles.body.copyWith(
          fontSize: 14,
          color: _name.isEmpty ? AppColors.textGray : AppColors.textDark,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppColors.iconMuted),
      onTap: _edit,
    );
  }
}

// ===========================================================================
// App Version Footer
// ===========================================================================

class _AppVersionFooter extends StatefulWidget {
  const _AppVersionFooter();

  @override
  State<_AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<_AppVersionFooter> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() =>
            _version = '${info.version} (${info.buildNumber})');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _version.isEmpty ? 'EverWith' : 'EverWith v$_version',
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          color: AppColors.textGray,
        ),
      ),
    );
  }
}
