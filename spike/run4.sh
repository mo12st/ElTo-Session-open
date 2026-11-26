#!/bin/bash
# Acceptance test for plugin/windowlist (code from the PR ref mounted at /pr)
set -x
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland
cp -r /pr/plugin/windowlist /tmp/wl && cd /tmp/wl && make 2>&1 | tail -15; ls -la /tmp/wl/elto-windowlist || { echo "BUILD-FAILED"; exit 1; }
cd /tmp
kwin_wayland --virtual --width 1280 --height 720 --socket wayland-spike --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 8
export WAYLAND_DISPLAY=wayland-spike
mkfifo /tmp/cmd; (tail -f /tmp/cmd | /tmp/wl/elto-windowlist > /tmp/wl.out 2>/tmp/wl.err) &
sleep 2
foot -T winA -e sh -c 'sleep 300' > /dev/null 2>&1 & A=$!
sleep 3
foot -T winB -e sh -c 'sleep 300' > /dev/null 2>&1 & B=$!
sleep 4
echo "== after two windows"; cat /tmp/wl.out
UB=$(grep -a '"title":"winB"' /tmp/wl.out | head -1 | sed 's/.*"uuid":"\([^"]*\)".*/\1/'); echo "uuid of winB: $UB"
UA=$(grep -a '"title":"winA"' /tmp/wl.out | head -1 | sed 's/.*"uuid":"\([^"]*\)".*/\1/'); echo "uuid of winA: $UA"
echo "activate $UA" > /tmp/cmd; sleep 2
echo "== after activate winA"; tail -5 /tmp/wl.out
kill $B; sleep 3
echo "== after closing winB"; tail -4 /tmp/wl.out
echo "== stderr"; cat /tmp/wl.err
echo "== counts"; for e in add title appid state close; do echo "$e: $(grep -a -c "\"event\":\"$e\"" /tmp/wl.out)"; done
echo "== json validity"; python3 -c "import json;[json.loads(l) for l in open('/tmp/wl.out')];print('JSON-OK')" 2>&1 || echo "python missing/invalid"
pgrep -f '^kwin_wayland' >/dev/null && echo ALIVE-kwin || echo KWIN-DEAD
