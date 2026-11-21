# PIXORA — Phase 02, Step 1: AI Restoration Engine Feasibility Audit

**Status:** audit only. **No application code was changed.** Phase 01 is intact
(72/72 tests, CI green on `ecac55e`). Phase 02 implementation has **not** started.

**Verdict in one line:** the only realistic candidate for a Redmi 9 is
**Real-ESRGAN `realesr-general-x4v3` (SRVGGNetCompact)** — 1.21 M parameters,
4.88 MB official weights, BSD-3-Clause, already proven to convert to LiteRT —
run **tiled on CPU through LiteRT** and **bundled in the APK**, with the AI path
**capped to small working resolutions**, because the binding constraint on this
hardware is *compute time, not memory*.

---

## 0. How to read this document — evidence legend

Every claim is tagged. Nothing is presented as measured unless it was measured.

| Tag | Meaning |
| --- | --- |
| ✅ **verified** | I checked it myself in this session: GitHub API metadata, repository source, PyPI, publisher documentation. Reproduce it with the commands in §13. |
| 📄 **published** | A number published by the model author / Google / Qualcomm / a hardware database, with a link. Not measured by me. |
| ⚠️ **estimate** | Arithmetic I performed from the published numbers, with the formula shown. **Must be replaced by an on-device measurement before it is shown to any user.** |

**What I could not do, and why it matters:**

* No Redmi 9, no emulator, no `adb` in this environment. Every performance
  number below is therefore *derived*, never observed on the target device.
