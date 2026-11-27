# ElTo Core (Phases A+B)

The layer that gathers system identity, settings and behavior. Files only: no daemon, no service, no engine.

- identity/: os-release, hostname, console banner, logo. NAME=ElTo, ID=elto, ID_LIKE=arch, VERSION_ID=2026.11 (date-based), per the owner's picks.
- defaults/: the system defaults other files used to printf from session/install.sh, now reviewable files with a reason each (MANIFEST.md).
- behavior/: 00-elto.preset (enable sddm, NetworkManager, bluetooth at first boot / preset-all) and 90-elto.conf (QT_QPA_PLATFORMTHEME=kde for the user manager).
- install.sh: installs all of it. Run as root from the repo root, after or instead of the settings section of session/install.sh.

Verification level: implemented; install.sh passes bash -n; os-release parses as shell assignments; preset and environment.d are trivial line formats; defaults content is byte-identical in effect to what session/install.sh writes today. NOT installed on a real system, NOT VM-tested: that is the implementer's step (see the PR body for the VM test list). Phase C (packaging as a PKGBUILD) waits for the image pipeline.
