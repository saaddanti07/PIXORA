# PIXORA — Phase 02 Report: on-device AI restoration

**Version:** 0.2.1 · **Status:** device-reported quality/history issues under corrective work; **not acceptance-complete**
**Date:** 2026-11-19 · **Branch:** `arena/f490bcd4-pixora`

This report records what Phase 02 actually ships, with the numbers the build
produced. Anything that was not measured is labelled as such — the device
benchmark is the one gate still open, because no Redmi 9 was available here.

---

## Device follow-up status

The previous 0.2.0 APK was tested by the user on a Redmi 9. The reported output
retained scratches, and the UI claimed a history save while the History tab was
empty. These are critical findings, not cosmetic issues. Follow-up root-cause
analysis, code changes, outstanding image-pair measurements, model assessment,
and device retest requirements are documented in
[`PHASE_02_DEVICE_FINDINGS.md`](PHASE_02_DEVICE_FINDINGS.md). The 89.7-second
figure is one user-reported run only; the two-run/no-ANR/no-OOM gate remains open.

## 1. What ships

| # | Deliverable | State |
| --- | --- | --- |
| 2 | Real-ESRGAN `realesr-general-x4v3` converted to LiteRT, with a fidelity gate | ✅ converted, gate passed |
| 3 | Native Kotlin tiled restoration engine | ✅ implemented |
| 4 | Flutter adapter + engine activation | ✅ implemented |
| 5 | Real progress, cancellation, device profiling | ✅ implemented |
| 6 | Benchmarks | ⚠️ CI-runner measurement done; **device measurement pending** |
| 7 | Restoration UI with original/result comparison | ✅ implemented |
| 8 | Classical "Fast enhancement" path | ✅ implemented |
| 9 | Tests, CI validation, documentation | ⚠️ follow-up tests added; this revision awaits CI and device retest |

No face restoration, colourisation, anime, ads, subscriptions, downloads or
network calls were added. Phase 03 has not been started.

---

## 2. The model

| Field | Value | How it was obtained |
| --- | --- | --- |
| Model | Real-ESRGAN `realesr-general-x4v3` (SRVGGNetCompact) | upstream release |
| Source weights | 4,885,111 bytes | GitHub Releases API |
| Weights SHA-256 | `8dc7edb9ac80ccdc30c3a5dca6616509367f05fbc184ad95b731f05bece96292` | measured, then **pinned** in `models/weights.sha256` |
| Licence | **BSD-3-Clause** | `xinntao/Real-ESRGAN` — full text in [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) and in-app under Settings → About → Open-source licenses |
| Parameters | 1,213,296 | counted from the checkpoint |
| LiteRT artefact | **4,910,280 bytes (4.68 MiB)** | produced by `tool/convert_model.py` |
| Artefact SHA-256 | `cedda0d6c8f59c3eca8558e7002a571f5437079d922a486068384599b2d0ddab` | recorded in `models/report.json`, asserted by CI |
| Converter | `litert-torch` 0.10.0, torch 2.14.1 (CPU) | official PyTorch → LiteRT path |
| Conversion time | 5.0 s | CI runner |
| Input tensor | `[1, 3, 128, 128]` float32, **NCHW**, 0–1 | read back from the converted file |
| Output tensor | `[1, 3, 512, 512]` float32, **NCHW** | read back from the converted file |
| Scale | ×4 | model definition |

The layout is deliberately **not hardcoded** in the app: the converter writes
`realesr_general_x4v3_fp32.tflite.meta.json` next to the model, and the Kotlin
engine reads it at runtime. The converter preserved PyTorch's NCHW order, and the
engine adapts to it; if a future converter emits NHWC, no app code changes.

### Conversion fidelity (the Step 2 gate)

The converted model was compared against the PyTorch reference on **seven
procedurally generated fixtures** — ramp, checkerboard, rings, gaussian noise,
high-frequency detail and quadrants. No photograph, and certainly no user
photograph, is involved anywhere in the pipeline.

| Fixture | Pearson correlation | max abs error (8-bit equivalent) | PSNR |
| --- | --- | --- | --- |
| ramp | 1.0000000000 | 0.0034 / 255 | 126.5 dB |
| checker | 1.0000000000 | 0.0010 / 255 | 123.7 dB |
| rings, noise, detail, quadrants | 1.0000000000 | ≤ 0.01 / 255 | ≥ 118 dB |

**Gate: min correlation 1.000000 against a threshold of 0.995 → PASS.**
The CPU execution path is numerically identical to the reference model, so any
visible difference in output is the model's, not the conversion's.

---

## 3. Architecture of the shipped engine

