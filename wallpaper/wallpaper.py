#!/usr/bin/env python3
"""Generate the ElTo default wallpaper (original, SVG) from palette/elto-palette.json. Stdlib only.
Run: python3 wallpaper/wallpaper.py   -> writes wallpaper/elto-default.svg. UNVERIFIED."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = json.load(open(os.path.join(ROOT, "palette", "elto-palette.json")))
W, H = 1920, 1080

def hill(y, amp, phase, fill, op):
    pts = []
    for i in range(0, W + 41, 40):
        x = i
        v = y + amp * (0.6 * __import__("math").sin(x / 310.0 + phase) + 0.4 * __import__("math").sin(x / 140.0 + phase * 2))
        pts.append((x, round(v, 1)))
    d = "M0 %d " % H + " ".join("L%d %s" % p for p in pts) + " L%d %d Z" % (W, H)
    return f'<path d="{d}" fill="{fill}" fill-opacity="{op}"/>\n'

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{P["lightGreen"]}"/>
<stop offset="1" stop-color="{P["cream"]}"/>
</linearGradient>
</defs>
<rect width="{W}" height="{H}" fill="url(#sky)"/>
<circle cx="1450" cy="330" r="120" fill="{P["rust"]}" fill-opacity="0.85"/>
<circle cx="1450" cy="330" r="170" fill="{P["rust"]}" fill-opacity="0.12"/>
'''
svg += hill(640, 40, 0.3, P["lightGreen"], 0.9)
svg += hill(740, 50, 1.7, P["midGreen"], 0.55)
svg += hill(850, 45, 3.1, P["midGreen"], 0.8)
svg += hill(960, 35, 4.4, P["green"], 0.9)
svg += "</svg>\n"
open(os.path.join(ROOT, "wallpaper", "elto-default.svg"), "w").write(svg)
print("wrote wallpaper/elto-default.svg")
