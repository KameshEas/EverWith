import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'caregiver_alert_service.dart';
import 'family_service.dart';
import 'medicine_service.dart';
import '../models/medicine.dart';
import '../settings/notification_settings.dart';

/// Periodically checks for missed medicines and sends caregiver SMS alerts.
///
/// A medicine is considered "missed" when:
///  1. Its scheduled time + [gracePeriod] has passed.
///  2. It hasn't been marked as taken today.
///  3. It's not an "only as needed" medicine.
///
/// Runs a timer every [_checkInterval] while the app is alive.
class MedicineMonitorService {
  MedicineMonitorService._();
  static final instance = MedicineMonitorService._();

  static const _gracePeriod = Duration(minutes: 30);
  static const _checkInterval = Duration(minutes: 15);

  Timer? _timer;

  /// Start periodic monitoring. Safe to call multiple times.
  void start() {
    if (_timer != null && _timer!.isActive) return;

    // Run an immediate check, then schedule periodic checks.
    _check();
    _timer = Timer.periodic(_checkInterval, (_) => _check());
    debugPrint('[MedicineMonitor] Started — checking every ${_checkInterval.inMinutes} min');
  }

  /// Stop monitoring.
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[MedicineMonitor] Stopped');
  }

  Future<void> _check() async {
    // Don't alert if the user turned off medicine notifications.
    if (!NotificationSettings.instance.medicine) return;

    // Need a caregiver to alert.
    if (FamilyService.instance.caregiver == null) return;

    final userName = FirebaseAuth.instance.currentUser?.displayName ?? 'Your loved one';
    final now = DateTime.now();
    final today = _todayKey(now);

    // Check for missed medicines
    for (final medicine in MedicineService.instance.medicines) {
      // Skip as-needed medicines.
      if (medicine.frequency == MedicineFrequency.onlyAsNeeded) continue;

      // Skip if already taken today.
      if (medicine.takenDates.contains(today)) continue;

      // Check if grace period has elapsed.
      final scheduled = DateTime(
        now.year, now.month, now.day,
        medicine.timeHour, medicine.timeMinute,
      );
      final deadline = scheduled.add(_gracePeriod);

      if (now.isAfter(deadline)) {
        await CaregiverAlertService.instance.alertMissedMedicine(
          medicineName: medicine.name,
          scheduledTime: medicine.timeLabel,
          userName: userName,
        );
      }
    }

    // Send daily summary at 8 PM if enabled
    if (now.hour >= 20) {
      final prefs = await SharedPreferences.getInstance();
      final lastSummaryDate = prefs.getString('daily_summary_date');
      if (lastSummaryDate != today) {
        // Count medicines: total non-asNeeded, how many taken
        final medicines = MedicineService.instance.medicines;
        final regularMedicines = medicines
            .where((m) => m.frequency != MedicineFrequency.onlyAsNeeded)
            .toList();
        final totalRegular = regularMedicines.length;
        final takenRegular = regularMedicines
            .where((m) => m.takenDates.contains(today))
            .length;

        final sent = await CaregiverAlertService.instance.sendDailySummary(
          elderName: userName,
          taken: takenRegular,
          total: totalRegular,
        );

        if (sent) {
          await prefs.setString('daily_summary_date', today);
        }
      }
    }
  }

  static String _todayKey(DateTime now) {
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
