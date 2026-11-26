#!/usr/bin/env python3
"""Generate the KDE color scheme theme/ElTo.colors from palette/elto-palette.json. Stdlib only.
Dolphin and every Qt/KDE app using the Breeze style follow it. CONCEPT, UNVERIFIED until applied in the VM."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = json.load(open(os.path.join(ROOT, "palette", "elto-palette.json")))

def rgb(h):
    return ",".join(str(int(h[i:i + 2], 16)) for i in (1, 3, 5))

def section(name, bg, alt, fg, inactive):
    rows = [("BackgroundAlternate", alt), ("BackgroundNormal", bg), ("DecorationFocus", P["midGreen"]),
            ("DecorationHover", P["rust"]), ("ForegroundActive", P["rust"]), ("ForegroundInactive", inactive),
            ("ForegroundLink", P["btnBlue"]), ("ForegroundNegative", P["rust"]), ("ForegroundNeutral", P["btnYellow"]),
            ("ForegroundNormal", fg), ("ForegroundPositive", P["btnGreen"]), ("ForegroundVisited", P["midGreen"])]
    return f"[Colors:{name}]\n" + "".join(f"{k}={rgb(v)}\n" for k, v in rows) + "\n"

out = ""
out += "[ColorEffects:Disabled]\nColor=%s\nColorAmount=0\nColorEffect=0\nContrastAmount=0.65\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n" % rgb(P["inactiveBg"])
out += "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=%s\nColorAmount=0.025\nColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\nEnable=false\nIntensityAmount=0\nIntensityEffect=0\n\n" % rgb(P["inactiveFg"])
out += section("Button", P["creamDark"], P["cream"], P["green"], P["inactiveFg"])
out += section("Complementary", P["green"], P["green"], P["cream"], P["inactiveFg"])
out += section("Header", P["creamDark"], P["cream"], P["green"], P["inactiveFg"])
out += section("Selection", P["midGreen"], P["green"], P["cream"], P["lightGreen"])
out += section("Tooltip", P["green"], P["green"], P["cream"], P["inactiveFg"])
out += section("View", P["cream"], P["creamDark"], P["green"], P["inactiveFg"])
out += section("Window", P["creamDark"], P["cream"], P["green"], P["inactiveFg"])
out += "[General]\nColorScheme=ElTo\nName=ElTo\nshadeSortColumn=true\n\n[KDE]\ncontrast=4\n\n"
out += "[WM]\nactiveBackground=%s\nactiveBlend=%s\nactiveForeground=%s\ninactiveBackground=%s\ninactiveBlend=%s\ninactiveForeground=%s\n" % (
    rgb(P["cream"]), rgb(P["green"]), rgb(P["green"]), rgb(P["inactiveBg"]), rgb(P["inactiveFg"]), rgb(P["inactiveFg"]))
open(os.path.join(ROOT, "theme", "ElTo.colors"), "w").write(out)
print("wrote theme/ElTo.colors")
