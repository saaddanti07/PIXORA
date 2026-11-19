# PIXORA

**Restore · Enhance · Create** — a premium, fully on-device photo restoration and creative
imaging app for Android.

PIXORA brings old and damaged photographs back to life, sharpens soft details, and turns
ordinary photos into creative artwork — with every pixel processed **on the user's own
device**. There is no upload, no account, and no paywall.

> **Phase 01 status:** the application foundation, design system, navigation, localization,
> theme handling, local storage and the local image picker/preview are **implemented and
> working**. The AI tools themselves are **not implemented yet** and are clearly labelled as
> coming soon. No screen presents fake processing results.

---

## Table of contents

1. [Product goals](#product-goals)
2. [Business model](#business-model)
3. [What works today (Phase 01)](#what-works-today-phase-01)
4. [What is planned (future phases)](#what-is-planned-future-phases)
5. [Technology stack](#technology-stack)
6. [Project architecture](#project-architecture)
7. [Supported languages](#supported-languages)
8. [Design system](#design-system)
9. [Development setup](#development-setup)
10. [Build and run commands](#build-and-run-commands)
11. [GitHub Actions: build the APK in the cloud](#github-actions-build-the-apk-in-the-cloud)
12. [Installing the APK on the Redmi 9](#installing-the-apk-on-the-redmi-9)
13. [Testing and static analysis](#testing-and-static-analysis)
14. [Privacy and permissions](#privacy-and-permissions)
15. [Localization workflow](#localization-workflow)
16. [Engine architecture (future AI)](#engine-architecture-future-ai)
17. [Advertising readiness](#advertising-readiness)
18. [Performance notes for low-end devices](#performance-notes-for-low-end-devices)
19. [Brand assets](#brand-assets)
20. [Troubleshooting](#troubleshooting)
21. [Roadmap](#roadmap)

---

## Product goals

- **Restore**: repair old, damaged, faded or scratched photographs.
- **Enhance**: improve clarity, sharpness and resolution; recover facial detail.
- **Colourise**: add realistic colour to black and white photographs.
- **Create**: anime style, artistic effects and pixel art.
- **Stay private**: processing happens on the device, offline-first.
- **Stay free**: advertising is the only revenue source, and it never blocks editing.

## Business model

| Rule | Status |
| --- | --- |
| Completely free to use | ✅ permanent design rule |
| Revenue only from Google AdMob | 🔜 AdMob not integrated in Phase 01 |
| No subscriptions, plans or credits | ✅ never added |
| No paywall before processing | ✅ never added |
| No ad required to process an image | ✅ permanent design rule |
| Ads never interrupt processing or cover the photo | ✅ permanent design rule |

AdMob dependencies are deliberately **not** included yet. See
[Advertising readiness](#advertising-readiness).

## What works today (Phase 01)

| Area | Status | Notes |
| --- | --- | --- |
| Application scaffold (`com.pixora.app`) | ✅ | Flutter 3.50, Material 3, Android only |
| Branding (`PIXORA` only, no "PIXORA AI") | ✅ | Wordmark, launcher icon, native splash |
| Home dashboard | ✅ | Hero restoration card, 8 tool cards, recent activity |
| Bottom navigation (Home / History / Settings) | ✅ | State preserved between tabs |
| Local image picker (gallery) | ✅ | Android system photo picker, no storage permission |
| Image preview | ✅ | Real dimensions read from the file header, size, format, pinch-zoom |
| Image validation & error handling | ✅ | Signature check, size/pixel caps, localized errors |
| History screen | ✅ | Designed empty state (ledger ready for Phase 02) |
| Settings | ✅ | Theme, language, privacy, about, open-source licences |
| Light / dark / system theme | ✅ | Persisted locally |
| English / Arabic / French | ✅ | Runtime switching, full RTL for Arabic |
| Local preferences persistence | ✅ | `SharedPreferences` behind a testable abstraction |
| Engine architecture (interfaces, registry) | ✅ | No models, no fake processors |
| GitHub Actions APK build | ✅ | Debug APK artifact |
| Tests + static analysis | ✅ | `flutter analyze`, `flutter test` |

## What is planned (future phases)

- **Phase 02** — first real on-device processing (classical enhancement) and history records.
- **Phase 03** — LiteRT integration, model download manager, Smart AI Engine device profiling
  (RAM, CPU, GPU, thermals) and model selection.
- **Phase 04** — restoration (Real-ESRGAN-class), face restoration (GFPGAN-class),
  colourisation, artistic styles, pixel art.
- **Phase 05** — AdMob (banner + limited interstitial + optional rewarded), release signing,
  Play Store packaging.

Chat with the developer: nothing from Phase 02 onwards starts until Phase 01 is approved.

## Technology stack

| Layer | Choice |
| --- | --- |
| Framework | Flutter (stable **3.50.0**) |
| Language | Dart 3.10+ |
| UI | Flutter Material 3 |
| Localization | `flutter_localizations` + `intl` + ARB files + `flutter gen-l10n` |
| Local storage | `shared_preferences` (behind a `KeyValueStore` abstraction) |
| Photo selection | `image_picker` (Android system photo picker) |
| Native | Kotlin (`MainActivity.kt`), Android Gradle Plugin 9.3.1, Kotlin 2.4.20, Gradle 9.5.0 |
| Target platform | Android (`com.pixora.app`), Java 17 bytecode |
| CI | GitHub Actions on `ubuntu-latest` |

Runtime dependencies are intentionally tiny (three packages). Every extra dependency is
APK size and memory pressure on a 2–3 GB RAM device.

## Project architecture

```
lib/
  main.dart                     # entry point; bootstraps services, then runApp
  app/
    app.dart                    # MaterialApp: theme mode, locale, routes
    bootstrap.dart              # composition root (services + preferences)
    theme/                      # colours, spacing/radius/motion tokens, typography,
                                #   PixoraPalette ThemeExtension, ThemeData builders
    localization/               # SupportedLanguage, context.l10n helper
    navigation/                 # RootShell with the bottom navigation bar
    state/                      # SettingsController + SettingsScoped InheritedNotifier
  core/
    constants/                  # app name, version, package id, memory budgets
    models/                     # ImageDimensions
    services/                   # ImagePickerService contract + failures
    storage/                    # KeyValueStore, SharedPreferences impl, in-memory impl
    utilities/                  # format detection, header dimension reader, byte formatting
    widgets/                    # PixoraCard, PixoraLogo, EmptyState, SectionHeader, badges
  features/
    home/                       # dashboard screen, hero card, tool grid, coming-soon sheet
    image_picker/               # validation controller, preview screen, details card
    history/                    # HistoryEntry model, repository, screen, empty state
    settings/                   # settings screen, theme/language selectors, about card
    image_engine/               # interfaces/, models/, services/ (no implementations yet)
  l10n/                         # app_en.arb, app_ar.arb, app_fr.arb (generated code ignored)
test/
  unit/                         # repositories, validation, header parsing, engine contract
  widget/                       # startup, navigation, localization/RTL, theme, preview, layout
  helpers/                      # in-memory harness, fake picker, image byte fixtures
tool/
  generate_brand_assets.py      # deterministic renderer for icon + splash artwork
.github/workflows/android-build.yml
```

Dependency direction is strictly inward: `features → core`, `app → features`, with no feature
importing another feature's internals except through its public screen/service.

## Supported languages

| Language | Code | Direction | File |
| --- | --- | --- | --- |
| English (default) | `en` | LTR | `lib/l10n/app_en.arb` |
| Arabic | `ar` | **RTL** | `lib/l10n/app_ar.arb` |
| French | `fr` | LTR | `lib/l10n/app_fr.arb` |

The language is applied instantly (no restart), stored locally, and restored on the next
launch. Arabic switches the whole interface — including alignment, icon direction and
navigation — to right-to-left.

## Design system

- Material 3 with a custom `ColorScheme` seeded from the brand violet `#5B4BE0`.
- `PixoraPalette` `ThemeExtension` carries brand gradients, card surfaces, borders and
  elevation shadows, and lerps smoothly between light and dark.
- 20 dp screen gutters, 20/26 dp radii, 24 dp card padding, 4/8/12/16/20/24/32 dp spacing
  scale.
- Typography: system font with tuned weights, tracking and line heights (keeps the APK small
  and gives full Arabic coverage through the platform fallback).
- Colour is never the only signal: selected settings use a border **and** an icon; tools state
  "Coming soon" in words.

## Development setup

You do **not** need Android Studio. The only requirements are:

1. **Flutter 3.50.0 stable** — https://docs.flutter.dev/get-started/install
2. **Java 21** (Temurin/OpenJDK) — required by the Gradle/AGP versions used here.
3. **Android SDK** (command line tools are enough) with `ANDROID_HOME` exported.
4. Git.

Windows 7 note: current Flutter SDKs and the Android build toolchain do not support Windows 7.
Develop on GitHub Codespaces, a Linux VM/cloud shell, or let
[GitHub Actions](#github-actions-build-the-apk-in-the-cloud) produce the APK — that is exactly
why the workflow exists.

```bash
git clone https://github.com/saaddanti07/PIXORA.git
cd PIXORA
flutter --version      # expect 3.50.0
flutter doctor         # Android toolchain must be green
```

## Build and run commands

```bash
# 1. Dependencies
flutter pub get

# 2. Generated localization sources (also runs automatically before build/test)
flutter gen-l10n

# 3. Static analysis (must be clean)
flutter analyze

# 4. Tests
flutter test

# 5. Debug APK
flutter build apk --debug
#    → build/app/outputs/flutter-apk/app-debug.apk

# 6. Optional: split release-style build (signed with the debug key in this phase)
flutter build apk --release --split-per-abi
```

Run on a connected device:

```bash
flutter devices
flutter run -d <device-id>
```

Changing the launcher icon or splash artwork:

```bash
python3 tool/generate_brand_assets.py
```

## GitHub Actions: build the APK in the cloud

The workflow is `.github/workflows/android-build.yml` and runs on every push to `main`,
`arena/**`, `feature/**`, on pull requests, and manually.

It performs, on `ubuntu-latest`:

1. checkout, JDK 21, Flutter 3.50.0 (cached);
2. `flutter pub get` and `flutter gen-l10n`;
3. `flutter analyze`;
4. `flutter test`;
5. `flutter build apk --debug`;
6. upload of the APK as the **`pixora-debug-apk`** artifact (30 days retention).

### Downloading the APK

1. Open the repository on GitHub → **Actions**.
2. Select the latest green run of **Android build**.
3. In the run summary, scroll to **Artifacts** and download **`pixora-debug-apk`**.
4. Unzip it — the file inside is `app-debug.apk`.

To trigger it by hand:

```bash
gh workflow run android-build.yml --ref main
gh run list --workflow android-build.yml
gh run watch <run-id>
# then
gh run download <run-id> -n pixora-debug-apk
```

No signing secrets are stored in the repository: Phase 01 produces a debug-signed APK. Release
signing (a local `key.properties` plus keystore outside Git) arrives in a later phase.

## Installing the APK on the Redmi 9

1. Copy `app-debug.apk` to the phone (USB, Google Drive, or `adb install app-debug.apk`).
2. Allow installation from unknown sources for the file manager you used.
3. Install and open **PIXORA**.
4. Tap **Choose a Photo** and pick any JPG/PNG/WebP image to see the preview and its real
   dimensions.

## Testing and static analysis

```bash
flutter analyze   # 0 issues expected
flutter test      # all tests green
```

Covered by the suite:

- application startup and first frame;
- bottom navigation across all three tabs;
- language switching (English → French → Arabic → English) with persistence;
- **Arabic RTL** direction, locale propagation and translated strings;
- theme switching (system / light / dark) with persistence and brightness assertions;
- preferences persistence across a simulated restart, plus corrupt-data resilience;
- image picking: cancel, success, unsupported file, oversized file, missing file,
  permission failure;
- image header parsing (PNG/JPEG/WebP/GIF) and byte formatting;
- preview screen details, re-pick, cancellation and error snackbars;
- history ledger round-trip and empty state;
- engine contract: no processors registered, no fake device numbers;
- a 360 × 780 dp (Redmi 9 class) layout sweep through every tab in every language.

## Privacy and permissions

- **No permissions are declared** in the main manifest. The photo picker grants one-off read
  access to the single image the user selects.
- No network code, no analytics, no crash reporting SDK, no image uploads.
- Preferences and history metadata live in `SharedPreferences` on the device.
- `INTERNET` appears **only** in the debug/profile manifests, which Flutter needs for hot
  reload during development.

## Localization workflow

1. Add the string to `lib/l10n/app_en.arb` (the template), then to `app_ar.arb` and
   `app_fr.arb`.
2. Run `flutter gen-l10n` (or any build command) to regenerate `lib/l10n/generated/`.
3. Use it: `Text(context.l10n.myNewString)`.

Placeholders are declared in the ARB metadata, for example:

```json
"settingsVersion": "Version {version}",
"@settingsVersion": { "placeholders": { "version": { "type": "String" } } }
```

There is no hardcoded interface string in the widgets; anything visible is translated.

## Engine architecture (future AI)

`lib/features/image_engine/` is ready for real models without touching the UI:

```
interfaces/
  image_processor.dart             # common contract every capability implements
  image_restoration_service.dart   # old photo restoration
  image_enhancement_service.dart   # upscaling / clarity
  face_enhancement_service.dart    # face restoration
  colorization_service.dart        # black & white → colour
  artistic_style_service.dart      # anime / artistic
  pixel_art_service.dart           # pixel art
models/
  processing_tool.dart             # stable tool identifiers
  image_processing_request.dart    # local path + tool + options
  image_processing_result.dart     # local output path, model id, duration
  model_spec.dart                  # backend, availability, download requirement
  device_capability_profile.dart   # RAM/CPU/GPU shape for the Smart AI Engine
services/
  model_registry.dart              # catalogue of planned models (all "planned")
  image_engine_registry.dart       # the processors available in this build (empty)
  device_capability_profiler.dart  # interface + explicit "not implemented" impl
```

Deliberate Phase 01 rules:

- **no** model files, downloads or LiteRT dependency;
- **no** processor implementations, so no screen can fake a result;
- **no** invented device metrics or model sizes — the profiler throws
  `UnsupportedError` until real measurements exist.

A future phase adds a class implementing e.g. `ImageRestorationService`, registers it in
`ImageEngineRegistry`, and the home catalogue can light the tool up.

## Advertising readiness

Not integrated, by design. The layout already leaves room for the formats planned later:

- a banner slot at the bottom of the Home list (below content, never over a photo);
- interstitial only *after* a completed save, with frequency capping;
- rewarded ads strictly optional (extra effect, never required).

Rule enforced everywhere: ads never sit on the preview screen, never cover the selected image,
and never gate processing.

## Performance notes for low-end devices

- Dimensions are parsed from the **file header only** (PNG IHDR, JPEG SOF, WebP VP8X/VP8/VP8L,
  GIF) — a 12 MP photo is described without decoding ~48 MB of pixels.
- Previews decode with `cacheWidth` capped at 1440 px, so a 108 MP image never allocates a
  full-resolution texture.
- Files above 40 MB or ~48 megapixels are rejected with a friendly message instead of risking
  an out-of-memory crash.
- Tabs live in an `IndexedStack`, so switching tabs never rebuilds or re-fetches.
- No image bytes are copied into preferences; only small metadata records.
- Only three runtime dependencies; no custom fonts bundled.

## Brand assets

| Asset | Location |
| --- | --- |
| Launcher icon (legacy, all densities) | `android/app/src/main/res/mipmap-*/ic_launcher.png` |
| Adaptive icon (foreground + background) | `mipmap-*/ic_launcher_foreground.png`, `mipmap-anydpi-v26/ic_launcher.xml` |
| Splash artwork | `android/app/src/main/res/drawable-nodpi/launch_logo.png` |
| Master artwork | `assets/branding/pixora_icon_1024.png`, `pixora_icon_512.png` |
| Renderer (source of truth) | `tool/generate_brand_assets.py` |

The mark is a four-point sparkle (light/enhancement, lens aperture) on a violet gradient. It is
rendered deterministically, so every density stays pixel-crisp and perfectly centred.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `flutter analyze` reports missing `app_localizations.dart` | run `flutter gen-l10n` (or `flutter pub get`) |
| Gradle fails with "unsupported class file major version" | use JDK 21 (`java -version`) |
| `sdkmanager`/Android SDK not found | install command-line tools and export `ANDROID_HOME` |
| APK build runs out of memory in CI | the workflow already caps Gradle; do not add heavy plugins |
| Emulator too slow on the dev machine | use a physical Redmi 9 or rely on the CI APK |

## Roadmap

| Phase | Scope |
| --- | --- |
| 01 ✅ | Foundation, branding, UI, navigation, localization/RTL, themes, preferences, picker/preview, history shell, engine architecture, CI, tests, docs |
| 02 | First real processing (classical enhancement), history capture and re-open |
| 03 | LiteRT integration, model storage/download manager, Smart AI Engine profiling |
| 04 | Restoration, face restoration, colourisation, artistic styles, pixel art |
| 05 | AdMob, release signing, Play Store release |

---

**PIXORA** — the app name is always `PIXORA`, never `PIXORA AI`. AI is a technology inside the
app, not part of its name.

Licensing: no licence file is included yet; the repository owner should choose one before the
project is published.
