import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    home = HomeScreen(userName: currentUser.displayName ?? 'Friend');
  } else if (seenOnboarding) {
    home = const LoginScreen();
  } else {
    home = const OnboardingScreen();
  }

  runApp(EverWithApp(home: home));
}

class EverWithApp extends StatelessWidget {
  const EverWithApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
    );
  }
}
