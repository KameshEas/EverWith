import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/alert_entry.dart';
import '../../core/models/medicine.dart';
import '../../core/models/user_profile.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Tab 0 — Dashboard overview for caregivers.
///
/// Shows elder status, medicine adherence, recent alerts, and quick actions.
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({
    super.key,
    required this.elderUid,
    required this.caregiverName,
    required this.onNavigateToTab,
  });

  final String? elderUid;
  final String caregiverName;
  final ValueChanged<int> onNavigateToTab;

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  UserProfile? _elderProfile;
  StreamSubscription<List<Medicine>>? _medSub;
  StreamSubscription<List<AlertEntry>>? _alertSub;

  List<Medicine> _medicines = [];
  List<AlertEntry> _alerts = [];

  @override
  void initState() {
    super.initState();
    if (widget.elderUid != null) {
      _loadElderProfile();
      _subscribeToData();
    }
  }

  @override
  void dispose() {
    _medSub?.cancel();
    _alertSub?.cancel();
    super.dispose();
  }

  Future<void> _loadElderProfile() async {
    final profile =
        await FirestoreService.instance.getUserProfile(widget.elderUid!);
    if (mounted) setState(() => _elderProfile = profile);
  }

  void _subscribeToData() {
    _medSub = FirestoreService.instance
        .streamElderMedicines(widget.elderUid!)
        .listen((meds) {
      if (mounted) setState(() => _medicines = meds);
    });
    _alertSub = FirestoreService.instance
        .streamAlertHistory(widget.elderUid!)
        .listen((alerts) {
      if (mounted) setState(() => _alerts = alerts);
    });
  }

  int get _takenCount =>
      _medicines.where((m) => m.status == MedicineStatus.taken).length;

  int get _scheduledCount =>
      _medicines.where((m) => m.frequency != MedicineFrequency.onlyAsNeeded).length;

  Future<void> _callElder() async {
    if (_elderProfile?.phone == null) return;
    final uri = Uri(scheme: 'tel', path: _elderProfile!.phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: widget.elderUid == null
          ? _NoPairingPlaceholder()
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Hello, ${widget.caregiverName}',
                  style: AppTextStyles.heading.copyWith(fontSize: 26),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Caregiver Dashboard',
                  style: AppTextStyles.subheading,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Elder Status Card ──────────────────────────────────
                _ElderStatusCard(profile: _elderProfile),
                const SizedBox(height: AppSpacing.lg),

                // ── Medicine Adherence ─────────────────────────────────
                _AdherenceCard(
                  taken: _takenCount,
                  total: _scheduledCount,
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Recent Alerts ──────────────────────────────────────
                _RecentAlertsCard(
                  alerts: _alerts.take(3).toList(),
                  onViewAll: () => widget.onNavigateToTab(2),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Quick Actions ──────────────────────────────────────
                _QuickActions(
                  onCallElder: _callElder,
                  onViewMedicines: () => widget.onNavigateToTab(1),
                  onViewAlerts: () => widget.onNavigateToTab(2),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Sub-widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _NoPairingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_off_rounded,
                size: 64, color: AppColors.textGray.withAlpha(120)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Not linked yet',
              style: AppTextStyles.heading.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ask your loved one to share their\npairing code from Settings.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _ElderStatusCard extends StatelessWidget {
  const _ElderStatusCard({required this.profile});
  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlueDark],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withAlpha(60),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            backgroundImage: profile?.photoUrl != null
                ? NetworkImage(profile!.photoUrl!)
                : null,
            child: profile?.photoUrl == null
                ? const Icon(Icons.person_rounded,
                    size: 32, color: Colors.white)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? 'Loading...',
                  style: AppTextStyles.heading
                      .copyWith(fontSize: 20, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  profile?.email ?? '',
                  style: AppTextStyles.body
                      .copyWith(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Linked',
                  style: AppTextStyles.caption
                      .copyWith(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({required this.taken, required this.total});
  final int taken;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? taken / total : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: AppColors.inputBackground,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0
                          ? AppColors.successGreen
                          : AppColors.primaryBlue,
                    ),
                  ),
                ),
                Text(
                  total > 0 ? '${(progress * 100).round()}%' : '—',
                  style: AppTextStyles.heading.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Medicines",
                  style: AppTextStyles.heading.copyWith(fontSize: 17),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  total > 0
                      ? '$taken of $total taken'
                      : 'No medicines scheduled',
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAlertsCard extends StatelessWidget {
  const _RecentAlertsCard({
    required this.alerts,
    required this.onViewAll,
  });

  final List<AlertEntry> alerts;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recent Alerts',
                style: AppTextStyles.heading.copyWith(fontSize: 17),
              ),
              const Spacer(),
              if (alerts.isNotEmpty)
                GestureDetector(
                  onTap: onViewAll,
                  child: Text('View All', style: AppTextStyles.linkText),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppColors.successGreen, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'No alerts — everything is on track!',
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                  ),
                ],
              ),
            )
          else
            ...alerts.map((a) => _AlertRow(alert: a)),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});
  final AlertEntry alert;

  @override
  Widget build(BuildContext context) {
    final isEmergency = alert.type == AlertEntryType.emergency;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEmergency
                  ? AppColors.errorRed.withAlpha(25)
                  : AppColors.primaryBlue.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEmergency
                  ? Icons.emergency_rounded
                  : Icons.medication_rounded,
              size: 18,
              color: isEmergency ? AppColors.errorRed : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.medicineName ?? (isEmergency ? 'Emergency SOS' : 'Alert'),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatTime(alert.timestamp),
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCallElder,
    required this.onViewMedicines,
    required this.onViewAlerts,
  });

  final VoidCallback onCallElder;
  final VoidCallback onViewMedicines;
  final VoidCallback onViewAlerts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: AppTextStyles.heading.copyWith(fontSize: 17),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.call_rounded,
                label: 'Call',
                color: AppColors.successGreen,
                onTap: onCallElder,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ActionCard(
                icon: Icons.medication_rounded,
                label: 'Medicines',
                color: AppColors.primaryBlue,
                onTap: onViewMedicines,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _ActionCard(
                icon: Icons.notifications_rounded,
                label: 'Alerts',
                color: AppColors.errorRed,
                onTap: onViewAlerts,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
