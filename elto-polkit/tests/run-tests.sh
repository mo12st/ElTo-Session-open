#!/bin/bash
# Tests for elto-polkit: setup script logic and the session launcher.
#
# Runs both scripts with stubbed root tools (pacman, usermod, id, pgrep,
# install, grep stays real) on PATH and temp fixture paths via the
# documented ELTO_POLKIT_* overrides. Verifies OUR logic only: argument and
# root checks, idempotency, fail-closed behavior, launcher behavior. Real
# pacman/usermod/polkit behavior is the VM test's job (see VERIFICATION.md).
#
# Run: bash tests/run-tests.sh   (from the elto-polkit/ directory)
set -u
cd "$(dirname "$0")/.."
HERE=$PWD
PASS=0
FAIL=0
FAILED=""

ok()   { PASS=$((PASS+1)); echo "ok   - $1"; }
bad()  { FAIL=$((FAIL+1)); FAILED="$FAILED $1"; echo "FAIL - $1 $2"; }

# ---------- fixture environment -------------------------------------------
TMP=$(mktemp -d /tmp/elto-polkit-test.XXXXXX)
trap 'rm -rf "$TMP"' EXIT
STUB=$TMP/stub
FIX=$TMP/fix
mkdir -p "$STUB" "$FIX"

# fixture agent binary (the pacman stub "installs" it when told to)
cat > "$FIX/agent" <<'EOF'
#!/bin/bash
echo "agent started: $0 $@" >> "$FIX/agent.log"
sleep 0 &
exit 0
EOF
chmod +x "$FIX/agent"

# fixture polkit rules files
cat > "$FIX/rules-wheel.rules" <<'EOF'
polkit.addAdminRule(function(action, subject) {
    return ["unix-user:0", "unix-group:wheel"];
});
EOF
cat > "$FIX/rules-nowheel.rules" <<'EOF'
polkit.addAdminRule(function(action, subject) {
    return ["unix-user:0"];
});
EOF

# ---------- stubs ----------------------------------------------------------
# pacman: logs; "installs" the agent unless PACMAN_SKIP_INSTALL=1
cat > "$STUB/pacman" <<'EOF'
#!/bin/bash
echo "pacman $*" >> "$FIX/pacman.log"
if [ "${PACMAN_SKIP_INSTALL:-0}" = "1" ]; then rm -f "$FIX/agent.installed"; else cp "$FIX/agent" "$FIX/agent.installed"; chmod +x "$FIX/agent.installed"; fi
exit "${PACMAN_EXIT:-0}"
EOF

# usermod: logs; fails when USERMOD_EXIT is set; marks the user as wheel
cat > "$STUB/usermod" <<'EOF'
#!/bin/bash
echo "usermod $*" >> "$FIX/usermod.log"
if [ "${USERMOD_EXIT:-0}" != "0" ]; then exit "$USERMOD_EXIT"; fi
touch "$FIX/user-is-wheel"
exit 0
EOF

# id: -u returns ID_U (default 0); -nG returns groups; bare 'id NAME' checks USER_EXISTS
cat > "$STUB/id" <<'EOF'
#!/bin/bash
case "$1" in
  -u) echo "${ID_U:-0}" ;;
  -nG) if [ -f "$FIX/user-is-wheel" ]; then echo "$2 wheel"; else echo "$2"; fi ;;
  *) [ "${USER_EXISTS:-1}" = "1" ] || exit 1; echo "uid=1000($1)" ;;
esac
EOF

# pgrep: matches when FIX/agent-running exists
cat > "$STUB/pgrep" <<'EOF'
#!/bin/bash
if [ -f "$FIX/agent-running" ]; then echo "1234"; exit 0; fi
exit 1
EOF

