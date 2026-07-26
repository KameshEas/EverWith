import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'caregiver_alert_service.dart';
import 'family_service.dart';
import 'tts_service.dart';

/// Result of voice command dispatch.
enum VoiceCommandResult {
  notRecognized,
  navigateToMedicines,
  navigateToSettings,
  navigateToHome,
  handled,
}

/// Parses recognized voice text and dispatches appropriate actions.
class VoiceCommandService {
  VoiceCommandService._();

  static final _tts = TtsService.instance;

  /// Dispatches a voice command based on recognized text.
  /// Returns a VoiceCommandResult indicating what action was taken.
  static Future<VoiceCommandResult> dispatch(BuildContext context, String text) async {
    final normalized = _normalize(text);

    // Call [name] — look up contact and launch tel:
    if (_matchesIntent(normalized, ['call', 'phone', 'dial'])) {
      await _handleCall(context, normalized);
      return VoiceCommandResult.handled;
    }

    // Add medicine / medication
    if (_matchesIntent(normalized, ['add', 'new'])) {
      await _tts.speak('Opening medicine form.');
      return VoiceCommandResult.navigateToMedicines;
    }

    // Open settings
    if (_matchesIntent(normalized, ['settings', 'preferences', 'options'])) {
      await _tts.speak('Opening settings.');
      return VoiceCommandResult.navigateToSettings;
    }

    // Medicines / my medicines
    if (_matchesIntent(normalized, ['medicine', 'medicines', 'medication'])) {
      await _tts.speak('Opening your medicines.');
      return VoiceCommandResult.navigateToMedicines;
    }

    // Emergency / SOS
    if (_matchesIntent(normalized, ['emergency', 'sos', 'help', 'alert'])) {
      await _handleEmergency(context);
      return VoiceCommandResult.handled;
    }

    // Home / go home
    if (_matchesIntent(normalized, ['home', 'go home'])) {
      await _tts.speak('Going home.');
      return VoiceCommandResult.navigateToHome;
    }

    return VoiceCommandResult.notRecognized;
  }

  static String _normalize(String text) => text.toLowerCase().trim();

  static bool _matchesIntent(String text, List<String> keywords) {
    return keywords.any((kw) => text.contains(kw));
  }

  static Future<bool> _handleCall(BuildContext context, String text) async {
    final familyService = FamilyService.instance;
    final contacts = familyService.contacts;

    if (contacts.isEmpty) {
      await _tts.speak('No family contacts available.');
      return true;
    }

    // Extract a name from the command (e.g. "call john" -> look for "john")
    final words = text.split(RegExp(r'\s+'));
    String? matchedName;

    for (final word in words) {
      if (word == 'call' || word == 'phone' || word == 'dial') continue;
      // Try to find a contact matching this word
      for (final contact in contacts) {
        if (contact.name.toLowerCase().contains(word)) {
          matchedName = contact.name;
          break;
        }
      }
      if (matchedName != null) break;
    }

    if (matchedName == null && contacts.isNotEmpty) {
      // Default to the caregiver if no name matched
      final caregiver = familyService.caregiver;
      if (caregiver != null) {
        matchedName = caregiver.name;
      } else {
        matchedName = contacts.first.name;
      }
    }

    if (matchedName == null) {
      await _tts.speak('Could not find anyone to call.');
      return true;
    }

    // Find the contact and get the phone number
    final contact =
        contacts.firstWhere((c) => c.name == matchedName, orElse: () => contacts.first);
    if (contact.phone.isEmpty) {
      await _tts.speak('$matchedName has no phone number.');
      return true;
    }

    await _tts.speak('Calling $matchedName.');
    try {
      final uri = Uri(scheme: 'tel', path: contact.phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('[VoiceCommandService] Cannot launch phone app');
        await _tts.speak('Could not open the phone app.');
      }
    } catch (e) {
      debugPrint('[VoiceCommandService] Error calling contact: $e');
      await _tts.speak('Could not open the phone app.');
    }

    return true;
  }

  static Future<void> _handleEmergency(BuildContext context) async {
    final caregiver = FamilyService.instance.caregiver;
    if (caregiver == null) {
      await _tts.speak(
          'No caregiver set. Please set a caregiver in the Family tab first.');
      return;
    }

    try {
      await _tts.speak('Sending emergency alert to ${caregiver.name}.');
      final sent = await CaregiverAlertService.instance.alertEmergency(
        userName: 'Your loved one',
      );
      if (!sent) {
        debugPrint('[VoiceCommandService] Emergency alert failed to send');
        await _tts.speak('Emergency alert could not be sent.');
      }
    } catch (e) {
      debugPrint('[VoiceCommandService] Error handling emergency: $e');
      await _tts.speak('Error sending emergency alert.');
    }
  }
}
