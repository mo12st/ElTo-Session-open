# elto-polkit (option A: authentication agent + wheel membership)

Approved by the user 2026-11-27 (Telegram, polkit question): a polkit
authentication agent in the ElTo session, the session user in the wheel
group, and **no permissive polkit rule**. Install/remove keep failing
closed for non-wheel users.

## Why this exists

ElTo Discovery (and anything else using PackageKit) needs admin
authentication for install/remove. PackageKit's shipped policy requires it:

- `org.freedesktop.packagekit.package-install`: `allow_active =
  auth_admin_keep` (same for `package-remove`) — the active session user
  must authenticate as a polkit admin identity. Source: PackageKit v1.4.1
  `data/policy/org.freedesktop.packagekit.policy.in`.
- polkit's default admin rule names wheel as an admin group:
  `/usr/share/polkit-1/rules.d/50-default.rules` (setup script verifies
  this and fails loudly if it ever changes).

Two pieces were missing in the ElTo session: something to *show* the
authentication prompt (the session runs KWin + Quickshell only, no agent),
and the session user being a polkit admin (wheel). This directory provides
both, and adds nothing else.

## What it is

- `setup-elto-polkit.sh` — run once as root:
  `setup-elto-polkit.sh --user NAME`. Installs the agent package
  (`--needed`, idempotent), installs the session launcher to
  `/usr/local/libexec/elto-polkit-agent.sh`, verifies polkit's default
  admin rule covers wheel (fails loudly otherwise instead of guessing),
  and adds the user to wheel (idempotent). No polkit rules are written.
- `elto-polkit-agent.sh` — session launcher. The ElTo session script
  starts only KWin and Quickshell; nothing processes `/etc/xdg/autostart`,
  so the agent is launched explicitly. One line in `elto-session`, after
  `WAYLAND_DISPLAY` is exported:

  ```
  /usr/local/libexec/elto-polkit-agent.sh &
  ```

  Idempotent (no-op if the agent already runs). That line is the
  implementer's one-line change to their file; it is intentionally not in
  this PR.

## Agent choice

`polkit-kde-agent` (default, overridable via `ELTO_POLKIT_AGENT_PKG`):

- Qt6 + Kirigami (QML) dialog: the same toolkit family as the
  Quickshell-based session, so the prompt can be brought closest to ElTo's
  look later.
- Ships its XDG autostart entry and a systemd user unit (neither is used
  here; the session launches it explicitly).
- Dependency cost (Arch `extra`, 2026-11-27): qt6-base, qt6-declarative,
  polkit-qt6, kcoreaddons, kcrash, kdbusaddons, ki18n, kirigami,
  knotifications, kwindowsystem. qt6-declarative and KWin's world are
  already in the session; the KF6 libraries are the added weight. No
  plasma-workspace anywhere in the chain (checked: the package does not
  depend on it).

Alternatives, if the KF6 weight is rejected later:

- `lxqt-policykit` — Qt6, much lighter (liblxqt + polkit-qt6), QtWidgets
  dialog, ships autostart. Set `ELTO_POLKIT_AGENT_PKG=lxqt-policykit` and
  `ELTO_POLKIT_AGENT_BIN=/usr/bin/lxqt-policykit-agent`.
- `polkit-gnome` — rejected: GTK3 dialog in a Qt session, and Arch's
  package ships no XDG autostart entry (checked its file list).

A custom QML agent over polkit-qt6 was considered and rejected for now:
directive #7 (mature component first). If ElTo's look demands it later,
that is its own proposal.

## Security model (unchanged by this component)

- PackageKit install/remove require admin authentication
  (`auth_admin_keep`): the agent prompts for the user's own password.
- polkit admin identity = wheel group (default rule; verified by setup).
- Non-wheel active users have no admin identity available: authentication
  fails closed, no prompt can succeed. This is the intended behavior.
- `pkgcli -y` (used by elto-discovery for install/remove) skips pkgcli's
  own confirmation only; it does not bypass polkit or signature trust
  (`only-trusted` stays on).
- No `polkit.addRule` files are added by this component.

## Verification level

Logic tested (15 checks, `bash tests/run-tests.sh`, all passing) with
stubbed pacman/usermod/id/pgrep: argument and root checks, idempotency,
fail-closed on wheel-less admin rule, missing binary, usermod failure,
launcher no-op/missing/exec paths. NOT verified: real pacman install, real
usermod, agent startup in a real session, the authentication dialog on
Wayland, a real authenticated install. See VERIFICATION.md for the VM test
list.
