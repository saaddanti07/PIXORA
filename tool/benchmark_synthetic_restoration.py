#!/usr/bin/env python3
"""Generate paired damage fixtures and score real LiteRT outputs.

No restoration is synthesized by this script. It generates clean ground truth,
known damaged inputs, binary masks, and input-vs-reference baselines. With
--model, it runs the actual converted LiteRT model over app-equivalent tiles;
otherwise --outputs can score actual externally-produced variant PNGs. Results
are compared on a common canvas, with dimensions and upscaling recorded
separately from damage-region error. All fixtures are deterministic.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
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
            "model_output": "NOT_RUN: this baseline report was generated without --model or external model outputs",
        }
    results["clean_reference"] = {"path": clean_path.name, "sha256": sha256(clean_path)}
    return results


def run_tiled_litert(model_path: Path, folder: Path, outputs: Path) -> dict:
    """Run the actual converted LiteRT model in app-equivalent 128px tiles."""
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError as error:
        raise RuntimeError("ai-edge-litert is required for --model inference") from error

    interpreter = Interpreter(model_path=str(model_path), num_threads=4)
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    input_shape = tuple(int(value) for value in input_detail["shape"])
    output_shape = tuple(int(value) for value in output_detail["shape"])
    input_nchw = input_shape[1] == 3
    output_nchw = output_shape[1] == 3
    tile_h, tile_w = (input_shape[2], input_shape[3]) if input_nchw else (input_shape[1], input_shape[2])
    out_h, out_w = (output_shape[2], output_shape[3]) if output_nchw else (output_shape[1], output_shape[2])
    if tile_w != tile_h or out_w % tile_w or out_h % tile_h or out_w // tile_w != out_h // tile_h:
        raise ValueError(f"unsupported model tile shapes: {input_shape} -> {output_shape}")
    scale = out_w // tile_w
    if input_detail["dtype"] != np.float32 or output_detail["dtype"] != np.float32:
        raise ValueError("benchmark supports the shipped float32 model only")
    if input_shape[1 if input_nchw else 3] != 3 or output_shape[1 if output_nchw else 3] != 3:
        raise ValueError(f"expected three RGB channels, got {input_shape} -> {output_shape}")
    halo = 16
    stride = tile_w - 2 * halo
    working_width, working_height = 384, 288  # 640x480 under conservative/low-RAM 1536px output policy
    if working_width < tile_w or working_height < tile_h:
        raise ValueError("working image must be at least one model tile")

    def starts(length: int) -> list[int]:
        count = math.ceil(length / stride)
        return [min(index * stride, max(length - stride, 0)) for index in range(count)]

    x_starts, y_starts = starts(working_width), starts(working_height)
    outputs.mkdir(parents=True, exist_ok=True)
    first_raw = None
    first_input = None
    all_results = {}
    clean = Image.open(folder / "clean_reference.png").convert("RGB")
    sources = {"clean_reference": clean}
    sources.update({name: Image.open(folder / f"input_{name}.png").convert("RGB") for name in VARIANTS})
    for name, source in sources.items():
        working = source.resize((working_width, working_height), Image.Resampling.BILINEAR)
        working.save(outputs / f"working_{name}.png")
        rgb = np.asarray(working, dtype=np.float32) / 255.0
        padded = np.pad(rgb, ((halo, halo), (halo, halo), (0, 0)), mode="reflect")
        canvas = np.zeros((working_height * scale, working_width * scale, 3), dtype=np.uint8)
        tile_count = 0
        for row, y in enumerate(y_starts):
            write_y0 = 0 if row == 0 else (y_starts[row - 1] + stride + y) // 2
            write_y1 = working_height if row == len(y_starts) - 1 else (y + stride + y_starts[row + 1]) // 2
            for column, x in enumerate(x_starts):
                write_x0 = 0 if column == 0 else (x_starts[column - 1] + stride + x) // 2
                write_x1 = working_width if column == len(x_starts) - 1 else (x + stride + x_starts[column + 1]) // 2
                tile = padded[y:y + tile_h, x:x + tile_w, :]
                tensor = np.transpose(tile, (2, 0, 1))[None, ...] if input_nchw else tile[None, ...]
                if first_input is None and name != "clean_reference":
                    first_input = np.ascontiguousarray(tensor[0])
                    np.save(outputs / "first_model_input_tile.npy", first_input)
                interpreter.set_tensor(input_detail["index"], tensor.astype(np.float32, copy=False))
                interpreter.invoke()
                raw = interpreter.get_tensor(output_detail["index"])
                if not np.isfinite(raw).all():
                    raise ValueError(f"non-finite LiteRT output for {name} tile {tile_count}")
                if first_raw is None and name != "clean_reference":
                    first_raw = np.ascontiguousarray(raw[0])
                    np.save(outputs / "first_raw_model_output_tile.npy", first_raw)
                predicted = raw[0]
                predicted = np.transpose(predicted, (1, 2, 0)) if output_nchw else predicted
                dx = (halo + write_x0 - x) * scale
                dy = (halo + write_y0 - y) * scale
                crop = predicted[dy:dy + (write_y1 - write_y0) * scale,
                                 dx:dx + (write_x1 - write_x0) * scale, :]
                if crop.shape[:2] != ((write_y1 - write_y0) * scale, (write_x1 - write_x0) * scale):
                    raise ValueError(f"tile crop has unexpected shape {crop.shape}")
                canvas[write_y0 * scale:write_y1 * scale,
                       write_x0 * scale:write_x1 * scale, :] = np.rint(np.clip(crop, 0, 1) * 255).astype(np.uint8)
                tile_count += 1
        result = Image.fromarray(canvas, "RGB")
        result_path = outputs / ("clean_reference_model.png" if name == "clean_reference" else f"{name}.png")
        result.save(result_path)
        all_results[name] = {
            "path": result_path.name,
            "sha256": sha256(result_path),
            "dimensions": list(result.size),
            "working_dimensions": [working_width, working_height],
            "model_scale": scale,
            "tile_count": tile_count,
        }
    input_bytes = np.ascontiguousarray(first_input, dtype="<f4").tobytes()
    first_input_report = {
        "path": "first_model_input_tile.npy",
        "sha256": sha256(outputs / "first_model_input_tile.npy"),
        "tensor_sha256_little_endian_f32": hashlib.sha256(input_bytes).hexdigest(),
        "shape_without_batch": list(first_input.shape),
        "min": float(first_input.min()),
        "max": float(first_input.max()),
        "mean": float(first_input.mean()),
        "channel_means": [float(first_input[i].mean()) for i in range(3)] if input_nchw else
                         [float(first_input[..., i].mean()) for i in range(3)],
        "note": "Actual first scratched-fixture tile tensor submitted to LiteRT, before inference.",
    }
    raw_bytes = np.ascontiguousarray(first_raw, dtype="<f4").tobytes()
    raw_report = {
        "path": "first_raw_model_output_tile.npy",
        "sha256": sha256(outputs / "first_raw_model_output_tile.npy"),
        "tensor_sha256_little_endian_f32": hashlib.sha256(raw_bytes).hexdigest(),
        "shape_without_batch": list(first_raw.shape),
        "min": float(first_raw.min()),
        "max": float(first_raw.max()),
        "mean": float(first_raw.mean()),
        "channel_means": [float(first_raw[i].mean()) for i in range(3)] if output_nchw else
                         [float(first_raw[..., i].mean()) for i in range(3)],
        "note": "Raw tile-0 LiteRT float32 output, before RGB conversion, tile stitching, clipping, or image encoding.",
    }
    return {
        "model": {"path": model_path.name, "sha256": sha256(model_path), "input_shape": list(input_shape),
                  "output_shape": list(output_shape), "input_layout": "NCHW" if input_nchw else "NHWC",
                  "output_layout": "NCHW" if output_nchw else "NHWC", "dtype": "float32"},
        "first_model_input_tile": first_input_report,
        "raw_first_tile_output": raw_report,
        "outputs": all_results,
        "resolution_observation": {
            "working_dimensions": [working_width, working_height],
            "network_output_dimensions": all_results["clean_reference"]["dimensions"],
            "network_scale": scale,
            "working_policy": "conservative/low-RAM: 640x480 fixture capped to 384x288 before 4x inference (1536px long edge)",
            "warning": "Output pixel count is increased; no high-resolution ground truth exists, so super-resolution fidelity is not scored here.",
        },
    }


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
        restored_damage_error = model_metrics["damage_region_mae_0_1"]
        output_canvas = Image.open(outputs / "clean_reference_model.png").size if (outputs / "clean_reference_model.png").is_file() else original_size
        working_path = outputs / f"working_{variant}.png"
        working_input = Image.open(working_path).convert("RGB") if working_path.is_file() else Image.open(folder / f"input_{variant}.png").convert("RGB").resize((384, 288), Image.Resampling.BILINEAR)
        bicubic_output = working_input.resize(output_canvas, Image.Resampling.BICUBIC)
        bicubic_comparable = bicubic_output.resize((W, H), Image.Resampling.LANCZOS)
        bicubic_metrics = metrics(clean, bicubic_comparable, mask)
        bicubic_damage_error = bicubic_metrics["damage_region_mae_0_1"]
        results["variants"][variant]["model_output"] = {
            "path": path.name,
            "sha256": sha256(path),
            "dimensions": list(original_size),
            "metrics_after_resize_to_reference_canvas": model_metrics,
            "matched_working_size_bicubic_baseline": bicubic_metrics,
            "damage_region_error_reduction_percent_vs_bicubic": (
                100 * (bicubic_damage_error - restored_damage_error) / bicubic_damage_error
                if bicubic_damage_error else None
            ),
            "input_scale_no_op_baseline": baseline,
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
    parser.add_argument("--outputs", type=Path, help="directory for actual restored {variant}.png model outputs and panels")
    parser.add_argument("--model", type=Path, help="run this actual LiteRT model on all paired fixtures before scoring")
    parser.add_argument("--report", type=Path, help="report JSON; defaults to <out-dir>/benchmark.json")
    args = parser.parse_args()
    report = generate(args.out_dir)
    if args.model:
        if not args.outputs:
            parser.error("--model requires --outputs")
        report["inference"] = run_tiled_litert(args.model, args.out_dir, args.outputs)
    if args.outputs:
        score_outputs(args.out_dir, args.outputs, report)
    report_path = args.report or args.out_dir / "benchmark.json"
    report_path.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(json.dumps(report, indent=2, allow_nan=False))
    print(f"report: {report_path}")


if __name__ == "__main__":
    main()