# install: real file copy without root semantics
cat > "$STUB/install" <<'EOF'
#!/bin/bash
# last arg is dest; second-to-last is src; ignore -Dm755
src=""; dst=""
for a in "$@"; do case "$a" in -*) ;; *) src="$dst"; dst="$a" ;; esac; done
mkdir -p "$(dirname "$dst")"
cp "$src" "$dst"
chmod +x "$dst"
EOF
chmod +x "$STUB"/*

run_setup() {
    env PATH="$STUB:/usr/bin:/bin" FIX="$FIX" \
        ELTO_POLKIT_AGENT_PKG=test-agent \
        ELTO_POLKIT_AGENT_BIN="$FIX/agent.installed" \
        ELTO_POLKIT_AUTOSTART_FILE="$FIX/autostart.desktop" \
        ELTO_POLKIT_RULES_FILE="$FIX/rules.rules" \
        ELTO_POLKIT_LAUNCHER_DST="$TMP/launcher" \
        ID_U="${ID_U:-0}" USER_EXISTS="${USER_EXISTS:-1}" \
        PACMAN_SKIP_INSTALL="${PACMAN_SKIP_INSTALL:-0}" \
        USERMOD_EXIT="${USERMOD_EXIT:-0}" PACMAN_EXIT="${PACMAN_EXIT:-0}" \
        bash "$HERE/setup-elto-polkit.sh" "$@"
}

reset_fix() {
    rm -f "$FIX"/*.log "$FIX/user-is-wheel" "$FIX/agent.installed" "$FIX/agent-running"
    cp "$FIX/rules-wheel.rules" "$FIX/rules.rules"
    touch "$FIX/autostart.desktop"
}

# ---------- setup script tests ---------------------------------------------
reset_fix
out=$(run_setup --user mostafa 2>&1); rc=$?
[ $rc -eq 0 ] && ok "fresh setup exits 0" || bad "fresh setup exits 0" "(rc=$rc: $out)"
grep -q 'pacman -S --needed --noconfirm test-agent' "$FIX/pacman.log" \
    && ok "pacman called with --needed --noconfirm" || bad "pacman called"
grep -q 'usermod -aG wheel mostafa' "$FIX/usermod.log" \
    && ok "usermod adds wheel" || bad "usermod adds wheel"
[ -x "$TMP/launcher" ] && ok "launcher installed" || bad "launcher installed"
echo "$out" | grep -q 'log in again' && ok "re-login note printed" || bad "re-login note"

# idempotent: already in wheel -> no usermod
reset_fix
touch "$FIX/user-is-wheel"
out=$(run_setup --user mostafa 2>&1); rc=$?
[ $rc -eq 0 ] && [ ! -f "$FIX/usermod.log" ] \
    && ok "second run skips usermod" || bad "second run skips usermod" "(rc=$rc)"

# rules file without wheel -> fail loudly
reset_fix
cp "$FIX/rules-nowheel.rules" "$FIX/rules.rules"
out=$(run_setup --user mostafa 2>&1); rc=$?
{ [ $rc -ne 0 ] && echo "$out" | grep -q 'does not name wheel'; } \
    && ok "wheel-less admin rule fails loudly" || bad "wheel-less admin rule" "(rc=$rc: $out)"

# agent binary missing after pacman -> fail
reset_fix
out=$(PACMAN_SKIP_INSTALL=1 run_setup --user mostafa 2>&1); rc=$?
{ [ $rc -ne 0 ] && echo "$out" | grep -q 'not found after installing'; } \
    && ok "missing agent binary fails" || bad "missing agent binary" "(rc=$rc: $out)"

# usermod failure -> nonzero
reset_fix
out=$(USERMOD_EXIT=1 run_setup --user mostafa 2>&1); rc=$?
[ $rc -ne 0 ] && ok "usermod failure propagates" || bad "usermod failure"

# unknown user -> nonzero
reset_fix
out=$(USER_EXISTS=0 run_setup --user ghost 2>&1); rc=$?
[ $rc -ne 0 ] && ok "unknown user fails" || bad "unknown user"

# not root -> usage exit 2
reset_fix
out=$(ID_U=1000 run_setup --user mostafa 2>&1); rc=$?
[ $rc -eq 2 ] && ok "non-root refused (exit 2)" || bad "non-root refused" "(rc=$rc)"

# no args -> usage exit 2
out=$(run_setup 2>&1); rc=$?
[ $rc -eq 2 ] && ok "no args is usage (exit 2)" || bad "no args"

# ---------- launcher tests --------------------------------------------------
run_launcher() {
    env PATH="$STUB:/usr/bin:/bin" FIX="$FIX" ID_U=1000 \
        ELTO_POLKIT_AGENT_BIN="$1" \
        bash "$HERE/elto-polkit-agent.sh"
}

# agent already running -> exit 0, does not exec
touch "$FIX/agent-running"
out=$(run_launcher "$FIX/agent.installed" 2>&1); rc=$?
{ [ $rc -eq 0 ] && [ ! -f "$FIX/agent.log" ]; } \
    && ok "launcher no-op when agent running" || bad "launcher no-op" "(rc=$rc: $out)"
rm -f "$FIX/agent-running"

# agent binary missing -> exit 1 with message
rm -f "$FIX/agent.log"
out=$(run_launcher "$FIX/nonexistent" 2>&1); rc=$?
{ [ $rc -eq 1 ] && echo "$out" | grep -q 'not found'; } \
    && ok "launcher fails when binary missing" || bad "launcher missing binary" "(rc=$rc: $out)"

# normal start -> execs the agent
rm -f "$FIX/agent.log"
cp "$FIX/agent" "$FIX/agent.installed"; chmod +x "$FIX/agent.installed"
out=$(run_launcher "$FIX/agent.installed" 2>&1); rc=$?
{ [ $rc -eq 0 ] && grep -q 'agent started' "$FIX/agent.log"; } \
    && ok "launcher execs agent" || bad "launcher execs agent" "(rc=$rc: $out)"

echo
if [ $FAIL -gt 0 ]; then
    echo "$FAIL FAILURES:$FAILED"
    exit 1
fi
echo "all tests passed ($PASS checks)"
