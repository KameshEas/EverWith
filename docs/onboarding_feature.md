# Onboarding Screen — Feature Instructions

> **Feature:** `onboarding`  
> **Entry file:** `lib/screens/onboarding_screen.dart`  
> **Last updated:** March 27, 2026

---

## 1. Purpose

The Onboarding Screen is the **first screen** every user encounters when opening EverWith. Its goals are:

- Introduce the app name and brand identity.
- Convey emotional warmth and accessibility for elderly users.
- Provide a single, obvious call-to-action to enter the app.

---

## 2. Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_assets.dart        # All asset path strings
│   │   └── app_spacing.dart       # 8-pt grid spacing & radius tokens
│   └── theme/
│       ├── app_colors.dart        # Entire app colour palette
│       └── app_text_styles.dart   # All named text styles
│
├── widgets/                       # Shared, reusable widgets
│   ├── app_logo.dart              # Brand lockup: sound-wave icon + "EverWith"
│   ├── app_header_icon_button.dart # Square card icon button (44×44 touch target)
│   ├── gradient_primary_button.dart# Full-width blue gradient CTA button
│   └── pill_chip.dart             # Rounded pill label chip
│
└── screens/
    └── onboarding_screen.dart     # Onboarding screen (composes above)
```

---

## 3. Architecture Rules

| Rule | Rationale |
|------|-----------|
| **Never use raw `Color()` literals in widget files.** Reference `AppColors.*` only. | Single source of truth; easy global theming. |
| **Never declare `TextStyle` inline for recurring styles.** Use `AppTextStyles.*`. | Avoids style drift across screens. |
| **Never use raw `double` literals for spacing/padding.** Use `AppSpacing.*`. | Enforces the 8-pt grid system. |
| **Never reference asset paths as bare strings.** Use `AppAssets.*`. | A single rename updates every reference. |
| **Shared widgets live in `lib/widgets/`.** Screen-only helpers stay private (`_`) in the screen file. | Maximises reuse; prevents bloat in shared layer. |

---

## 4. Reusable Widgets

### `AppLogo`
**File:** `lib/widgets/app_logo.dart`

Horizontal brand lockup: custom sound-wave `CustomPainter` icon + "EverWith" word mark.

```dart
AppLogo()                  // default 28px icon
AppLogo(iconSize: 36.0)    // larger variant, e.g. splash screen
```

---

### `AppHeaderIconButton`
**File:** `lib/widgets/app_header_icon_button.dart`

Square white card button with drop shadow. Guaranteed 44×44 minimum touch target per WCAG 2.5.5.

```dart
AppHeaderIconButton(
  icon: Icons.settings_rounded,
  semanticLabel: 'Open settings',
  onTap: () { /* navigate */ },
)
```

---

### `GradientPrimaryButton`
**File:** `lib/widgets/gradient_primary_button.dart`

Full-width blue gradient CTA button with a glow shadow and an optional trailing frosted-circle icon.

```dart
GradientPrimaryButton(
  label: 'Get Started',
  onTap: () { /* navigate */ },
)

// Custom trailing icon
GradientPrimaryButton(
  label: 'Continue',
  onTap: () {},
  trailingIcon: Icons.check_rounded,
)
```

---

### `PillChip`
**File:** `lib/widgets/pill_chip.dart`

Rounded pill label badge. Defaults to the blue chip palette; fully themeable.

```dart
PillChip(label: 'Your friendly voice companion')  // default blue

// Custom colours
PillChip(
  label: 'Beta',
  backgroundColor: Colors.amber.shade100,
  textStyle: AppTextStyles.subheading.copyWith(color: Colors.orange),
)
```

---

## 5. Screen-Private Widgets (Onboarding Only)

These are prefixed with `_` and declared inside `onboarding_screen.dart`. Do **not** lift them to `lib/widgets/` unless a second screen needs them.

| Widget | Responsibility |
|--------|---------------|
| `_OnboardingHeader` | Row: spacer + `AppLogo` + two `AppHeaderIconButton` |
| `_HeroCard` | 340px image card with bottom scrim + floating `_MicButton` |
| `_MicButton` | Pulsing animated circular mic FAB |
| `_OnboardingTextContent` | Heading + `PillChip` + body description |
| `_OnboardingFooter` | "Designed for easy viewing & use" row |
| `_WarmGradientPlaceholder` | Fallback shown when `elderlyperson.png` is missing |

---

## 6. Adding the Hero Image

1. Place your image file at:
   ```
   assets/images/elderlyperson.png
   ```
2. The asset is already declared in `pubspec.yaml` under `assets/images/`.
3. Run `flutter pub get` — no code changes needed. The placeholder disappears automatically.

> **Recommended specs:** 750 × 1000 px minimum, warm-toned, soft natural lighting. JPEG or PNG.

---

## 7. Spacing System (8-pt Grid)

| Token | Value | Usage |
|-------|-------|-------|
| `AppSpacing.xs` | 4px | Tight gaps, icon padding |
| `AppSpacing.sm` | 8px | Between inline elements |
| `AppSpacing.md` | 16px | Internal card padding |
| `AppSpacing.lg` | 24px | Screen edge padding |
| `AppSpacing.xl` | 32px | Section gaps |
| `AppSpacing.xxl` | 40px | Large section breaks |
| `AppSpacing.radiusSm` | 14px | Icon buttons |
| `AppSpacing.radiusMd` | 20px | CTA button, labels |
| `AppSpacing.radiusLg` | 28px | Cards |
| `AppSpacing.radiusPill` | 40px | Pill chips |
| `AppSpacing.minTouchTarget` | 44px | All interactive widgets |

---

## 8. Accessibility Checklist

- [x] All interactive elements wrapped in `Semantics(button: true, label: '...')`
- [x] Minimum touch target 44×44 px (`AppSpacing.minTouchTarget`)
- [x] Body text ≥ 17px (`AppTextStyles.body`)
- [x] Heading text 30px bold (`AppTextStyles.heading`)
- [x] Status bar transparent with dark icons (`SystemUiOverlayStyle`)
- [x] `BouncingScrollPhysics` for natural scrolling
- [x] `semanticLabel` on hero `Image.asset`
- [x] WCAG AA contrast: white text on blue primary (#3B82F6 meets 3.1:1 on white; button white-on-blue meets 4.5:1)

---

## 9. Navigation

The CTA button's `onTap` is marked with a `// TODO` comment. Replace it with your router call:

```dart
GradientPrimaryButton(
  label: 'Get Started',
  onTap: () => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const HomeScreen()),
  ),
)
```

---

## 10. Extending This Screen

| Want to… | Do this |
|----------|---------|
| Change app name | Update `AppTextStyles.appBarTitle` font size; change `'EverWith'` string in `app_logo.dart` |
| Change brand colour | Edit `AppColors.primaryBlue` — propagates everywhere |
| Add a second language | Pass locale to `_OnboardingTextContent` strings |
| Add page indicator dots | Insert a `Row` of dots between `_HeroCard` and `_OnboardingTextContent` |
| Dark mode | Extend `AppColors` with a dark variant; use `Theme.of(context).brightness` in widgets |
