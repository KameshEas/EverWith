import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sends SMS messages via the device's native SIM card (Android SmsManager).
/// No third-party API — free, automatic, and works offline.
class SmsService {
  SmsService._();
  static final instance = SmsService._();

  static const _channel = MethodChannel(
    'com.example.everwith/sms',
  );

  /// Sends an SMS to [phoneNumber] with [message].
  /// Returns `true` on success, `false` on failure.
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendSms', {
        'phone': phoneNumber,
        'message': message,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[SmsService] Error sending SMS: ${e.message}');
      return false;
    }
  }

  /// Returns `true` if SEND_SMS permission is granted.
  Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasSmsPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[SmsService] Error checking SMS permission: ${e.message}');
      return false;
    }
  }
}
