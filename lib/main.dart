import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/wake_word_service.dart';
import 'core/settings/accessibility_settings.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase already initialized (e.g. on hot restart)
  }
  await AccessibilitySettings.instance.load();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
  final currentUser = FirebaseAuth.instance.currentUser;

  Widget home;
  if (currentUser != null) {
    // Check if launched from wake word → auto-start mic on HomeScreen
    bool autoListen = false;
    try {
      autoListen = await WakeWordService.instance.getAutoListen();
    } catch (_) {}
    home = HomeScreen(
      userName: currentUser.displayName ?? 'Friend',
      autoListen: autoListen,
    );
  } else if (seenOnboarding) {
    // Check if launched from wake word but not logged in → show message
    bool notLoggedIn = false;
    try {
      notLoggedIn = await WakeWordService.instance.getNotLoggedIn();
    } catch (_) {}
    home = LoginScreen(wakeWordNotLoggedIn: notLoggedIn);
  } else {
    home = const OnboardingScreen();
  }

  runApp(EverWithApp(home: home));
}

/// Starts the wake word background service once the Flutter engine is ready.
class _WakeWordStarter extends StatefulWidget {
  const _WakeWordStarter({required this.child});
  final Widget child;
  @override
  State<_WakeWordStarter> createState() => _WakeWordStarterState();
}

class _WakeWordStarterState extends State<_WakeWordStarter> {
  @override
  void initState() {
    super.initState();
    // Start after first frame so the MethodChannel is ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      WakeWordService.instance.start();
      // Request "Display over other apps" permission if not already granted.
      // This allows the service to directly open the app when a wake word is
      // detected, without requiring the user to tap a notification.
      final hasOverlay = await WakeWordService.instance.hasOverlayPermission();
      if (!hasOverlay) {
        await WakeWordService.instance.requestOverlayPermission();
      }
    });
  }

  @override
  void dispose() {
    WakeWordService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class EverWithApp extends StatelessWidget {
  const EverWithApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return _WakeWordStarter(
      child: MaterialApp(
        title: 'EverWith - Elderly Voice Companion',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: home,
      ),
    );
  }
}
