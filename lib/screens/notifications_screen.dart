import 'package:flutter/material.dart';

import '../core/constants/app_spacing.dart';
import '../core/settings/notification_settings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _ns = NotificationSettings.instance;

  @override
  void initState() {
    super.initState();
    _ns.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ns.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top bar ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.pop(context)),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Settings',
                    style: AppTextStyles.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),

            // ── Title block ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notifications',
                      style:
                          AppTextStyles.heading.copyWith(fontSize: 34)),
                  const SizedBox(height: 6),
                  Text(
                    'Manage how your voice companion keeps\nyou updated.',
                    style: AppTextStyles.body
                        .copyWith(fontSize: 15, color: AppColors.textGray),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Cards ────────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                physics: const BouncingScrollPhysics(),
                children: [
                  _NotifCard(
                    iconBg: const Color(0xFFDBEAFF),
                    icon: Icons.medical_services_rounded,
                    iconColor: AppColors.primaryBlue,
                    title: 'Medicine\nReminders',
                    subtitle:
                        'Daily alerts for\nyour prescriptions\nand vitamins.',
                    value: _ns.medicine,
                    onChanged: _ns.setMedicine,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _NotifCard(
                    iconBg: const Color(0xFFDCFCE7),
                    icon: Icons.phone_rounded,
                    iconColor: const Color(0xFF16A34A),
                    title: 'Family Calls',
                    subtitle:
                        'Alerts when your\nfamily members\ntry to reach you.',
                    value: _ns.familyCalls,
                    onChanged: _ns.setFamilyCalls,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _NotifCard(
                    iconBg: const Color(0xFFFEF3C7),
                    icon: Icons.directions_walk_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Daily Activity',
                    subtitle:
                        'Gentle nudges to\nstay active and\nreach your goals.',
                    value: _ns.dailyActivity,
                    onChanged: _ns.setDailyActivity,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _NotifCard(
                    iconBg: const Color(0xFFFEE2E2),
                    icon: Icons.emergency_rounded,
                    iconColor: AppColors.errorRed,
                    title: 'Emergency\nAlerts',
                    subtitle:
                        'Critical alerts\nregarding health\nand safety.',
                    value: _ns.emergency,
                    onChanged: _ns.setEmergency,
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // ── Advanced Settings button ────────────────────────────────
                  _AdvancedSettingsButton(),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _NotifCard
// ─────────────────────────────────────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon bubble
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, size: 32, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.25),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textGray,
                      height: 1.4),
                ),
              ],
            ),
          ),

          // Toggle
          Transform.scale(
            scale: 1.1,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primaryBlue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: AppColors.inputBorder,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AdvancedSettingsButton
// ─────────────────────────────────────────────────────────────────────────────
class _AdvancedSettingsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // TODO: navigate to system notification settings
        // openAppSettings() via app_settings package if needed
      },
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        alignment: Alignment.center,
        child: Text(
          'Advanced Settings',
          style: AppTextStyles.body.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _CircleBackButton
// ─────────────────────────────────────────────────────────────────────────────
class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textDark),
      ),
    );
  }
}
