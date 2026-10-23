"""Generate Ticky's logo (docs/images): a ring timer draining like a cooldown, a white mark for
each tick, a spark where it ends, and a T. Writes the icon (512, 256 and 64 px PNGs and an SVG)
and a 1200x400 banner with the wordmark and the tagline.

usage: python tools/make_logo.py <bold font .ttf> <semibold font .ttf>
       (the images in the repo used Inter Bold and Inter SemiBold, free under the SIL OFL)
needs: pip install pillow
"""
import math
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

if len(sys.argv) != 3:
    sys.exit(__doc__)
FONT_BOLD, FONT_SEMI = sys.argv[1], sys.argv[2]
OUT = pathlib.Path(__file__).resolve().parent.parent / "docs" / "images"
TOP, BOTTOM = (38, 16, 66), (9, 5, 16)
VIOLET_A, VIOLET_B = (124, 58, 237), (205, 150, 255)
TRACK = (54, 42, 76)
WHITE = (248, 244, 255)
LAVENDER = (196, 178, 240)
START, SWEEP, TICKS = -90, 280, 8


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def background(w, h, radius):
    grad = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(grad)
    for y in range(h):
        d.line([(0, y), (w, y)], fill=lerp(TOP, BOTTOM, y / (h - 1)) + (255,))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def blurred_disc(size, cx, cy, r, color, blur):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)
    return layer.filter(ImageFilter.GaussianBlur(blur))


def round_line(draw, p0, p1, width, fill):
    draw.line([p0, p1], fill=fill, width=int(width))
    for x, y in (p0, p1):
        draw.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=fill)


def dial(img, cx, cy, rc):
    """The ring centred at (cx, cy), centre-line radius rc."""
    w = rc * 0.27                      # ring width
    outer = rc + w / 2                 # PIL draws an arc's width inward from its box
    box = [cx - outer, cy - outer, cx + outer, cy + outer]

    def at(angle, r):
        a = math.radians(angle)
        return cx + r * math.cos(a), cy + r * math.sin(a)

    img.alpha_composite(blurred_disc(img.size, cx, cy, outer * 1.02, (112, 48, 205, 85), rc * 0.32))
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    d.arc(box, 0, 360, fill=TRACK, width=int(w))
    steps = SWEEP * 2
    for i in range(steps):             # the arc in short pieces, for a colour gradient along it
        a0 = START + SWEEP * i / steps
        a1 = min(START + SWEEP * (i + 1.6) / steps, START + SWEEP)
        d.arc(box, a0, a1, fill=lerp(VIOLET_A, VIOLET_B, i / steps), width=int(w))
    x, y = at(START, rc)               # round cap where it starts
    d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=VIOLET_A)
    img.alpha_composite(ring)

    ticks = Image.new("RGBA", img.size, (0, 0, 0, 0))
    td = ImageDraw.Draw(ticks)
    for i in range(TICKS):             # a mark per tick; dim where the time has run out
        ang = START + i * 360 / TICKS
        live = (ang - START) % 360 <= SWEEP
        col = WHITE + ((240,) if live else (95,))
        round_line(td, at(ang, rc - w * 0.78), at(ang, rc + w * 0.78), rc * 0.058, col)
    img.alpha_composite(ticks)

    sx, sy = at(START + SWEEP, rc)     # the spark at the arc's end
    img.alpha_composite(blurred_disc(img.size, sx, sy, w * 0.95, (196, 140, 255, 230), w * 0.45))
    img.alpha_composite(blurred_disc(img.size, sx, sy, w * 0.42, (255, 255, 255, 255), w * 0.12))

    t = Image.new("RGBA", img.size, (0, 0, 0, 0))  # the T
    tdraw = ImageDraw.Draw(t)
    bar_w, bar_h, stem_w, height = rc * 0.92, rc * 0.25, rc * 0.25, rc * 0.86
    top = cy - height / 2
    rad = rc * 0.06
    tdraw.rounded_rectangle([cx - bar_w / 2, top, cx + bar_w / 2, top + bar_h], radius=rad, fill=WHITE)
    tdraw.rounded_rectangle([cx - stem_w / 2, top, cx + stem_w / 2, top + height], radius=rad, fill=WHITE)
    img.alpha_composite(t)


def icon(px):
    k = 4
    s = px * k
    img = background(s, s, int(s * 0.22))
    dial(img, s / 2, s / 2, s * 0.315)
    return img.resize((px, px), Image.LANCZOS)


