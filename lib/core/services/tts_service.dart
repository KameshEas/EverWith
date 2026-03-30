import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TtsService — HTTP-based text-to-speech (Google Translate TTS endpoint)
//  Avoids the Android TTS engine entirely.
// ─────────────────────────────────────────────────────────────────────────────
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  /// Call once at startup to wire up the completion callback listener.
  void init({
    void Function()? onComplete,
    void Function()? onCancel,
  }) {
    _player.onPlayerComplete.listen((_) {
      _isSpeaking = false;
      onComplete?.call();
    });
  }

  /// Fetch TTS audio via HTTP and play it. [onDone] is called when playback
  /// finishes (or on error) so callers can chain subsequent actions.
  Future<void> speak(
    String text, {
    String languageCode = 'en',
    void Function()? onDone,
    void Function(String)? onError,
  }) async {
    if (text.trim().isEmpty) {
      onDone?.call();
      return;
    }
    // Stop any in-progress speech first.
    await stop();

    try {
      final encoded = Uri.encodeComponent(text);
      final uri = Uri.parse(
        'https://translate.google.com/translate_tts'
        '?ie=UTF-8&q=$encoded&tl=$languageCode&client=tw-ob',
      );

      final response = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Chrome/120.0.0.0 Mobile Safari/537.36',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        onError?.call('HTTP ${response.statusCode}');
        onDone?.call();
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_output.mp3');
      await file.writeAsBytes(response.bodyBytes);

      _isSpeaking = true;

      // Wire up done callback for this particular speak call.
      late final StreamSubscription sub;
      sub = _player.onPlayerComplete.listen((_) {
        _isSpeaking = false;
        onDone?.call();
        sub.cancel();
      });

      await _player.play(DeviceFileSource(file.path));
    } catch (e) {
      _isSpeaking = false;
      onError?.call(e.toString());
      onDone?.call();
    }
  }

  Future<void> stop() async {
    if (_isSpeaking) {
      await _player.stop();
      _isSpeaking = false;
    }
  }

  void dispose() {
    _player.dispose();
  }
}
