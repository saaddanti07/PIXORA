# PIXORA — architecture notes (Phase 01)

This document explains *why* the code is shaped the way it is, so the next phases can extend it
without re-deciding the fundamentals.

## 1. Layering

```
main.dart
  └─ PixoraBootstrap.create()          composition root (async, before first frame)
       ├─ KeyValueStore → SharedPreferencesStore
       ├─ SettingsRepository → AppSettings
       ├─ SettingsController (ChangeNotifier)
       ├─ DeviceImagePickerService
       └─ HistoryRepository
  └─ PixoraApp(bootstrap)
       └─ SettingsScope (InheritedNotifier)
            └─ ListenableBuilder → MaterialApp(themeMode, locale)
                 └─ RootShell (IndexedStack + NavigationBar)
                      ├─ HomeScreen      → ImageSelectionController → ImagePreviewScreen
                      ├─ HistoryScreen   → HistoryRepository
                      └─ SettingsScreen  → SettingsScope.of(context)
```

Rules:

- `core/` has no dependency on `features/` and knows nothing about screens.
- `features/` may depend on `core/` and on its own public API.
- `app/` wires everything; it is the only place that knows about every feature.
- Nothing imports `package:flutter/material.dart` from `core/storage` or `core/services`, which
  keeps persistence and picking testable without a widget tree.

## 2. Why bootstrap before `runApp`

Reading preferences is asynchronous. If the app rendered first, the user would briefly see the
light theme and English before switching to their saved dark/Arabic setup. The native launch
screen covers the few milliseconds of `PixoraBootstrap.create()`, so the first Flutter frame is
already correct.

## 3. Settings flow

```
tap → SettingsController.setThemeMode/setLanguage
        ├─ mutate in-memory AppSettings
        ├─ notifyListeners()          → ListenableBuilder rebuilds MaterialApp
        └─ SettingsRepository.save()  → KeyValueStore (SharedPreferences)
```

Applying before persisting means the UI never lags behind a tap; persisting right after means a
process kill cannot lose the choice. `ThemeMode` and language are stored by name/code, never by
index, so enum reordering can never corrupt saved data — and unknown values fall back to the
defaults (`system`, `en`).

## 4. Image pipeline (Phase 01)

```
ImagePickerService.pickImagePath()   (Android Photo Picker; string path only)
        ↓
ImageSelectionController.pickImage()
        ├─ file exists?              → fileUnreadable
        ├─ size ≤ 40 MB?             → imageTooLarge
        ├─ signature sniffing        → unsupportedFormat
        ├─ header-only dimensions    → ImageDimensions (or null)
        └─ pixels ≤ 48 MP?           → imageTooLarge
        ↓
PickedImage (path, name, bytes, format, dimensions)
        ↓
ImagePreviewScreen  → Image.file(cacheWidth ≤ 1440)
```

Why the header parser exists: `decodeImageFromList` allocates the full bitmap (a 12 MP JPEG is
~48 MB as ARGB). On a Redmi 9 that is a crash waiting to happen. `ImageDimensionsReader` reads at
most 64 KB and understands PNG, JPEG (SOF markers), WebP (VP8X/VP8/VP8L) and GIF.

The picker service returns a `String?` path rather than a plugin-specific `XFile`, so the
abstraction has no dependency on `image_picker`, and tests can implement it in three lines.

## 5. Storage

`KeyValueStore` is a three-method interface (`read`, `write`, `remove`) with synchronous reads.

- `SharedPreferencesStore` — production; wraps `SharedPreferences`.
- `InMemoryKeyValueStore` — tests and design previews; no platform channels.

Synchronous reads keep the settings screen free of `FutureBuilder` flicker, and because both the
settings repository and the history repository are just functions over a `KeyValueStore`, they are
unit-testable without mocking Flutter plugins.

Records stored today:

| Key | Content |
| --- | --- |
| `pixora.preferences.themeMode` | `system` \| `light` \| `dark` |
| `pixora.preferences.language` | `en` \| `ar` \| `fr` |
| `pixora.history.entries` | JSON array of `HistoryEntry` metadata (empty in Phase 01) |

