# PIXORA critical restoration investigation

**Status: failure acknowledged; not fixed. No replacement restoration model has been validated or adopted.** This report is committed before the next CI APK build. The supplied Redmi 9 photo, result file, screenshot, and matching device logs are not present in this checkout, so claims about those exact bytes would be invented.

## 1. Root cause: what is known vs not known

### Leading, source-supported cause: wrong model capability for the requested damage

PIXORA currently runs Real-ESRGAN `realesr-general-x4v3` (SRVGGNetCompact). It is a 4× general super-resolution/enhancement network, not a scratch detector, mask predictor, or inpainting/reconstruction model. It has no damage mask input. It is not designed to remove extensive scratches/stains or reconstruct missing emulsion. Severe visible damage remaining is therefore consistent with a **model capability mismatch** and is the leading product root cause. “Inference completed” is not evidence that damage was removed.

### Pipeline/display faults cannot be ruled out for the reported device run yet

No original, output, screenshot, model tensor dump, or Redmi logcat from that run exists here. Thus the exact physical-run root cause is **not yet proven** to be capability-only. Source audit shows these intended connections:

| Stage | Source evidence / contract | Exact physical image evidence |
| --- | --- | --- |
| A. Original decode | `SuperResolutionEngine` reads request `sourcePath`, checks encoded bounds, applies EXIF orientations 1–8, chooses a working size, and decodes/scales that source. | Not available. New debug trace records source byte length/SHA-256, encoded bounds, EXIF orientation, and oriented working-pixel dimensions/hash/RGB range/means. |
| B. LiteRT input | `ModelMeta` declares 128×128 RGB float32; shipped contract is NCHW, normalized to 0..1. `RgbTensorCodec` reads Android ARGB as R,G,B and writes the declared tensor layout/range. Runtime checks actual LiteRT shape and float32 type. | Not available. Debug trace records a rolling SHA-256, count/min/max/mean over all input tile float values and preserves the first input tile as little-endian float32. |
| C. Raw model output | `LiteRtRunner.runTile()` copies LiteRT output floats before `composeTile` converts them to pixels. | Not available. Debug trace records the pre-postprocess float output rolling SHA-256/count/min/max/mean over every tile and saves the first raw output tile before conversion as little-endian float32. This is the raw tensor, not a filtered/reconstructed image. |
| D. Conversion / encoding | `RgbTensorCodec.outputPixel` reads RGB by NCHW/NHWC contract, maps recorded value range to 8-bit RGB and clamps. Kotlin composes ARGB pixels and JPEG-encodes at configured quality. | Not available. Debug trace records the stitched pre-JPEG bitmap hash/dimensions/RGB summary and final JPEG length/SHA-256/dimensions. The tensor input/output byte dumps can be pulled only from the debug app’s private cache with `run-as`; no photo is uploaded. |
| E. Tiles | `TilePlan` partitions each output coordinate into one owner; native tests cover tile bounds/coverage. `composeTile` crops the halo and writes only that partition. | Native coverage tests pass in last recorded CI. That is an arithmetic test, not a measured seam/quality check on a real model output. |
| F. Result path | Native outcome returns the produced output file path to the processor; the success view uses `result.outputPath` for the result side. History comparison uses `entry.imagePath`. | No user run files to hash. New regression checks `BeforeAfterView.afterPath == processor outputPath` and `beforePath == picked sourcePath`, and asserts they differ. |
| G. Comparison sources | `BeforeAfterView` paints `afterPath` as the background/result and `beforePath` as the clipped original. | New widget test records the two actual builder calls and requires the two distinct expected paths. The widget now asserts against identical path strings in debug/test builds. |

The source-level A–G wiring is internally consistent; that does not establish that the reported app build, path contents, or model outputs were correct. The new trace is intended to settle this on the next debug Redmi run.

## 2. Is model output meaningfully different?

