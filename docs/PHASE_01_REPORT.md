# PIXORA — Phase 01 implementation report

> **Note (0.1.1):** this report describes Phase 01 as originally delivered (51 tests).
> The runtime bug fix that followed — lost photo picks, preview freshness, state
> restoration, locale pinning — is documented in
> [`BUGFIX_0_1_1_RUNTIME.md`](BUGFIX_0_1_1_RUNTIME.md) and raises the suite to 72 tests.

**Scope delivered:** project foundation, premium UI, branding, navigation, localization (EN/AR/FR
with RTL), themes, local preferences, real image picking and preview, history foundation, engine
architecture, CI and documentation.

**Explicitly not delivered (by design):** any AI/ML processing, model downloads, AdMob, accounts,
payments. Nothing in the app pretends otherwise.

## 1. Toolchain actually used

| Item | Version / source |
| --- | --- |
| Flutter SDK | **3.50.0** (stable; CI pins it, `channel: stable`) |
| Dart | 3.10+ constraint (`environment: sdk: ">=3.10.0 <4.0.0"`) |
| Android Gradle Plugin | 9.3.1 (Flutter 3.50.0 template default) |
| Kotlin | 2.4.20 |
| Gradle wrapper | 9.5.0 |
| JDK (CI) | Temurin 21 |
| Compile SDK / min SDK | from the Flutter SDK (`flutter.compileSdkVersion` / `flutter.minSdkVersion`) |
| Build target | Android, `com.pixora.app`, Java 17 bytecode |

Runtime dependencies: `flutter`, `flutter_localizations`, `intl ^0.20.3`, `image_picker ^1.1.2`,
`shared_preferences ^2.3.2`. Dev: `flutter_test`, `flutter_lints ^6.0.0`.

The Android project files were generated from the **official Flutter 3.50.0 Android template**
(fetched from the `flutter/flutter` `3.50.0` tag) so the Gradle/AGP/Kotlin combination is the
supported one, not a guess.

## 2. What was implemented

### Foundation and configuration
- `pubspec.yaml` (name `pixora`, display name `PIXORA`, application id `com.pixora.app`).
- `analysis_options.yaml` (flutter_lints + two extra rules, generated l10n excluded).
- `l10n.yaml` (official gen-l10n pipeline, output in `lib/l10n/generated/`).
- `.metadata`, `.gitignore`, `tool/generate_brand_assets.py`.

### Branding
- Deterministic launcher icon (sparkle mark) at all five densities, adaptive icon
  (`mipmap-anydpi-v26` + foreground layers), master 512/1024 artwork.
- Native splash: gradient layer-list with the mark, plus Android 12+
  `windowSplashScreenBackground` / `windowSplashScreenAnimatedIcon` (light and night variants).
- In-app mark painted by `CustomPainter` (`PixoraLogo`), wordmark `PIXORA` — the string `PIXORA AI`
  appears nowhere in the app or project name.

### UI/UX
- Material 3 theme with a brand `ColorScheme`, custom typography scale, component themes, and a
  `PixoraPalette` `ThemeExtension` for gradients/borders/shadows.
- Home: branded header + settings shortcut, welcome block, gradient "Restore Your Memories" hero
  card with the "Choose a Photo" CTA and an on-device badge, an 8-tool creative grid with honest
  "Coming soon" badges and a bottom sheet explaining each tool is in development, and a
  data-driven recent-activity section with a designed empty state.
- History: header, designed empty state with a call to action and a privacy note, plus a dormant
  list renderer for Phase 02.
- Settings: appearance selector (system/light/dark), language selector (English/العربية/Français),
  privacy card, about card (name, version, application id, free-and-ad-supported statement,
  open-source licences page).
- Preview: framed photo with `InteractiveViewer`, metadata card (name, dimensions, size, format,
  "stored only on this device"), honest "arrives in an upcoming update" notice, "Choose another
  photo" and "Back to home".

### Behaviour
- Theme and language apply instantly and persist across restarts.
- Arabic switches the entire UI to RTL (verified by test).
- Photo picking uses the Android system picker (no storage permission); the picked file is
  validated (existence, signature-based format, 40 MB and ~48 MP ceilings), and dimensions are read
  from the file header only.
