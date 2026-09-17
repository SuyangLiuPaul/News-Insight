"""Generates the News Insight app icon: a flat green globe with white
grid lines, an open white book in front — the app's news-meets-Scripture
motif — on a pale green ground.

v4 (2026-09-17) — GREEN, and the point is that it is not blue.
「news insight the color is the same as yahweh's words」, and it was:
v3 sampled its palette straight out of yswords/web/icons/Icon-512.png
so the two would read as siblings on a home screen. They read as twins
instead. At 44 px on the /about page, 雅伟之言 (blue mark on pale blue)
and this one (blue mark on pale blue) are the same picture, while
雅伟之剑 (red on pale pink) and 雅伟之界 (navy on cream) are instantly
apart.

So the FAMILY is kept and the HUE is moved: still a flat illustration —
pale ground, saturated fill, white detail, dark outline of the same hue,
no gradients, no shadows — which is what actually makes these four look
related. Green rather than the warm amber of v2 because the globe app's
ground is cream, and two warm pale grounds would have swapped one
collision for another.

The app's chrome follows this file: `lib/theme/app_theme.dart` seeds
Material 3 from BLUE below, so changing the icon changes the app.

Outputs:
  icon.png            — full icon (background + foreground), 1024x1024
  icon_foreground.png — foreground only, transparent bg, for Android
                        adaptive icons (kept within the ~66% safe zone)
  preview_*.png       — small-size legibility checks

Run from anywhere: python3 assets/icon/generate_icon.py
       then: dart run flutter_launcher_icons
"""

import os

from PIL import Image, ImageDraw

# Beside THIS FILE, not beside whatever directory it was run from.
# 2026-09-17: run once from the repository root, it wrote eight PNGs
# there and left the real ones untouched — and said "wrote icon.png"
# while doing it, so nothing looked wrong until the icons in git were
# still the old colour.
HERE = os.path.dirname(os.path.abspath(__file__))


def out(name: str) -> str:
    return os.path.join(HERE, name)

SCALE = 4
SIZE = 1024 * SCALE

# How much of the drawing canvas the artwork actually spans: the open
# book is the widest element at +/-0.335 either side of centre.
ART_SPAN = 0.67

# The composition runs from the top of the globe (0.40 - 0.265 = 0.135)
# to the bottom of the book (0.83), whose midpoint is 0.4825, not 0.5 —
# so every y below is nudged down by the difference to sit optically
# centred in the tile.
ART_VSHIFT = 0.5 - (0.135 + 0.83) / 2

# Sister-app palette (sampled from Yahweh's Words Icon-512.png).
BG = (188, 232, 204, 255)        # pale green ground
BLUE = (46, 140, 90, 255)        # medium green fill
WHITE = (240, 250, 244, 255)     # near-white detail
OUTLINE = (26, 107, 66, 255)     # dark green outline


def quad_bezier(p0, p1, p2, steps=60):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t ** 2 * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t ** 2 * p2[1]
        pts.append((x, y))
    return pts


def page_path(cx, sign, half_width, spine_top, spine_bottom, outer_top, outer_bottom, curl):
    """Outline of one page (sign=+1 right, -1 left), gently curved."""
    far_x = cx + sign * half_width
    top_ctrl = (cx + sign * half_width * 0.5, spine_top - curl)
    top_edge = quad_bezier((cx, spine_top), top_ctrl, (far_x, outer_top))
    bottom_ctrl = (cx + sign * half_width * 0.5, spine_bottom + curl * 0.6)
    bottom_edge = quad_bezier((far_x, outer_bottom), bottom_ctrl, (cx, spine_bottom))
    return top_edge + bottom_edge


def draw_globe(draw, cx, cy, r, lw):
    """Flat globe: blue disc, white parallels + meridians, dark ring."""
    box = [cx - r, cy - r, cx + r, cy + r]
    draw.ellipse(box, fill=BLUE, outline=OUTLINE, width=int(lw * 1.4))

    grid_w = int(lw * 0.9)
    # Sparse grid — the sister icon's line work is minimal, and fewer
    # lines stay legible at 48px where a dense grid turns to mush.
    for frac in (-0.5, 0.0, 0.5):
        y = cy + r * frac
        half = (r * r - (y - cy) ** 2) ** 0.5 * 0.985
        draw.line([(cx - half, y), (cx + half, y)], fill=WHITE, width=grid_w)
    draw.line([(cx, cy - r * 0.985), (cx, cy + r * 0.985)], fill=WHITE, width=grid_w)
    rx = r * 0.52
    draw.ellipse([cx - rx, cy - r * 0.985, cx + rx, cy + r * 0.985],
                 outline=WHITE, width=grid_w)


