import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_spacing.dart';
import '../core/services/wake_word_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import 'role_selection_screen.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  // Permission statuses
  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notifStatus = PermissionStatus.denied;
  PermissionStatus _smsStatus = PermissionStatus.denied;
  bool _contactsGranted = false;

  bool get _canProceed => _micStatus.isGranted;

  @override
  void initState() {
    super.initState();
    _checkAll();
  }

  Future<void> _checkAll() async {
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    final sms = await Permission.sms.status;
    final contacts = await FlutterContacts.requestPermission(readonly: true)
        .catchError((_) => false);
    if (mounted) {
      setState(() {
        _micStatus = mic;
        _notifStatus = notif;
        _smsStatus = sms;
        _contactsGranted = contacts;
      });
    }
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    setState(() => _micStatus = status);
    if (status.isPermanentlyDenied && mounted) _showSettingsHint('Microphone');
  }

  Future<void> _requestNotif() async {
    final status = await Permission.notification.request();
    setState(() => _notifStatus = status);
    if (status.isPermanentlyDenied && mounted) _showSettingsHint('Notifications');
  }

  Future<void> _requestContacts() async {
    final granted = await FlutterContacts.requestPermission(readonly: true)
        .catchError((_) => false);
    setState(() => _contactsGranted = granted);
    if (!granted && mounted) _showSettingsHint('Contacts');
  }

  Future<void> _requestSms() async {
    final status = await Permission.sms.request();
    setState(() => _smsStatus = status);
    if (status.isPermanentlyDenied && mounted) _showSettingsHint('SMS');
  }

  void _showSettingsHint(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '$name permission was denied. Please enable it in app Settings.'),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Open Settings',
          textColor: Colors.white,
          onPressed: openAppSettings,
        ),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }

  Future<void> _onContinue() async {
    if (!_canProceed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Microphone access is required to use EverWith\'s voice features.'),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_permissions', true);
    // Start the wake word service now that microphone permission is granted
    try {
      WakeWordService.instance.start();
    } catch (e) {
      debugPrint('[PermissionsScreen] Error starting wake word service: $e');
    }
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => const RoleSelectionScreen(),
        transitionsBuilder: (_, animation, __ , child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),

              // ── Icon ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.chipBlueLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: AppColors.primaryBlue, size: 40),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Title ─────────────────────────────────────────────────
              Text('App Permissions',
                  style: AppTextStyles.heading.copyWith(fontSize: 28),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'EverWith needs a few permissions to work properly for you.',
                style:
                    AppTextStyles.body.copyWith(fontSize: 16, color: AppColors.textGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ── Microphone (mandatory) ────────────────────────────────
              _PermissionCard(
                icon: Icons.mic_rounded,
                iconColor: AppColors.primaryBlue,
                iconBg: AppColors.chipBlueLight,
                title: 'Microphone',
                description:
                    'Required to listen to your voice commands and respond to you.',
                isMandatory: true,
                isGranted: _micStatus.isGranted,
                onAllow: _requestMic,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Notifications (recommended) ───────────────────────────
              _PermissionCard(
                icon: Icons.notifications_rounded,
                iconColor: const Color(0xFFF59E0B),
                iconBg: const Color(0xFFFFFBEB),
                title: 'Notifications',
                description:
                    'Sends you medicine reminders and important alerts.',
                isMandatory: false,
                isGranted: _notifStatus.isGranted,
                onAllow: _requestNotif,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Contacts (recommended) ────────────────────────────────
              _PermissionCard(
                icon: Icons.contacts_rounded,
                iconColor: const Color(0xFF16A34A),
                iconBg: const Color(0xFFF0FDF4),
                title: 'Contacts',
                description:
                    'Lets you add family members quickly from your phone contacts.',
                isMandatory: false,
                isGranted: _contactsGranted,
                onAllow: _requestContacts,
              ),
              const SizedBox(height: AppSpacing.md),

              // ── SMS (recommended — caregiver alerts) ──────────────────
              _PermissionCard(
                icon: Icons.sms_rounded,
                iconColor: const Color(0xFFE11D48),
                iconBg: const Color(0xFFFFF1F2),
                title: 'SMS',
                description:
                    'Sends automatic alerts to your caregiver when you miss medicine or press SOS.',
                isMandatory: false,
                isGranted: _smsStatus.isGranted,
                onAllow: _requestSms,
              ),

              const SizedBox(height: AppSpacing.xxl),

              // ── Continue button ───────────────────────────────────────
              _ContinueButton(
                enabled: _canProceed,
                onTap: _onContinue,
              ),

              if (!_canProceed) ...[
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: AppColors.errorRed),
                    const SizedBox(width: 6),
                    Text(
                      'Microphone access is required to continue',
                      style: AppTextStyles.body.copyWith(
                          fontSize: 13, color: AppColors.errorRed),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _PermissionCard
// ─────────────────────────────────────────────────────────────────────────────
class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.isMandatory,
    required this.isGranted,
    required this.onAllow,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;
  final bool isMandatory;
  final bool isGranted;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: isGranted
              ? const Color(0xFF16A34A)
              : isMandatory
                  ? AppColors.errorRed.withAlpha(80)
                  : AppColors.inputBorder,
          width: isGranted ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(width: 6),
                    if (isMandatory)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.errorRedLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Required',
                            style: AppTextStyles.body.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.errorRed)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(description,
                    style: AppTextStyles.body
                        .copyWith(fontSize: 13, color: AppColors.textGray)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Allow / Granted button
          if (isGranted)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_rounded,
                      size: 14, color: Color(0xFF16A34A)),
                  const SizedBox(width: 4),
                  Text('Granted',
                      style: AppTextStyles.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A))),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: onAllow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text('Allow',
                    style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ContinueButton
// ─────────────────────────────────────────────────────────────────────────────
class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryBlue : AppColors.inputBorder,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(
          'Continue',
          style: AppTextStyles.body.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: enabled ? Colors.white : AppColors.textGray),
        ),
      ),
    );
  }
}
