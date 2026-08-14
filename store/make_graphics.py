"""Generates the Play listing graphics from the app's own icon and brand tokens.

    python store/make_graphics.py

Rerun it after changing icon.png or the accent in lib/core/tokens.dart, so the
listing never drifts from the app. Outputs land in store/.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store"
FONTS = ROOT / "assets" / "fonts"

# lib/core/tokens.dart — the app's own ramp, so the listing matches the screens.
ACCENT = (0x02, 0x4C, 0x7D)
ACCENT_800 = (0x01, 0x25, 0x40)
ACCENT_900 = (0x07, 0x19, 0x28)
WHITE = (0xFF, 0xFF, 0xFF)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def vertical_gradient(size, top, bottom):
    """A gradient drawn a row at a time — no numpy needed for 500 rows."""
    width, height = size
    base = Image.new("RGB", (1, height))
    pixels = base.load()
    for y in range(height):
        t = y / max(height - 1, 1)
        pixels[0, y] = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
    return base.resize((width, height), Image.BILINEAR)


def brick_courses(size, colour, alpha, course_h=34, brick_w=104, mortar=4):
    """The faint running bond behind the wordmark — the app is about building."""
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    fill = colour + (alpha,)
    width, height = size
    for row, y in enumerate(range(-course_h, height + course_h, course_h)):
        offset = 0 if row % 2 == 0 else brick_w // 2
        for x in range(-brick_w, width + brick_w, brick_w):
            draw.rectangle(
                [x + offset, y, x + offset + brick_w - mortar, y + course_h - mortar],
                fill=fill,
            )
    return layer


def store_icon():
    """512x512, flattened onto white.

    Play masks the icon to a rounded shape on some surfaces, so the artwork is
    inset rather than run to the edge, and the transparency the launcher icon
    relies on is filled in — a store icon should not show the page behind it.
    """
    art = Image.open(ROOT / "icon.png").convert("RGBA")
    canvas = Image.new("RGB", (512, 512), WHITE)

    inset = round(512 * 0.80)
    art = art.resize((inset, inset), Image.LANCZOS)
    canvas.paste(art, ((512 - inset) // 2, (512 - inset) // 2), art)

    path = OUT / "app-icon-512.png"
    canvas.save(path, "PNG")
    return path


def feature_graphic():
    """1024x500, no transparency, nothing important near the edges.

    Play crops this differently across surfaces and sometimes lays its own text
    over it, so the mark and the line sit in the middle band.
    """
    size = (1024, 500)
    canvas = vertical_gradient(size, ACCENT, ACCENT_900).convert("RGBA")
    canvas.alpha_composite(brick_courses(size, WHITE, 12))

    draw = ImageDraw.Draw(canvas)

    art = Image.open(ROOT / "icon.png").convert("RGBA")
    mark = 132
    art = art.resize((mark, mark), Image.LANCZOS)

    word_font = font("Archivo-ExtraBold.ttf", 86)
    tag_font = font("Archivo-Regular.ttf", 31)

    word = "BUNYAD"
    word_w = draw.textlength(word, font=word_font)
    gap = 26
    block_w = mark + gap + word_w
    left = (1024 - block_w) / 2
    top = 150

    canvas.alpha_composite(art, (round(left), round(top + 4)))
    draw.text(
        (left + mark + gap, top + mark / 2),
        word,
        font=word_font,
        fill=WHITE,
        anchor="lm",
    )

    tagline = "Every rupee your building costs, in one book."
    draw.text((512, 352), tagline, font=tag_font, fill=(0xD8, 0xE9, 0xF8), anchor="mm")

    path = OUT / "feature-graphic-1024x500.png"
    canvas.convert("RGB").save(path, "PNG")
    return path


if __name__ == "__main__":
    for made in (store_icon(), feature_graphic()):
        with Image.open(made) as check:
            print(f"{made.relative_to(ROOT)}  {check.size[0]}x{check.size[1]}  {check.mode}")
