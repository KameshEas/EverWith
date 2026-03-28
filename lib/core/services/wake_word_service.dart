import 'package:flutter/services.dart';

class WakeWordService {
  WakeWordService._();
  static final instance = WakeWordService._();

  static const _methodChannel = MethodChannel(
    'com.aspiredesignovation.everwith/wake_word',
  );
  static const _eventChannel = EventChannel(
    'com.aspiredesignovation.everwith/wake_word_events',
  );

  Stream<String>? _broadcastStream;

  Stream<String> get onWakeWordDetected {
    _broadcastStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event as String);
    return _broadcastStream!;
  }

  Future<void> start() => _methodChannel.invokeMethod<void>('start');
  Future<void> stop() => _methodChannel.invokeMethod<void>('stop');

  /// Release the mic without stopping the service (fast — no service restart).
  Future<void> pause() => _methodChannel.invokeMethod<void>('pause');

  /// Reclaim the mic after Flutter STT is done.
  Future<void> resume() => _methodChannel.invokeMethod<void>('resume');

  /// Asks the OS to show the "Display over other apps" settings page.
  /// Must be called once (e.g. at first launch) so the service can
  /// directly open the app when a wake word is detected.
  Future<void> requestOverlayPermission() =>
      _methodChannel.invokeMethod<void>('requestOverlayPermission');

  /// Returns true if the overlay (SYSTEM_ALERT_WINDOW) permission is granted.
  Future<bool> hasOverlayPermission() async =>
      await _methodChannel.invokeMethod<bool>('hasOverlayPermission') ?? false;

  /// True if the app was launched by a wake word AND the user is authenticated.
  Future<bool> getAutoListen() async =>
      await _methodChannel.invokeMethod<bool>('getAutoListen') ?? false;

  /// True if the app was launched by a wake word but the user is NOT logged in.
  Future<bool> getNotLoggedIn() async =>
      await _methodChannel.invokeMethod<bool>('getNotLoggedIn') ?? false;
}
