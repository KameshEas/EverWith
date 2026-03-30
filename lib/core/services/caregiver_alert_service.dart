import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alarm_notification_service.dart';
import 'family_service.dart';
import 'sms_service.dart';

/// The type of alert being sent to the caregiver.
enum AlertType { missedMedicine, emergency }

/// Sends SMS alerts to the designated caregiver automatically.
///
/// Features:
/// - Rate-limited: max 1 alert per medicine per day, max 6 total per day.
/// - Stores send log in SharedPreferences to survive restarts.
class CaregiverAlertService {
  CaregiverAlertService._();
  static final instance = CaregiverAlertService._();

  static const _logKey = 'caregiver_alert_log';
  static const _maxDailyAlerts = 6;

  /// Send an alert SMS to the caregiver for a missed medicine.
  ///
  /// [medicineName] — name of the missed medicine.
  /// [scheduledTime] — e.g. "8:30 AM".
  /// [userName] — the parent/elderly user's display name.
  Future<bool> alertMissedMedicine({
    required String medicineName,
    required String scheduledTime,
    required String userName,
  }) async {
    final caregiver = FamilyService.instance.caregiver;
    if (caregiver == null) return false;

    // Rate-limit: one alert per medicine per day
    final alertKey = 'medicine_$medicineName';
    if (await _alreadySentToday(alertKey)) return false;
    if (await _dailyLimitReached()) return false;

    final message = '[EverWith Alert] $userName missed their medicine '
        '"$medicineName" scheduled at $scheduledTime. '
        'Please check on them.';

    final sent = await SmsService.instance.sendSms(
      phoneNumber: caregiver.phone,
      message: message,
    );

    if (sent) {
      await _recordAlert(alertKey);
      // Fire a loud alarm notification on the parent's device too
      await AlarmNotificationService.instance.showMissedMedicineAlarm(
        medicineName: medicineName,
        scheduledTime: scheduledTime,
        caregiverName: caregiver.name,
      );
    }
    return sent;
  }

  /// Send an emergency SOS alert to the caregiver.
  ///
  /// Emergency alerts bypass the per-medicine rate limit but still respect
  /// the daily cap (to prevent button-mashing abuse).
  Future<bool> alertEmergency({required String userName}) async {
    final caregiver = FamilyService.instance.caregiver;
    if (caregiver == null) return false;

    if (await _dailyLimitReached()) return false;

    final message = '[EverWith EMERGENCY] $userName pressed the SOS button '
        'and may need immediate help! Please call or visit them right away.';

    final sent = await SmsService.instance.sendSms(
      phoneNumber: caregiver.phone,
      message: message,
    );

    if (sent) {
      await _recordAlert('emergency_${DateTime.now().millisecondsSinceEpoch}');
      // Fire a loud alarm notification on the parent's device
      await AlarmNotificationService.instance.showEmergencyAlarm(
        caregiverName: caregiver.name,
      );
    }
    return sent;
  }

  // ── Rate-limiting helpers ────────────────────────────────────────────────

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<Map<String, List<String>>> _loadLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_logKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) =>
          MapEntry(k, (v as List<dynamic>).cast<String>()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLog(Map<String, List<String>> log) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logKey, jsonEncode(log));
  }

  Future<bool> _alreadySentToday(String alertKey) async {
    final log = await _loadLog();
    final todayEntries = log[_todayKey] ?? [];
    return todayEntries.contains(alertKey);
  }

  Future<bool> _dailyLimitReached() async {
    final log = await _loadLog();
    final todayEntries = log[_todayKey] ?? [];
    return todayEntries.length >= _maxDailyAlerts;
  }

  Future<void> _recordAlert(String alertKey) async {
    final log = await _loadLog();
    final today = _todayKey;

    // Clean up old entries (keep only today)
    log.removeWhere((key, _) => key != today);

    final todayEntries = log[today] ?? [];
    todayEntries.add(alertKey);
    log[today] = todayEntries;

    await _saveLog(log);
    debugPrint('[CaregiverAlert] Recorded alert: $alertKey');
  }
}
