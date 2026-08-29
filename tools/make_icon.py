"""
Derives the launcher icons from the supplied artwork.

Two files are produced, and they are not the same picture:

  assets/icon/icon.png        the artwork whole, for iOS, the web and older
                              Android launchers, which show a square
  assets/icon/foreground.png  the medallion alone on transparency, for
                              Android's adaptive icon

The split is forced by how Android draws an icon. The launcher crops the
foreground layer to whatever shape the device uses — a circle, a squircle, a
rounded square — and only the middle two-thirds of the canvas is guaranteed to
survive. Handing it the whole artwork would cut the ornamented border and bite
into the gold ring, which is the part that makes the mark recognisable. So the
medallion is cut out, dropped to the safe size, and left to sit on the app's
black.

Regenerate with:
    python3 tools/make_icon.py && dart run flutter_launcher_icons
"""
from PIL import Image, ImageDraw

SIZE = 1024

# The medallion, measured off the artwork by walking in from each edge until
# the bright gold of the ring gives way to the dark scene inside it.
CENTRE = (512, 512)
RADIUS = 460

# How much of the adaptive canvas the medallion may fill. Android guarantees
# the middle 66%; a little under that keeps the ring clear of every mask.
SAFE = 0.68

SOURCE = "assets/icon/artwork.jpg"
MASTER = "assets/icon/icon.png"
FOREGROUND = "assets/icon/foreground.png"
STORE = "assets/icon/play-store-512.png"


def main() -> None:
    art = Image.open(SOURCE).convert("RGB")
    if art.size != (SIZE, SIZE):
        art = art.resize((SIZE, SIZE), Image.LANCZOS)

    # Whole, and flat: iOS refuses an icon carrying an alpha channel.
    art.save(MASTER)
    art.resize((512, 512), Image.LANCZOS).save(STORE)

    # The medallion, cut to its circle. Masked at four times the size and then
    # brought down, which is what keeps the cut edge smooth rather than
    # stepped.
    scale = 4
    mask = Image.new("L", (SIZE * scale, SIZE * scale), 0)
    ImageDraw.Draw(mask).ellipse(
        [
            (CENTRE[0] - RADIUS) * scale,
            (CENTRE[1] - RADIUS) * scale,
            (CENTRE[0] + RADIUS) * scale,
            (CENTRE[1] + RADIUS) * scale,
        ],
        fill=255,
    )
    mask = mask.resize((SIZE, SIZE), Image.LANCZOS)

    cut = art.copy()
    cut.putalpha(mask)
    cut = cut.crop(
        (
            CENTRE[0] - RADIUS,
            CENTRE[1] - RADIUS,
            CENTRE[0] + RADIUS,
            CENTRE[1] + RADIUS,
        )
    )

    inner = round(SIZE * SAFE)
    cut = cut.resize((inner, inner), Image.LANCZOS)

    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    canvas.paste(cut, ((SIZE - inner) // 2, (SIZE - inner) // 2), cut)
    canvas.save(FOREGROUND)

    print(f"wrote {MASTER}, {FOREGROUND}, {STORE}")


if __name__ == "__main__":
    main()