- Errors (permission, unsupported, too large, unreadable, unknown) are mapped to localized messages.
- Gallery cancelled → nothing happens; no fake results anywhere.

### Architecture for future phases
- Six processing interfaces (`ImageRestorationService`, `ImageEnhancementService`,
  `FaceEnhancementService`, `ColorizationService`, `ArtisticStyleService`, `PixelArtService`) behind
  a common `PixoraImageProcessor` contract.
- `ImageEngineRegistry` (empty in Phase 01 — the reason tools say "coming Soon"),
  `ModelRegistry` (planned models, no invented sizes), `DeviceCapabilityProfiler` interface with an
  implementation that throws `UnsupportedError` instead of fabricating hardware data.

## 3. Verification results (GitHub Actions, run on `ubuntu-latest`)

| Check | Result |
| --- | --- |
| `flutter pub get` | ✅ success |
| `flutter gen-l10n` | ✅ success (92 messages × 3 locales) |
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **51 / 51 passing** |
| `flutter build apk --debug` | ✅ success, APK uploaded as `pixora-debug-apk` |

Tests: 51 cases (30 pure unit + 21 widget), covering startup, navigation, language switching and persistence,
Arabic RTL, theme switching/persistence, corrupt-storage resilience, image validation and header
parsing, preview interactions, history ledger, engine contract, and a 360 × 780 dp layout sweep in
all three languages.

Local environment note: the development sandbox had **no Flutter SDK, no JDK and no Android SDK**,
and its network allow-list blocked the SDK/artifact hosts. Everything above was therefore verified
in GitHub Actions, which is also the documented workflow for the developer.

## 4. Repository layout

```
lib/  main.dart, app/ (theme, localization, navigation, state, bootstrap),
      core/ (constants, models, services, storage, utilities, widgets),
      features/ (home, image_picker, history, settings, image_engine), l10n/
test/ unit/ (5 files), widget/ (6 files), helpers/
android/ (Flutter 3.50 template + PIXORA manifest, icons, splash)
.github/workflows/android-build.yml
docs/ ARCHITECTURE.md, PHASE_01_REPORT.md
tool/generate_brand_assets.py, assets/branding/
```

## 5. Known limitations / notes

1. No release signing: the release build type still uses debug keys (template default). Phase 05
   adds a keystore via `key.properties` (never committed).
2. `pubspec.lock` is not committed yet because it can only be produced by a machine with the Flutter
   SDK; the first local `flutter pub get` should be committed for fully reproducible builds.
3. `flutter analyze` reports no issues; `dart format` was not enforced in CI because no Dart SDK was
   available locally to normalise formatting. Run `dart format lib test` before the next release.
4. The `package:flutter/material.dart` library is annotated deprecated in Flutter 3.50 in favour of
   the new `material_ui` package; PIXORA stays on the SDK library and the library-level notice is
   silenced in `analysis_options.yaml` with an explanatory comment. Revisit when `material_ui`
   stabilises.
5. History is intentionally empty: it fills only when real processing exists (Phase 02).
6. `.gitignore` keeps generated l10n sources out of Git; `flutter gen-l10n` (or any build) recreates
   them.

## 6. Manual steps for the developer

1. Download the APK: GitHub → Actions → latest green **Android build** → Artifacts →
   `pixora-debug-apk` → unzip → `app-debug.apk`.
2. Install on the Redmi 9 (allow install from unknown sources) and verify: theme switch, language
   switch (Arabic RTL), photo picking and preview.
3. If you want a signed release later: create a keystore locally, add `android/key.properties`
   (ignored by Git) and a release `signingConfig` — do not commit secrets.
4. Decide the repository licence (no licence file yet).

## 7. Not started (next phases, pending approval)

Phase 02 (first real processing + history capture), Phase 03 (LiteRT + Smart AI Engine + model
download manager), Phase 04 (restoration/face/colourisation/artistic/pixel art), Phase 05 (AdMob,
release signing, store release).
