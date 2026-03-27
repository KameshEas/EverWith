import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase already initialized (e.g. on hot restart)
  }
  runApp(const EverWithApp());
}

class EverWithApp extends StatelessWidget {
  const EverWithApp({super.key});

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
      home: const OnboardingScreen(),
    );
  }
}
