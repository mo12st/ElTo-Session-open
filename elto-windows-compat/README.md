# elto-windows-compat

Open Windows programs on ElTo with a double-click. Mature parts only: Wine, umu-launcher (Proton), shared-mime-info, desktop file associations, optional binfmt.d. No service, no UI, no shell changes.

Packages for the packages track: `wine` `winetricks` `umu-launcher` `icoutils` (icoutils is for later icon extraction, not used yet).

Install: `elto-run-windows` to /usr/bin, `elto-windows.desktop` to /usr/share/applications, `mimeapps.list` content into /usr/share/applications/ (defaults), `elto-windows.conf` to /usr/lib/binfmt.d/ (optional).

Behavior: one prefix per program folder under ~/.local/share/elto/prefixes, log in ~/.cache/elto/windows. Proton via umu-run, Wine fallback, clear notification if neither exists.

## Verification
- Implemented: yes. Static checks only so far (sh syntax, desktop-file-validate).
- VM-tested: no. Hardware: no. No GPU in the VM, so DirectX/Vulkan apps stay unverified.
