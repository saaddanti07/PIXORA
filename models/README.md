# Model provenance — `realesr-general-x4v3`

Phase 02 ships exactly one AI model. This file records where it came from, how it
was converted, and how to reproduce the artefact. It is the paper trail for the
licence and for the fidelity numbers quoted in
[`docs/PHASE_02_REPORT.md`](../docs/PHASE_02_REPORT.md).

## Identity

| Field | Value |
| --- | --- |
| Model | Real-ESRGAN `realesr-general-x4v3` |
| Architecture | `SRVGGNetCompact` (33 convs @ input resolution, `PixelShuffle` ×4, nearest-neighbour residual) |
| Parameters | 1,213,296 |
| Upstream | <https://github.com/xinntao/Real-ESRGAN> |
| Licence | **BSD-3-Clause** — see [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) |
| Weights | `v0.2.5.0` release asset, 4,885,111 bytes (SHA-256 pinned below) |
| Weights URL | <https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-x4v3.pth> |
| SHA-256 | pinned in [`weights.sha256`](weights.sha256) |

## Artefacts

The `.tflite` file is **generated, not committed** (see `.gitignore`). CI builds it
on every run from the pinned weights and refuses to continue if the fidelity gate
fails. Local developers can run the same command.

| Artefact | Where |
| --- | --- |
| `realesr_general_x4v3_fp32.tflite` | `android/app/src/main/assets/models/` (generated) |
| `realesr_general_x4v3_fp32.tflite.meta.json` | same directory; tensor layout, read at runtime by Kotlin |
| `models/report.json` | conversion + fidelity report (generated, uploaded as a CI artefact) |

## Reproduce

```bash
python3.12 -m venv .venv-model
. .venv-model/bin/activate
pip install --index-url https://download.pytorch.org/whl/cpu torch
pip install -r tool/requirements-model.txt

python tool/convert_model.py \
  --out android/app/src/main/assets/models/realesr_general_x4v3_fp32.tflite \
  --report models/report.json
```

The script exits non-zero — and produces no model — unless:

- the weights match their pinned SHA-256 and their exact byte size;
- the checkpoint's own tensors confirm `num_feat=64`, `num_conv=32`, `upscale=4`;
- the converted model agrees with the PyTorch reference on seven deterministic
  fixtures with **Pearson correlation ≥ 0.995** and max absolute error ≤ 0.02.

First verified run (CI run 44773378380): correlation **1.000000**, max error
**0.00/255**, LiteRT artefact **4,910,280 bytes**, SHA-256
`cedda0d6c8f59c3eca8558e7002a571f5437079d922a486068384599b2d0ddab`.

No photograph — and certainly no user photograph — is used anywhere in that
process; the fixtures are procedurally generated from fixed seeds.

## Why this model

The audit in [`docs/PHASE_02_STEP1_MODEL_AUDIT.md`](../docs/PHASE_02_STEP1_MODEL_AUDIT.md)
compares ten candidates. This is the only one that is simultaneously: freely
downloadable with a commercial licence, small enough to bundle (4.7 MiB), proven
to convert to LiteRT, and cheap enough per pixel to be usable on a
Helio G35-class device when processed in 128×128 tiles.