def banner(w, h):
    k = 3
    W, H = w * k, h * k
    img = background(W, H, int(H * 0.08))
    dial(img, H * 0.5, H * 0.5, H * 0.30)
    d = ImageDraw.Draw(img)
    left = H * 0.98
    big = ImageFont.truetype(FONT_BOLD, int(H * 0.40))
    small = ImageFont.truetype(FONT_SEMI, int(H * 0.095))
    d.text((left, H * 0.10), "Ticky", font=big, fill=WHITE)
    # one of Ticky's bars: a draining fill, a mark per tick, a spark at the fill's edge
    bx0, bx1 = left + H * 0.02, W - H * 0.12
    by0, by1 = H * 0.60, H * 0.665
    r = (by1 - by0) / 2
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=r, fill=TRACK)
    fill_to = bx0 + (bx1 - bx0) * 0.68
    bar = Image.new("RGBA", img.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    steps = 200
    for i in range(steps):
        x0 = bx0 + (fill_to - bx0) * i / steps
        x1 = min(bx0 + (fill_to - bx0) * (i + 1.5) / steps, fill_to)
        bd.rectangle([x0, by0, x1, by1], fill=lerp(VIOLET_A, VIOLET_B, i / steps) + (255,))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([bx0, by0, bx1, by1], radius=r, fill=255)
    clipped = Image.new("RGBA", img.size, (0, 0, 0, 0))
    clipped.paste(bar, (0, 0), Image.composite(bar.split()[3], Image.new("L", img.size, 0), mask))
    img.alpha_composite(clipped)
    n = 8
    for i in range(1, n):
        x = bx0 + (bx1 - bx0) * i / n
        col = WHITE + ((235,) if x < fill_to else (95,))
        tick = Image.new("RGBA", img.size, (0, 0, 0, 0))
        round_line(ImageDraw.Draw(tick), (x, by0 - H * 0.012), (x, by1 + H * 0.012), H * 0.008, col)
        img.alpha_composite(tick)
    sy = (by0 + by1) / 2
    img.alpha_composite(blurred_disc(img.size, fill_to, sy, H * 0.05, (196, 140, 255, 220), H * 0.025))
    img.alpha_composite(blurred_disc(img.size, fill_to, sy, H * 0.018, (255, 255, 255, 255), H * 0.006))
    d = ImageDraw.Draw(img)
    d.text((left + H * 0.01, H * 0.73), "Know every tick.", font=small, fill=LAVENDER)
    return img.resize((w, h), Image.LANCZOS)


def svg_icon(size=512):
    cx = cy = size / 2
    rc = size * 0.315
    w = rc * 0.27

    def at(angle, r):
        a = math.radians(angle)
        return cx + r * math.cos(a), cy + r * math.sin(a)

    x0, y0 = at(START, rc)
    x1, y1 = at(START + SWEEP, rc)
    large = 1 if SWEEP > 180 else 0
    ticks = []
    for i in range(TICKS):
        ang = START + i * 360 / TICKS
        live = (ang - START) % 360 <= SWEEP
        a, b = at(ang, rc - w * 0.78), at(ang, rc + w * 0.78)
        ticks.append(f'  <line x1="{a[0]:.1f}" y1="{a[1]:.1f}" x2="{b[0]:.1f}" y2="{b[1]:.1f}" '
                     f'stroke="#f8f4ff" stroke-opacity="{0.94 if live else 0.37}" '
                     f'stroke-width="{rc * 0.058:.1f}" stroke-linecap="round"/>')
    bw, bh, sw, ht = rc * 0.92, rc * 0.25, rc * 0.25, rc * 0.86
    top = cy - ht / 2
    rad = rc * 0.06
    tick_lines = "\n".join(ticks)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#26103e"/><stop offset="1" stop-color="#090510"/>
    </linearGradient>
    <linearGradient id="arc" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#7c3aed"/><stop offset="1" stop-color="#cd96ff"/>
    </linearGradient>
    <radialGradient id="halo">
      <stop offset="0.55" stop-color="#7030cd" stop-opacity="0.35"/>
      <stop offset="1" stop-color="#7030cd" stop-opacity="0"/>
    </radialGradient>
    <filter id="blur" x="-1" y="-1" width="3" height="3"><feGaussianBlur stdDeviation="{w * 0.4:.1f}"/></filter>
  </defs>
  <rect width="{size}" height="{size}" rx="{size * 0.22:.0f}" fill="url(#bg)"/>
  <circle cx="{cx}" cy="{cy}" r="{rc + w:.1f}" fill="url(#halo)"/>
  <circle cx="{cx}" cy="{cy}" r="{rc:.1f}" fill="none" stroke="#362a4c" stroke-width="{w:.1f}"/>
  <path d="M {x0:.1f} {y0:.1f} A {rc:.1f} {rc:.1f} 0 {large} 1 {x1:.1f} {y1:.1f}" fill="none"
        stroke="url(#arc)" stroke-width="{w:.1f}" stroke-linecap="round"/>
{tick_lines}
  <circle cx="{x1:.1f}" cy="{y1:.1f}" r="{w * 0.9:.1f}" fill="#c48cff" opacity="0.85" filter="url(#blur)"/>
  <circle cx="{x1:.1f}" cy="{y1:.1f}" r="{w * 0.32:.1f}" fill="#ffffff"/>
  <rect x="{cx - bw / 2:.1f}" y="{top:.1f}" width="{bw:.1f}" height="{bh:.1f}" rx="{rad:.1f}" fill="#f8f4ff"/>
  <rect x="{cx - sw / 2:.1f}" y="{top:.1f}" width="{sw:.1f}" height="{ht:.1f}" rx="{rad:.1f}" fill="#f8f4ff"/>
</svg>
'''


icon(512).save(f"{OUT}/ticky-icon-512.png")
icon(256).save(f"{OUT}/ticky-icon-256.png")
icon(64).save(f"{OUT}/ticky-icon-64.png")
banner(1200, 400).save(f"{OUT}/ticky-banner-1200x400.png")
with open(f"{OUT}/ticky-icon.svg", "w") as f:
    f.write(svg_icon())
print("done")
