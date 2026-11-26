#!/bin/bash
# Re-checks every package name in lists/ against the live Arch package API
# (archlinux.org). Needs curl and python3. Read-only; installs nothing.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
fail=0
for f in "$HERE"/lists/*.packages; do
  echo "# $(basename "$f")"
  while read -r pkg rest; do
    [ -z "$pkg" ] && continue
    case "$pkg" in \#*) continue ;; esac
    r=$(curl -sf "https://archlinux.org/packages/search/json/?name=$pkg") || { echo "  $pkg  API-ERROR"; fail=1; continue; }
    line=$(printf '%s' "$r" | python3 -c "
import json,sys
d=json.load(sys.stdin)
rs=[x for x in d.get('results',[]) if x['pkgname']=='$pkg']
print('  $pkg  OK  repo='+rs[0]['repo']+'  '+rs[0]['pkgver']) if rs else print('  $pkg  NOT-IN-REPOS')")
    echo "$line"
    case "$line" in *NOT-IN-REPOS*) fail=1 ;; esac
  done < "$f"
done
if [ "$fail" = 0 ]; then
  echo "ALL-NAMES-OK"
else
  echo "SOME-NAMES-FAILED"
  exit 1
fi
