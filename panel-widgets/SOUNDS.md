# Shell sounds (CONCEPT)

`Sound.qml` (singleton) + `SoundBank.qml`: in-process Qt Multimedia `SoundEffect`, no process per event.
Gate: overlay `sounds.enabled` (default false: silent). Theme: `~/.local/share/sounds/<_world.id>/stereo/<event>.wav`
(installed by `elto-world`). Missing dir, file or QtMultimedia: silent skip, logged as `ELTOSOUND ...`.

Wired events: `session-start` (shell start, held up to 5 s until the overlay loads), `notification`,
`drawer-open`, `drawer-close`. Same event at most once per 150 ms.
Ready but not wired (no hook point yet): `lock`, `unlock` (lock screen is its own process, Phase 2), `session-end`.
Call `Sound.play("lock")` from the lock integration when it exists.

Needs `qt6-multimedia` at runtime: not confirmed on the image (implementer to check). The world tool ships no audio
yet: free-licensed assets (CC0/CC-BY, per-asset license in CREDITS) must be supplied or approved by the owner.

Verification: nothing run yet. VM can prove: shell starts, `ELTOSOUND fire notification` appears with sounds.enabled=true,
nothing with it false, shell survives missing files/QtMultimedia. Audible quality is hardware-only.