```
Flutter                                    Android (Kotlin)
─────────────────────────────────────      ─────────────────────────────────
PreviewScreen                              MainActivity
  └─ "Restore with AI"                       └─ EngineChannel("pixora/engine")
ProcessingScreen                                ├─ SuperResolutionEngine
  ├─ ImageProcessingRequest  ───────────────▶   │    ├─ decode (sampled, EXIF-aware)
  ├─ progress stream ◀──── onProgress ─────     │    ├─ mirror padding
  └─ ImageProcessingResult ◀── result ──────    │    ├─ TilePlanner + LiteRtRunner
                                                │    └─ compose → JPEG
ImageEngineRegistry                             ├─ ClassicalEnhancer
  ├─ LiteRtRestorationProcessor                 └─ DeviceProbe
  └─ ClassicalEnhancementProcessor
```

Channel methods: `capabilities`, `paths`, `restore`, `enhance`, `cancel`,
`setKeepScreenOn`; one native → Dart event: `onProgress`.

**Only paths, numbers and status cross the channel.** No bitmap is ever copied
through the platform boundary, which is what keeps a 2048×1536 result cheap.

### Tiling

* Tiles are **128×128** input → **512×512** output (the shape the model was
  converted and verified at).
* Each tile is cut from a **mirror-padded** working image with a **16 px halo**, so
  the network always sees real neighbours; the halo is computed and then thrown
  away, so neighbouring tiles never overwrite each other.
* The last tile in a row is pulled back inside the image and only its own region
  is written — no double writes, no blending seams introduced by the engine.
* Cancellation is checked **between** tiles; a cancelled job deletes its partial
  file and reports `cancelled`, never a half-written image.

### Device policy (Smart AI Engine v1)

Derived from the platform's own numbers (`ActivityManager.MemoryInfo`,
`isLowRamDevice`, CPU count), never estimated:

| Tier | When | Working long edge | Output | Tiles for 640×480 |
| --- | --- | --- | --- | --- |
| classicalOnly | model not bundled | — | 2048 | fast path |
| conservative | low-RAM flag, or < 2.5 GB | 384 | 1536 | 12 |
| **balanced** | **2.5–3.5 GB — the Redmi 9 case** | **512** | **2048** | **24** |
| generous | ≥ 3.5 GB | 640 | 2560 | 35 |

The AI path never enlarges its input; it only ever reduces it, and the UI reports
the working size when a reduction happened. Anything outside the budget goes to
**Fast enhancement**, which is explicitly labelled as classical processing.

---

## 4. Measured results

| Measurement | Value | Where |
| --- | --- | --- |
| Conversion fidelity | correlation **1.000000**, max error **0.0034/255** | CI run 44775487671 |
| Inference, CI runner (4 vCPU, x86_64) | **96–212 ms per tile** | CI, repeated runs |
| Modelled cost per megapixel | 61 tiles | arithmetic |
| Flutter tests | **104 passing**, 0 failing | CI |
| `flutter analyze` | **No issues found!** | CI |
| Debug APK | Prior 0.2.0: 171,772,517 bytes (163.8 MiB); follow-up APK size pending CI | CI artifact |
| Model inside the APK | `assets/models/realesr_general_x4v3_fp32.tflite` — 4,910,280 B | CI asserts it |
| LiteRT native library | 3.55 MB (arm64) · 2.37 MB (armeabi-v7a) | APK listing |

**What is *not* measured:** pixel-difference/quality metrics for the user's photo pair (not present in this workspace), or the second device run. The CI runner is an
x86_64 server CPU with a different memory subsystem; its numbers bound nothing
about the phone. See §6.

---

## 5. The test suite

The previous suite had 104 passing tests. Follow-up adds history/persistence/UI, gallery-channel, and native tiling tests; this revision's exact test count/result is pending CI. Phase 01 tests remain present:

| File | What it pins down |
| --- | --- |
| `test/unit/processing_policy_test.dart` | tier selection, working-resolution maths (long edge, pixel budget, aspect ratio), tile counts, 90-second budget arithmetic |
| `test/unit/native_engine_channel_test.dart` | capabilities parsing, missing engine, argument forwarding, cancelled/failed mapping, progress events, best-effort cancel |
| `test/unit/image_engine_processors_test.dart` | both processors: availability, success mapping, cancellation, missing source, no invented model ids |
| `test/widget/processing_screen_test.dart` | progress line and ETA, cancel really cancels, failure can be retried, history written once, comparison labels |
| `test/unit/image_engine_test.dart` (updated) | shipped models are bundled, offline and carry a **measured** size; unshipped models stay planned and claim nothing |

---

## 6. The open gate: Redmi 9 benchmark

The acceptance gate — 640×480 in **≤ 90 s**, two consecutive runs, no ANR, no OOM,
honest progress, accurate cancel, correct output dimensions — **cannot be closed
here**: no Redmi 9 was available to this session, and no emulator can model an
ARM Cortex-A53 cluster honestly.

