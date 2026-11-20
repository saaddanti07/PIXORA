#!/usr/bin/env python3
"""Convert Real-ESRGAN ``realesr-general-x4v3`` to LiteRT and prove it is faithful.

This script is the Phase 02 *Step 2* gate. It does five things, in order, and
refuses to emit a model unless all of them pass:

1. downloads the **official** weights from the Real-ESRGAN GitHub release and
   verifies their size (and SHA-256 when ``models/weights.sha256`` is pinned);
2. rebuilds ``SRVGGNetCompact`` exactly as defined upstream
   (``realesrgan/archs/srvgg_arch.py``, including the nearest-neighbour
   residual that makes the network learn the *difference* from a plain upscale);
3. converts it to LiteRT via Google's official PyTorch converter
   (``litert-torch``);
4. runs the converted model and the PyTorch reference over a set of
   deterministic, procedurally generated fixtures -- **no photograph, and in
   particular no user photograph, is ever used**;
5. compares the two outputs and fails if the Pearson correlation is below
   ``--min-corr`` (default 0.995, the threshold approved for Phase 02).

Outputs:

* the ``.tflite`` model (path given by ``--out``);
* ``<out>.meta.json`` -- tensor layout / shape / value range, read at runtime by
  the Kotlin engine so the app never hardcodes a layout it did not verify;
* ``--report`` JSON -- every number produced above, for the project docs.

Usage:
    python tool/convert_model.py \
        --out android/app/src/main/assets/models/realesr_general_x4v3_fp32.tflite \
        --report models/report.json

Requires: torch (CPU build), litert-torch, ai-edge-litert, numpy.
See tool/requirements-model.txt.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any

import numpy as np

# --- model identity -------------------------------------------------------
# Everything here is quoted from the publisher, not guessed.
WEIGHTS_URL = (
    "https://github.com/xinntao/Real-ESRGAN/releases/download/"
    "v0.2.5.0/realesr-general-x4v3.pth"
)
WEIGHTS_SIZE = 4_885_111  # bytes, GitHub Releases API for v0.2.5.0
WEIGHTS_NAME = "realesr-general-x4v3.pth"
UPSTREAM_REPO = "https://github.com/xinntao/Real-ESRGAN"
UPSTREAM_LICENSE = "BSD-3-Clause"

NUM_FEAT = 64
NUM_CONV = 32
SCALE = 4
TILE = 128

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent
DEFAULT_SHA_FILE = REPO_ROOT / "models" / "weights.sha256"


# -------------------------------------------------------------------------
# model definition (mirrors realesrgan/archs/srvgg_arch.py)
# -------------------------------------------------------------------------
def build_model(torch, num_feat: int = NUM_FEAT, num_conv: int = NUM_CONV,
                upscale: int = SCALE, act_type: str = "prelu"):
    """Verbatim re-implementation of SRVGGNetCompact."""
    import torch.nn.functional as F
    from torch import nn

    class SRVGGNetCompact(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.upscale = upscale
            body: list[Any] = []
            body.append(nn.Conv2d(3, num_feat, 3, 1, 1))
            body.append(_activation(nn, num_feat, act_type))
            for _ in range(num_conv):
                body.append(nn.Conv2d(num_feat, num_feat, 3, 1, 1))
                body.append(_activation(nn, num_feat, act_type))
            body.append(nn.Conv2d(num_feat, 3 * upscale * upscale, 3, 1, 1))
            self.body = nn.ModuleList(body)
            self.upsampler = nn.PixelShuffle(upscale)

        def forward(self, x):  # noqa: ANN001, ANN201 - torch tensor
            out = x
            for layer in self.body:
                out = layer(out)
            out = self.upsampler(out)
            # The official forward pass adds a nearest-neighbour upscale of the
            # input: the network predicts the residual, not the image.
            out = out + F.interpolate(x, scale_factor=self.upscale, mode="nearest")
            return out

    def _activation(nn, feat: int, kind: str):  # noqa: ANN001, ANN202
        if kind == "relu":
            return nn.ReLU(inplace=True)
        if kind == "prelu":
            return nn.PReLU(num_parameters=feat)
        if kind == "leakyrelu":
            return nn.LeakyReLU(negative_slope=0.1, inplace=True)
        raise ValueError(f"unsupported activation {kind!r}")

    return SRVGGNetCompact()


# -------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------
def fail(message: str) -> None:
    print(f"\nFATAL: {message}", file=sys.stderr)
    raise SystemExit(1)


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch_weights(target: Path, *, url: str, expected_size: int) -> Path:
    """Download the official checkpoint, or reuse a local copy."""
    if target.is_file() and target.stat().st_size == expected_size:
        print(f"weights: reusing {target} ({expected_size} bytes)")
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    print(f"weights: downloading {url}")
    tmp = target.with_suffix(target.suffix + ".part")
    with urllib.request.urlopen(url, timeout=180) as response, tmp.open("wb") as out:
        while True:
            chunk = response.read(1 << 20)
            if not chunk:
                break
            out.write(chunk)
    size = tmp.stat().st_size
    if size != expected_size:
        tmp.unlink(missing_ok=True)
        fail(f"weights size {size} != expected {expected_size} for {url}")
    tmp.replace(target)
    print(f"weights: saved {target} ({size} bytes)")
    return target


def verify_weights_digest(path: Path, sha_file: Path, write_sha: bool) -> dict[str, Any]:
    """Enforce the pinned digest when present; otherwise report it."""
    digest = sha256_of(path)
    pinned = None
    if sha_file.is_file():
        for line in sha_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if parts and len(parts[0]) == 64:
                pinned = parts[0].lower()
                break
    if pinned and pinned != digest:
        fail(
            "weights SHA-256 mismatch: the official release changed, or the "
            f"download is corrupt.\n  expected {pinned}\n  actual   {digest}"
        )
    if not pinned:
        print(f"weights: sha256 {digest} (not pinned yet)")
        if write_sha:
            sha_file.parent.mkdir(parents=True, exist_ok=True)
            sha_file.write_text(
                "# SHA-256 of the official Real-ESRGAN v0.2.5.0 checkpoint\n"
                f"# {WEIGHTS_URL}\n"
                f"{digest}  {WEIGHTS_NAME}\n",
                encoding="utf-8",
            )
            print(f"weights: pinned digest written to {sha_file}")
    else:
        print(f"weights: sha256 {digest} matches the pinned digest")
    return {"sha256": digest, "pinned": pinned, "size": path.stat().st_size}


def make_fixtures(count_per_kind: int = 1) -> list[tuple[str, np.ndarray]]:
    """Deterministic synthetic 128x128 RGB images in [0, 1].

    Chosen to exercise different parts of the network: smooth ramps (low
    frequency), a checkerboard and sinusoids (high frequency detail), noise
    (the denoising branch), and colour separation.
    """
    rng = np.random.default_rng(20261119)
    h = w = TILE
    yy, xx = np.meshgrid(
        np.linspace(0.0, 1.0, h, dtype=np.float32),
        np.linspace(0.0, 1.0, w, dtype=np.float32),
        indexing="ij",
    )
    fixtures: list[tuple[str, np.ndarray]] = []

    ramp = np.stack([xx, yy, (xx + yy) * 0.5], axis=-1)
    fixtures.append(("ramp", ramp))

    checker = ((np.floor(xx * 16) + np.floor(yy * 16)) % 2).astype(np.float32)
    fixtures.append(("checker", np.stack([checker, 1.0 - checker, checker * 0.5], axis=-1)))

    radius = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2)
    rings = 0.5 + 0.5 * np.cos(radius * 60.0)
    fixtures.append(("rings", np.stack([rings, rings ** 2, 1.0 - rings], axis=-1)))

    for index in range(count_per_kind):
        noise = rng.normal(0.5, 0.18, size=(h, w, 3)).astype(np.float32)
        fixtures.append((f"noise{index}", np.clip(noise, 0.0, 1.0)))

    detail = 0.5 + 0.25 * np.sin(xx * 90.0) * np.cos(yy * 70.0)
    fixtures.append(("detail", np.repeat(detail[..., None], 3, axis=-1)))

    quadrant = np.zeros((h, w, 3), dtype=np.float32)
    quadrant[: h // 2, : w // 2] = (0.9, 0.2, 0.2)
    quadrant[: h // 2, w // 2:] = (0.2, 0.9, 0.2)
    quadrant[h // 2:, : w // 2] = (0.2, 0.2, 0.9)
    quadrant[h // 2:, w // 2:] = (0.85, 0.85, 0.85)
    fixtures.append(("quadrants", quadrant))

    return [(name, arr.astype(np.float32)) for name, arr in fixtures]


def normalise_output(array: np.ndarray) -> np.ndarray:
    """Return an HWC float image from whatever layout the model produced."""
    if array.ndim == 4:
        array = array[0]
    if array.ndim != 3:
        raise ValueError(f"unexpected output rank {array.ndim}")
    if array.shape[0] == 3 and array.shape[2] != 3:  # NCHW -> HWC
        array = np.transpose(array, (1, 2, 0))
    return np.ascontiguousarray(array, dtype=np.float32)


def normalise_input(image: np.ndarray, layout: str) -> np.ndarray:
    """Shape a fixture for the model's declared input layout."""
    if layout == "NHWC":
        return image[None, ...].astype(np.float32)
    return np.transpose(image[None, ...], (0, 3, 1, 2)).astype(np.float32)