def draw_book(draw, cx, s, lw):
    """Open white book with dark-blue outline, front and center."""
    half_width = s * 0.335
    spine_top = s * 0.615
    spine_bottom = s * 0.815
    outer_top = s * 0.545
    outer_bottom = s * 0.755
    curl = s * 0.035

    for sign in (1, -1):
        pts = page_path(cx, sign, half_width, spine_top, spine_bottom,
                        outer_top, outer_bottom, curl)
        draw.polygon(pts, fill=WHITE, outline=OUTLINE, width=int(lw * 1.4))
    # Spine crease.
    draw.line([(cx, spine_top), (cx, spine_bottom)], fill=OUTLINE, width=int(lw))


def build(foreground_only: bool) -> Image.Image:
    img = Image.new("RGBA", (SIZE, SIZE),
                    (0, 0, 0, 0) if foreground_only else BG)
    draw = ImageDraw.Draw(img)

    lw = SIZE * 0.010  # base line weight, matches the sister icon's strokes

    if foreground_only:
        # Android shrinks this layer TWICE before it reaches the screen:
        # flutter_launcher_icons wraps it in <inset android:inset="16%">
        # (leaving 68% of the layer), and the launcher then shows only
        # the central 66.7% safe zone. Drawing the artwork at the safe
        # zone here as well compounded to ~46% of the visible tile —
        # the icon looked shrunken next to its sister app on a home
        # screen. Sizing by the final visible result instead:
        #
        #   content_in_tile = FG_CONTENT x 0.68 / 0.667
        #
        # FG_CONTENT = 0.80 lands the artwork at ~82% of the tile:
        # 0.90 filled it edge to edge and clipped the top of the globe,
        # and this matches the breathing room the sister app's icon has
        # on the same home screen. Fixing it here rather
        # than in ic_launcher.xml, which flutter_launcher_icons
        # rewrites on every run.
        FG_CONTENT = 0.80
        s = SIZE * FG_CONTENT / ART_SPAN
        offset = (SIZE - s) / 2
    else:
        s = SIZE
        offset = 0

    cx = offset + s * 0.5
    voff = offset + s * ART_VSHIFT
    # Globe sits high, half-hidden behind the book — same composition
    # as v2 so the app stays recognizable, just flat now.
    draw_globe(draw, cx, voff + s * 0.40, s * 0.265, lw)
    # Local closure so book coordinates track the safe-zone canvas.
    half_width = s * 0.335
    spine_top = voff + s * 0.635
    spine_bottom = voff + s * 0.83
    outer_top = voff + s * 0.535
    outer_bottom = voff + s * 0.73
    curl = s * 0.06
    for sign in (1, -1):
        pts = page_path(cx, sign, half_width, spine_top, spine_bottom,
                        outer_top, outer_bottom, curl)
        draw.polygon(pts, fill=WHITE, outline=OUTLINE, width=int(lw * 1.4))
    draw.line([(cx, spine_top), (cx, spine_bottom)], fill=OUTLINE, width=int(lw))

    return img


def save_downscaled(img: Image.Image, path: str, out_size: int = 1024):
    img.resize((out_size, out_size), Image.LANCZOS).save(path)


if __name__ == "__main__":
    full = build(foreground_only=False)
    save_downscaled(full, out("icon.png"))
    print("wrote", out("icon.png"))
    fg = build(foreground_only=True)
    save_downscaled(fg, out("icon_foreground.png"))
    print("wrote", out("icon_foreground.png"))

    for size in (16, 32, 48, 96, 180):
        full.resize((size, size), Image.LANCZOS).save(out(f"preview_{size}.png"))
    strip = Image.new("RGBA", (16 + 32 + 48 + 96 + 180 + 60, 190), (255, 255, 255, 255))
    x = 10
    for size in (16, 32, 48, 96, 180):
        strip.paste(Image.open(out(f"preview_{size}.png")), (x, 185 - size - 3))
        x += size + 10
    strip.save(out("preview_strip.png"))
    print("wrote previews")