The arithmetic that motivates the default policy (24 tiles × 1.3–2.8 s estimated
per tile on a Helio G35 = **31–67 s**) is a prediction, not a measurement. It is
written down so the device run can confirm or refute it.

`docs/PHASE_02_BENCHMARKS.md` contains the exact procedure; `docs/PHASE_02_DEVICE_FINDINGS.md` contains the user-reported findings, model review, and photo-pair audit command. The fixture table to use
and the table to fill in. Until it is filled in, **no speed claim about the Redmi 9
may be made in the app, the store listing or the README.**

---

## 6.1 Known limitations (honest list)

1. **Device gate not closed.** User reports one Redmi 9 run at 89.7 s; the second consecutive run and memory/ANR observations are still unverified.
2. **Seam quality is not verified on real photographs.** The tiler now partitions overlapping predictions without double-writing; the design avoids the
   most common causes, but only eyes on real output can confirm it.
3. **Gallery export is implemented in the follow-up, but must still be physically verified** on Android versions covering scoped storage and legacy permission behavior.
4. **Debug APK is 163.8 MiB.** Debug builds bundle three ABIs plus debug Flutter
   engines; the LiteRT JNI libraries add ~10.6 MB and the model 4.7 MiB. A release
   build with per-ABI splits is the Phase 03 task.
5. **CPU only.** No GPU delegate is used: on the conservative target
   (PowerVR GE8320) it has to prove numerical agreement and a real speed-up first,
   and that proof needs the device.
6. **EXIF flips are treated as rotations.** The common orientations (1/3/6/8) are
   handled exactly; mirrored orientations are rare and currently rotated, not
   mirrored.
7. **No thermal mitigation beyond reporting it.** The engine reads thermal status
   but does not throttle the job.
8. **Large photos are reduced.** A 12 MP photo is processed at 512 px on the long
   edge; the UI says so. That is a deliberate product decision, not a defect.

---

## 7. Offline and privacy verification

| Claim | How it is verified |
| --- | --- |
| The model is inside the APK | CI asserts `assets/models/*.tflite` is present and its SHA-256 matches the report |
| No upload is possible | ``android/app/src/main/AndroidManifest.xml` declares no `INTERNET` permission; the follow-up adds only `WRITE_EXTERNAL_STORAGE` capped at API 28 for explicit legacy gallery export |
| No network code exists | dependencies are `intl`, `image_picker`, `shared_preferences` — no HTTP client, no analytics |
| The photo never leaves the device | the engine reads a local path and writes a local path; the channel has no other data source |
| No fake AI | the restoration tool only renders when the bundled model is present; the classical path is labelled "Fast enhancement / Classical enhancement" |

---

## 8. Installation (exact)

1. Open the CI run for the latest commit on
   `arena/f490bcd4-pixora` → **Actions** → **Android build** → the run whose
   *Build debug APK* job is green.
2. Download the artifact **`pixora-debug-apk`** (163.8 MiB) and unzip it once —
   it contains `app-debug.apk`.
3. On the phone: **Settings → About phone → tap MIUI version 7×** to enable
   developer options, then **Settings → Additional settings → Developer options →
   USB debugging**.
4. Connect by USB, then:

```bash
adb devices                              # the phone must appear as "device"
adb install -r app-debug.apk             # or: adb install -r <path>/app-debug.apk
```

5. If MIUI blocks the install: allow **"Install via USB"** in Developer options
   (it may require a Xiaomi account sign-in and mobile data on some MIUI builds).
6. Launch **PIXORA** → *Choose a photo* → pick a small old photo →
   **Restore with AI**.

There is no model download and no first-run setup: the network is never used.

---

## 9. What to test on the device (fills the open gate)

| Check | Expected |
| --- | --- |
| 640×480 photo, first run | completes in ≤ 90 s, progress bar advances per tile, ETA counts down |
| the same photo, second run | similar time (no thermal cliff), no ANR dialog |
| Cancel at ~50 % | stops within one tile, result is "Cancelled", no file left behind |
| A 12 MP phone photo | **Fast enhancement** path, UI states the working size |
| Result dimensions | exactly ×4 of the working size, aspect ratio preserved |
| Portrait photo with EXIF rotation | result is upright |
| History tab | contains the result after processing |
| Airplane mode, whole flow | works identically (proves offline) |
| `adb shell dumpsys meminfo com.pixora.app` | no OOM, no runaway growth |

---

## 10. Reproducing everything

```bash
# model pipeline (writes the artefact + report, enforces every gate)
python tool/convert_model.py \
  --out android/app/src/main/assets/models/realesr_general_x4v3_fp32.tflite \
  --report models/report.json

# app
flutter analyze && flutter test
flutter build apk --debug
```

CI does exactly this; the model job runs first, and the APK job refuses to build
without a verified artefact whose SHA-256 matches `models/report.json`.
