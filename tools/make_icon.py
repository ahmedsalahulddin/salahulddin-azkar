"""
Draws the launcher icon: a rub' el hizb — the eight-pointed star that marks
divisions in the Mushaf — in the app's gold on its near-black.

Two files are produced:
  icon_master.png      full-bleed, for legacy launchers, iOS and the web
  icon_foreground.png  transparent, for Android's adaptive icon

The adaptive foreground is drawn smaller on purpose: launchers crop that layer
to a circle, a squircle or a rounded square depending on the device, and only
the middle two-thirds is guaranteed to survive.
"""
import math
from PIL import Image, ImageDraw

SIZE = 1024
GOLD = (212, 168, 67)
GOLD_DEEP = (184, 134, 11)
INK = (13, 13, 13)
NAVY = (22, 35, 61)


def star_points(cx, cy, outer, inner, points=8, rotation=0.0):
    """Alternating outer/inner vertices — an eight-pointed star."""
    verts = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = rotation + i * math.pi / points
        verts.append((cx + r * math.sin(a), cy - r * math.cos(a)))
    return verts


def vertical_gradient(size, top, bottom):
    grad = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        grad.putpixel(
            (0, y),
            tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)),
        )
    return grad.resize((size, size))


def square(cx, cy, half_diagonal, rotation):
    """A square given by its centre and the distance to a corner."""
    return [
        (
            cx + half_diagonal * math.sin(rotation + i * math.pi / 2),
            cy - half_diagonal * math.cos(rotation + i * math.pi / 2),
        )
        for i in range(4)
    ]


def draw_star(draw, cx, cy, outer, stroke_ratio=0.075):
    """The rub' el hizb: two squares crossed at 45°, as printed in the Mushaf.

    An eight-pointed star with spikes was tried first and read as a sun or a
    compass rose. The two-square construction is the actual Mushaf mark, and
    stays legible when a launcher shrinks it to a few dozen pixels.
    """
    stroke = max(2, int(outer * stroke_ratio))

    for rotation in (0.0, math.pi / 4):
        draw.polygon(
            square(cx, cy, outer, rotation),
            outline=GOLD,
            width=stroke,
        )

    # The disc that sits at the centre of the printed mark.
    r = outer * 0.17
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD)


def build(path, *, background, scale, border):
    if background:
        img = vertical_gradient(SIZE, NAVY, INK).convert("RGBA")
    else:
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Draw oversampled, then downsample: PIL has no anti-aliasing for polygons.
    ss = 4
    layer = Image.new("RGBA", (SIZE * ss, SIZE * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = SIZE * ss / 2
    draw_star(d, c, c, SIZE * ss * scale / 2)

    if border:
        inset = SIZE * ss * 0.055
        d.rounded_rectangle(
            [inset, inset, SIZE * ss - inset, SIZE * ss - inset],
            radius=SIZE * ss * 0.14,
            outline=GOLD_DEEP,
            width=int(SIZE * ss * 0.012),
        )

    layer = layer.resize((SIZE, SIZE), Image.LANCZOS)
    img.alpha_composite(layer)
    img.save(path)
    print(f"wrote {path}")


# Full bleed for legacy launchers, iOS and the web.
build("icon_master.png", background=True, scale=0.56, border=True)

# Adaptive foreground: no background, and small enough to survive cropping.
build("icon_foreground.png", background=False, scale=0.42, border=False)
