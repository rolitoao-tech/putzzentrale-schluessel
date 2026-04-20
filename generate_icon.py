#!/usr/bin/env python3
# Generiert das App-Icon für Putzzentrale Schlüsselverwaltung

from PIL import Image, ImageDraw
import os, json, math

BASE = "/Users/roli/Desktop/Claude Code/Putzzentrale - Schlüsselverwaltung"
OUT  = os.path.join(BASE, "Quellcode", "Assets.xcassets", "AppIcon.appiconset")

ICON_SIZES = [
    ("icon_16.png",    16),
    ("icon_32.png",    32),
    ("icon_64.png",    64),
    ("icon_128.png",  128),
    ("icon_256.png",  256),
    ("icon_512.png",  512),
    ("icon_1024.png", 1024),
]

CONTENTS = {
    "images": [
        {"size": "16x16",   "scale": "1x", "filename": "icon_16.png",   "idiom": "mac"},
        {"size": "16x16",   "scale": "2x", "filename": "icon_32.png",   "idiom": "mac"},
        {"size": "32x32",   "scale": "1x", "filename": "icon_32.png",   "idiom": "mac"},
        {"size": "32x32",   "scale": "2x", "filename": "icon_64.png",   "idiom": "mac"},
        {"size": "128x128", "scale": "1x", "filename": "icon_128.png",  "idiom": "mac"},
        {"size": "128x128", "scale": "2x", "filename": "icon_256.png",  "idiom": "mac"},
        {"size": "256x256", "scale": "1x", "filename": "icon_256.png",  "idiom": "mac"},
        {"size": "256x256", "scale": "2x", "filename": "icon_512.png",  "idiom": "mac"},
        {"size": "512x512", "scale": "1x", "filename": "icon_512.png",  "idiom": "mac"},
        {"size": "512x512", "scale": "2x", "filename": "icon_1024.png", "idiom": "mac"},
    ],
    "info": {"version": 1, "author": "xcode"}
}

def create_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # ── Hintergrund ────────────────────────────────────────────────
    BG   = (30, 82, 155, 255)          # Kräftiges Blau
    DARK = (20, 58, 115, 255)          # Dunkleres Blau für Gradient
    r    = int(size * 0.22)

    # Weicher Gradient von oben-hell nach unten-dunkel
    for y in range(size):
        t = y / size
        c = tuple(int(BG[i] + (DARK[i] - BG[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (size, y)], fill=c)

    # Rounded-corner Maske
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size-1, size-1], radius=r, fill=255)
    img.putalpha(mask)

    # ── Schlüssel ──────────────────────────────────────────────────
    # Alle Koordinaten normiert auf 100 Einheiten
    def sc(v): return int(round(v * size / 100))

    W   = (255, 255, 255, 255)   # Weiss
    SHD = (0, 0, 0, 55)          # Schatten (halbtransparent)

    # Schlüsselkopf (Ring) – leicht oben-links positioniert
    cx, cy = sc(36), sc(43)
    ro, ri = sc(19), sc(12)

    # Minimaler Schatten-Ring für Tiefe
    if size >= 64:
        sd = sc(1.2)
        shd_img = Image.new("RGBA", (size, size), (0,0,0,0))
        shd_d   = ImageDraw.Draw(shd_img)
        shd_d.ellipse([cx-ro+sd, cy-ro+sd, cx+ro+sd, cy+ro+sd], fill=SHD)
        img = Image.alpha_composite(img, shd_img)
        d   = ImageDraw.Draw(img)

    # Weisser Aussenring
    d.ellipse([cx-ro, cy-ro, cx+ro, cy+ro], fill=W)
    # Loch im Ring (Farbe des Hintergrunds an dieser Stelle ~Gradient-Mitte)
    hole_col = tuple(int(BG[i] + (DARK[i]-BG[i]) * cy/size) for i in range(3)) + (255,)
    d.ellipse([cx-ri, cy-ri, cx+ri, cy+ri], fill=hole_col)

    # Kleiner Schlüsselstift im Ring (für erkennbares Detail ab 64px)
    if size >= 64:
        dot_r = sc(3.5)
        d.ellipse([cx-dot_r, cy-dot_r, cx+dot_r, cy+dot_r], fill=W)

    # Schaft
    sx1 = cx + ro - sc(1)
    sx2 = sc(82)
    sy1 = cy - sc(7)
    sy2 = cy + sc(7)
    d.rectangle([sx1, sy1, sx2, sy2], fill=W)

    # Abgerundeter rechter Abschluss
    er = sc(7)
    d.ellipse([sx2-er, cy-er, sx2+er, cy+er], fill=W)

    # Zähne (2 Stück, nach unten)
    th = sc(13)
    for tx in [sc(60), sc(71)]:
        tw = sc(8)
        # Abgerundetes Tooth-Ende
        d.rectangle([tx, sy2, tx+tw, sy2+th], fill=W)
        if size >= 64:
            d.ellipse([tx, sy2+th-tw, tx+tw, sy2+th+tw], fill=W)

    return img


def main():
    os.makedirs(OUT, exist_ok=True)

    base = create_icon(1024)

    for fname, sz in ICON_SIZES:
        img  = base if sz == 1024 else base.resize((sz, sz), Image.LANCZOS)
        path = os.path.join(OUT, fname)
        img.save(path, "PNG")
        print(f"  ✓ {fname:20s} ({sz}×{sz})")

    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump(CONTENTS, f, indent=2)
    print("  ✓ Contents.json")
    print(f"\nGespeichert: {OUT}")


if __name__ == "__main__":
    main()
