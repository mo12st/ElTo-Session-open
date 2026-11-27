#!/usr/bin/env python3
"""ElTo theme helper for the Customize Themes page. Data only: it reads, validates and copies theme.json files.
It never executes anything from a theme package.
  list                 JSON array of {slug, builtin, theme} (shipped themes first, then ~/.config/elto/themes)
  save <slug>          read a theme JSON on stdin, validate, write ~/.config/elto/themes/<slug>/theme.json
  install <path>       install a theme from a folder or .zip (only theme.json is read)
  export <slug>        zip a user theme to ~/ElTo-themes/<slug>.zip
  install-bundle <file.elworld>   install a world bundle by calling elto-world install (PR #40):
                                  verify + staged unpack into ~/.local/share/elto/worlds/<id>/,
                                  never overwrites, does not apply the world. Its JSON answer is
                                  passed through unchanged.
Every command prints one JSON object or array on stdout.
"""
import json, os, re, subprocess, sys, zipfile, glob

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD_TOOL = os.path.normpath(os.path.join(HERE, "..", "elto-worlds", "elto-world"))
SHIPPED = os.path.normpath(os.path.join(HERE, "..", "themes"))
HOME = os.path.expanduser("~")
USER = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config")), "elto", "themes")
MAX = 256 * 1024
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")

def slugify(s):
    s = re.sub(r"[^a-z0-9]+", "-", str(s).lower()).strip("-")
    return s[:40] or "theme"

def validate(t):
    if not isinstance(t, dict): raise ValueError("theme.json must be an object")
    if not isinstance(t.get("name"), str) or not t["name"].strip() or len(t["name"]) > 60: raise ValueError("missing or bad name")
    for sec in ("colors", "roles"):
        if not isinstance(t.get(sec), dict) or not t[sec]: raise ValueError("missing " + sec)
    for k, v in t["colors"].items():
        if not isinstance(v, str) or not HEX.match(v): raise ValueError("color %s must be #rrggbb" % k)
    for k, v in t["roles"].items():
        if v not in t["colors"]: raise ValueError("role %s points to unknown color" % k)
    for sec in ("shape", "fonts"):
        if sec in t and not isinstance(t[sec], dict): raise ValueError(sec + " must be an object")
    return t

def load(path):
    if os.path.getsize(path) > MAX: raise ValueError("theme.json too large")
    with open(path) as f: return validate(json.load(f))

def write_user(slug, t):
    d = os.path.join(USER, slug); os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "theme.json"), "w") as f: json.dump(t, f, indent=2)

def cmd_list():
    out = []
    for builtin, root in ((True, SHIPPED), (False, USER)):
        for p in sorted(glob.glob(os.path.join(root, "*", "theme.json"))):
            try: out.append({"slug": os.path.basename(os.path.dirname(p)), "builtin": builtin, "theme": load(p)})
            except Exception as e: sys.stderr.write("skip %s: %s\n" % (p, e))
    print(json.dumps(out))

def cmd_save(slug):
    slug = slugify(slug)
    if os.path.isdir(os.path.join(SHIPPED, slug)): raise ValueError("built-in theme is read-only")
    t = validate(json.loads(sys.stdin.read(MAX)))
    write_user(slug, t); print(json.dumps({"ok": True, "slug": slug}))

def cmd_install(src):
    src = os.path.expanduser(src)
    if os.path.isdir(src): t = load(os.path.join(src, "theme.json"))
    else:
        with zipfile.ZipFile(src) as z:
            names = [n for n in z.namelist() if re.fullmatch(r"([^/]+/)?theme\.json", n)]
            if not names: raise ValueError("no theme.json in the zip")
            info = z.getinfo(names[0])
            if info.file_size > MAX: raise ValueError("theme.json too large")
            t = validate(json.loads(z.read(names[0])))
    slug = slugify(t["name"]); base = slug; i = 2
    while os.path.isdir(os.path.join(SHIPPED, slug)) or os.path.isdir(os.path.join(USER, slug)):
        slug = "%s-%d" % (base, i); i += 1
    write_user(slug, t); print(json.dumps({"ok": True, "slug": slug, "name": t["name"]}))

def cmd_export(slug):
    slug = slugify(slug); p = os.path.join(USER, slug, "theme.json")
    t = load(p); out_dir = os.path.join(HOME, "ElTo-themes"); os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, slug + ".zip")
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z: z.write(p, slug + "/theme.json")
    print(json.dumps({"ok": True, "path": out}))

def cmd_install_bundle(src):
    """Install an .elworld bundle via elto-world install (elto-worlds/elto-world, PR #40).
    theme-tool stays data-only: elto-world does the verify/unpack, nothing from the bundle runs."""
    src = os.path.abspath(os.path.expanduser(src))
    if not os.path.isfile(src): raise ValueError("no such file: " + src)
    if not os.path.isfile(WORLD_TOOL): raise ValueError("elto-world not found at " + WORLD_TOOL)
    p = subprocess.run([sys.executable, WORLD_TOOL, "install", src],
                       capture_output=True, text=True, timeout=180)
    try:
        rep = json.loads(p.stdout)
    except Exception:
        raise ValueError("elto-world did not answer JSON: " + (p.stderr or p.stdout).strip()[:200])
    if not rep.get("ok"):
        errs = rep.get("errors") or [rep.get("error", "install failed")]
        raise ValueError("; ".join(str(e) for e in errs))
    print(json.dumps(rep))

if __name__ == "__main__":
    try:
        a = sys.argv[1:]
        if a[:1] == ["list"]: cmd_list()
        elif a[:1] == ["save"] and len(a) == 2: cmd_save(a[1])
        elif a[:1] == ["install"] and len(a) == 2: cmd_install(a[1])
        elif a[:1] == ["install-bundle"] and len(a) == 2: cmd_install_bundle(a[1])
        elif a[:1] == ["export"] and len(a) == 2: cmd_export(a[1])
        else: raise ValueError("usage: list | save <slug> | install <path> | install-bundle <file.elworld> | export <slug>")
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)})); sys.exit(1)
