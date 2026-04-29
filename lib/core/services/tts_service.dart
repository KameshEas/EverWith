import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TtsService — Piper TTS via FakeYou API (Open-source TTS)
//  No Android permission checks; eliminates background noise issues.
// ─────────────────────────────────────────────────────────────────────────────

/// Piper voice model definition
class PiperVoice {
  final String id;
  final String name;
  final String language;

  PiperVoice({
    required this.id,
    required this.name,
    required this.language,
  });
}

/// Available Piper voices (FakeYou API voice IDs)
final piperVoices = [
  PiperVoice(
    id: 'tts_voices_en_US_lessac_low',
    name: 'Lessac (Male)',
    language: 'en',
  ),
  PiperVoice(
    id: 'tts_voices_en_US_ryan_high',
    name: 'Ryan (Male)',
    language: 'en',
  ),
  PiperVoice(
    id: 'tts_voices_en_US_goofy_low',
    name: 'Goofy (Male)',
    language: 'en',
  ),
  PiperVoice(
    id: 'tts_voices_en_GB_alba_medium',
    name: 'Alba (Female - British)',
    language: 'en',
  ),
  PiperVoice(
    id: 'tts_voices_en_US_libritts_high',
    name: 'LibriTTS (Female)',
    language: 'en',
  ),
];

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final AudioPlayer _player = AudioPlayer();
  bool _isSpeaking = false;
  String _selectedVoiceId = 'tts_voices_en_US_lessac_low';

  bool get isSpeaking => _isSpeaking;
  String get selectedVoiceId => _selectedVoiceId;

  /// Set the voice to use for TTS
  void setVoice(String voiceId) {
    _selectedVoiceId = voiceId;
  }

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

  /// Fetch TTS audio via Piper (FakeYou API) and play it.
  /// [onDone] is called when playback finishes (or on error) so callers can chain subsequent actions.
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
      _isSpeaking = true;

      // Request TTS from Piper via FakeYou API
      final jobUrl = await _requestTtsJob(text);

      // Poll for completion
      final audioUrl = await _pollTtsJob(jobUrl, onError: onError);

      if (audioUrl == null) {
        _isSpeaking = false;
        onDone?.call();
        return;
      }

      // Download audio
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_piper_output.wav');

      final response = await http.get(Uri.parse(audioUrl))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        onError?.call('Download failed: ${response.statusCode}');
        _isSpeaking = false;
        onDone?.call();
        return;
      }

      await file.writeAsBytes(response.bodyBytes);

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
      onError?.call('TTS error: $e');
      onDone?.call();
    }
  }

  /// Request a TTS job from FakeYou API
  Future<String> _requestTtsJob(String text) async {
    const endpoint = 'https://api.fakeyou.com/tts/inference';

    final payload = {
      'uuid_idempotency_token':
          DateTime.now().millisecondsSinceEpoch.toString(),
      'tts_model_token': _selectedVoiceId,
      'inference_text': text,
    };

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to request TTS: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map;
    final jobToken = data['inference_job_token'] as String?;

    if (jobToken == null) {
      throw Exception('No job token in response');
    }

    return jobToken;
  }

  /// Poll FakeYou API for TTS job completion
  Future<String?> _pollTtsJob(
    String jobToken, {
    void Function(String)? onError,
    int maxAttempts = 120, // 2 minutes with 0.5-second intervals
  }) async {
    const endpoint = 'https://api.fakeyou.com/tts/job/';
    const pollInterval = Duration(milliseconds: 500);

    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await http
            .get(Uri.parse('$endpoint$jobToken'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map;
          final status = data['state'] as String?;

          if (status == 'complete_success') {
            final result = data['result'] as Map?;
            final audioUrl = result?['audio_url'] as String?;
            if (audioUrl != null) {
              return audioUrl;
            }
          } else if (status == 'complete_failure') {
            onError?.call('TTS generation failed');
            return null;
          }
        }

        await Future.delayed(pollInterval);
      } catch (e) {
        onError?.call('Polling error: $e');
        return null;
      }
    }

    onError?.call('TTS generation timeout');
    return null;
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
