import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firestore_service.dart';

class AccessibilitySettings extends ChangeNotifier {
  AccessibilitySettings._();
  static final instance = AccessibilitySettings._();

  static const _keyLargeFont = 'a11y_large_font';
  static const _keyHighContrast = 'a11y_high_contrast';
  static const _keyTts = 'a11y_tts';
  static const _keyTtsVoice = 'a11y_tts_voice';
  static const _keyLanguage = 'a11y_language';

  bool _largeFont = false;
  bool _highContrast = false;
  bool _tts = false;
  String _ttsVoice = 'tts_voices_en_US_lessac_low';
  String _languageCode = 'en';

  bool get largeFont => _largeFont;
  bool get highContrast => _highContrast;
  bool get tts => _tts;
  String get ttsVoice => _ttsVoice;
  String get languageCode => _languageCode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _largeFont = prefs.getBool(_keyLargeFont) ?? false;
    _highContrast = prefs.getBool(_keyHighContrast) ?? false;
    _tts = prefs.getBool(_keyTts) ?? false;
    _ttsVoice = prefs.getString(_keyTtsVoice) ?? 'tts_voices_en_US_lessac_low';
    _languageCode = prefs.getString(_keyLanguage) ?? 'en';
    notifyListeners();
  }

  Future<void> setLargeFont(bool value) async {
    _largeFont = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLargeFont, value);
    await _syncToFirestore();
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighContrast, value);
    await _syncToFirestore();
  }

  Future<void> setTts(bool value) async {
    _tts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTts, value);
    await _syncToFirestore();
  }

  Future<void> setTtsVoice(String voiceId) async {
    _ttsVoice = voiceId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTtsVoice, voiceId);
    await _syncToFirestore();
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, code);
    await _syncToFirestore();
  }

  /// Best-effort sync of all accessibility settings to Firestore.
  /// Silent fail — local settings always work as fallback.
  Future<void> _syncToFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirestoreService.instance.updateUserProfile(uid, {
        'accessibilitySettings': {
          'largeFont': _largeFont,
          'highContrast': _highContrast,
          'tts': _tts,
          'ttsVoice': _ttsVoice,
          'languageCode': _languageCode,
        }
      });
    } catch (_) {
      // Silent fail — local-only settings work fine
    }
  }
}
