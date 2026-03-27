# EverWith — Elderly Voice Companion

<p align="center">
  <img src="assets/images/app_logo.png" alt="EverWith Logo" width="120"/>
</p>

<p align="center">
  <strong>A warm, accessible voice-companion app designed for elderly users.</strong><br/>
  Built with Flutter · Firebase · Google Sign-In
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-blue?logo=dart" />
  <img src="https://img.shields.io/badge/Firebase-Auth-orange?logo=firebase" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green" />
</p>

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Screenshots](#screenshots)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Firebase Setup](#firebase-setup)
- [Architecture & Conventions](#architecture--conventions)
- [Contributing](#contributing)
- [License](#license)

---

## About

**EverWith** is a Flutter mobile application built to be a gentle, always-available voice companion for elderly users. The app prioritises large readable typography, high-contrast colours, spacious touch targets, and an emotionally warm design — all meeting WCAG AA accessibility standards.

---

## Features

- 🎙️ **Voice Assistant Interface** — Large mic button with animated pulse feedback
- 🔐 **Authentication** — Email/password sign-up & sign-in, Google Sign-In (OAuth)
- 👤 **Profile Setup** — Collects name and phone number after social sign-in
- 🔑 **Password Reset** — Email-based password recovery flow
- 🎨 **Accessibility-First Design** — 60 px+ touch targets, WCAG AA contrast, elderly-friendly typography
- 🌊 **Smooth Onboarding** — Animated brand introduction screen
- 🏗️ **Design System** — Centralised tokens for colours, spacing, and text styles

---

## Screenshots

> _Add screenshots here once the UI is finalised._

| Onboarding | Sign Up | Login | Home |
|---|---|---|---|
| _soon_ | _soon_ | _soon_ | _soon_ |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x (Dart 3.x) |
| Authentication | Firebase Auth 5.x |
| Social Sign-In | Google Sign-In 6.x |
| State | `setState` (local, screen-level) |
| Rendering | Skia (Impeller disabled for device compatibility) |
| Linting | `flutter_lints` |

---

## Project Structure

```
lib/
├── core/
│   ├── auth/
│   │   ├── auth_result.dart        # Sealed AuthResult (AuthSuccess / AuthFailure)
│   │   └── auth_service.dart       # Firebase Auth + Google Sign-In service
│   ├── constants/
│   │   ├── app_assets.dart         # All asset path constants
│   │   └── app_spacing.dart        # 8-pt grid spacing & radius tokens
│   └── theme/
│       ├── app_colors.dart         # Entire colour palette
│       └── app_text_styles.dart    # Named text styles
│
├── screens/
│   ├── onboarding_screen.dart      # First-launch brand introduction
│   ├── login_screen.dart           # Email/password + Google login
│   ├── signup_screen.dart          # Registration form (5 fields + Google)
│   ├── profile_setup_screen.dart   # Post-Google-Sign-In profile collection
│   └── home_screen.dart            # Main voice assistant dashboard
│
├── widgets/                        # Reusable UI components
│   ├── app_logo.dart
│   ├── app_header_icon_button.dart
│   ├── auth_text_field.dart
│   ├── google_sign_in_button.dart
│   ├── gradient_primary_button.dart
│   └── pill_chip.dart
│
├── firebase_options.dart           # ⚠️ Auto-generated — DO NOT commit
└── main.dart
```

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.10.1` — [Install Flutter](https://docs.flutter.dev/get-started/install)
- Dart SDK `^3.10.1`
- Android Studio / Xcode for device/emulator
- A Firebase project (see [Firebase Setup](#firebase-setup))

### 1. Clone the repository

```bash
git clone https://github.com/your-username/everwith.git
cd everwith
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Add Firebase config files

> These files are **gitignored** and must be added manually (see [Firebase Setup](#firebase-setup)).

```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
```

### 4. Run the app

```bash
flutter run
```

---

## Firebase Setup

1. Go to the [Firebase Console](https://console.firebase.google.com) and create a project.
2. Add an **Android app** with your package name (`com.yourcompany.everwith`).
3. **Register the SHA-1 fingerprint** of your debug keystore:
   ```bash
   cd android && ./gradlew signingReport
   ```
   Copy the `SHA1` under `variant: debug` and add it in Firebase → Project Settings → Android app.
4. Download `google-services.json` and place it at `android/app/google-services.json`.
5. (iOS) Add an **iOS app**, download `GoogleService-Info.plist`, and place it at `ios/Runner/GoogleService-Info.plist`.
6. Enable **Email/Password** and **Google** sign-in methods in Firebase Console → Authentication → Sign-in method.
7. Run the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli) to regenerate `firebase_options.dart`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

---

## Architecture & Conventions

| Rule | Rationale |
|---|---|
| Never use raw `Color()` literals in widgets — use `AppColors.*` | Single source of truth |
| Never declare `TextStyle` inline — use `AppTextStyles.*` | Prevents style drift |
| Never use raw `double` literals for spacing — use `AppSpacing.*` | Enforces 8-pt grid |
| Never reference asset paths as bare strings — use `AppAssets.*` | A single rename updates everything |
| Auth methods return `AuthResult` (sealed) — never throw | Callers use exhaustive pattern matching |

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'feat: add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

<p align="center">Built with ❤️ for our elders</p>