**Unknown for the reported photo.** Neither input nor output bytes from the Redmi 9 were supplied. The CI converter report shows the converted network is not a pure bicubic pass-through on its synthetic checker/noise/detail fixtures (reported mean absolute change vs bicubic roughly 0.1055–0.1346 on normalized 0..1 data). That is a conversion/nontrivial-output check, not evidence of scratch removal, and does not quantify the Redmi result against its original.

## 3. Correct comparison path and regression protection

The intended result path is the engine's newly created JPEG; History keeps that result path separate from its private copy of the untouched original. The success screen's source code passes distinct arguments. Added regressions:

- processing completion must wire the picked source and processor's exact output path into the comparison;
- the comparison's image builder must receive both paths and they must be distinct;
- same before/after path strings are rejected by a debug assertion;
- History comparison reopens its archived source and stored result separately.

These tests protect against a future path-wiring regression. They do not inspect the absent device artifact.

## 4. Controlled synthetic benchmark (actual results, baseline only)

A reproducible procedural 640×480 test chart plus exact clean reference and four artificial degradations is in `test/fixtures/restoration_benchmark/`. It is deliberately a **synthetic chart, not a photograph**. Generate/score with:

```bash
python -m pip install -r tool/requirements-image-audit.txt
python tool/benchmark_synthetic_restoration.py
# After actually running a model, put its outputs at <outputs>/{scratches,stains,faded,severe}.png:
python tool/benchmark_synthetic_restoration.py --outputs <outputs>
```

The checked-in JSON contains fixed image/mask SHA-256 values and baseline quality versus the clean synthetic reference. These are measured degradation baselines; model-output rows say NOT_RUN rather than fabricating a restored output.

| Synthetic degradation | Mask area | No-op damage-region MAE (0–1) | No-op full-image MAE (0–1) | No-op PSNR (dB) | No-op SSIM |
| --- | ---: | ---: | ---: | ---: | ---: |
| Scratches | 2.41% | 0.29869 | 0.00719 | 24.32 | 0.93418 |
| Stains | 3.96% | 0.17769 | 0.00704 | 27.30 | 0.97229 |
| Fading | 100.00% | 0.11085 | 0.11085 | 17.81 | 0.93957 |
| Severe: scratches, stains, missing patch | 12.69% | 0.18735 | 0.02378 | 20.91 | 0.85881 |

Reference SHA-256: `949da4748255a17455b5260db4c3e7820e912dc475c99fbf0a8a135ac48650ef`. Input hashes are in `benchmark.json`. The report keeps damage-region error reduction separate from whole-image quality and records original output dimensions independently; outputs are resampled to the reference canvas only for damage comparisons. MAE/PSNR/SSIM are not perceptual-quality guarantees. No restored-output metrics, restoration percentage, or “80% improvement” claim is made because no real model output has been run against this benchmark.

There is no same-image before/raw/final AI comparison to show yet. The checked-in image set is clean reference + synthetic damaged inputs/masks only; I will not label a no-op or filter image as AI restoration.

## 5. Candidate model/licence/runtime assessment

| Candidate | Relevant capability | Licence / weight evidence | Android / Redmi 9 status | Decision |
| --- | --- | --- | --- | --- |
| Real-ESRGAN `realesr-general-x4v3` | General SR/enhancement; no explicit damage mask or scratch inpainting | BSD-3-Clause; official weights 4,885,111 B; converted TFLite 4,910,280 B | Current bundled LiteRT CPU/XNNPACK path. Conversion verified; Redmi result quality not independently audited. | Retain only as optional upscaling/general enhancement; **not** market or label it as scratch removal. |
| Microsoft Bringing Old Photos Back to Life | Dedicated structured/unstructured old-photo restoration and scratch pipeline; optional face enhancement module is out of PIXORA scope | Official repository says code and pretrained model are MIT; official v1.0 global weights zip 2,036,400,762 B and face weights zip 684,354,563 B. However, its maintenance section also says “for academic research use only”; commercial-use clearance is therefore unresolved despite MIT text. | Author documents Ubuntu/NVIDIA GPU/CUDA testing and says performance is not optimized; no verified LiteRT conversion, Android memory/runtime, or Redmi result. Repository is archived. | Most capability-relevant researched candidate, but not deployable on Redmi 9 as-is and not cleared for commercial use. Do not bundle without rights resolution. |
| `leonelhs/zeroscratches` | Fork/implementation wrapping Microsoft's scratch pipeline | GitHub presents MIT, while `setup.py` says Apache; Hugging Face model card does not provide an explicit weights licence in the page reviewed. Model assets are hosted separately; exact file inventory/checkpoint digests and commercial rights are not verified here. | PyTorch/torchvision/huggingface_hub code; no verified LiteRT/Android path or Redmi measurement. Secondary description says roughly 500 MB weights and ~1 GB RAM; treated as unverified. | Do not adopt until weight rights/size/digests and mobile runtime are independently confirmed. |