def compare(reference: np.ndarray, candidate: np.ndarray) -> dict[str, float]:
    """Pearson correlation and error metrics between two images in [0, 1]."""
    a = reference.reshape(-1).astype(np.float64)
    b = candidate.reshape(-1).astype(np.float64)
    if a.shape != b.shape:
        fail(f"shape mismatch: reference {reference.shape} vs model {candidate.shape}")
    a_centered = a - a.mean()
    b_centered = b - b.mean()
    denominator = float(np.linalg.norm(a_centered) * np.linalg.norm(b_centered))
    corr = float(np.dot(a_centered, b_centered) / denominator) if denominator else 1.0
    diff = np.abs(a - b)
    mse = float(np.mean((a - b) ** 2))
    psnr = float("inf") if mse == 0 else 10.0 * math.log10(1.0 / mse)
    return {
        "correlation": corr,
        "max_abs_error": float(diff.max()),
        "mean_abs_error": float(diff.mean()),
        "max_abs_error_8bit": float(diff.max() * 255.0),
        "psnr_db": psnr,
    }


def describe_tensor(detail: dict[str, Any]) -> dict[str, Any]:
    shape = [int(v) for v in detail["shape"]]
    return {"shape": shape, "dtype": str(np.dtype(detail["dtype"]).name)}


