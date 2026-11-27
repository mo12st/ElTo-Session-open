# elto-polkit - verification status

Per the governance directive: exactly what was verified and what was not.
Nothing here has touched a live Arch system, a real session, a VM, or
hardware.

## Verified (with proof)

1. **Implemented**: `setup-elto-polkit.sh`, `elto-polkit-agent.sh`,
   `tests/run-tests.sh`.
2. **Logic tested**: 15 checks pass (`bash tests/run-tests.sh` in the
   author's sandbox: `all tests passed (15 checks)`) with stubbed
   pacman/usermod/id/pgrep and fixture rules files. Covers: fresh setup,
   pacman `--needed --noconfirm` call, wheel add, launcher install,
   re-login note, idempotent second run, fail-loud when the admin rule
   lacks wheel, missing agent binary, usermod failure, unknown user,
   non-root refusal, usage errors, launcher no-op/missing/exec paths.
   `bash -n` clean on all three scripts (shellcheck not installed in the
   author's sandbox).
3. **External facts checked live (archlinux.org and upstream source,
   2026-11-27)**:
   - Arch `extra` ships `polkit-kde-agent` 6.8.3 with binary
     `/usr/lib/polkit-kde-authentication-agent-1`, XDG autostart entry,
     and no plasma-workspace dependency (deps listed in README);
     `lxqt-policykit` 2.5.0 ships `/usr/bin/lxqt-policykit-agent` +
     autostart; `polkit-gnome` 0.105 ships NO XDG autostart entry.
   - PackageKit v1.4.1 `data/policy/org.freedesktop.packagekit.policy.in`:
     `package-install` and `package-remove` both require
     `auth_admin_keep` for the active user. The shipped
     `org.freedesktop.packagekit.rules` only passwordlessly covers
     offline system-update triggers, not install/remove.
   - Arch `polkit` ships `/usr/share/polkit-1/rules.d/50-default.rules`.
   - The ElTo session script (`session/elto-session` at f4bbed9) starts
     only `kwin_wayland` and `quickshell`: nothing processes
     `/etc/xdg/autostart`, hence the explicit launcher.

## NOT verified

- No real `pacman -S polkit-kde-agent` was run; the dependency list is
  from archlinux.org metadata, not an install.
- The agent binary was never started in a real session; whether its
  dialog appears correctly on `kwin_wayland` (Qt wayland platform,
  `XDG_CURRENT_DESKTOP=KDE` as the session sets) is unproven.
- The exact content of `50-default.rules` on a live system (that it names
  wheel) is unverified by the author; the setup script checks it and fails
  loudly if wheel is missing.
- A real authenticated install/remove through the agent is unproven.
- Whether wheel membership picked up without re-login is untested
  (standard behavior says re-login is required; the script says so).
- The one-line `elto-session` change belongs to the implementer and is
  intentionally not in this PR; without it the agent never starts.

## VM test list (for the implementer)

1. As root: `setup-elto-polkit.sh --user <session-user>` -> expect
   package installed (or already present), launcher at
   `/usr/local/libexec/elto-polkit-agent.sh`, wheel verified/added, and
   the re-login note.
2. Add the launcher line to `elto-session` after `WAYLAND_DISPLAY` is
   exported (your file; see README). Log in fresh.
3. `pgrep -u $USER -f polkit-kde-authentication-agent-1` -> running.
4. `elto-discovery install sl;5.05-3;x86_64;extra` (PR #26 helper, or
   `pkgcli --json --no-color -y install sl;5.05-3;x86_64;extra`) ->
   expect the authentication dialog on screen; enter the user's password;
   install succeeds. Screenshot the dialog as proof.
5. `elto-discovery remove sl;5.05-3;x86_64;installed` -> prompt again
   (or auth kept briefly per auth_admin_keep), remove succeeds.
6. Wrong password / cancel at the dialog -> clean failure
   (`not-authorized` / `cancelled` from the helper), no partial state.
7. Create a non-wheel user, log in, repeat step 4 -> must fail closed
   (not-authorized), never a silent allow.
8. `grep -A3 addAdminRule /usr/share/polkit-1/rules.d/50-default.rules`
   -> record that wheel is the admin group (the setup script already
   refuses to proceed otherwise).
9. After a full logout/login (not just unlock), repeat step 3 to confirm
   the agent starts via the session line alone.

Report each step's raw output as proof; update this file's levels after
the run.
