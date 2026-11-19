#!/usr/bin/env python3
"""Deterministically render the PIXORA brand assets (icons + splash mark).

The PIXORA mark is a four-point sparkle with concave sides (an "astroid"
superellipse) that reads as both a light/sparkle of enhancement and the
aperture of a lens. Rendering it from math keeps the icon pixel-crisp and
perfectly centred at every density, and makes the artwork reproducible.

Usage:
    python3 tool/generate_brand_assets.py

Outputs (all paths relative to the repository root):
    android/app/src/main/res/mipmap-*/ic_launcher.png              legacy icons
    android/app/src/main/res/mipmap-*/ic_launcher_foreground.png   adaptive icons
    android/app/src/main/res/drawable-nodpi/launch_logo.png        splash mark
    assets/branding/pixora_icon_512.png                            store artwork
    assets/branding/pixora_icon_1024.png                           master artwork
"""

import math
import os
import struct
import zlib

# --- Brand palette -----------------------------------------------------------
BRAND_CENTER = (0x74, 0x62, 0xF8)
BRAND_EDGE = (0x41, 0x33, 0xC6)
WHITE = (0xFF, 0xFF, 0xFF)

EXPO = 0.55  # < 1 gives concave sides; 0.5 would be a pure astroid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _clamp(value, low=0.0, high=1.0):
    return low if value < low else high if value > high else value


def _lerp(a, b, t):
    return a + (b - a) * t


def _smoothstep(edge0, edge1, x):
    if edge1 == edge0:
        return 0.0
    t = _clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def _sparkle_sdf(x, y, half, scale):
    """Signed distance (in pixels) to the PIXORA sparkle outline.

    ``x``/``y`` are pixel offsets from the canvas centre, ``half`` is half the
    canvas size and ``scale`` is the mark diameter as a fraction of the canvas.
    """
    radius = half * scale
    if radius <= 0.0:
        return 1e9
    u = abs(x) / radius
    v = abs(y) / radius
    if u < 1e-9 and v < 1e-9:
        return -radius
    q = u**EXPO + v**EXPO
    gu = EXPO * (u ** (EXPO - 1.0)) if u > 1e-9 else 0.0
    gv = EXPO * (v ** (EXPO - 1.0)) if v > 1e-9 else 0.0
    gradient = math.hypot(gu, gv) / radius
    if gradient < 1e-12:
        return 1e9
    # (q - 1) / |grad| is a first-order distance in pixels.
    return (q - 1.0) / gradient


def _rounded_rect_sdf(x, y, half, radius):
    qx = abs(x) - (half - radius)
    qy = abs(y) - (half - radius)
    ax = max(qx, 0.0)
    ay = max(qy, 0.0)
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - radius


def _background(x, y, half):
    radial = _clamp(math.hypot(x, y) / (half * 1.18))
    diagonal = _clamp(((x + y) / (2.0 * half) + 1.0) / 2.0)
    t = _clamp(0.78 * _smoothstep(0.0, 1.0, radial) + 0.22 * (1.0 - diagonal))
    return (
        int(round(_lerp(BRAND_CENTER[0], BRAND_EDGE[0], t))),
        int(round(_lerp(BRAND_CENTER[1], BRAND_EDGE[1], t))),
        int(round(_lerp(BRAND_CENTER[2], BRAND_EDGE[2], t))),
    )


def render(size, glyph_scale, corner_radius=0.0, transparent=False):
    """Render one square RGBA image as a bytearray of size*size*4."""
    half = size / 2.0
    radius_px = corner_radius * size
    buffer = bytearray(size * size * 4)
    for py in range(size):
        y = py + 0.5 - half
        row = py * size * 4
        for px in range(size):
            x = px + 0.5 - half
            glyph = _clamp(0.5 - _sparkle_sdf(x, y, half, glyph_scale))
            if transparent:
                r = g = b = WHITE[0]
                a = glyph
            else:
                r, g, b = _background(x, y, half)
                r = int(round(_lerp(r, WHITE[0], glyph)))
                g = int(round(_lerp(g, WHITE[1], glyph)))
                b = int(round(_lerp(b, WHITE[2], glyph)))
                a = 1.0
            if radius_px > 0.0:
                a *= _clamp(0.5 - _rounded_rect_sdf(x, y, half, radius_px))
            index = row + px * 4
            buffer[index] = r
            buffer[index + 1] = g
            buffer[index + 2] = b
            buffer[index + 3] = int(round(_clamp(a) * 255.0))
    return buffer


def write_png(path, size, pixels):
    raw = bytearray()
    stride = size * 4
    for row in range(size):
        raw.append(0)  # filter type: none
        raw.extend(pixels[row * stride:(row + 1) * stride])

    def chunk(tag, payload):
        body = tag + payload
        return (
            struct.pack(">I", len(payload))
            + body
            + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)
        )

    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    data = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(data)
    print("wrote {} ({}x{})".format(os.path.relpath(path, ROOT), size, size))


def main():
    res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    densities = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    for density, size in densities.items():
        # Legacy launcher icon: rounded square, mark fills 56% of the canvas.
        write_png(
            os.path.join(res, "mipmap-" + density, "ic_launcher.png"),
            size,
            render(size, 0.56, corner_radius=0.225),
        )
        # Adaptive foreground: full bleed, mark inside the 66% safe zone.
        adaptive = int(round(size * 108.0 / 48.0))
        write_png(
            os.path.join(res, "mipmap-" + density, "ic_launcher_foreground.png"),
            adaptive,
            render(adaptive, 0.50),
        )

    write_png(
        os.path.join(res, "drawable-nodpi", "launch_logo.png"),
        384,
        render(384, 0.94, transparent=True),
    )
    write_png(
        os.path.join(ROOT, "assets", "branding", "pixora_icon_512.png"),
        512,
        render(512, 0.56, corner_radius=0.225),
    )
    write_png(
        os.path.join(ROOT, "assets", "branding", "pixora_icon_1024.png"),
        1024,
        render(1024, 0.56, corner_radius=0.225),
    )


if __name__ == "__main__":
    main()
