"""Frames the raw emulator captures as Play listing screenshots.

    python store/make_screenshots.py

Reads store/screenshots/raw/<class>/NN-name.png and writes the finished
listing images to store/screenshots/<class>/. Re-run after recapturing; the
raw folder is the source of truth and is never written to.

Phone captures are 1080x2424, which is steeper than the 2:1 Play allows. The
frame fixes that as a side effect: the device is composited onto a 9:16 canvas
rather than the screenshot being stretched or cropped to fit.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

from make_graphics import ACCENT, ACCENT_900, WHITE, brick_courses, font, vertical_gradient

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "store" / "screenshots"
RAW = SHOTS / "raw"

# One line per screen, in listing order. Kept to what the screen actually
# shows — a caption promising something the picture does not show is the
# fastest way to get a listing reported.
CAPTIONS = {
    "01-dashboard": "Every rupee your\nbuilding costs",
    "02-project": "Watch the total\nbuild itself",
    "03-stages": "Stage by stage,\nfloor by floor",
    "04-stage-timeline": "Every purchase,\nlogged on site",
    "05-privacy-delete": "No ads. No tracking.\nYour data stays yours.",
}

# What to build, and from which raw capture.
#
# Play: phones go to 9:16 because the 1080x2424 raws are steeper than the 2:1
# Play allows; the tablet captures are already 5:8 and keep their own shape.
#
# App Store: Apple requires 6.9" iPhone, and iPad 13" as well because the
# project targets device family "1,2". The sources are the same Android
# captures — this is one Flutter UI and it renders identically — but the
# Android status bar and gesture pill are cropped off first, so no other
# platform's chrome appears in an Apple listing. `crop` is (top, bottom) in
# source pixels.
TARGETS = {
    "phone": {"canvas": (1080, 1920), "source": "phone", "crop": None},
    "tablet7": {"canvas": (1200, 1920), "source": "tablet7", "crop": None},
    "tablet10": {"canvas": (1600, 2560), "source": "tablet10", "crop": None},
    "ios-6.9": {"canvas": (1320, 2868), "source": "phone", "crop": (132, 72)},
    "ios-ipad-13": {"canvas": (2064, 2752), "source": "tablet10", "crop": (104, 64)},
}


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius, fill=255)
    return mask


def wrap_lines(draw, text, fnt, max_width):
    """Honours the newline in CAPTIONS, then wraps anything still too wide."""
    lines = []
    for paragraph in text.split("\n"):
        words, line = paragraph.split(), ""
        for word in words:
            trial = f"{line} {word}".strip()
            if draw.textlength(trial, font=fnt) <= max_width or not line:
                line = trial
            else:
                lines.append(line)
                line = word
        lines.append(line)
    return lines


def frame(shot_path: Path, caption: str, canvas_size, crop=None) -> Image.Image:
    width, height = canvas_size
    canvas = vertical_gradient(canvas_size, ACCENT, ACCENT_900).convert("RGBA")
    canvas.alpha_composite(brick_courses(
        canvas_size, WHITE, 10,
        course_h=round(height / 56), brick_w=round(width / 10), mortar=4))

    draw = ImageDraw.Draw(canvas)

    # Headline sits in the top band; the device gets everything below it.
    title_size = round(width * 0.062)
    title_font = font("Archivo-ExtraBold.ttf", title_size)
    margin = round(width * 0.08)
    lines = wrap_lines(draw, caption, title_font, width - 2 * margin)

    line_h = round(title_size * 1.16)
    top = round(height * 0.055)
    for i, line in enumerate(lines):
        draw.text((width / 2, top + i * line_h), line, font=title_font, fill=WHITE, anchor="ma")

    header_bottom = top + len(lines) * line_h + round(height * 0.035)

    # Device, scaled to whatever room is left.
    shot = Image.open(shot_path).convert("RGB")
    if crop is not None:
        top, bottom = crop
        shot = shot.crop((0, top, shot.width, shot.height - bottom))
    avail_h = height - header_bottom - round(height * 0.045)
    avail_w = width - 2 * round(width * 0.13)
    scale = min(avail_w / shot.width, avail_h / shot.height)
    device = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)

    radius = round(device.width * 0.055)
    device.putalpha(rounded_mask(device.size, radius))

    x = (width - device.width) // 2
    # Centred in the space under the headline rather than pinned to the top of
    # it: the App Store canvases are taller than the captures, and pinning
    # leaves the whole remainder as one dead band along the bottom.
    y = header_bottom + max(0, (avail_h - device.height) // 2)

    # Shadow first, so the device reads as lifted off the gradient.
    blur = round(width * 0.02)
    shadow = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x, y + round(blur * 0.6), x + device.width, y + device.height + round(blur * 0.6)],
        radius, fill=(0, 0, 0, 120))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    canvas.alpha_composite(device, (x, y))

    return canvas.convert("RGB")


if __name__ == "__main__":
    for name, target in TARGETS.items():
        out_dir = SHOTS / name
        out_dir.mkdir(parents=True, exist_ok=True)
        for shot in sorted((RAW / target["source"]).glob("*.png")):
            caption = CAPTIONS.get(shot.stem)
            if caption is None:
                print(f"  ! no caption for {shot.stem}, skipped")
                continue
            made = frame(shot, caption, target["canvas"], target["crop"])
            made.save(out_dir / shot.name, "PNG")
            print(f"{name}/{shot.name}  {made.size[0]}x{made.size[1]}")
