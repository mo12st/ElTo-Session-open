# ElTo Core (Phase A)

The layer that gathers system identity, settings and behavior. Files only: no daemon, no service, no engine. Approved scope for Phase A is identity/ + defaults/; behavior/ (systemd preset, environment.d session contract) is Phase B and is not here.

- identity/: os-release, hostname, console banner, logo. NAME=ElTo, ID=elto, ID_LIKE=arch, VERSION_ID=2026.11 (date-based), per the owner's picks.
- defaults/: the system defaults other files used to printf from session/install.sh, now reviewable files with a reason each (MANIFEST.md).
- install.sh: installs both. Run as root from the repo root, after or instead of the settings section of session/install.sh. Do not run both against the same targets more than once intentionally; the writes are identical in content.

Verification level: implemented; install.sh passes bash -n and ShellCheck; os-release parses as shell assignments; defaults content is byte-identical in effect to what session/install.sh writes today (kdeglobals, kwinrc, plasmashellrc, sddm.conf.d). NOT installed on a real system, NOT VM-tested: that is the implementer's step (see the PR body for the VM test list).
