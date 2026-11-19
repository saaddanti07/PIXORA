# PIXORA 0.1.1 — runtime bug fix (settings + image selection)

Branch: `arena/f490bcd4-pixora` · App version `0.1.1` (versionCode 2)
Scope: the bugs reported from real-device testing on a Redmi 9. **No Phase 02
work.**

---

## 1. Method, and its limits

| What | How |
| --- | --- |
| Static review | full read of `lib/` (66 Dart files), Android config, ARB files, workflow |
| Compilation, analysis, tests, APK | **GitHub Actions only** — this environment has no Flutter/Dart/JDK/Android SDK and cannot reach `pub.dev`, `storage.googleapis.com` or `services.gradle.org` |
| Device behaviour | **not available** — no Redmi 9, no emulator, no `adb` |

Because a physical device is unavailable, everything below states *what the code
does*, *what was proven in CI*, and *what only a device can confirm*. Nothing is
reported as "fixed on the device".

The one thing the widget tests could never catch is Android activity lifecycle
handling. That is exactly where the image-selection bug was.

---

## 2. Findings

### F1 — A picked photo could be dropped entirely (image selection) · **defect confirmed in code**

`ImagePickerService` only ever asked the plugin for a *new* pick
(`ImagePicker.pickImage`). Android is free to destroy the app's activity while
the system picker is in the foreground; on a 2 GB device under MIUI that is a
routine event, not an edge case. When it happens:

* `pickImage()`'s `Future` is never completed (the activity that would have
  received `onActivityResult` no longer exists),
* `image_picker` keeps the chosen file in its lost-data store,
* the app restarts on Home, `_isPicking` is gone, and the user sees
  **nothing happen** after choosing a photo.

Nothing recovered the file, because `retrieveLostData()` was never called.

**Fix:** `ImagePickerService.retrieveLostImagePath()` +
`DeviceImagePickerService` implementation (`retrieveLostData`, mapping
`LostDataResponse.exception` to the same failure kinds) +
`ImageSelectionController.recoverLostImage()` (same validation as a normal pick)
+ `RootShell` calling it on first frame **and** on every `AppLifecycleState.resumed`
and opening the preview when something came back. Guarded against re-entrancy,
and a recovered-but-unusable file is swallowed instead of blocking the app.

### F2 — The preview could show the *previous* photo · **defect confirmed in code**

Three separate mechanisms allowed a stale bitmap:

1. `Image.file(..., gaplessPlayback: true)` deliberately keeps the **old frame**
   on screen until the new decode finishes — and keeps it forever if the new
   decode fails (which is what an unreadable/`.heic`/truncated file does).
2. `PhotoPreviewFrame` had no key, so the same `Element`/`Image` state was reused
   for a different photo (zoom/pan state and pending decode carried over).
3. Nothing evicted the old `FileImage` from `imageCache`, so both full bitmaps
   stayed resident on a 2 GB phone.

**Fix:** `PhotoPreviewFrame` is keyed by file path, `gaplessPlayback` is `false`,
and `ImagePreviewScreen._releasePreviousImage()` evicts the previous
`FileImage` from the image cache before swapping.

### F3 — Theme and language · **no reproducible defect found; binding hardened**

The reported symptom ("changing language/theme does nothing") could **not** be
reproduced: switching works in the widget-test environment, and the *previous*
suite already tapped the real tiles and asserted the new text/direction/theme
(4 localization + 4 theme tests). The data flow was verified line by line:

`LanguageSelector` → `SettingsController.setLanguage` → `notifyListeners` →
root rebuild → `MaterialApp.locale` → `Localizations` → every `context.l10n`.
Same path for `themeMode`. Persistence: `SharedPreferences` → `AppSettings` →
read in `PixoraBootstrap.create()` **before** the first frame.

Two real weaknesses were found and fixed anyway, because both can produce a
"stuck" appearance and neither was covered:

