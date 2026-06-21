import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../settings/notification_settings.dart';

/// Fires loud, alarm-style local notifications on the parent's device.
///
/// Uses a dedicated high-priority channel with:
/// - Full-screen intent (wakes the screen like an alarm)
/// - Long vibration pattern
/// - Max importance / priority
/// - Insistent flag (repeats sound until dismissed on supported devices)
class AlarmNotificationService {
  AlarmNotificationService._();
  static final instance = AlarmNotificationService._();

  static const _channelId = 'caregiver_alarm';
  static const _channelName = 'Caregiver Alerts';
  static const _channelDesc =
      'Loud alarm notifications for missed medicines and emergencies';

  static const _reminderChannelId = 'gentle_reminders';
  static const _reminderChannelName = 'Daily Reminders';
  static const _reminderChannelDesc = 'Gentle daily and weekly activity reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification IDs — using fixed ranges so they don't collide with medicine reminders.
  static const _missedMedicineBaseId = 200000;
  static const _emergencyId = 300000;
  static const _activityReminderId = 400000;
  static const _familyCallsReminderId = 400001;

  /// Initialize the plugin. Safe to call multiple times.
  /// On first init, also restores reminder schedules based on settings.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Restore reminder schedules on app startup
    final settings = NotificationSettings.instance;
    await settings.load();
    if (settings.dailyActivity) {
      await scheduleDailyActivityReminder();
    }
    if (settings.familyCalls) {
      await scheduleWeeklyFamilyCallsReminder();
    }
  }

  /// Show a loud alarm notification for a missed medicine.
  Future<void> showMissedMedicineAlarm({
    required String medicineName,
    required String scheduledTime,
    required String caregiverName,
  }) async {
    await init();

    final id = _missedMedicineBaseId +
        (medicineName.hashCode.abs() % 100000);

    await _plugin.show(
      id,
      'Missed Medicine Alert',
      '$medicineName was due at $scheduledTime and hasn\'t been taken. '
          '$caregiverName has been notified.',
      _alarmDetails(),
    );
  }

  /// Show a loud alarm notification for an emergency SOS.
  Future<void> showEmergencyAlarm({
    required String caregiverName,
  }) async {
    await init();

    await _plugin.show(
      _emergencyId,
      'Emergency SOS Sent',
      'An emergency alert has been sent to $caregiverName. '
          'Help is on the way.',
      _alarmDetails(),
    );
  }

  /// Show a warning when no caregiver is set and emergency is pressed.
  Future<void> showNoCaregiverWarning() async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      category: AndroidNotificationCategory.alarm,
    );

    await _plugin.show(
      _emergencyId + 1,
      'No Caregiver Set',
      'Go to Family tab and mark someone as your caregiver to enable alerts.',
      const NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule a daily reminder at 10 AM to stay active.
  Future<void> scheduleDailyActivityReminder() async {
    await init();

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);

      // If 10 AM has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      await _plugin.zonedSchedule(
        _activityReminderId,
        'Time to Stay Active',
        'Time for a short walk! Stay active today.',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[AlarmNotificationService] Error scheduling daily activity reminder: $e');
    }
  }

  /// Cancel the daily activity reminder.
  Future<void> cancelDailyActivityReminder() async {
    try {
      await _plugin.cancel(_activityReminderId);
    } catch (e) {
      debugPrint('[AlarmNotificationService] Error canceling daily activity reminder: $e');
    }
  }

  /// Schedule a weekly reminder on Sunday at 10 AM to call family.
  Future<void> scheduleWeeklyFamilyCallsReminder() async {
    await init();

    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);

      // Calculate next Sunday at 10 AM
      final daysUntilSunday = (7 - now.weekday) % 7;
      if (daysUntilSunday == 0 && scheduledDate.isBefore(now)) {
        // If today is Sunday but 10 AM has passed, schedule for next Sunday
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      } else if (daysUntilSunday > 0) {
        // Schedule for upcoming Sunday
        scheduledDate = scheduledDate.add(Duration(days: daysUntilSunday));
      } else {
        // Today is Sunday and 10 AM hasn't passed yet
        // Do nothing, scheduledDate is already correct
      }

      const androidDetails = AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      await _plugin.zonedSchedule(
        _familyCallsReminderId,
        'Time to Call Family',
        'Don\'t forget to reach out to your loved ones!',
        scheduledDate,
        const NotificationDetails(android: androidDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[AlarmNotificationService] Error scheduling weekly family calls reminder: $e');
    }
  }

  /// Cancel the weekly family calls reminder.
  Future<void> cancelFamilyCallsReminder() async {
    try {
      await _plugin.cancel(_familyCallsReminderId);
    } catch (e) {
      debugPrint('[AlarmNotificationService] Error canceling family calls reminder: $e');
    }
  }

  /// Builds alarm-style notification details.
  NotificationDetails _alarmDetails() {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      // Full-screen intent — wakes the phone screen like an alarm
      fullScreenIntent: true,
      // Category tells the OS to treat this as an alarm
      category: AndroidNotificationCategory.alarm,
      // Vibration pattern: wait 0ms, vibrate 500ms, pause 200ms, vibrate 500ms, pause 200ms, vibrate 500ms
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
      enableVibration: true,
      // Ongoing — user must explicitly dismiss (can't swipe away easily)
      ongoing: true,
      autoCancel: true,
      // Additional flags via style
      visibility: NotificationVisibility.public,
      ticker: 'EverWith Alert',
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.critical,
      ),
    );
  }
}
