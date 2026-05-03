import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Notification IDs — using fixed ranges so they don't collide with medicine reminders.
  static const _missedMedicineBaseId = 200000;
  static const _emergencyId = 300000;

  /// Initialize the plugin. Safe to call multiple times.
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
