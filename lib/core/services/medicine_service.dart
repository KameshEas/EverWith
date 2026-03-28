import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/medicine.dart';

/// Manages medicine CRUD (SharedPreferences) and daily reminder notifications.
class MedicineService extends ChangeNotifier {
  MedicineService._();
  static final instance = MedicineService._();

  static const _prefsKey = 'medicines';
  static const _channelId = 'medicine_reminders';
  static const _channelName = 'Medicine Reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  List<Medicine> _medicines = [];
  bool _initialized = false;

  List<Medicine> get medicines => List.unmodifiable(_medicines);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Request Android 13+ notification permission
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _load();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> add(Medicine medicine) async {
    _medicines.add(medicine);
    await _save();
    await _scheduleNotification(medicine);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _medicines.removeWhere((m) => m.id == id);
    await _cancelNotification(id);
    await _save();
    notifyListeners();
  }

  /// Toggle today's taken status for a medicine.
  Future<void> toggleTaken(String id) async {
    final idx = _medicines.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final m = _medicines[idx];
    final today = _todayKey();
    final dates = List<String>.from(m.takenDates);
    if (dates.contains(today)) {
      dates.remove(today);
    } else {
      dates.add(today);
    }
    _medicines[idx] = m.copyWith(takenDates: dates);
    await _save();
    notifyListeners();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _medicines = Medicine.listFromJson(raw);
      } catch (_) {
        _medicines = [];
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, Medicine.listToJson(_medicines));
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> _scheduleNotification(Medicine medicine) async {
    if (medicine.frequency == MedicineFrequency.onlyAsNeeded) return;

    final notifId = medicine.id.hashCode.abs() % 100000;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Reminders to take your medicines',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    final now = DateTime.now();
    var scheduled = DateTime(
      now.year, now.month, now.day,
      medicine.timeHour, medicine.timeMinute,
    );
    // If time today already passed, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);

    await _plugin.zonedSchedule(
      notifId,
      'Time to take ${medicine.name}',
      '${medicine.dosage} — ${medicine.timeLabel}',
      tzScheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _cancelNotification(String id) async {
    final notifId = id.hashCode.abs() % 100000;
    await _plugin.cancel(notifId);
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
