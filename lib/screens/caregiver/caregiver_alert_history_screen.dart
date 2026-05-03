import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/alert_entry.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Tab 2 — Chronological timeline of all alerts sent by the elder's device.
class CaregiverAlertHistoryScreen extends StatefulWidget {
  const CaregiverAlertHistoryScreen({super.key, required this.elderUid});

  final String? elderUid;

  @override
  State<CaregiverAlertHistoryScreen> createState() =>
      _CaregiverAlertHistoryScreenState();
}

class _CaregiverAlertHistoryScreenState
    extends State<CaregiverAlertHistoryScreen> {
  StreamSubscription<List<AlertEntry>>? _sub;
  List<AlertEntry> _alerts = [];

  @override
  void initState() {
    super.initState();
    if (widget.elderUid != null) {
      _sub = FirestoreService.instance
          .streamAlertHistory(widget.elderUid!)
          .listen((alerts) {
        if (mounted) setState(() => _alerts = alerts);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elderUid == null) {
      return _emptyState('Link to an elder to view alerts.');
    }

    return SafeArea(
      child: _alerts.isEmpty
          ? _emptyState('No alerts yet — everything is on track!')
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Alert History',
                  style: AppTextStyles.heading.copyWith(fontSize: 28),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'All notifications sent from your loved one\'s device',
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                ),
                const SizedBox(height: AppSpacing.xl),
                ..._buildGroupedAlerts(),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  List<Widget> _buildGroupedAlerts() {
    final widgets = <Widget>[];
    String? lastDateHeader;

    for (final alert in _alerts) {
      final header = _dateHeader(alert.timestamp);
      if (header != lastDateHeader) {
        lastDateHeader = header;
        widgets.add(Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            header,
            style: AppTextStyles.subheading.copyWith(fontSize: 15),
          ),
        ));
      }
      widgets.add(_AlertTimelineEntry(alert: alert));
    }
    return widgets;
  }

  String _dateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final alertDay = DateTime(dt.year, dt.month, dt.day);

    if (alertDay == today) return 'Today';
    if (alertDay == today.subtract(const Duration(days: 1))) return 'Yesterday';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _emptyState(String message) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off_rounded,
                  size: 56, color: AppColors.textGray.withAlpha(100)),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Timeline entry
// ─────────────────────────────────────────────────────────────────────────────

class _AlertTimelineEntry extends StatelessWidget {
  const _AlertTimelineEntry({required this.alert});
  final AlertEntry alert;

  @override
  Widget build(BuildContext context) {
    final isEmergency = alert.type == AlertEntryType.emergency;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isEmergency
              ? AppColors.errorRed.withAlpha(60)
              : AppColors.divider,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Container(
            width: 40,
            height: 40,
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
              size: 20,
              color: isEmergency ? AppColors.errorRed : AppColors.primaryBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEmergency
                            ? 'Emergency SOS'
                            : 'Missed Medicine',
                        style: AppTextStyles.heading.copyWith(
                          fontSize: 15,
                          color: isEmergency
                              ? AppColors.errorRed
                              : AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(alert.timestamp),
                      style: AppTextStyles.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  alert.message,
                  style: AppTextStyles.body.copyWith(fontSize: 14),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (alert.medicineName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chipBlueLight,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                    ),
                    child: Text(
                      alert.medicineName!,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}
