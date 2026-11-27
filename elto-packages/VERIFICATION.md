# Verification status (2026-11-27)

Honest levels, per the governance directive:

- **Implemented**: the lists, install.sh and verify.sh in this directory.
- **Name-verified against the live Arch repos**: every package name in
  lists/ was checked with the archlinux.org package API on 2026-11-27
  (verify.sh re-runs this). Result: ALL-NAMES-OK, 55 packages, repos
  core/extra/multilib. umu-launcher is in **multilib** (must be enabled).
- **Dependency-verified against live Arch metadata**: `breeze`,
  `plasma-integration`, `plasma5support` and `polkit-kde-agent` confirmed
  free of `plasma-workspace`/`libplasma`; `xdg-desktop-portal-kde`
  confirmed to hard-depend on `plasma-workspace` (basis of AVOIDED.md).
- **Statically checked**: install.sh and verify.sh pass `bash -n` and
  ShellCheck 0.11.0 (no warnings). install.sh --dry-run exercised for all
  flag combinations in this sandbox.
- **NOT installed, NOT built into an image, NOT VM-tested, NOT
  hardware-tested by this track.** Running install.sh on the ElTo VM is
  the implementer agent's step. Expected risk points for the VM run:
  1. `aurorae` is required by session/install.sh's kwinrc
     (org.kde.kwin.aurorae) but was NOT in the spike boot lists; the VM
     must confirm the ElToClassic decoration renders with it present.
  2. Without xdg-desktop-portal-kde (avoided, see AVOIDED.md) there is no
     KDE screen-sharing portal; confirm nothing in the session needs it.
  3. 50-windows-compat needs [multilib] enabled; install.sh checks this.
- **No AUR packages, no paid/proprietary packages.** All 55 are in the
  official Arch repos.