* **Locale fallback.** Resolution was delegated to
  `basicLocaleListResolution`. It resolves from the platform list, so a device
  reporting a dialect (`ar-DZ`, `fr-DZ`) or an unrelated system language could
  resolve to a locale that is not the one shown as selected, and any edit to the
  generated `supportedLocales` order silently changed the result. Added
  `localeListResolutionCallback` pinning the resolved locale to the user's
  choice.
* **Rebuild path.** The root used an `InheritedNotifier` *and* a nested
  `ListenableBuilder` over the same controller. It worked, but it is two
  mechanisms for one job and there was no single place to reason about. The root
  is now a `StatefulWidget` with one explicit
  `addListener`/`setState`/`removeListener` pair; `SettingsScope` remains only
  for descendants that need read access.

**Conclusion:** if the settings symptom persists after installing build ≥ 2, it
is not this data flow. Retrieval of the *installed* build is therefore made
provable (F5) and the retest steps in §6 isolate the remaining possibilities.

> Note on plausible non-code causes, eliminated or not: the previous APK was
> `0.1.0+1` and the new one is `0.1.1+2`, so Android now sees a different
> version and Settings shows the CI run number of the build that is installed.
> The earlier artifact could have been an older/losing build with no way to tell.

### F4 — State restoration was absent (Android lifecycle)

After a background kill (or "Don't keep activities"), the app always came back
on Home. Added `restorationScopeId: 'pixora'` on `MaterialApp` and
`RestorationMixin` + `RestorableInt` in `RootShell`, so the open tab is
restored. Covered by a `tester.restartAndRestore()` test.

### F5 — You could not tell which build was on the phone

`Settings → About` showed `Version 0.1.0` for every APK ever produced. It now
shows `0.1.1 · build <CI run number>`, injected with
`--dart-define=PIXORA_BUILD=${{ github.run_number }}`. This is the single most
useful diagnostic for the remaining device questions.

---

## 3. Files changed

| File | Change |
| --- | --- |
| `lib/app/app.dart` | stateful root, single listener, `localeListResolutionCallback`, `restorationScopeId` |
| `lib/app/navigation/root_shell.dart` | `RestorationMixin` + `RestorableInt` tab, `WidgetsBindingObserver`, lost-photo recovery |
| `lib/core/services/image_picker_service.dart` | `retrieveLostImagePath()` in the interface |
| `lib/features/image_picker/services/device_image_picker_service.dart` | `retrieveLostData()` implementation |
| `lib/features/image_picker/services/image_selection_controller.dart` | shared `_validate()`, `recoverLostImage()` |
| `lib/features/image_picker/screens/image_preview_screen.dart` | path-keyed frame, image-cache eviction |
| `lib/features/image_picker/widgets/photo_preview_frame.dart` | `gaplessPlayback: false` |
| `lib/features/settings/screens/settings_screen.dart` | corrected widget nesting/indentation (no behaviour change) |
| `lib/features/settings/widgets/{language,theme_mode}_selector.dart` | stable `ValueKey`s for tests |
| `lib/features/settings/widgets/about_card.dart`, `lib/core/constants/app_constants.dart` | version `0.1.1`, visible build stamp |
| `pubspec.yaml` | `0.1.1+2` |
| `.github/workflows/android-build.yml` | `--build-name 0.1.1`, `--dart-define PIXORA_BUILD` |
| `test/helpers/test_harness.dart` | fake picker supports lost data |
| `test/widget/settings_switch_test.dart` | **new**, 9 cases |
| `test/widget/image_selection_test.dart` | **new**, 7 cases |
| `test/unit/image_selection_controller_test.dart` | +4 recovery cases |
| `test/widget/navigation_test.dart` | +1 restoration case |

Unchanged on purpose: app name, `com.pixora.app`, design system, navigation,
architecture, ARB files (no new keys), workflow shape, no new dependencies, no
AdMob/network/AI code.

---

## 4. Verification (CI, this branch)

Local `flutter analyze` / `flutter test` / `flutter build apk` are impossible in
the development sandbox (no Flutter, Dart, JDK, Gradle or Android SDK, and
`pub.dev` / `storage.googleapis.com` / `services.gradle.org` are unreachable), so
the workflow is the only evidence — and the only place these commands were run.

