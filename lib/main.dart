import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/services/medicine_service.dart';
import 'core/services/wake_word_service.dart';
import 'core/settings/accessibility_settings.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';

/// Global navigator key — lets the auth gate redirect from outside widget tree.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // Firebase already initialized (e.g. on hot restart)
  }
  await AccessibilitySettings.instance.load();
  await MedicineService.instance.init();
  runApp(const EverWithApp());
}

class EverWithApp extends StatelessWidget {
  const EverWithApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _WakeWordStarter(
      child: ListenableBuilder(
        listenable: AccessibilitySettings.instance,
        builder: (context, _) {
          final a11y = AccessibilitySettings.instance;
          return MaterialApp(
            title: 'EverWith',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: a11y.highContrast
                ? AppTheme.highContrast()
                : AppTheme.normal(),
            // Override text scale factor for large-font mode.
            builder: (context, child) {
              final scale = a11y.largeFont ? 1.3 : 1.0;
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child!,
              );
            },
            home: const _AppEntry(),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _AppEntry
//  Shows SplashScreen while resolving the destination route in the background.
//  Navigation only happens after BOTH the splash animation AND async checks finish.
//  Also starts the auth-state listener AFTER the splash so it never triggers
//  during initialisation.
// ─────────────────────────────────────────────────────────────────────────────
class _AppEntry extends StatefulWidget {
  const _AppEntry();
  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  final _splashCompleter = Completer<void>();
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([
      _resolveDestination(),
      _splashCompleter.future,
    ]);
    if (mounted) {
      _navigate();
      // Start listening for auth changes only after we've navigated away from
      // the splash — avoids false redirects during startup.
      AuthGate.instance.start();
    }
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
    navigatorKey.currentState?.pushReplacement(
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
//  AuthGate
//
//  Singleton that listens to Firebase authStateChanges.
//  Firebase NEVER silently logs users out — tokens refresh automatically every
//  hour for the lifetime of the app. The stream only emits null when:
//    • The user explicitly signs out
//    • The account is deleted or disabled from the Firebase console
//
//  In both cases we redirect to LoginScreen, clearing the back stack.
//  A brief snackbar explains what happened if it was not an explicit sign-out.
// ─────────────────────────────────────────────────────────────────────────────
class AuthGate {
  AuthGate._();
  static final instance = AuthGate._();

  StreamSubscription<User?>? _sub;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;

    // Skip the very first event — it just reflects the current state that we
    // already handled during splash routing.
    bool firstEvent = true;

    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (firstEvent) {
        firstEvent = false;
        return;
      }

      if (user == null) {
        // User was signed out (explicitly or account revoked server-side).
        // Navigate to LoginScreen, wiping the entire back stack.
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  /// Call this before a deliberate programmatic sign-out so the listener
  /// doesn't show an unexpected message on top of the sign-out flow.
  void pause() => _sub?.pause();
  void resume() => _sub?.resume();

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
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
    AuthGate.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