Image bytes are never stored in preferences.

## 6. Localization

Flutter's official pipeline: ARB files → `flutter gen-l10n` → `AppLocalizations`.

- `l10n.yaml` writes generated code to `lib/l10n/generated/` (git-ignored, excluded from
  analysis) — the modern replacement for synthetic packages.
- `context.l10n` (`lib/app/localization/l10n.dart`) is the single access point in widgets.
- Because the chosen `Locale` is passed to `MaterialApp`, Flutter derives
  `Directionality.rtl` for Arabic automatically; layouts use directional widgets
  (`EdgeInsetsDirectional`, `AlignmentDirectional`) and mirror correctly.
- `SupportedLanguage` carries the locale, native name and direction flag, so the picker and the
  app never disagree.
- Language names are shown in their own script (English / العربية / Français) — the one place
  where text is intentionally not translated.

## 7. Theme system

`AppTheme` builds two `ThemeData`s. Brand values that Material does not model (gradients, hairline
borders, shadows, muted surfaces) live in `PixoraPalette`, a `ThemeExtension` with a `lerp`
implementation — so the light↔dark transition animates instead of snapping, and widgets ask for
`PixoraPalette.of(context)` instead of branching on `Brightness`.

Component themes (`NavigationBar`, `FilledButton`, `OutlinedButton`, `Card`, `SnackBar`,
`Divider`) are configured once, which is why screens contain almost no ad-hoc styling.

## 8. Engine architecture

```
PixoraImageProcessor          (toolId, availability, models, process)
  ├─ ImageRestorationService  restore()
  ├─ ImageEnhancementService  enhance()
  ├─ FaceEnhancementService   enhanceFace()
  ├─ ColorizationService      colorize()
  ├─ ArtisticStyleService     stylize()
  └─ PixelArtService          convert()

ImageEngineRegistry           which processors exist in this build (empty in Phase 01)
ModelRegistry                 what models are planned (all ModelAvailability.planned)
DeviceCapabilityProfiler      interface; UnavailableDeviceCapabilityProfiler throws
```

Design decisions:

- Availability is data, not a boolean flag in the UI. A tool is "coming soon" because no
  processor is registered for its `ProcessingToolId`, not because a screen hardcodes a label.
- `ModelRegistry` deliberately omits download sizes until they are measured on real hardware —
  the app must never promise a number it has not verified.
- The profiler throws instead of guessing, which is why the Smart AI Engine cannot accidentally
  be "demoed" with invented RAM figures.

Phase 02/03 will add real classes, register them, and (optionally) surface
`registry.isAvailable(tool)` in the home grid.

The model, runtime and tiling decisions for the first real engine are audited in
[`PHASE_02_STEP1_MODEL_AUDIT.md`](PHASE_02_STEP1_MODEL_AUDIT.md). That report is
the authority for anything size-, speed- or licence-related; nothing in it may be
implemented before it is approved.

## 9. Advertising placement (not implemented)

When AdMob lands, the intended seams are:

- banner: bottom of the Home/History scroll content (inside the list, above the navigation bar);
- interstitial: after a completed save, frequency-capped, never mid-processing;
- rewarded: optional boost, never required.

Nothing in Phase 01 needs to change structurally: ads become a widget in the page layout and a
service behind an interface, mirroring `ImagePickerService`.

## 10. Testing strategy

- **Unit tests** cover pure logic: preferences (including corrupt values), history ledger,
  header parsing, validation thresholds, engine contract.
- **Widget tests** drive the real app through `PixoraApp` with `InMemoryKeyValueStore` and a
  `FakeImagePickerService`, so startup, navigation, RTL, theming and preview are exercised
  end-to-end without any plugin or real I/O.
- `test/widget/layout_test.dart` runs the whole app at 360 × 780 dp (Redmi 9 class) in all three
  languages — including Arabic — so text/expansion overflows fail in CI instead of on the phone.