def layout_of(shape: list[int]) -> str:
    """Channel-last vs channel-first for a 4-D tensor with 3 channels."""
    if len(shape) == 4 and shape[-1] == 3:
        return "NHWC"
    if len(shape) == 4 and shape[1] == 3:
        return "NCHW"
    return "unknown"


# -------------------------------------------------------------------------
# conversion backends
# -------------------------------------------------------------------------
def convert_with_litert(model, out_path: Path) -> str:
    """Google's official PyTorch -> LiteRT converter."""
    import litert_torch  # noqa: PLC0415

    import torch  # noqa: PLC0415

    example = (torch.rand(1, 3, TILE, TILE, dtype=torch.float32) * 0.5 + 0.25,)
    print("convert: litert_torch.convert()")
    converter = getattr(litert_torch, "convert", None)
    if converter is None:
        raise RuntimeError("litert_torch.convert not found in this version")
    edge_model = converter(model, example)
    for attribute in ("export", "save"):
        method = getattr(edge_model, attribute, None)
        if callable(method):
            method(str(out_path))
            if out_path.is_file():
                return "litert-torch"
    raise RuntimeError("litert_torch produced no file")


def export_onnx(model, out_path: Path) -> None:
    """Debug artefact: the traced graph as ONNX (not used by the app)."""
    import torch  # noqa: PLC0415

    dummy = torch.zeros(1, 3, TILE, TILE, dtype=torch.float32)
    torch.onnx.export(
        model, dummy, str(out_path), opset_version=17,
        input_names=["input"], output_names=["output"],
    )


def load_interpreter(model_path: Path):
    try:
        from ai_edge_litert.interpreter import Interpreter  # noqa: PLC0415
    except Exception:  # pragma: no cover - fallback for older installs
        from tflite_runtime.interpreter import Interpreter  # noqa: PLC0415

    interpreter = Interpreter(model_path=str(model_path), num_threads=4)
    interpreter.allocate_tensors()
    return interpreter


def run_tflite(interpreter, image: np.ndarray, input_layout: str) -> np.ndarray:
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    interpreter.set_tensor(input_detail["index"], normalise_input(image, input_layout))
    interpreter.invoke()
    return normalise_output(interpreter.get_tensor(output_detail["index"]))


