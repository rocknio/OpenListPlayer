"""Render the 云序 logo to PNG with Pillow (no SVG renderer required).

Geometry and colors mirror yunxu_logo.svg exactly. Render at 4x then
downsample with LANCZOS for clean edges.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).parent
TERRA = (0xB8, 0x5C, 0x38, 255)
CREAM = (0xF5, 0xF2, 0xEC, 255)
INK = (0x21, 0x20, 0x1D, 255)
MUTED = (0x93, 0x8A, 0x7E, 255)
S = 4  # supersample factor


def draw_icon(size: int, solid: bool = False) -> Image.Image:
    """Draw the app icon. solid=True fills the whole canvas (opaque launcher icon)."""
    k = S
    canvas = size * k
    img = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def sc(v: float) -> int:
        return int(v * size / 512 * k)

    # background: full square for launcher icons, squircle for preview art
    if solid:
        d.rectangle([0, 0, canvas - 1, canvas - 1], fill=TERRA)
    else:
        d.rounded_rectangle([0, 0, canvas - 1, canvas - 1], radius=sc(112), fill=TERRA)

    # cloud: three circles + rounded base bar
    d.ellipse([sc(196 - 58), sc(248 - 58), sc(196 + 58), sc(248 + 58)], fill=CREAM)
    d.ellipse([sc(256 - 82), sc(218 - 82), sc(256 + 82), sc(218 + 82)], fill=CREAM)
    d.ellipse([sc(330 - 54), sc(252 - 54), sc(330 + 54), sc(252 + 54)], fill=CREAM)
    d.rounded_rectangle([sc(196), sc(248), sc(330), sc(306)], radius=sc(29), fill=CREAM)

    # play triangle carved out in terra
    d.polygon([(sc(236), sc(188)), (sc(236), sc(268)), (sc(306), sc(228))], fill=TERRA)

    # ascending bars
    for x, w in ((176, 26), (210, 40), (256, 54)):
        d.rounded_rectangle([sc(x), sc(348), sc(x + w), sc(358)], radius=sc(5), fill=CREAM)

    return img.resize((size, size), Image.LANCZOS)


def draw_wordmark() -> Image.Image:
    w, h = 900, 280
    img = Image.new("RGBA", (w * S, h * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    icon = draw_icon(210)
    img.alpha_composite(icon, (24 * S, 34 * S))

    def font(path: str, px: int) -> ImageFont.FreeTypeFont:
        return ImageFont.truetype(path, px * S)

    zh = font("C:/Windows/Fonts/msyhbd.ttc", 82)
    en = font("C:/Windows/Fonts/arial.ttf", 28)
    sl = font("C:/Windows/Fonts/msyh.ttc", 20)

    # Pillow text y is the top edge (ascender anchor), not the baseline.
    d.text((256 * S, 58 * S), "云序", font=zh, fill=INK, spacing=0)
    d.text((262 * S, 158 * S), "Y U N X U", font=en, fill=TERRA)
    d.text((262 * S, 208 * S), "云端有序，续播无忧", font=sl, fill=MUTED)

    return img.resize((w, h), Image.LANCZOS)


if __name__ == "__main__":
    for size in (512, 192, 180, 120):
        draw_icon(size).save(OUT / f"yunxu_{size}.png")
        print(f"wrote yunxu_{size}.png")
    draw_wordmark().save(OUT / "yunxu_wordmark.png")
    print("wrote yunxu_wordmark.png")
