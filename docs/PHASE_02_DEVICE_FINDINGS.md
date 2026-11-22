# Phase 02 device findings and corrective work

**State: follow-up in progress; do not call Phase 02 acceptance complete.**

The user reports a real Redmi 9 run with a 640×480 input taking **89.7 seconds**,
visible scratches/stains remaining, and a History screen that stays empty after
the result says it was saved. This is a *single user-reported run*, not an
independently captured benchmark. It is 0.3 s under the 90 s limit, but the
required second consecutive run, memory/ANR observations, and output-file audit
are not available in this workspace; G2 is therefore **not passed**.

## What the source audit found

### Model capability and display path

The bundled Real-ESRGAN `realesr-general-x4v3` is a general-purpose 4×
super-resolution/enhancement model, not a scratch mask detector or inpainting
model. It cannot reconstruct missing content reliably; visible damage remaining
is an expected capability limitation, not evidence by itself that the model
failed. No claim of scratch removal or complete old-photo restoration is valid.

The app path does connect the native model output file to the comparison UI:
Kotlin extracts RGB from Android ARGB pixels, lays out values according to the
model's recorded NCHW/NHWC metadata, normalizes from the recorded value range,
executes the LiteRT interpreter, converts output channels back to ARGB, writes
JPEG, returns its path, and Flutter displays that path beside the source. New
runtime shape/dtype guards reject model/metadata mismatches. This is strong
source-level evidence that model output is intended to be displayed; it is **not**
proof of which bytes appeared in the user's screenshot. An actual source/output
pair and its file hashes are needed for that determination.

The tiler had a real edge-tile defect: it shifted the last 96-pixel core backward
but still wrote the complete fixed core, so non-multiple widths/heights could
write the same output pixels more than once. The update assigns every pixel to
exactly one tile using midpoint partitions across prediction overlap and crops
the corresponding model-output coordinates. Kotlin unit tests enumerate coverage
to require every output pixel to be written once. It uses the existing 16-pixel
context halo; it does not pretend to do image-dependent blending.

EXIF handling previously collapsed mirrored orientations into rotations. All
eight EXIF orientations are now represented explicitly before inference. The
orientation-normalized output is upright and does not rely on copying the source
EXIF tag into the new JPEG.

### History root cause

History records were written through the same shared-preferences store and the
success screen awaited `add()`, but it swallowed any write failure and always
showed “Saved to your History.” More importantly, both Home and History captured
`repository.load()` once in `late final` fields. `RootShell` retains those screens
inside an `IndexedStack`, so their initial empty snapshots survived processing
and tab changes. That stale view explains the reported empty History screen
without requiring a database/path mismatch. Previously records also lacked the
original-image reference and processing metadata.

The fix serializes repository mutations, notifies `Listenable` consumers only
after the backing store completes, refreshes Home and History reactively, copies
the original bytes into an app-private history archive, validates both source
and output files before recording, stores method/time/duration/dimensions, and
shows a save-success label only if the archive and ledger write succeeded. Failed
and cancelled results never enter history. Tapping an entry opens the archived
before/after comparison. The shared-preferences metadata ledger survives process
restart; originals and outputs remain in app-private files (not gallery).

### Gallery export

The separate Export action uses Android `MediaStore.Images` and publishes to
`Pictures/PIXORA`. Android 10+ uses scoped storage plus `IS_PENDING` until the
file copy is complete; Android 9 and older request a `WRITE_EXTERNAL_STORAGE`
permission only after the user taps Export, with `maxSdkVersion=28`. Each export
uses a unique name, retains the internal original, removes a partial MediaStore
row on failure, and reports success only after the URI is published. CI can
compile and test the channel contract but cannot verify a physical Gallery app;
that device check remains required.

## What cannot be measured from this checkout

No user-provided original photo, restored file, or screenshot attachment is
present in the repository/workspace. Therefore this report does **not** invent
before/after dimensions, hashes, MAE, PSNR, SSIM, a same-scale visual result, or
an assertion that those scratches were actually altered. The new reproducible
pair audit is:

```bash
python -m pip install -r tool/requirements-image-audit.txt
python tool/audit_restoration_pair.py original.jpg restored.jpg \
  --json restoration-audit.json --comparison restoration-comparison.png
```

It reports original/output dimensions and SHA-256, EXIF-corrects the original,
resizes it to the output dimensions without changing aspect ratio, computes RGB
MAE/RMSE/PSNR and SSIM, and writes an identically scaled side-by-side PNG. These
are pixel-difference measurements, **not** restoration-quality scores. Both
actual device files are needed to produce the requested evidence.

## Additional-model assessment

The official Microsoft **Bringing Old Photos Back to Life** project is a relevant
scratch-restoration candidate and lists MIT licensing, but its official v1.0
release assets are `global_checkpoints.zip` **2,036,400,762 bytes** and
`face_checkpoints.zip` **684,354,563 bytes**. The released pipeline also includes
face enhancement (out of PIXORA's approved scope), is tested as Python/CUDA code,
and its README warns the pretrained model may not work ideally at arbitrary
resolutions because of its 256×256 training size. It is not a lightweight,
verified LiteRT/Android/Redmi 9 drop-in. It is therefore **not added**.

No additional checkpoint is being substituted or silently introduced. A
technically justified next step is to evaluate a **separate, mask-aware scratch
segmentation + inpainting model**, with a checked commercial-compatible license,
verified official checkpoint digest/size, representative scratch test set,
LiteRT conversion fidelity (correlation ≥0.995), and two-run Redmi 9 timing/RAM
measurements. Until such a candidate passes those gates, keep the honest label
and describe the shipped model as super-resolution/general enhancement, not
scratch removal.

## Required device retest

1. Use the actual same damaged source that prompted the report, copy the exact
   original and result files off the device without re-encoding, then run the
   audit command above.
2. Compare the exported side-by-side image at 1:1 pane scaling and review the
   scratch/stain regions. A large MAE alone is not success; it may reflect JPEG,
   color, resize, or hallucinated detail.
3. Install the follow-up APK on the Redmi 9, repeat the documented 640×480 case
   twice consecutively, record elapsed time, output dimensions, peak memory,
   cancellation, and absence of ANR/OOM. The user's 89.7 s is recorded only as a
   single reported run until this is repeated.
4. Confirm the history item is visible, opens comparison, survives force-stop /
   relaunch, and that Export creates an openable image under Pictures/PIXORA.

No physical device or user image pair is available to this coding environment;
these device checks remain open.
