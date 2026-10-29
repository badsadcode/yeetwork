"""Generates the menu's button and panel art (nine-patch PNGs) into assets/ui/.

Chunky, beveled, chamfered toy-like plates in the style of the title art: a dark outline,
a vertical gradient body, a light rim on top, a darker lip underneath and little rivets.
Everything is drawn 4x larger and scaled down for smooth edges.

    python tools/make_ui_art.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(__file__).resolve().parent.parent / "assets" / "ui"
SS = 4  # supersampling

BUTTONS = {
    "yellow": (255, 196, 46),
    "blue": (46, 122, 240),
    "red": (238, 64, 74),
    "grey": (78, 86, 104),
    "green": (70, 200, 96),
}
OUTLINE = (24, 26, 40)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def chamfer_poly(x0, y0, x1, y1, c):
    return [(x0 + c, y0), (x1 - c, y0), (x1, y0 + c), (x1, y1 - c), (x1 - c, y1), (x0 + c, y1), (x0, y1 - c), (x0, y0 + c)]


def vgrad(size, top, bottom):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        g.putpixel((0, y), mix(top, bottom, y / max(h - 1, 1)))
    return g.resize((w, h))


def plate(w, h, base, state):
    """One button plate: normal, hover (brighter) or pressed (darker, lip squashed)."""
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lift = {"normal": 0.0, "hover": 0.1, "pressed": -0.12}[state]
    col = mix(base, (255, 255, 255), lift) if lift > 0 else mix(base, (0, 0, 0), -lift)
    c = 9 * SS
    lip = (3 if state == "pressed" else 7) * SS
    pad = 2 * SS
    top = pad + (4 * SS if state == "pressed" else 0)
    # Drop shadow.
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon(chamfer_poly(pad, top + 3 * SS, W - pad, H - pad + 2 * SS, c), fill=(0, 0, 0, 90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3 * SS)))
    d = ImageDraw.Draw(img)
    # Outline + darker lip (the bottom "thickness" of the plate).
    d.polygon(chamfer_poly(pad, top, W - pad, H - pad, c), fill=OUTLINE + (255,))
    o = 3 * SS
    d.polygon(chamfer_poly(pad + o, top + o, W - pad - o, H - pad - o, c - o // 2), fill=mix(col, (0, 0, 0), 0.38) + (255,))
    # Body with a vertical gradient.
    body_box = (pad + o, top + o, W - pad - o, H - pad - o - lip)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(chamfer_poly(*body_box, c - o // 2), fill=255)
    g = vgrad((W, H), mix(col, (255, 255, 255), 0.28), mix(col, (0, 0, 0), 0.12))
    img.paste(g, (0, 0), mask)
    # Glossy band on the upper half and a light rim along the top edge.
    gloss = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gb = (body_box[0] + 4 * SS, body_box[1] + 3 * SS, body_box[2] - 4 * SS, body_box[1] + (body_box[3] - body_box[1]) * 0.42)
    ImageDraw.Draw(gloss).polygon(chamfer_poly(*[int(v) for v in gb], c // 2), fill=(255, 255, 255, 48))
    img.alpha_composite(gloss)
    rim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(rim).line([(body_box[0] + c, body_box[1] + SS), (body_box[2] - c, body_box[1] + SS)], fill=(255, 255, 255, 150), width=2 * SS)
    img.alpha_composite(rim)
    # Rivets at both ends.
    cy = (body_box[1] + body_box[3]) // 2
    for cx in (body_box[0] + 9 * SS, body_box[2] - 9 * SS):
        r = 3 * SS
        d.ellipse((cx - r, cy - r + SS, cx + r, cy + r + SS), fill=mix(col, (0, 0, 0), 0.45) + (255,))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=mix(col, (255, 255, 255), 0.55) + (255,))
    return img.resize((w, h), Image.LANCZOS)


def panel(w, h):
    """Dark slate panel with a riveted metal frame and yellow corner trims."""
    W, H = w * SS, h * SS
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pad = 3 * SS
    c = 16 * SS
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).polygon(chamfer_poly(pad, pad + 4 * SS, W - pad, H - pad, c), fill=(0, 0, 0, 110))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4 * SS)))
    d = ImageDraw.Draw(img)
    d.polygon(chamfer_poly(pad, pad, W - pad, H - pad - 2 * SS, c), fill=OUTLINE + (255,))
    # Metal frame.
    o = 3 * SS
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(chamfer_poly(pad + o, pad + o, W - pad - o, H - pad - 2 * SS - o, c - o // 2), fill=255)
    img.paste(vgrad((W, H), (214, 220, 232), (120, 128, 146)), (0, 0), mask)
    # Yellow trims along the top and bottom edges (inside the corners).
    trim = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(trim)
    t = 9 * SS
    td.polygon(chamfer_poly(pad + o, pad + o, W - pad - o, pad + o + t + c // 2, c - o // 2), fill=(255, 196, 46, 255))
    td.rectangle((pad + o, pad + o + t, W - pad - o, pad + o + t + c), fill=(0, 0, 0, 0))
    img.alpha_composite(trim)
    # Inner dark screen.
    f = 11 * SS
    inner = chamfer_poly(pad + f, pad + f + 4 * SS, W - pad - f, H - pad - f - 2 * SS, c - f // 2)
    d.polygon(inner, fill=OUTLINE + (255,))
    mask2 = Image.new("L", (W, H), 0)
    i2 = chamfer_poly(pad + f + 2 * SS, pad + f + 6 * SS, W - pad - f - 2 * SS, H - pad - f - 4 * SS, c - f // 2)
    ImageDraw.Draw(mask2).polygon(i2, fill=255)
    img.paste(vgrad((W, H), (46, 52, 66), (30, 34, 46)), (0, 0), mask2)
    # Bolts in the frame corners.
    m = pad + o + 4 * SS  # middle of the metal frame
    for bx, by in ((m + 10 * SS, m + 10 * SS), (W - m - 10 * SS, m + 10 * SS), (m + 10 * SS, H - m - 12 * SS), (W - m - 10 * SS, H - m - 12 * SS)):
        r = 3 * SS
        d.ellipse((bx - r, by - r + SS, bx + r, by + r + SS), fill=(70, 76, 92, 255))
        d.ellipse((bx - r, by - r, bx + r, by + r), fill=(236, 240, 248, 255))
        d.line([(bx - r // 2, by), (bx + r // 2, by)], fill=(110, 118, 134, 255), width=SS)
    return img.resize((w, h), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, col in BUTTONS.items():
        for state in ("normal", "hover", "pressed"):
            plate(192, 72, col, state).save(OUT / f"button_{name}_{state}.png")
    panel(256, 256).save(OUT / "panel.png")
    print("wrote", len(BUTTONS) * 3 + 1, "images to", OUT)


if __name__ == "__main__":
    main()
