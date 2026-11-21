#!/usr/bin/env python3
"""Compare an original image and PIXORA output without modifying either input.

The original is EXIF-oriented and resized to the result's display dimensions
using Lanczos so metrics and the exported visual sheet use identical scaling.
Metrics quantify pixel change only; they are not a restoration-quality score.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps
from skimage.metrics import structural_similarity


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_rgb(path: Path) -> Image.Image:
    with Image.open(path) as image:
        return ImageOps.exif_transpose(image).convert("RGB")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("restored", type=Path)
    parser.add_argument("--json", type=Path, default=Path("restoration-audit.json"))
    parser.add_argument("--comparison", type=Path, default=Path("restoration-comparison.png"))
    args = parser.parse_args()

    original = load_rgb(args.original)
    restored = load_rgb(args.restored)
    if original.width * restored.height != original.height * restored.width:
        raise SystemExit(
            f"Aspect ratios differ: {original.size} vs {restored.size}; refusing to stretch."
        )
    display_original = original.resize(restored.size, Image.Resampling.LANCZOS)
    before = np.asarray(display_original, dtype=np.float64)
    after = np.asarray(restored, dtype=np.float64)
    difference = np.abs(before - after)
    mae = float(difference.mean())
    mse = float(np.square(before - after).mean())
    psnr = None if mse == 0 else float(10 * np.log10((255.0**2) / mse))
    ssim = float(structural_similarity(before, after, channel_axis=2, data_range=255))

    panel_h = restored.height + 48
    sheet = Image.new("RGB", (restored.width * 2, panel_h), "#161616")
    sheet.paste(display_original, (0, 48))
    sheet.paste(restored, (restored.width, 48))
    draw = ImageDraw.Draw(sheet)
    draw.text((12, 14), "Original (EXIF-corrected, display-scaled)", fill="white")
    draw.text((restored.width + 12, 14), "PIXORA output", fill="white")
    sheet.save(args.comparison, format="PNG")

    report = {
        "warning": "Difference metrics quantify change, not perceptual restoration quality.",
        "original": {"path": str(args.original), "dimensions": list(original.size), "sha256": sha256(args.original)},
        "restored": {"path": str(args.restored), "dimensions": list(restored.size), "sha256": sha256(args.restored)},
        "displayComparison": {"dimensions": list(display_original.size), "resampling": "Pillow Lanczos", "sideBySidePath": str(args.comparison)},
        "difference": {"mae_rgb_0_255": mae, "rmse_rgb_0_255": float(np.sqrt(mse)), "psnr_db": psnr, "ssim": ssim, "changed_channel_values_gt_1": float((difference > 1).mean())},
    }
    args.json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