* Binary downloads from GitHub Releases and Hugging Face are blocked in this
  sandbox (only `github.com`'s API and `pypi.org` answered). Weight **sizes and
  download URLs** come from the GitHub Releases API — authoritative metadata —
  but I could not run the weights locally.
* `pub.dev` and Maven Central are unreachable here. Dependency versions must be
  resolved by CI (GitHub Actions has full network), which is already how this
  project builds.

---

## 1. Executive decision

| Question | Decision |
| --- | --- |
| **Recommended model** | Real-ESRGAN **`realesr-general-x4v3`** (SRVGGNetCompact), x4 |
| **Weights** | 4,885,111 bytes (4.66 MiB), BSD-3-Clause, official release |
| **Runtime** | **LiteRT** (`com.google.ai.edge.litert`), Kotlin, CPU/XNNPACK; GPU attempted once behind a self-check |
| **Execution** | **Tiled**, 128×128 tiles, halo + feathered blending (mandatory) |
| **Distribution** | **Bundled in the APK** (no download, no network permission) |
| **Feature scope** | AI path for small/medium working resolutions; classical path for everything else |
| **Face restoration (GFPGAN/CodeFormer)** | **Deferred / rejected** — CodeFormer is non-commercial, GFPGAN is ~348 MB |
| **Phase 02 deliverable** | One genuinely-AI tool ("Old Photo Restoration") + Smart AI Engine v1 + classical enhancement — not eight |

---

## 2. Where the engine plugs into PIXORA

The Phase 01 architecture was designed for exactly this, and it needs **no
restructuring** — only new implementations behind existing seams. ✅ verified in
the repository.

| Seam | File | Current state | Phase 02 use |
| --- | --- | --- | --- |
| `PixoraImageProcessor` | `lib/features/image_engine/interfaces/image_processor.dart` | interface only | every engine implements it |
| `ImageRestorationService` | `.../interfaces/image_restoration_service.dart` | interface, doc already says "Real-ESRGAN style … LiteRT" | the recommended model lands **here** |
| `ImageEnhancementService` | `.../interfaces/image_enhancement_service.dart` | interface | classical pipeline (no model) |
| `ModelSpec` / `InferenceBackend` | `.../models/model_spec.dart` | has `liteRt`, `onnxRuntime`, `nativeAlgorithm`; `ModelAvailability.bundled/downloadable` | flip `real_esrgan_general` from `planned` to `bundled` **only** after the benchmark gate |
| `ModelRegistry` | `.../services/model_registry.dart` | 6 planned specs, sizes deliberately `null` | add verified size/hash once the artifact exists |
| `ImageEngineRegistry` | `.../services/image_engine_registry.dart` | `.empty()` — nothing can be called | becomes the single switch that lights up the UI |
| `DeviceCapabilityProfiler` | `.../services/device_capability_profiler.dart` | throws `UnsupportedError` on purpose | becomes real: RAM, cores, accelerator self-check |
| `DeviceCapabilityProfile` | `.../models/device_capability_profile.dart` | shape defined, `imageMemoryBudgetBytes = 35% of free RAM` | drives tile size / model variant / refuse-to-run |
| `ImageProcessingRequest` | `.../models/image_processing_request.dart` | `sourcePath`, `tool`, `options`, `maxOutputDimension` | `maxOutputDimension` is exactly the cap the hardware needs |
| Composition root | `lib/app/bootstrap.dart` | builds services before the first frame | constructs the processor; no UI change needed |
| Native side | `android/app/src/main/kotlin/com/pixora/app/MainActivity.kt` | bare `FlutterActivity` | host of a `MethodChannel` + the LiteRT module |

**The one architectural addition** the audit recommends: inference lives in
**Kotlin**, behind a `MethodChannel`, not in Dart. Reasons, in order:

1. **Memory control.** Android's `BitmapRegionDecoder` decodes *one tile at a
   time* straight from the JPEG/PNG file. Dart-side plugins must decode the whole
   bitmap first — a 12 MP photo is 48 MB of ARGB_8888 before any AI work starts.
2. **No megabyte buffers over the channel.** Only paths and small progress
   messages cross the platform boundary; a 2048×2048 RGBA frame would otherwise
   be copied twice (≈16 MB per copy).
3. **Access to the current API.** Google's LiteRT README (2026) states new code
   **must** use the Compiled-Model API and **must not** start new work on the
   legacy `Interpreter` (`org.tensorflow.lite.Interpreter` is in maintenance
   mode). ✅ verified in `google-ai-edge/LiteRT/README.md`.
4. Kotlin + `flutter` Gradle plugin are already in the project — no new build
   system, no new ABI concerns beyond the `arm64-v8a`/`armeabi-v7a` split that
   Flutter already produces.

Dart then holds a thin adapter:

```
ImageRestorationService  ←  LiteRtRestorationProcessor (Dart)
                              └─ MethodChannel("pixora/engine")
                                    └─ SuperResolutionEngine.kt  →  LiteRT
```

---

## 3. Candidate models — evidence table

Sizes are exact bytes from the publishers' release metadata (✅ verified), not
rounded marketing numbers.

| # | Model | Weights available | Size | License | Params | TFLite/LiteRT path | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **1** | **Real-ESRGAN `realesr-general-x4v3`** (SRVGGNetCompact) | ✅ official `.pth`, GitHub release `v0.2.5.0` | **4,885,111 B (4.66 MiB)** | **BSD-3-Clause** | 1.21 M | ✅ proven: Qualcomm AI Hub export, `litert-community` export, our own `litert-torch` conversion | **SELECTED** |
| 2 | Real-ESRGAN `RealESRGAN_x4plus` (RRDBNet 23 blocks) | ✅ official `.pth` | 63.94 MB | BSD-3-Clause | ~16.7 M | ✅ same lineage | Rejected for R9: 13× bigger, ~10× the compute per pixel |
| 3 | Real-ESRGAN `RealESRGAN_x2plus` | ✅ official `.pth` | 63.96 MB | BSD-3-Clause | ~16.7 M | ✅ | Rejected: same weight class as #2 |
| 4 | Real-ESRGAN `realesr-animevideov3` | ✅ official `.pth` | 2,504,012 B (2.39 MiB) | BSD-3-Clause | ~0.6 M | ✅ | Held for the **Anime Style** tool (Phase 04), not for photos |
| 5 | Real-CUGAN (2× SE) | ✅ in `bilibili/ailab/Real-CUGAN` | ~2.6 MB/model | **MIT** | ~1.5 M | ONNX path exists | Anime/illustration only → Phase 04 |
| 6 | SwinIR (light) | ✅ official | 2.5–11 MB | **Apache-2.0** | 0.9–3 M | ❌ attention/window ops convert badly; slow on CPU | Rejected |
| 7 | NAFNet (width 32) | ✅ official | ~270 MB fp32 | **MIT** | ~67 M | ❌ | Rejected: 60× too heavy |
| 8 | GFPGAN v1.4 | ✅ official | ~348 MB | Apache-2.0 **+ third-party components** (StyleGAN2/FFHQ, FFHQ is CC BY-NC-SA) | ~70 M | ❌ | Rejected: size + licence ambiguity |
| 9 | **CodeFormer** | ✅ official | ~360 MB | **S-Lab License 1.0 — non-commercial** ✅ verified verbatim | ~40 M | ❌ | **Excluded on licence grounds** — incompatible with an ad-supported public app |
| 10 | ESRGAN (TF Hub `captain-pool/esrgan-tf2`) | ✅ SavedModel | ~67 MB fp32 | Apache-2.0 | ~16.7 M | ✅ easiest (Google's own sample uses an `ESRGAN.tflite`) | Rejected: RRDB is 10× the compute of #1 |

**Why #9 and #8 matter:** the Phase 01 `ModelRegistry` lists `gfpgan_face` as a
planned model. That plan must change before Phase 04: **CodeFormer cannot be
used at all** (non-commercial), and GFPGAN's weights carry a training-data
provenance risk for a monetised app. Both are also far outside the Redmi 9's
memory class.

**Only #1 satisfies all five hard constraints**: real downloadable weights ✅,
BSD-3-Clause with commercial use ✅, small enough to bundle ✅, proven LiteRT
conversion ✅, and a compute profile that can be made usable by tiling ✅.

---

## 4. The recommended model, in engineering detail

### 4.1 Architecture ✅ verified from `realesrgan/archs/srvgg_arch.py`

```
conv(3→64, 3×3) → PReLU
× 32 : conv(64→64, 3×3) → PReLU          # the whole body runs at INPUT resolution
conv(64→48, 3×3) → PixelShuffle(×4)
```

Two consequences that decide the whole design:

1. **No convolution happens at output resolution.** An x4 upscale of a 128×128
   tile costs the same as a 1× restore of a 128×128 tile. The scale factor is
   free; the *input area* is what you pay for.
2. **Fully convolutional with a fixed 3×3 kernel** → tileable, and its receptive
   field is computable: 33 layers × 1 px = **33 px radius / 67 px window**. This
   is why tiling needs a halo (see §8).

### 4.2 Parameter and compute arithmetic ✅ derived from the verified architecture

```
conv_first   3·64·9                     =     1,728
body ×32    32 · 64·64·9                = 1,179,648
PReLU       32 · 64                     =     2,048   (scalar per channel)
conv_last   64·48·9                     =    27,648
                                     total ≈ 1,211,000  ≈ 1.21 M   ✅ matches the publisher's figure
```

MACs for one **128×128** tile:

```
conv_first 128·128·3·64·9     =  28.3 M MAC
body ×32   32 · 128·128·64·64·9 = 19.33 G MAC     ← 97 % of the cost
conv_last  128·128·64·48·9    = 453.0 M MAC
                            ≈ 19.8 GMAC  ≈ 39.6 GFLOP per tile (fp32)
```

Output per tile: **512×512**. That single number drives the entire product scope.

### 4.3 Conversion plan (both variants, produced by us)

| Variant | Graph | Purpose |
| --- | --- | --- |
| `realesr_general_x4v3_fp32.tflite` | stock ops (`PReLU`, `RESHAPE`/`PIXEL_SHUFFLE`) | CPU/XNNPACK path — the Redmi 9 default |
| `realesr_general_x4v3_gpu.tflite` *(optional)* | PReLU → `relu(x) − a·relu(−x)`; PixelShuffle → one-hot `Conv2D` | GPU-clean graph, only if a device's GPU wins the self-check |

The published `litert-community` card documents exactly this op-rewrite problem
and reports `corr = 1.000000` against the original graph after re-authoring ✅ —
i.e. the rewrite is lossless, not an approximation. 📄

Toolchain, all installable from PyPI ✅ verified in this session:
`litert-torch 0.10.0` (Google's official PyTorch→LiteRT converter),
`ai-edge-litert 2.3.0` (runtime for verification), `onnx 1.23.2` +
`onnx2tf 2.6.9` (fallback path), `tensorflow 2.21.0` (only if the ONNX path is used).

### 4.4 Numeric precision — a Redmi 9-specific trap

| Redmi 9 variant | CPU | FP16 arithmetic | INT8 dot-product |
| --- | --- | --- | --- |
| Global (Helio G80) | 2×Cortex-A75 + 6×A55 (ARMv8.2-A) | ✅ | ✅ (A75 has ARMv8.2 `SDOT`) |
| India / 9C-class (Helio G35) | 8×Cortex-A53 (ARMv8.0-A) | ❌ no half-precision arithmetic | ⚠️ decode path only |

→ **Ship fp32 first.** An fp16-weight file would silently fall back to fp32 on
the A53 variant (no speed-up, no benefit), and int8 quantisation of a
GAN-trained SR network is a *quality* risk that must be A/B-tested, not assumed.
int8 `w8a8` is a later optimisation (publisher lists 1.25 MB for that variant 📄).

---

## 5. Performance on the Redmi 9 — the honest arithmetic

### 5.1 Published anchors (measured by others, on hardware comparable in kind)

| Device / runtime | Per 128×128 tile | Source |
| --- | --- | --- |
| Raspberry Pi 5, CPU, 4 threads | **558 ms** median (555–603), peak RSS **213 MB** | 📄 `litert-community` model card |
| Pixel 8a, CPU XNNPACK 4 threads | **532 ms** | 📄 same card |
| Pixel 8a, GPU (classic `TfLiteGpuDelegateV2`, OpenCL) | 40.4 ms | 📄 same card |
| Pixel 8a, GPU (LiteRT `CompiledModel`, `LITERT_CL`) | ≈1 ms | 📄 same card |
| Qualcomm NPU devices (S23 Ultra …) | 2–35 ms | 📄 Qualcomm AI Hub — **irrelevant**: the Redmi 9 has no NPU |

Two very different CPUs landing at ~550 ms/tile tells us the graph is
**memory-bandwidth-bound**, which is good news for extrapolation: bandwidth is a
harder limit than raw FLOPs, and we know the Redmi 9's bandwidth (~13–15 GB/s
LPDDR4x) precisely.

### 5.2 Derived estimate for the target device ⚠️

Inputs: single-core performance ratio vs a Cortex-A76 (Pi 5) from Geekbench 6
single-core — Redmi 9 India **189**, Redmi 9 global **416**, A76-class ≈ 700–800
📄; 8 threads vs 4, discounted to ≈1.4× scaling because the workload is
bandwidth-bound.

| Device | Per tile (⚠️) | Per **megapixel of input** (⚠️, ≈61 tiles/MP) |
| --- | --- | --- |
| Redmi 9 **global** (G80 / Mali-G52) | 0.7 – 1.4 s | 43 – 85 s |
| Redmi 9 **India/9C** (G35 / PowerVR) | 1.3 – 2.8 s | 80 – 170 s |

### 5.3 What that means for the product (the core finding)

| Input size | Output at ×4 | Estimated time (India variant) | Verdict |
| --- | --- | --- | --- |
| 640×480 (0.31 MP) — *typical old photo* | 2560×1920 | **25 – 52 s** | ✅ viable |
| 800×600 (0.48 MP) | 3200×2400 | 38 – 82 s | ✅ viable with progress + cancel |
| 1000×750 (0.75 MP) | 4000×3000 | 60 – 128 s | ⚠️ borderline — cap output instead |
| 1280×960 (1.2 MP) | 5120×3840 | 96 – 204 s | ❌ too slow, output absurd |
| 4032×3024 (12 MP phone photo) | 192 MP | hours, and a pointless output | ❌ never |

**Conclusion — memory is not the problem, time is.** The engine must:

1. **Cap the working input** (~0.5–0.75 MP, e.g. fit into 900×900) — an old photo
   is small anyway, and a 12 MP modern photo gains nothing from ×4.
2. **Cap the output** (`ImageProcessingRequest.maxOutputDimension` already exists
   for this) at ~2560 px.
3. Show **progress + honest ETA + cancel**, hold `FLAG_KEEP_SCREEN_ON`, and never
   let MIUI's battery saver treat a 90 s job as an ANR (work on a background
   thread, keep the UI responsive, report every tile).
4. Take the **classical path** for anything above the cap, and say so in the UI
   ("photo is large — applying fast enhancement"; not a lie, not a fake AI claim).

That is the difference between a feature that ships and a feature that gets
one-star reviews.

---

## 6. RAM analysis and Redmi 9 compatibility

### 6.1 Memory budget ⚠️ (component arithmetic; must be measured)

| Component | Estimate | Note |
| --- | --- | --- |
| `.tflite` weights (mmap'd, fp32) | 4.9 MB | mapped, shared, evictable |
| Interpreter activation arena | 20 – 40 MB | 128²×64×4 B per buffer ≈ 4.2 MB, ~4–6 live buffers |
| One decoded tile | ~0.25 MB | `BitmapRegionDecoder` in `RGB_565`/`ARGB_8888` |
| Output canvas (2560² ARGB_8888) | 26 MB | the ceiling we set |
| Flutter engine + UI | 150 – 250 MB | measured empirically on similar devices |
| **Peak marginal cost of the AI path** | **≈ 60–90 MB** | |

The published 213 MB peak for the *whole* runner process on a Pi 5 is the
conservative upper bound 📄. **Neither Redmi 9 variant (3/4 GB, or 2 GB on the
9C-class) is at risk of OOM** if tiles are decoded region-wise and the output is
capped. This is the opposite of the usual low-end AI failure mode, and it is why
this model is the right choice.

### 6.2 Two different phones called "Redmi 9" — the single biggest unknown

| | Redmi 9 (global) | Redmi 9 (India) = 9C-class |
| --- | --- | --- |
| SoC | MediaTek **Helio G80** (12 nm) | MediaTek **Helio G35** (12 nm) |
| CPU | 2×A75 @2.0 + 6×A55 @1.8 | 8×A53 @2.3/1.8 |
| GPU | **Mali-G52 MC2**, OpenCL 2.0 | **PowerVR GE8320** @650–680 MHz, OpenCL 1.2 |
| RAM | 3 / 4 / 6 GB | 4 / 6 GB (9C: 2 / 3 GB) |
| OS | Android 10 / MIUI 11–12 | Android 10 / MIUI 12 |
| Geekbench 6 SC | 416 | 189 |

📄 GSMArena, XDA, versus.com.

This matters because:
* The **G80/Mali** device is ~2× faster and has a GPU the LiteRT GPU delegate is
  far more likely to support.
* The **G35/PowerVR** device is the worst case, has no FP16 arithmetic, and its
  GPU is (a) weaker than its CPU and (b) a known source of silent wrong-output
  bugs in GPU delegates.

→ **Ask:** please confirm from *Settings → About phone* whether the test device
is the Helio G80 or the Helio G35 variant. The plan below is written for the G35
worst case; on the G80 it will simply be ~2× faster and the caps can be relaxed.

### 6.3 GPU acceleration on the target — position

Do **not** assume the GPU helps. On PowerVR GE8320 it very likely does not, and a
GPU delegate that produces a plausible-but-wrong image is worse than no GPU at
all. Phase 02 will therefore:

1. Try the accelerator **once**, on the first run, with a **self-check**: run one
   fixed tile on the accelerator and on the CPU, compare (the published card uses
   correlation ≈0.995 as the reference-agreement threshold 📄). Require ≥0.99.
2. Persist the result in preferences; never retry a failing accelerator on that
   device.
3. Log it (developer-visible) so a user report like "photos come out grey" has an
   immediate answer.

This is exactly the job the Phase 01 `DeviceCapabilityProfiler` was created for,
and `DeviceCapabilityProfile.supportsGpuAcceleration` already has the field.

---

## 7. Recommended runtime: LiteRT (CPU/XNNPACK first)

| Criterion | LiteRT | ONNX Runtime Mobile | ncnn / Vulkan | TFLite (legacy) |
| --- | --- | --- | --- | --- |
| First-party Android support in 2026 | ✅ Google, releases v2.3.2 (Oct 2026) ✅ | ✅ Microsoft | ⚠️ community | ⛔ maintenance mode (Google's own words ✅) |
| Kotlin API | ✅ `CompiledModel` + Java `Interpreter` | ✅ | C++/JNI only | ✅ |
| CPU backend quality on A53/A75 | ✅ XNNPACK | ✅ | ✅ | ✅ |
| GPU on PowerVR GE8320 | ⚠️ auto-fallback, unproven on this GPU | ⚠️ | ⚠️ Vulkan 1.0, unproven | ❌ delegate is legacy |
| Convert from PyTorch | ✅ `litert-torch` (official) | ✅ via ONNX | ✅ via ONNX | ✅ |
| Sample code for **super-resolution specifically** | ✅ `litert-samples/samples/litert_interpreter/super_resolution` ✅ | — | — | (same sample, older API) |

Maven coordinates ✅ verified from the official sample's version catalog:
`com.google.ai.edge.litert:litert`, `:litert-support`, `:litert-metadata`
(and `:litert-api` for the Compiled-Model API). The sample uses `minSdk = 24`;
PIXORA is already on Flutter's `minSdk = 24` ✅ (`FlutterExtension.kt` @ 3.50.0),
and the Redmi 9 runs Android 10, so no minimum-API problem.

**Decision:** LiteRT, Kotlin, **CPU/XNNPACK as the baseline**, GPU as an opt-in
after a self-check. ONNX Runtime stays as the documented fallback in
`InferenceBackend.onnxRuntime` if LiteRT conversion ever blocks us — the interface
already supports it.

> Note on the `Interpreter` vs `CompiledModel` question: Google's 2026 guidance
> says new code must use `CompiledModel`, but the only official SR sample uses the
> legacy `Interpreter`. Phase 02 will start with `CompiledModel` on the CPU
> accelerator and keep the `Interpreter` path behind the same Kotlin class if the
> older API turns out to be the more stable one on Android 10/MIUI 12. This is a
> build-time decision, not an architecture change.

---

## 8. Tiled processing — mandatory, and here is the design

**Yes, tiling is required.** Three independent reasons:

1. The model is exported with a **fixed 128×128 input** (that is the shape the
   publishers validate and benchmark 📄).
2. Whole-image inference would allocate activations proportional to the *image*
   area — a 4 MP photo would need multiple gigabytes.
3. A fixed tile gives a **constant** per-step cost, which is what makes an honest
   progress bar and a cancel button possible at all.

**Design:**

```
for each tile position (stride = 128 − 2·halo):
    decode 128×128 RGB from the source file via BitmapRegionDecoder
    normalise to [0,1] float
    run LiteRT               → 512×512 float
    crop the invalid border (halo × 4)
    composite into the output bitmap with a feathered (cosine) alpha mask
report progress after every tile  →  user-visible ETA
check cancellation between tiles, never inside a run
```

* **Halo.** The receptive field radius is 33 px (§4.1). Halo **16 px** with
  feathered blending is the fast default; **32 px** is the quality option for
  "restoration" mode. Measured seam quality on three sample photos is a Phase 02
  acceptance criterion, because this is exactly the kind of thing that looks fine
  in a summary and terrible on a face.
* **Edge tiles** are padded by *mirroring* rather than black — black borders
  produce visible darkening on every photo edge.
* **Region decoding** (`BitmapRegionDecoder`) keeps the source image out of RAM
  entirely; this is the reason for the Kotlin design in §2.
* **Determinism:** the same photo + same mode must produce byte-identical output
  on repeated runs (needed for golden-image tests).

---

## 9. Bundle or download? → **Bundle**

This is not really a size question; it is a **privacy-contract** question.

| Option | Verdict |
| --- | --- |
| **Bundle the 4.66 MiB model in `assets/`** | ✅ **Chosen.** Works forever offline, first run has no waiting, zero download code, and — decisively — the app keeps **no `INTERNET` permission in its main manifest**, which is what makes "PIXORA cannot upload your photos" a *verifiable claim* rather than a promise ✅ (`android/app/src/main/AndroidManifest.xml` declares no permissions; `INTERNET` exists only in the debug/profile manifests). |
| Download on first use | ❌ Would require adding `INTERNET`, a downloader, integrity checking, storage management, resumable state, error UX and a new privacy statement — to save 4.66 MB. |
| Download a *larger* model later (face restoration) | ⏸ Deferred to a future phase, and it would need a visible, explicit, user-initiated design — plus a privacy-policy change. |

APK impact: **+4.66 MB** on a debug APK that is already 76.95 MB, plus the LiteRT
native libraries (~4–6 MB per ABI; Flutter release AABs are split per ABI, so
each download grows by roughly 5–8 MB). Acceptable.

---

## 10. Licence summary

| Model / asset | Licence | Commercial use | Obligation |
| --- | --- | --- | --- |
| Real-ESRGAN code + official weights | **BSD-3-Clause** ✅ | ✅ | retain copyright notice + licence text (add `THIRD_PARTY_NOTICES.md` in Phase 02) |
| Real-CUGAN | MIT ✅ | ✅ | same |
| SwinIR / BasicSR | Apache-2.0 ✅ | ✅ | NOTICE file |
| NAFNet | MIT ✅ | ✅ | — |
| GFPGAN code | Apache-2.0, **except third-party components** ✅ | ⚠️ | StyleGAN2/FFHQ provenance; audit before any use |
| **CodeFormer** | **S-Lab License 1.0 — "for non-commercial purpose"** ✅ | ❌ | **must not ship** |
| Qualcomm AI Hub pre-exported `.tflite` | model card points to a **placeholder** deploy-licence URL ✅ | ⚠️ unclear | do not depend on it |
| LiteRT runtime | Apache-2.0 ✅ | ✅ | NOTICE file |

**Decision:** convert the model **ourselves** from the official BSD-3-Clause
weights. Then the only licence that applies to the artifact we ship is
BSD-3-Clause — no third-party asset terms, no ambiguity, fully reproducible
(SHA-256 recorded in the repo).

---

## 11. Main technical risks and mitigations

| # | Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- | --- |
| R1 | Too slow on the G35 variant (2 min for one photo) | **High** | Product feels broken | hard input/output caps (§5.3), honest ETA, cancel, classical fallback; benchmark gate before shipping |
| R2 | Thermal throttling / battery drain on a 90 s job | High | Device gets hot, MIUI kills us | per-tile budget, thermal check via `PowerManager` thermal status where available, warn above a threshold, never run in a service |
| R3 | GPU delegate produces silently wrong output on PowerVR | Medium | Corrupt-looking results, no crash | one-time self-check with a reference tile (§6.3), correlation ≥0.99, persist the verdict |
| R4 | Visible tile seams | Medium | Looks amateurish | halo + cosine blending, mirror padding, seam QA on real photos, 32 px halo in "restoration" mode |
| R5 | Quality does not match the "AI restoration" expectation | Medium | Trust damage | fixed sample set + before/after on device; copy that describes what it does, not what it might do |
| R6 | OOM on a 2 GB 9C-class device | Low | Crash | region decoding, capped output, `DeviceCapabilityProfile.imageMemoryBudgetBytes` gate, refuse politely instead of dying |
| R7 | Conversion drift / non-reproducible artifacts | Medium | Can't rebuild the app in a year | conversion script + pinned versions + SHA-256 checked into the repo, CI job that re-runs the check |
| R8 | Licence contamination (CodeFormer/GFPGAN) | Low but severe | Legal takedown | §10; `THIRD_PARTY_NOTICES.md`; no non-commercial weights anywhere in `assets/` |
| R9 | Platform-channel overhead | Low | Jank on large frames | only paths/progress cross the channel; bitmaps stay native |
| R10 | Overstating "AI" in the store listing / UI | Medium | Policy + trust risk | one tool is labelled AI *because it runs a network*; the classical path is labelled "Fast enhancement" |
| R11 | MIUI background restrictions killing a long job | Medium | Partial output | run in the foreground with `FLAG_KEEP_SCREEN_ON`, write output atomically, resume-from-scratch (documented) |

---

## 12. Phase 02 implementation plan (after approval — **not** started)

Ordered, each step with a pass/fail gate. Nothing here is implemented yet.

### Step 2 — Model acquisition and conversion *(repo: `tool/convert_model.py`, `assets/models/`, `models/CHECKSUMS.txt`)*
Python 3.11 venv; `torch` (CPU), `litert-torch`, `ai-edge-litert`, pinned;
download `realesr-general-x4v3.pth` from the official release, verify SHA-256,
trace and convert to `realesr_general_x4v3_fp32.tflite` (fixed 128×128 in,
512×512 out, NHWC, float32 0–1).
**Gate G1:** the `.tflite` runs under `ai-edge-litert` on a fixture and matches the
PyTorch reference with **correlation ≥ 0.995** and max abs error ≤ 2/255. Record
exact file size + SHA-256 in the repo. *(Expected ≈ 4.9 MB fp32.)*

### Step 3 — Native LiteRT engine *(new: `android/app/src/main/kotlin/com/pixora/app/engine/`)*
`SuperResolutionEngine.kt`: model load (mmap from assets), tiled runner,
`BitmapRegionDecoder`, halo + cosine blend, progress events, cancellation,
`FLAG_KEEP_SCREEN_ON`, accelerator self-check, thermal guard.
**Gate G2:** a debug-only harness processes a fixed 640×480 photo end-to-end in
**≤ 90 s** on the target device, twice in a row, without ANR and without OOM.

### Step 4 — Dart adapter + registry *(edit: `lib/features/image_engine/...`, `lib/app/bootstrap.dart`)*
`LiteRtRestorationProcessor implements ImageRestorationService` (MethodChannel
`pixora/engine`); register in `ImageEngineRegistry`; flip
`ModelRegistry.real_esrgan_general` to `bundled` **only after G2**.
**Gate G3:** `flutter analyze` clean; unit tests for tiling math, blending
weights, request validation and cancellation are green; the UI still shows
"coming soon" for every tool until G2 *and* G4 pass.

### Step 5 — Smart AI Engine v1 *(implement `DeviceCapabilityProfiler` for real)*
`ActivityManager.MemoryInfo` (total/available RAM, `isLowRamDevice`), CPU cores
and max frequency, accelerator self-check result, thermal status → choose
{tile/halo profile, max input, max output, AI vs classical}. Replace the
`UnsupportedError` placeholder with a real implementation **and keep the existing
test that asserts no invented numbers**.

### Step 6 — Device benchmark harness *(new: debug-only route or `adb`-driven script)*
Fixed set: 1 small (640×480), 1 medium (1000×750), 1 large (12 MP), 1 low-quality
scan, 1 portrait. Record per-tile latency, total time, peak RSS, thermal state,
battery delta, before/after images. **Publish the table in `docs/`.**

### Step 7 — Product surface *(edit: `lib/features/image_picker/`, `home`, `history`)*
Processing screen with real progress, ETA, cancel, "runs entirely on your device"
reassurance; before/after comparison; save to a local output file; history entry
with model id + duration (the `ImageProcessingResult` fields already exist);
localised in EN/AR/FR.

### Step 8 — Classical enhancement path *(no model)*
Unsharp mask, contrast/levels, mild denoise, JPEG-artefact smoothing in Kotlin,
available on **every** device and mandatory as the fallback. Labelled honestly
("Fast enhancement", not "AI").

### Step 9 — Tests, CI, docs
Unit + widget tests (progress, cancel, failure, RTL, dark mode), a golden-image
regression on tiny fixtures, a CI step that verifies model SHA-256 and that no
non-BSD weights are in `assets/`, and a device retest checklist in `docs/`.

### Explicitly **out of scope** for Phase 02
Face restoration, colourisation, anime/artistic styles, pixel art, AdMob,
subscriptions, any network call, any model download, Phase 03 profiling work.

### Definition of done for Phase 02
A user on a Redmi 9 picks a small/medium photo, taps **Old Photo Restoration**,
sees honest progress for under two minutes, gets a visibly improved local file,
the app never asks for a permission, never touches the network, and the same
photo on a 6 GB phone finishes faster **without any change in the UI**.

---

## 13. Reproducing the evidence

```bash
# exact weight sizes + download URLs
gh api repos/xinntao/Real-ESRGAN/releases/tags/v0.2.5.0 \
  --jq '.assets[] | "\(.name) \(.size) \(.browser_download_url)"'

# licence
gh api repos/xinntao/Real-ESRGAN/license --jq '.license.spdx_id'      # BSD-3-Clause

# architecture (32 body convs, 3x3, PixelShuffle last)
gh api repos/xinntao/Real-ESRGAN/contents/realesrgan/archs/srvgg_arch.py \
  --jq .content | base64 -d | sed -n '20,60p'

# non-commercial licence that excludes CodeFormer
gh api repos/sczhou/CodeFormer/license --jq .content | base64 -d | head -8

# Google's own LiteRT super-resolution sample (Kotlin, ESRGAN.tflite)
gh api repos/google-ai-edge/litert-samples/contents/samples/litert_interpreter/super_resolution

# official maven coordinates used by that sample
gh api repos/google-ai-edge/litert-samples/contents/samples/litert_interpreter/super_resolution/android/gradle/libs.versions.toml \
  --jq .content | base64 -d | grep -i litert

# conversion toolchain versions
curl -s https://pypi.org/pypi/litert-torch/json     | jq -r .info.version    # 0.10.0
curl -s https://pypi.org/pypi/ai-edge-litert/json   | jq -r .info.version    # 2.3.0
```

---

## 14. Sources

| What | Link |
| --- | --- |
| Real-ESRGAN repository (BSD-3-Clause) | https://github.com/xinntao/Real-ESRGAN |
| Real-ESRGAN weights, release `v0.2.5.0` | https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.5.0 |
| Real-ESRGAN paper | https://arxiv.org/abs/2107.10833 |
| `SRVGGNetCompact` source | https://github.com/xinntao/Real-ESRGAN/blob/master/realesrgan/archs/srvgg_arch.py |
| Qualcomm AI Hub — Real-ESRGAN general x4v3 (params, sizes, per-device latency) | https://huggingface.co/qualcomm/Real-ESRGAN-General-x4v3 · https://aihub.qualcomm.com/models/real_esrgan_general_x4v3 |
| LiteRT-ready x4v3 with CPU/GPU benchmarks + Peak memory | https://huggingface.co/litert-community/real-esrgan-x4v3-litert |
| Google LiteRT (repo, releases v2.3.2, API guidance) | https://github.com/google-ai-edge/LiteRT |
| Google LiteRT samples — super resolution (Kotlin) | https://github.com/google-ai-edge/litert-samples/tree/main/samples/litert_interpreter/super_resolution |
| `litert-torch` / `ai-edge-litert` | https://pypi.org/project/litert-torch/ · https://pypi.org/project/ai-edge-litert/ |
| TF blog: TFLite super-resolution on Android | https://blog.tensorflow.org/2020/12/how-to-generate-super-resolution-images-using-tensorflow-lite-on-android.html |
| Real-CUGAN (MIT, anime) | https://github.com/bilibili/ailab/tree/main/Real-CUGAN |
| SwinIR (Apache-2.0) | https://github.com/JingyunLiang/SwinIR |
| NAFNet (MIT) | https://github.com/megvii-research/NAFNet |
| GFPGAN (Apache-2.0 + third-party) | https://github.com/TencentARC/GFPGAN |
| CodeFormer (S-Lab 1.0, **non-commercial**) | https://github.com/sczhou/CodeFormer |
| Redmi 9 (India) specifications | https://www.gsmarena.com/xiaomi_redmi_9_(india)-10398.php |
| Redmi 9 global (G80/Mali-G52) vs India (G35/PowerVR) | https://versus.com/en/xiaomi-redmi-9-vs-xiaomi-redmi-9-india |
| Redmi 9 launch / SoC confirmation | https://www.xda-developers.com/xiaomi-redmi-9-mediatek-helio-g35-5000mah-battery-launched-india/ |

---

## 15. Open questions — please confirm before Step 2

1. **Which Redmi 9?** Helio **G80/Mali-G52** (global) or Helio **G35/PowerVR**
   (India/9C-class)? It is a ~2× difference and it decides whether the GPU is
   ever worth trying. *(Settings → About phone → Processor.)*
2. **Time budget:** is up to **90 s** for a small photo acceptable if the UI is
   honest about it (progress + cancel), or must the target be ≤ 30 s (which
   implies a smaller working resolution and less visible gain)?
3. **Output ceiling:** is 2560 px on the long edge the right cap, or would you
   rather have a 2048 px cap with faster runs?
4. **Naming:** confirm that the AI tool is called *"Old Photo Restoration"* while
   the non-AI one is *"Fast enhancement"* — no "AI" label on the classical path.
5. **Attribution:** OK to add `THIRD_PARTY_NOTICES.md` (BSD-3-Clause text) and
   surface it from Settings → About → Open-source licences (the licence page
   already exists)?

**Waiting for approval before any of §12 is implemented.**
