# elto-worlds-helper

Minimal polkit-gated helper that installs world **data** files system-wide.
Components that run before login (SDDM, lock screen, Plymouth) cannot read
a user's home, so worlds that want a pre-login presence need their data
under `/usr/share/elto/worlds`. This helper is the only write path to that
tree.

## What it does

`pkexec /usr/lib/elto/elto-worlds-helper install --manifest M.json --source-root DIR`

- `M.json`: `{"files": [{"src": "rel/under/source-root", "dest": "rel/under/dest-root"}, ...]}`
- Copies each file to `/usr/share/elto/worlds/<dest>`, mode 0644, root:root,
  via same-directory temp + rename.
- Prints `{"installed": N, "files": [...]}` as JSON. Exit 0 on success,
  2 with a `refused:` message on any validation failure, changing nothing.

## What it refuses (enforced in code, not in the caller)

- anything except `install` (no remove/update/daemon; no network, no
  subprocess, no shell, no eval)
- a run outside pkexec (`PKEXEC_UID` must be set)
- a source root outside the **calling** user's home
- sources not owned by, or not regular files of, the calling user, so root
  never copies a file the caller could not have read (confused-deputy guard)
- a manifest not owned by the calling user, so one user cannot spend
  another's polkit approval
- destinations outside `/usr/share/elto/worlds`

## Install (packaging)

- `elto-worlds-helper` -> `/usr/lib/elto/elto-worlds-helper`, mode 0755, root:root
- `org.elto.worlds.policy` -> `/usr/share/polkit-1/actions/`, mode 0644, root:root

The polkit action is `auth_admin_keep` for the active session only; any
other session state is denied. `exec.path` pins the helper path, so polkit
runs exactly this file, never a caller-supplied program.

## Non-goals

No removal yet: installed files are inert data under one tree; a `remove`
verb lands with the manager wiring, as its own review. Widening the
destination root (e.g. `/usr/share/fonts`) is a policy decision for the
user, not something this helper assumes.