Primary sources reviewed: [Microsoft official README](https://github.com/microsoft/Bringing-Old-Photos-Back-to-Life) (MIT statement, academic-research-only maintenance note, CUDA testing instructions, and model download commands); [Zero Scratches repository](https://github.com/leonelhs/zeroscratches) and [its setup.py](https://github.com/leonelhs/zeroscratches/blob/main/setup.py) (MIT badge vs Apache package metadata); [Zero Scratches model card](https://huggingface.co/leonelhs/zeroscratches) (hosted separately; no explicit weights licence visible in the reviewed card).

The Microsoft candidate is a **research candidate, not an app recommendation**: it has relevant damage capability and MIT licensing stated by the official repository, but is multi-gigabyte, GPU-oriented, and not tested on Android; the simultaneous academic-research-only statement makes commercial rights uncertain. No candidate currently meets all commercial-licence, official-weight, mobile-runtime, size/RAM, offline, and Redmi CPU gates. A realistic next step is to run the official candidate through rights review, isolate its global scratch/global-restoration stages (no face enhancement), convert the minimum pipeline, and benchmark it on the synthetic paired set before any product integration. Until it passes Redmi memory/timing and quality tests, PIXORA must not promise true extensive damage reconstruction on that device.

## 6. Changes in this investigation

- Added debug-build-only trace records for source file, working decoded pixels, normalized RGB input tensors, raw pre-postprocess model output, stitched bitmap, and encoded JPEG. No image pixels are logged. Debug builds save first-tile input and raw output float32 dumps inside app-private cache; release builds do not capture those dumps.
- Added comparison output-path wiring assertions and widget-level two-source test.
- Added deterministic synthetic paired benchmark generator, binary masks, hashes, baseline MAE/PSNR/SSIM, optional actual-output scorer, and comparison-panel generation. It intentionally does not generate restoration output itself.
- Existing History persistence and gallery export fixes remain covered by current widget/unit tests; this investigation does not alter their behavior.

## 7. APK / validation status

No new APK has been produced for this investigation at report authoring time. Local Flutter, Android Gradle wrapper executable, ADB, and physical device are unavailable in this checkout. CI must run after these changes are pushed to validate analyzer/tests/native tests/build. That debug APK would contain diagnostics only for a physical-device reproduction; it is **not** a restoration fix and must not be described as one. The acceptance blocker remains open until real same-image evidence demonstrates meaningful damage reduction and a suitable model passes the target-device gates.

### Needed to close this incident

1. Provide the exact Redmi 9 original and its output file (or run the new debug instrumentation and export the private diagnostics + image pair); no cloud upload is needed—local USB transfer is fine.
2. Inspect source SHA, tensor and tile traces, raw output dump/stats, stitched bitmap and encoded JPEG hashes; run `tool/audit_restoration_pair.py` and the synthetic benchmark scorer on the same output.
3. Run the genuine scratch restoration candidate through the four paired synthetic cases and a licensed real-photo benchmark, report damage-region reduction separately from upscaling, and assess hallucination in missing areas.
4. Only then decide if a separate, commercially cleared and Redmi-validated damage-restoration model can ship alongside Real-ESRGAN. Until that evidence exists, keep the issue open.
