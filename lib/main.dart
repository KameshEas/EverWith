import 'dart:async';

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
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase already initialized (e.g. on hot restart)
  }
  await AccessibilitySettings.instance.load();
  runApp(const EverWithApp());
}

class EverWithApp extends StatelessWidget {
  const EverWithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _WakeWordStarter(
      child: MaterialApp(
        title: 'EverWith',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const _AppEntry(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AppEntry
//  Shows SplashScreen while resolving the destination route in the background.
//  Navigation only happens after BOTH the splash animation AND async checks finish.
// ─────────────────────────────────────────────────────────────────────────────
class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  // Completer lets us signal from the splash callback into the Future.wait
  final _splashCompleter = Completer<void>();
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Run route resolution and splash timer in parallel.
    // Navigation only proceeds when BOTH are done.
    await Future.wait([
      _resolveDestination(),
      _splashCompleter.future,
    ]);
    if (mounted) _navigate();
  }

  Future<void> _resolveDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    final currentUser = FirebaseAuth.instance.currentUser;

    Widget dest;
    if (currentUser != null) {
      bool autoListen = false;
      try { autoListen = await WakeWordService.instance.getAutoListen(); } catch (_) {}
      dest = HomeScreen(
        userName: currentUser.displayName ?? 'Friend',
        autoListen: autoListen,
      );
    } else if (seenOnboarding) {
      bool notLoggedIn = false;
      try { notLoggedIn = await WakeWordService.instance.getNotLoggedIn(); } catch (_) {}
      dest = LoginScreen(wakeWordNotLoggedIn: notLoggedIn);
    } else {
      dest = const OnboardingScreen();
    }
    _destination = dest;
  }

  void _onSplashComplete() {
    if (!_splashCompleter.isCompleted) _splashCompleter.complete();
  }

  void _navigate() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => _destination!,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SplashScreen(onComplete: _onSplashComplete);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _WakeWordStarter — starts the wake word service once the engine is ready
// ─────────────────────────────────────────────────────────────────────────────
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WakeWordService.instance.start();
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

