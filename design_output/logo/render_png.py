"""Render the 云序「声环留声」logo to PNG with Pillow (no SVG renderer required).

Geometry and colors mirror yunxu_logo.svg / yunxu_logo_compact.svg exactly.
Render at 4x then downsample with LANCZOS for crisp anti-aliased edges.
"""

import math
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent

PAPER_TOP = (0xFC, 0xFB, 0xF8)
PAPER_BOT = (0xF2, 0xEC, 0xE2)
BORDER = (0xE5, 0xDD, 0xD0, 255)
TERRA = (0xB8, 0x5C, 0x38)
ACCENT_TOP = (0xCE, 0x6D, 0x43)
ACCENT_BOT = (0xA6, 0x4D, 0x2A)
INK = (0x21, 0x20, 0x1D, 255)
MUTED = (0x8A, 0x80, 0x74, 255)

S = 4  # supersample factor


def _lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return (
        int(round(c1[0] + (c2[0] - c1[0]) * t)),
        int(round(c1[1] + (c2[1] - c1[1]) * t)),
        int(round(c1[2] + (c2[2] - c1[2]) * t)),
    )


def _make_vertical_gradient(size: int, top: tuple[int, int, int], bot: tuple[int, int, int]) -> Image.Image:
    """Create a vertical linear gradient RGBA image."""
    strip = Image.new("RGBA", (1, size))
    px = strip.load()
    denom = max(1, size - 1)
    for y in range(size):
        r, g, b = _lerp_color(top, bot, y / denom)
        px[0, y] = (r, g, b, 255)
    return strip.resize((size, size), Image.NEAREST)


def _draw_rounded_arc(
    layer: Image.Image,
    cx: float,
    cy: float,
    radius: float,
    stroke: float,
    start_deg: float,
    end_deg: float,
    color: tuple[int, int, int, int],
) -> None:
    """Draw a smooth circular arc with true circular round caps on an RGBA layer."""
    d = ImageDraw.Draw(layer)
    half = stroke / 2.0
    # Sample densely along the arc and stamp circles so thickness & caps are uniform
    span = abs(end_deg - start_deg)
    steps = max(120, int(span * 2.5))
    for i in range(steps + 1):
        ang = math.radians(start_deg + (end_deg - start_deg) * (i / steps))
        x = cx + radius * math.cos(ang)
        y = cy + radius * math.sin(ang)
        d.ellipse([x - half, y - half, x + half, y + half], fill=color)


def _cubic_bezier(
    p0: tuple[float, float],
    p1: tuple[float, float],
    p2: tuple[float, float],
    p3: tuple[float, float],
    steps: int = 24,
) -> list[tuple[float, float]]:
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1.0 - t
        x = mt**3 * p0[0] + 3 * mt**2 * t * p1[0] + 3 * mt * t**2 * p2[0] + t**3 * p3[0]
        y = mt**3 * p0[1] + 3 * mt**2 * t * p1[1] + 3 * mt * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def _rounded_play_polygon(compact: bool, scale: float) -> list[tuple[float, float]]:
    """Mirror the exact SVG cubic-bezier rounded play triangle."""
    if compact:
        # M 232 204 C 232 195 242 189 250 194 L 320 244 C 328 249 328 263 320 268 L 250 318 C 242 323 232 317 232 308 Z
        segs = [
            ((232, 204), (232, 195), (242, 189), (250, 194)),
            ((320, 244), (328, 249), (328, 263), (320, 268)),
            ((250, 318), (242, 323), (232, 317), (232, 308)),
        ]
    else:
        # M 239 218 C 239 210 248 205 255 209 L 311 247 C 318 251 318 261 311 265 L 255 303 C 248 307 239 302 239 294 Z
        segs = [
            ((239, 218), (239, 210), (248, 205), (255, 209)),
            ((311, 247), (318, 251), (318, 261), (311, 265)),
            ((255, 303), (248, 307), (239, 302), (239, 294)),
        ]
    pts: list[tuple[float, float]] = []
    for p0, p1, p2, p3 in segs:
        pts.extend(_cubic_bezier(p0, p1, p2, p3, steps=20))
    return [(x * scale, y * scale) for x, y in pts]


