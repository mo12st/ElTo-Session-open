#!/bin/bash
# Sanitizer rig for plugin/windowlist: ASan+UBSan build exercised under nested KWin --virtual.
# CI adaptation of the implementer's acceptance rig spike/run4.sh (see .github/workflows/sanitizer.yml).
set -u
export XDG_RUNTIME_DIR=/tmp/xdg; mkdir -p $XDG_RUNTIME_DIR; chmod 700 $XDG_RUNTIME_DIR
export LIBGL_ALWAYS_SOFTWARE=1 KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 QT_QPA_PLATFORM=wayland
# Leak check off: the helper is a long-lived reader and never exits cleanly in this rig.
export ASAN_OPTIONS=halt_on_error=1:detect_leaks=0
export UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1
cp -r /pr/plugin/windowlist /tmp/wl && cd /tmp/wl
make CFLAGS="-O1 -g -Wall -Wextra -fsanitize=address,undefined -fno-omit-frame-pointer" 2>&1 | tail -15
[ -x /tmp/wl/elto-windowlist ] || { echo "BUILD-FAILED"; exit 1; }
cd /tmp
kwin_wayland --virtual --width 1280 --height 720 --socket wayland-san --no-lockscreen > /tmp/kwin.log 2>&1 &
sleep 8
pgrep -f '^kwin_wayland' >/dev/null || { echo KWIN-DIED; tail -30 /tmp/kwin.log; exit 1; }
export WAYLAND_DISPLAY=wayland-san
mkfifo /tmp/cmd
(tail -f /tmp/cmd | /tmp/wl/elto-windowlist > /tmp/wl.out 2>/tmp/wl.err) &
sleep 2
foot -T winA -e sh -c 'sleep 120' > /dev/null 2>&1 & A=$!
sleep 3
foot -T winB -e sh -c 'sleep 120' > /dev/null 2>&1 & B=$!
sleep 4
UB=$(grep -a '"title":"winB"' /tmp/wl.out | head -1 | sed 's/.*"uuid":"\([^"]*\)".*/\1/')
UA=$(grep -a '"title":"winA"' /tmp/wl.out | head -1 | sed 's/.*"uuid":"\([^"]*\)".*/\1/')
echo "uuid of winA: $UA / winB: $UB"
if [ -n "$UA" ]; then echo "activate $UA" > /tmp/cmd; sleep 2; fi
kill $B 2>/dev/null || true; sleep 3
# Stress: rapid open/close, windows killed right after launch (unmapped/early-destroy paths), reopen.
echo "== stress"
PIDS=""
for i in $(seq 1 20); do
  foot -T "stress$i" -e sh -c 'sleep 60' > /dev/null 2>&1 & P=$!
  PIDS="$PIDS $P"
  if [ $((i % 3)) -eq 0 ]; then sleep 0.05; kill $P 2>/dev/null || true; else sleep 0.2; fi
done
sleep 3
for P in $PIDS; do kill $P 2>/dev/null || true; sleep 0.1; done
sleep 3
for i in 1 2 3 4 5; do foot -T "reopen$i" -e sh -c 'sleep 1' > /dev/null 2>&1 & sleep 0.3; done
sleep 5
pgrep -f '/tmp/wl/elto-windowlist' >/dev/null || { echo "HELPER-DIED-DURING-STRESS"; cat /tmp/wl.err; exit 1; }
echo "stress adds: $(grep -a -c '"event":"add"' /tmp/wl.out) closes: $(grep -a -c '"event":"close"' /tmp/wl.out)"
echo "== counts"; for e in add title appid state close; do echo "$e: $(grep -a -c "\"event\":\"$e\"" /tmp/wl.out)"; done
ADDS=$(grep -a -c '"event":"add"' /tmp/wl.out)
[ "$ADDS" -ge 1 ] || { echo "RIG-NO-WINDOWS: instrumented helper saw no windows"; tail -20 /tmp/wl.err; exit 1; }
echo "== sanitizer findings check"
if grep -aE 'AddressSanitizer|LeakSanitizer|UndefinedBehaviorSanitizer|runtime error:' /tmp/wl.err; then
  echo "SANITIZER-FINDINGS"; echo "== full helper stderr"; cat /tmp/wl.err; exit 1
fi
echo "NO-SANITIZER-FINDINGS"
pgrep -f '^kwin_wayland' >/dev/null && echo ALIVE-kwin || echo KWIN-DEAD
