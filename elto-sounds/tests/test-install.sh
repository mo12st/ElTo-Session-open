#!/bin/sh
# Install/toggle test in a sandbox HOME. Uses generated 0.1 s test tones as FIXTURES ONLY (not shipped, not artwork).
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d); export HOME=$T XDG_DATA_HOME=$T/d XDG_CONFIG_HOME=$T/c
cp -r "$HERE" "$T/pkg"
python3 - "$T/pkg/themes/elto-soft/stereo" <<'PY'
import wave,sys,struct,math
for n in ["message-new-instant","elto-drawer-open","elto-drawer-close","elto-lock","elto-unlock","desktop-login"]:
    w=wave.open(sys.argv[1]+"/"+n+".wav","wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes(b"".join(struct.pack("<h",int(2000*math.sin(i/10))) for i in range(4410))); w.close()
PY
"$T/pkg/elto-sounds" install | tee $T/out; grep -q "(6 sounds)" $T/out
"$T/pkg/elto-sounds" enable; grep -q '"enabled": true' $T/c/elto/theme.json
"$T/pkg/elto-sounds" disable; grep -q '"enabled": false' $T/c/elto/theme.json
"$T/pkg/elto-sounds" uninstall; [ ! -d $T/d/sounds/elto-soft ]
echo PASS; rm -rf "$T"