def draw_icon(size: int, solid: bool = False, compact: bool | None = None) -> Image.Image:
    """Draw the 声环留声 app icon.

    - solid=True: full square opaque background (Android mipmap / iOS AppIcon).
    - solid=False: squircle rounded corners + subtle border (preview art / wordmark).
    - compact: auto-enabled for size <= 32 when None.
    """
    if compact is None:
        compact = size <= 32

    canvas = size * S
    scale = canvas / 512.0

    bg = _make_vertical_gradient(canvas, PAPER_TOP, PAPER_BOT)
    if solid:
        img = bg
    else:
        img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        mask = Image.new("L", (canvas, canvas), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, canvas - 1, canvas - 1],
            radius=int(round(114 * scale)),
            fill=255,
        )
        img.paste(bg, (0, 0), mask)
        # Subtle warm sand border on squircle preview
        ImageDraw.Draw(img).rounded_rectangle(
            [2 * scale, 2 * scale, canvas - 1 - 2 * scale, canvas - 1 - 2 * scale],
            radius=int(round(112 * scale)),
            outline=BORDER,
            width=max(1, int(round(4 * scale))),
        )

    cx = 256.0 * scale
    cy = 256.0 * scale

    if compact:
        # Single thick open ring (r=138, stroke=34, alpha=55%, opening right -42°..+42°)
        ring = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        _draw_rounded_arc(
            ring,
            cx,
            cy,
            radius=138.0 * scale,
            stroke=34.0 * scale,
            start_deg=42.0,
            end_deg=318.0,
            color=(*TERRA, int(round(255 * 0.55))),
        )
        img = Image.alpha_composite(img, ring)
    else:
        # Outer ring (r=146, stroke=22, alpha=30%, opening right -41°..+41°)
        outer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        _draw_rounded_arc(
            outer,
            cx,
            cy,
            radius=146.0 * scale,
            stroke=22.0 * scale,
            start_deg=41.0,
            end_deg=319.0,
            color=(*TERRA, int(round(255 * 0.30))),
        )
        img = Image.alpha_composite(img, outer)

        # Inner ring (r=94, stroke=22, alpha=66%, opening right -46°..+46°)
        inner = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
        _draw_rounded_arc(
            inner,
            cx,
            cy,
            radius=94.0 * scale,
            stroke=22.0 * scale,
            start_deg=46.0,
            end_deg=314.0,
            color=(*TERRA, int(round(255 * 0.66))),
        )
        img = Image.alpha_composite(img, inner)

    # Center rounded play triangle with subtle diagonal terracotta gradient
    poly = _rounded_play_polygon(compact=compact, scale=scale)
    play_mask = Image.new("L", (canvas, canvas), 0)
    ImageDraw.Draw(play_mask).polygon(poly, fill=255)
    play_fill = _make_vertical_gradient(canvas, ACCENT_TOP, ACCENT_BOT)
    play_layer = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    play_layer.paste(play_fill, (0, 0), play_mask)
    img = Image.alpha_composite(img, play_layer)

    return img.resize((size, size), Image.LANCZOS)


def _load_font(candidates: Iterable[str], px: int) -> ImageFont.FreeTypeFont:
    for p in candidates:
        if Path(p).exists():
            return ImageFont.truetype(p, px)
    return ImageFont.load_default()


def draw_wordmark() -> Image.Image:
    w, h = 900, 280
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    icon = draw_icon(210 * S, solid=False, compact=False)
    img.alpha_composite(icon, (24 * S, 34 * S))

    zh = _load_font(
        [
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "C:/Windows/Fonts/msyhbd.ttc",
        ],
        82 * S,
    )
    en = _load_font(
        [
            "/System/Library/Fonts/Helvetica.ttc",
            "/Library/Fonts/Arial Unicode.ttf",
            "C:/Windows/Fonts/arial.ttf",
        ],
        28 * S,
    )
    sl = _load_font(
        [
            "/System/Library/Fonts/STHeiti Light.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "C:/Windows/Fonts/msyh.ttc",
        ],
        20 * S,
    )

    d.text((256 * S, 58 * S), "云序", font=zh, fill=INK, spacing=0)
    d.text((262 * S, 158 * S), "Y U N X U", font=en, fill=(*TERRA, 255))
    d.text((262 * S, 208 * S), "云端有序，续播无忧", font=sl, fill=MUTED)

    return img.resize((w, h), Image.LANCZOS)


if __name__ == "__main__":
    for size in (512, 192, 180, 120):
        draw_icon(size, solid=False).save(OUT / f"yunxu_{size}.png")
        print(f"wrote yunxu_{size}.png")
    draw_wordmark().save(OUT / "yunxu_wordmark.png")
    print("wrote yunxu_wordmark.png")
