#!/bin/bash
# Load test for the dock variants: starts one nested KWin, then loads dock-smoke.qml once per case with
# a different overlay, and checks that the variant the registry resolved is the one expected.
# It proves the QML loads and the right window is chosen; it does not prove how the dock looks.
set -u
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland
cd /tmp

# the real window-list helper is a C binary that is not in this container; a silent stand-in keeps the
# dock's Process quiet so the log only carries QML problems
printf '#!/bin/sh\ncat >/dev/null\n' > /tmp/fake-windowlist
chmod 755 /tmp/fake-windowlist

kwin_wayland --virtual --width 1280 --height 720 --socket wayland-dk --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 8
pgrep -f '^kwin_wayland' >/dev/null || { echo KWIN-DIED; tail -30 /tmp/kwin.log; exit 1; }
export WAYLAND_DISPLAY=wayland-dk

fail=0
run() { # label, expected resolved variant, options.dock value ("" = key absent), optional log line
  local label="$1" want="$2" val="$3" warn="${4:-}"
  local ov=/tmp/elto-dock-overlay.json log=/tmp/qs-dock-$label.log
  if [ -n "$val" ]; then printf '{"options":{"dock":"%s"}}' "$val" > "$ov"; else printf '{}' > "$ov"; fi
  ELTO_THEME="$ov" ELTO_WINDOWLIST=/tmp/fake-windowlist quickshell -p /src/panel-widgets/dock-smoke.qml > "$log" 2>&1 &
  local pid=$!
  sleep 12
  if ! kill -0 "$pid" 2>/dev/null; then echo "QUICKSHELL-EXITED ($label)"; cat "$log"; fail=1; fi
  grep -a "ELTODOCK variant $want" "$log" >/dev/null || { echo "WRONG-VARIANT ($label, wanted $want)"; grep -a ELTODOCK "$log"; fail=1; }
  if [ -n "$warn" ]; then
    grep -a "$warn" "$log" >/dev/null || { echo "MISSING-WARNING ($label)"; grep -a ELTODOCK "$log"; fail=1; }
  fi
  # Load failures only. "Unable to assign [undefined]" is pre-existing startup noise: Theme.qml
  # publishes its tokens before the base theme file lands, so every token warns once and then resolves.
  if grep -aE 'is not a type|is not installed|Cannot load|Failed to load|module .* not found|ReferenceError|Cannot read property' "$log"; then
    echo "QML-LOAD-ERRORS ($label)"; fail=1
  fi
  kill "$pid" 2>/dev/null
  sleep 2
}

run island-absent island ""
run bar bar bar
run island-fallback island nonsense "unknown or unsupported dock style"

echo "== island (absent key)"; cat /tmp/qs-dock-island-absent.log
echo "== bar"; cat /tmp/qs-dock-bar.log
echo "== island (unknown value)"; cat /tmp/qs-dock-island-fallback.log
if [ "$fail" -eq 0 ]; then echo DOCK-VARIANTS-OK; else echo DOCK-VARIANTS-FAILED; fi
exit "$fail"
