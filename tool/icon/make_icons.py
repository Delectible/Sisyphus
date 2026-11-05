"""Generates every Sisyphus launcher / store icon from one drawing.

    python3 tool/icon/make_icons.py        (needs Pillow + numpy)

The mark: the boulder, a shaded stone sphere, resting on the crest of a
slope against a terracotta sky, like a black-figure vase painting with a
little more light in it.

Writes:
  Android  adaptive icon (background colour, foreground, monochrome for
           Android 13+ themed icons), legacy icon for API 24-25, status-bar
           notification glyph, launch-screen mark.
  iOS      single-size 1024 AppIcon.
  Play     512 icon + 1024x500 feature graphic (fastlane/metadata/android/en-AU/images).
  GitHub   docs/social_preview.png (1280x640).
"""
import json, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SS = 4
CLAY_TOP, CLAY_BOT = (214, 124, 82), (164, 72, 42)
INK = (30, 23, 20)
STONE_LIT, STONE_MID, STONE_DARK = (226, 214, 196), (139, 128, 116), (40, 34, 32)


def sphere(D, light=(-0.5, -0.6, 0.62)):
    """RGBA shaded stone of diameter D (supersampled by caller)."""
    y, x = np.mgrid[0:D, 0:D].astype(np.float32)
    r = D / 2
    nx, ny = (x - r + 0.5) / r, (y - r + 0.5) / r
    rr = nx * nx + ny * ny
    inside = rr <= 1
    nz = np.sqrt(np.clip(1 - rr, 0, 1))
    L = np.array(light, np.float32)
    L /= np.linalg.norm(L)
    lam = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    # Speckled granite: cheap value noise at a few scales.
    rng = np.random.default_rng(7)
    noise = np.zeros_like(nx)
    for scale, amp in ((6, 0.5), (14, 0.3), (40, 0.2)):
        g = rng.random((scale, scale)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((D, D), Image.BICUBIC)
        noise += amp * (np.asarray(img, np.float32) / 255)
    lam = np.clip(lam * (0.86 + 0.28 * noise), 0, 1)
    lit, mid, dark = (np.array(c, np.float32) for c in (STONE_LIT, STONE_MID, STONE_DARK))
    t = lam[..., None]
    col = np.where(t > 0.5, mid + (lit - mid) * ((t - 0.5) * 2), dark + (mid - dark) * (t * 2))
    # Warm bounce light from below-right and a dark rim.
    bounce = np.clip(ny * 0.7 + nx * 0.3, 0, 1) ** 2 * (1 - nz) * 0.5
    col += bounce[..., None] * np.array([90, 40, 15], np.float32)
    rim = np.clip((rr - 0.82) / 0.18, 0, 1)[..., None]
    col = col * (1 - rim * 0.45)
    a = np.where(inside, 255, 0).astype(np.uint8)
    out = np.dstack([np.clip(col, 0, 255).astype(np.uint8), a])
    im = Image.fromarray(out, 'RGBA')
    # A couple of cracks and chips.
    d = ImageDraw.Draw(im)
    w = max(1, D // 140)
    d.line([(D * .58, D * .18), (D * .62, D * .3), (D * .57, D * .38), (D * .63, D * .5)], fill=(52, 44, 40, 200), width=w)
    d.line([(D * .3, D * .62), (D * .36, D * .7), (D * .33, D * .8)], fill=(52, 44, 40, 160), width=w)
    return im


def mark(S, bg=True, mono=False, k=1.0):
    """The icon artwork on an S x S canvas (full bleed), drawn at scale k
    about the centre (adaptive icons crop to the middle two thirds)."""
    S2 = S * SS

    def X(f):
        return S2 * (0.5 + (f - 0.5) * k)
    if bg:
        g = np.linspace(0, 1, S2, dtype=np.float32)[:, None, None]
        top, bot = np.array(CLAY_TOP, np.float32), np.array(CLAY_BOT, np.float32)
        arr = np.broadcast_to(top + (bot - top) * g, (S2, S2, 3)).astype(np.uint8)
        im = Image.fromarray(np.ascontiguousarray(arr), 'RGB').convert('RGBA')
        # Sun disc behind the stone.
        sun = Image.new('L', (S2, S2), 0)
        ImageDraw.Draw(sun).ellipse((X(.52), X(.14), X(.86), X(.48)), fill=255)
        sun = sun.filter(ImageFilter.GaussianBlur(S2 * 0.004))
        im.paste((246, 196, 140, 255), (0, 0), sun.point(lambda v: int(v * 0.55)))
    else:
        im = Image.new('RGBA', (S2, S2), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    ink = (255, 255, 255, 255) if mono else INK + (255,)
    # The slope: rising left to right, crest under the stone.
    slope = [(X(-1), X(1.3)), (X(-.1), X(.92)), (X(.3), X(.74)), (X(.62), X(.69)), (X(2), X(.5)),
             (X(2), X(2)), (X(-1), X(2))]
    d.polygon(slope, fill=ink)
    # Greek key band along the bottom of the slope (incised).
    if not mono:
        unit = S2 * 0.028 * k
        y0 = X(0.83)
        x = -unit * 4
        lw = max(1, int(unit * 0.32))
        col = CLAY_BOT + (255,)
        while x < S2:
            pts = [(x, y0 + unit * 3), (x, y0), (x + unit * 3, y0), (x + unit * 3, y0 + unit * 2),
                   (x + unit, y0 + unit * 2), (x + unit, y0 + unit)]
            d.line(pts, fill=col, width=lw)
            d.line([(x + unit * 3, y0 + unit * 3), (x + unit * 4, y0 + unit * 3)], fill=col, width=lw)
            x += unit * 4
        d.line([(0, y0 - unit), (S2, y0 - unit)], fill=col, width=lw)
        d.line([(0, y0 + unit * 4), (S2, y0 + unit * 4)], fill=col, width=lw)
    # The boulder.
    D = int(S2 * 0.5 * k)
    cx, cy = X(0.47), X(0.715) - D * 0.48
    if mono:
        # A clear gap between the stone and the slope so they read apart.
        gap = D * 0.08
        hole = Image.new('L', (S2, S2), 0)
        ImageDraw.Draw(hole).ellipse((cx - D / 2 - gap, cy - D / 2 - gap, cx + D / 2 + gap, cy + D / 2 + gap), fill=255)
        im.paste((0, 0, 0, 0), (0, 0), hole)
        stone = Image.new('L', (D, D), 0)
        ImageDraw.Draw(stone).ellipse((0, 0, D - 1, D - 1), fill=255)
        im.paste((255, 255, 255, 255), (int(cx - D / 2), int(cy - D / 2)), stone)
    else:
        # Contact shadow.
        sh = Image.new('L', (S2, S2), 0)
        ImageDraw.Draw(sh).ellipse((cx - D * .42, cy + D * .42, cx + D * .5, cy + D * .56), fill=200)
        sh = sh.filter(ImageFilter.GaussianBlur(S2 * 0.012))
        im.paste((10, 6, 5, 255), (0, 0), sh)
        st = sphere(D)
        im.alpha_composite(st, (int(cx - D / 2), int(cy - D / 2)))
    return im.resize((S, S), Image.LANCZOS)


def save(im, *path):
    p = os.path.join(ROOT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    im.save(p, optimize=True)


def main():
    full = mark(1024)
    # iOS: one 1024 icon, no alpha.
    save(full.convert('RGB'), 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'Icon-App-1024x1024@1x.png')
    with open(os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset', 'Contents.json'), 'w') as f:
        json.dump({'images': [{'filename': 'Icon-App-1024x1024@1x.png', 'idiom': 'universal',
                               'platform': 'ios', 'size': '1024x1024'}],
                   'info': {'author': 'xcode', 'version': 1}}, f, indent=2)
    # Play store icon.
    save(mark(512).convert('RGB'), 'fastlane', 'metadata', 'android', 'en-AU', 'images', 'icon.png')
    # Android legacy + adaptive.
    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for name, k in dens.items():
        res = ('android', 'app', 'src', 'main', 'res', f'mipmap-{name}')
        n = int(48 * k)
        legacy = mark(n * 4).resize((n, n), Image.LANCZOS)
        m = Image.new('L', (n, n), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, n - 1, n - 1), radius=n * 0.18, fill=255)
        legacy.putalpha(m)
        save(legacy, *res, 'ic_launcher.png')
        # Adaptive layers are 108dp with the 72dp safe zone in the middle;
        # the artwork is full bleed, so draw it at 108dp.
        a = int(108 * k)
        save(mark(a, k=0.8), *res, 'ic_launcher_foreground.png')
        mono = mark(a, bg=False, mono=True, k=0.72)
        save(mono, *res, 'ic_launcher_monochrome.png')
        # Notification glyph: white stone on a white crest, 24dp.
        g = int(24 * k)
        glyph = Image.new('RGBA', (g * 8, g * 8), (0, 0, 0, 0))
        dd = ImageDraw.Draw(glyph)
        G = g * 8
        dd.ellipse((G * .2, G * .12, G * .8, G * .72), fill=(255, 255, 255, 255))
        dd.polygon([(0, G * .95), (G * .45, G * .78), (G, G * .74), (G, G * .86), (0, G)], fill=(255, 255, 255, 255))
        save(glyph.resize((g, g), Image.LANCZOS), 'android', 'app', 'src', 'main', 'res', f'drawable-{name}',
             'ic_stat_sisyphus.png')
        # Launch screen mark (96dp stone).
        sp = int(96 * k)
        save(sphere(sp * 4).resize((sp, sp), Image.LANCZOS), 'android', 'app', 'src', 'main', 'res',
             f'drawable-{name}', 'splash_boulder.png')

    # Play feature graphic and GitHub social preview.
    def banner(W, H, path):
        im = Image.new('RGB', (W, H), (243, 238, 228))
        icon = mark(int(H * 0.72))
        msk = Image.new('L', icon.size, 0)
        ImageDraw.Draw(msk).rounded_rectangle((0, 0, icon.width - 1, icon.height - 1), radius=icon.width * 0.22, fill=255)
        im.paste(icon, (int(H * 0.14), int(H * 0.14)), msk)
        d = ImageDraw.Draw(im)
        try:
            title = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'Cinzel-700.ttf'), int(H * 0.17))
            sub = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'Jost-400.ttf'), int(H * 0.065))
        except OSError:
            title = sub = ImageFont.load_default()
        x = int(H * 1.05)
        d.text((x, int(H * 0.28)), 'SISYPHUS', font=title, fill=(38, 37, 44))
        d.text((x + 4, int(H * 0.55)), 'A focus timer. Push the stone, rest, push again.', font=sub, fill=(119, 115, 107))
        save(im, *path)

    banner(1024, 500, ('fastlane', 'metadata', 'android', 'en-AU', 'images', 'featureGraphic.png'))
    banner(1280, 640, ('docs', 'social_preview.png'))


if __name__ == '__main__':
    main()
