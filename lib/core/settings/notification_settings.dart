import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores user notification preferences locally (SharedPreferences).
class NotificationSettings extends ChangeNotifier {
  NotificationSettings._();
  static final instance = NotificationSettings._();

  static const _keyMedicine = 'notif_medicine';
  static const _keyFamilyCalls = 'notif_family_calls';
  static const _keyDailyActivity = 'notif_daily_activity';
  static const _keyEmergency = 'notif_emergency';

  bool _medicine = true;
  bool _familyCalls = true;
  bool _dailyActivity = false;
  bool _emergency = true;

  bool get medicine => _medicine;
  bool get familyCalls => _familyCalls;
  bool get dailyActivity => _dailyActivity;
  bool get emergency => _emergency;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _medicine = prefs.getBool(_keyMedicine) ?? true;
    _familyCalls = prefs.getBool(_keyFamilyCalls) ?? true;
    _dailyActivity = prefs.getBool(_keyDailyActivity) ?? false;
    _emergency = prefs.getBool(_keyEmergency) ?? true;
    notifyListeners();
  }

  Future<void> setMedicine(bool v) => _set(_keyMedicine, v, () => _medicine = v);
  Future<void> setFamilyCalls(bool v) => _set(_keyFamilyCalls, v, () => _familyCalls = v);
  Future<void> setDailyActivity(bool v) => _set(_keyDailyActivity, v, () => _dailyActivity = v);
  Future<void> setEmergency(bool v) => _set(_keyEmergency, v, () => _emergency = v);

  Future<void> _set(String key, bool value, void Function() apply) async {
    apply();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }
}
