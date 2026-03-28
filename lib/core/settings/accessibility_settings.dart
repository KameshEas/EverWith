import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();
  static final instance = AccessibilitySettings._();

  static const _keyLargeFont = 'a11y_large_font';
  static const _keyHighContrast = 'a11y_high_contrast';
  static const _keyTts = 'a11y_tts';

  bool _largeFont = false;
  bool _highContrast = false;
  bool _tts = false;

  bool get largeFont => _largeFont;
  bool get highContrast => _highContrast;
  bool get tts => _tts;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _largeFont = prefs.getBool(_keyLargeFont) ?? false;
    _highContrast = prefs.getBool(_keyHighContrast) ?? false;
    _tts = prefs.getBool(_keyTts) ?? false;
    notifyListeners();
  }

  Future<void> setLargeFont(bool value) async {
    _largeFont = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLargeFont, value);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighContrast, value);
  }

  Future<void> setTts(bool value) async {
    _tts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTts, value);
  }
}
