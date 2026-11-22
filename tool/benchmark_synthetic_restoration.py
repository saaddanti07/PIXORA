#!/usr/bin/env python3
"""Generate controlled old-photo damage fixtures and score real outputs.

No restoration is synthesized by this script. It generates clean ground truth,
known damaged inputs, binary damage masks, and input-vs-reference baselines. If
--outputs is supplied, it scores actual model output files named
{scratches,stains,faded,severe}.png. Output may be x4; it is resized only for
same-canvas restoration metrics, while the original output dimensions are kept
separately as resolution metadata.

Requires tool/requirements-image-audit.txt. All fixtures are deterministic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from skimage.metrics import structural_similarity

W, H = 640, 480
VARIANTS = ("scratches", "stains", "faded", "severe")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def clean_reference() -> Image.Image:
    """Procedural colored test chart with face-like oval/lines, not a photo."""
    y, x = np.mgrid[0:H, 0:W]
    glow = np.exp(-(((x - 320) / 260) ** 2 + ((y - 220) / 330) ** 2))
    arr = np.zeros((H, W, 3), dtype=np.uint8)
    arr[..., 0] = np.clip(62 + 74 * x / W + 52 * glow, 0, 255)
    arr[..., 1] = np.clip(72 + 65 * y / H + 28 * glow, 0, 255)
    arr[..., 2] = np.clip(88 + 46 * (1 - x / W) + 24 * glow, 0, 255)
    image = Image.fromarray(arr, "RGB")
    draw = ImageDraw.Draw(image)
    draw.rectangle((24, 24, 166, 132), fill=(205, 178, 133), outline=(238, 225, 196), width=4)
    draw.rectangle((34, 34, 155, 122), fill=(35, 87, 119))
    draw.ellipse((218, 78, 424, 354), fill=(184, 124, 99), outline=(57, 39, 36), width=5)
    draw.ellipse((270, 172, 294, 184), fill=(23, 25, 28))
    draw.ellipse((348, 172, 372, 184), fill=(23, 25, 28))
    draw.arc((291, 194, 354, 251), start=15, end=165, fill=(84, 34, 32), width=5)
    draw.polygon(((249, 342), (392, 342), (470, 476), (176, 476)), fill=(43, 75, 107))
    for i in range(7):
        xx = 28 + i * 22
        draw.line((xx, 406, xx + 170, 406), fill=(210, 198 - i * 7, 164 + i * 4), width=2)
    return image


def mark(draw: ImageDraw.ImageDraw, coords, width: int = 1):
    draw.line(coords, fill=255, width=width)


def make_damage(clean: Image.Image, kind: str) -> tuple[Image.Image, Image.Image]:
    rng = np.random.default_rng({"scratches": 11, "stains": 22, "faded": 33, "severe": 44}[kind])
    image = clean.copy()
    mask = Image.new("L", clean.size, 0)
    damage = ImageDraw.Draw(image)
    mask_draw = ImageDraw.Draw(mask)
    if kind in ("scratches", "severe"):
        count = 26 if kind == "scratches" else 44
        for _ in range(count):
            x, y = int(rng.integers(W)), int(rng.integers(H))
            length = int(rng.integers(28, 180))
            dx = int(rng.integers(-15, 16))
            dy = length if rng.random() < 0.75 else -length
            end = (max(0, min(W - 1, x + dx)), max(0, min(H - 1, y + dy)))
            width = int(rng.integers(1, 4))
            color = (245, 235, 210) if rng.random() < 0.6 else (31, 25, 24)
            damage.line((x, y, *end), fill=color, width=width)
            mark(mask_draw, (x, y, *end), width + 1)
    if kind in ("stains", "severe"):
        count = 13 if kind == "stains" else 22
        for _ in range(count):
            x, y = int(rng.integers(12, W - 12)), int(rng.integers(12, H - 12))
            rx, ry = int(rng.integers(8, 30)), int(rng.integers(6, 24))
            color = (135, 87, 53) if rng.random() < 0.65 else (226, 215, 189)
            box = (x - rx, y - ry, x + rx, y + ry)
            damage.ellipse(box, fill=color)
            mask_draw.ellipse((x - rx - 1, y - ry - 1, x + rx + 1, y + ry + 1), fill=255)
        if kind == "severe":
            # A deliberately missing rectangular patch: no algorithm can know its
            # exact hidden content unless the reconstruction prior guesses it.
            box = (405, 166, 487, 252)
            damage.rectangle(box, fill=(128, 113, 94))
            mask_draw.rectangle(box, fill=255)
    if kind == "faded":
        # Global fading is measured separately over the full frame.
        image = Image.blend(image, Image.new("RGB", clean.size, (213, 204, 184)), 0.42)
        image = Image.blend(image, Image.eval(image.convert("L"), lambda p: int(112 + (p - 112) * 0.53)).convert("RGB"), 0.38)
        mask_draw.rectangle((0, 0, W - 1, H - 1), fill=255)
    return image, mask


def metrics(reference: Image.Image, candidate: Image.Image, mask: Image.Image) -> dict:
    ref = np.asarray(reference.convert("RGB"), dtype=np.float32) / 255.0
    got = np.asarray(candidate.convert("RGB"), dtype=np.float32) / 255.0
    m = np.asarray(mask.convert("L"), dtype=np.float32) > 0
    delta = np.abs(ref - got)
    global_mae = float(delta.mean())
    affected_mae = float(delta[m].mean()) if m.any() else 0.0
    mse = float(np.square(ref - got).mean())
    psnr = None if mse == 0 else 10 * math.log10(1 / mse)
    return {
        "global_mae_0_1": global_mae,
        "damage_region_mae_0_1": affected_mae,
        "damage_mask_fraction": float(m.mean()),
        "global_psnr_db": psnr,
        "global_ssim": float(structural_similarity(ref, got, channel_axis=2, data_range=1.0)),
    }


def generate(folder: Path) -> dict:
    folder.mkdir(parents=True, exist_ok=True)
    clean = clean_reference()
    clean_path = folder / "clean_reference.png"
    clean.save(clean_path)
    results = {"schema": 1, "syntheticOnly": True, "dimensions": [W, H], "variants": {}}
    for variant in VARIANTS:
        damaged, mask = make_damage(clean, variant)
        input_path = folder / f"input_{variant}.png"
        mask_path = folder / f"mask_{variant}.png"
        damaged.save(input_path)
        mask.save(mask_path)
        results["variants"][variant] = {
            "input": {"path": input_path.name, "sha256": sha256(input_path)},
            "mask": {"path": mask_path.name, "sha256": sha256(mask_path)},
            "no_op_baseline_vs_clean_reference": metrics(clean, damaged, mask),
            "model_output": "NOT_RUN: no LiteRT model/runtime/device photo was available in this workspace",
        }
    results["clean_reference"] = {"path": clean_path.name, "sha256": sha256(clean_path)}
    return results


def score_outputs(folder: Path, outputs: Path, results: dict) -> None:
    clean = Image.open(folder / "clean_reference.png").convert("RGB")
    for variant in VARIANTS:
        path = outputs / f"{variant}.png"
        if not path.is_file():
            raise FileNotFoundError(f"missing restored output {path}")
        actual = Image.open(path).convert("RGB")
        original_size = actual.size
        comparable = actual.resize((W, H), Image.Resampling.LANCZOS)
        mask = Image.open(folder / f"mask_{variant}.png").convert("L")
        model_metrics = metrics(clean, comparable, mask)
        baseline = results["variants"][variant]["no_op_baseline_vs_clean_reference"]
        baseline_damage_error = baseline["damage_region_mae_0_1"]
        restored_damage_error = model_metrics["damage_region_mae_0_1"]
        results["variants"][variant]["model_output"] = {
            "path": path.name,
            "sha256": sha256(path),
            "dimensions": list(original_size),
            "metrics_after_resize_to_reference_canvas": model_metrics,
            "damage_region_error_reduction_percent": (
                100 * (baseline_damage_error - restored_damage_error) / baseline_damage_error
                if baseline_damage_error else None
            ),
            "warning": "Damage-region MAE is not a perceptual quality score; inspect comparison panels and missing-content hallucination.",
        }
        panel = Image.new("RGB", (W * 3, H + 32), "white")
        draw = ImageDraw.Draw(panel)
        draw.text((8, 8), "Clean reference", fill="black")
        draw.text((W + 8, 8), "Damaged model input", fill="black")
        draw.text((W * 2 + 8, 8), f"Model output {original_size[0]}x{original_size[1]} (resized for damage metrics)", fill="black")
        panel.paste(clean, (0, 32))
        panel.paste(Image.open(folder / f"input_{variant}.png").convert("RGB"), (W, 32))
        panel.paste(comparable, (W * 2, 32))
        panel.save(outputs / f"comparison_{variant}.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", type=Path, default=Path("test/fixtures/restoration_benchmark"))
    parser.add_argument("--outputs", type=Path, help="directory of actual restored {variant}.png model outputs")
    parser.add_argument("--report", type=Path, help="report JSON; defaults to <out-dir>/benchmark.json")
    args = parser.parse_args()
    report = generate(args.out_dir)
    if args.outputs:
        score_outputs(args.out_dir, args.outputs, report)
    report_path = args.report or args.out_dir / "benchmark.json"
    report_path.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(report, indent=2, allow_nan=False))
    print(f"report: {report_path}")


if __name__ == "__main__":
    main()