Workflow run **44532573782** on commit `cc07b95` (`push`, branch
`arena/f490bcd4-pixora`): **both jobs green.**

| Step | Result |
| --- | --- |
| `flutter pub get` | ✅ |
| `flutter gen-l10n` | ✅ |
| `flutter analyze` | ✅ **`No issues found!`** (exit 0) |
| `flutter test` | ✅ **72 / 72 passing**, 0 failures, 14 files |
| `flutter build apk --debug` | ✅ `app-debug.apk` |
| Artifact | ✅ `pixora-debug-apk`, **76,950,351 bytes**, not expired |

Test suite growth: 51 → **72** (30 → 34 unit, 21 → 38 widget). No existing test
was weakened or removed; the new ones are listed in §3.

> Honest note on the way there: the first CI attempt on this branch
> (`547407f`) was **red** — `flutter analyze` was clean but 5 of the new image
> tests failed, because the picker's real file-system `await`s cannot be driven
> by the fake test clock. The tests were fixed to alternate real time with
> frames (commit `cc07b95`), not loosened: they still assert on the exact file
> the preview is displaying.

Static pre-checks (Android resources and manifests, localization parity,
imports, workflow shape, forbidden dependencies): **58 / 58 pass**.

---

## 5. How to get the APK

1. GitHub → **Actions** → workflow **Android build** → the newest run on
   `arena/f490bcd4-pixora` whose *Build debug APK* job is green.
2. Scroll to **Artifacts** → download **`pixora-debug-apk`**.
3. Unzip → `app-debug.apk`.

---

## 6. Retest on the Redmi 9

Before anything else: **Settings → About** must read
`0.1.1 · build <number>` with the number matching the Actions run. If it still
says `0.1.0`, the new APK was not installed and nothing below is meaningful
(uninstall the old PIXORA first, then install).

**A. Language (Settings → Language)**
1. Choose `Français` → every string changes at once, including the bottom bar
   and the Home hero; the app stays left-to-right.
2. Choose `العربية` → every string is Arabic **and the whole layout mirrors**
   (nav bar order, icon side, text alignment).
3. Choose `English` → back to the original.
4. Kill the app from recents and reopen → the last language is still applied on
   the first frame (no flash of English).

**B. Theme (Settings → Appearance)**
1. `Dark` → backgrounds, cards, borders, nav bar and text all go dark.
2. `Light` → the same screens go light, even with the phone in dark mode.
3. `System` → follow the phone: switch MIUI dark mode on/off while the app is
   open; the app must follow without a restart.
4. Reopen the app → the chosen mode persists.

**C. Image selection**
1. Home → **Choose a Photo** → the system picker opens.
2. Pick a JPG → the preview opens with that file's name, real dimensions and
   size; the photo is the one you picked.
3. **Choose another photo** → pick a *different* image → the preview shows the
   new one, with new dimensions. Zoom/pan must be reset.
4. Cancel the picker → you stay where you were, no error, no stuck spinner.
5. Try a PNG as well as a JPEG.
6. Turn on *Developer options → Don't keep activities*, then repeat step 2. The
   activity is destroyed while the gallery is in front — the preview must still
   open with the photo you chose (this is what F1 fixed).
7. Rotate the phone on the preview screen → the photo is not lost.

**D. General**
1. Airplane mode on → everything above still works (nothing is uploaded).
2. Navigate Home → History → Settings repeatedly; no jank or black screen.

If something still misbehaves, capture `adb logcat` (or MIUI's bug report) for
the PIXORA process while reproducing it — that turns the remaining unknown into
a fixable stack trace.

---

## 7. Still open / not claimed

* **The Redmi 9 symptoms are not confirmed fixed.** No device was available.
* All eight AI tools remain *Coming soon*; no model, no LiteRT, no AdMob, no
  releases signing, no Phase 02 work.
* `dart format` has not been applied to the whole tree and `pubspec.lock` is
  still not committed (both unchanged from Phase 01).
* The debug APK is ~77 MB; a release build is still to come.