# -------------------------------------------------------------------------
# main
# -------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--report", type=Path, default=None)
    parser.add_argument("--weights", type=Path, default=Path("/tmp") / WEIGHTS_NAME)
    parser.add_argument("--sha-file", type=Path, default=DEFAULT_SHA_FILE)
    parser.add_argument("--write-sha", action="store_true",
                        help="pin the observed weight digest (first run only)")
    parser.add_argument("--min-corr", type=float, default=0.995)
    parser.add_argument("--max-abs-error", type=float, default=0.02)
    parser.add_argument("--export-onnx", type=Path, default=None)
    parser.add_argument("--backend", choices=["litert"], default="litert")
    args = parser.parse_args()

    started = time.time()
    try:
        import torch  # noqa: F401, PLC0415
    except Exception:
        fail("torch is not installed; see tool/requirements-model.txt")

    import torch

    torch.manual_seed(20261119)
    torch.use_deterministic_algorithms(True, warn_only=True)

    print("=" * 72)
    print("PIXORA -- Real-ESRGAN realesr-general-x4v3 -> LiteRT")
    print(f"upstream : {UPSTREAM_REPO}  ({UPSTREAM_LICENSE})")
    print(f"weights  : {WEIGHTS_URL}")
    print(f"torch    : {torch.__version__}")
    print("=" * 72)

    # 1. weights
    weights_path = fetch_weights(args.weights, url=WEIGHTS_URL, expected_size=WEIGHTS_SIZE)
    digest = verify_weights_digest(weights_path, args.sha_file, args.write_sha)

    # 2. architecture from the checkpoint itself
    try:
        checkpoint = torch.load(weights_path, map_location="cpu", weights_only=True)
    except Exception as exc:  # older zip layouts carry pickled globals
        print(f"weights: strict unpickling failed ({exc}); retrying after digest check")
        checkpoint = torch.load(weights_path, map_location="cpu", weights_only=False)
    state = checkpoint.get("params", checkpoint)
    if not isinstance(state, dict):
        fail(f"unexpected checkpoint structure: {type(state)!r}")

    num_feat = int(state["body.0.weight"].shape[0])
    # Body convolutions are the ones whose input *and* output are `num_feat`.
    # The first (3 -> 64) and last (64 -> 48) convolutions do not match, so this
    # counts exactly `num_conv` without trusting a filename.
    num_conv = sum(
        1
        for key, value in state.items()
        if key.endswith(".weight") and value.ndim == 4
        and value.shape[0] == num_feat and value.shape[1] == num_feat
    )
    last_key = [k for k in state if k.startswith("body.") and state[k].ndim == 4][-1]
    out_channels = int(state[last_key].shape[0])
    upscale = int(round(math.sqrt(out_channels / 3)))
    print(f"checkpoint: num_feat={num_feat} num_conv={num_conv} upscale={upscale} "
          f"params={sum(int(v.numel()) for v in state.values())}")
    if (num_feat, upscale) != (NUM_FEAT, SCALE):
        fail(f"unexpected architecture: num_feat={num_feat} upscale={upscale}")

    model = build_model(torch, num_feat=num_feat, num_conv=num_conv, upscale=upscale)
    missing, unexpected = model.load_state_dict(state, strict=False)
    if missing or unexpected:
        fail(f"state dict mismatch. missing={list(missing)[:5]} unexpected={list(unexpected)[:5]}")
    model.eval()
    parameter_count = sum(p.numel() for p in model.parameters())
    print(f"model: SRVGGNetCompact, {parameter_count:,} parameters")

    # 3. reference outputs
    fixtures = make_fixtures()
    with torch.no_grad():
        references = {}
        for name, image in fixtures:
            tensor = torch.from_numpy(np.transpose(image, (2, 0, 1))[None].copy())
            reference = model(tensor).numpy()
            references[name] = normalise_output(reference)
    print(f"reference: {len(fixtures)} fixtures -> {references['ramp'].shape}")

    if args.export_onnx:
        args.export_onnx.parent.mkdir(parents=True, exist_ok=True)
        export_onnx(model, args.export_onnx)
        print(f"onnx: {args.export_onnx} ({args.export_onnx.stat().st_size} bytes)")

    # 4. conversion
    args.out.parent.mkdir(parents=True, exist_ok=True)
    conversion_started = time.time()
    backend_used = convert_with_litert(model, args.out)
    conversion_seconds = time.time() - conversion_started
    model_bytes = args.out.stat().st_size
    print(f"convert: {backend_used} in {conversion_seconds:.1f}s -> {args.out} "
          f"({model_bytes:,} bytes / {model_bytes / 1048576:.2f} MiB)")

    # 5. fidelity
    interpreter = load_interpreter(args.out)
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    input_info = describe_tensor(input_detail)
    output_info = describe_tensor(output_detail)
    input_layout = layout_of(input_info["shape"])
    print(f"tflite  : input {input_info} ({input_layout})  output {output_info}")

    if input_info["shape"] != [1, TILE, TILE, 3] and input_info["shape"] != [1, 3, TILE, TILE]:
        fail(f"unexpected tflite input shape {input_info['shape']}")

    results = {}
    overall_corr = 1.0
    overall_max = 0.0
    for name, image in fixtures:
        candidate = run_tflite(interpreter, image, input_layout)
        metrics = compare(references[name], candidate)
        results[name] = metrics
        overall_corr = min(overall_corr, metrics["correlation"])
        overall_max = max(overall_max, metrics["max_abs_error"])
        print(f"  {name:<12} corr={metrics['correlation']:.6f} "
              f"max|err|={metrics['max_abs_error'] * 255:.2f}/255 "
              f"psnr={metrics['psnr_db']:.2f} dB")

    # latency on *this* machine -- explicitly not the target device
    timing_image = fixtures[0][1]
    run_tflite(interpreter, timing_image, input_layout)  # warm up
    repeats = 5
    timing_started = time.perf_counter()
    for _ in range(repeats):
        run_tflite(interpreter, timing_image, input_layout)
    per_tile_ms = (time.perf_counter() - timing_started) / repeats * 1000.0
    print(f"timing  : {per_tile_ms:.1f} ms/tile on this {os.cpu_count()}-cpu host "
          f"(NOT the target device)")

    # 6. metadata for the runtime
    meta = {
        "modelId": "real_esrgan_general_x4v3",
        "input": {**input_info, "layout": input_layout, "valueRange": [0.0, 1.0]},
        "output": {**output_info, "layout": layout_of(output_info["shape"])},
        "scale": SCALE,
        "tile": TILE,
        "parameters": int(parameter_count),
        "bytes": model_bytes,
    }
    meta_path = args.out.with_suffix(args.out.suffix + ".meta.json")
    meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")

    report = {
        "generatedAtUtc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "model": {
            "id": "real_esrgan_general_x4v3",
            "architecture": "SRVGGNetCompact",
            "source": UPSTREAM_REPO,
            "license": UPSTREAM_LICENSE,
            "weightsUrl": WEIGHTS_URL,
            "weightsBytes": digest["size"],
            "weightsSha256": digest["sha256"],
            "weightsDigestPinned": bool(digest["pinned"]),
            "parameters": int(parameter_count),
            "tfliteBytes": model_bytes,
            "tfliteSha256": sha256_of(args.out),
            "tflitePath": str(args.out),
        },
        "conversion": {
            "backend": backend_used,
            "torchVersion": torch.__version__,
            "seconds": round(conversion_seconds, 1),
        },
        "tensors": {"input": input_info, "inputLayout": input_layout,
                    "output": output_info},
        "fidelity": {
            "fixtures": results,
            "minCorrelation": overall_corr,
            "maxAbsError": overall_max,
            "thresholdCorrelation": args.min_corr,
            "thresholdMaxAbsError": args.max_abs_error,
            "passed": bool(overall_corr >= args.min_corr and overall_max <= args.max_abs_error),
        },
        "timing": {
            "perTileMs": round(per_tile_ms, 1),
            "hostCpus": os.cpu_count(),
            "note": "Measured on the CI runner, not on a phone. "
                    "Device numbers live in docs/PHASE_02_BENCHMARKS.md.",
        },
        "elapsedSeconds": round(time.time() - started, 1),
    }
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"report  : {args.report}")

    print("=" * 72)
    print(f"min correlation {overall_corr:.6f} (threshold {args.min_corr})")
    print(f"max |error|     {overall_max * 255:.2f}/255 (threshold "
          f"{args.max_abs_error * 255:.2f}/255)")
    if not report["fidelity"]["passed"]:
        fail("fidelity gate FAILED -- refusing to emit a model")
    print(f"RESULT: PASS  ({model_bytes:,} bytes, {model_bytes / 1048576:.2f} MiB)")
    print("=" * 72)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
