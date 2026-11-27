# Shell hooks (proposed, NOT applied)

These files belong to other tracks (shell, lock), so they are listed here for the implementer to apply,
not edited in this PR. Each is one line. `Sound.qml` must be in the same module directory as the shell QML
(installer copies it to the session root next to panel-widgets, or the implementer moves it into panel-widgets).

| File | Hook | Event |
|---|---|---|
| panel-widgets/NotificationPopups.qml | in `onNotification`: `Sound.play("message-new-instant")` | notification |
| panel-widgets/AppDrawer.qml | `onOpenChanged: Sound.play(open ? "elto-drawer-open" : "elto-drawer-close")` | drawer |
| lock/LockScreen.qml | on `locked` change: `Sound.play(locked ? "elto-lock" : "elto-unlock")` | lock |
| panel-widgets/elto-shell.qml | `Component.onCompleted: Sound.play("desktop-login")` in ShellRoot | start |

No other events. Sounds are off unless `options.sounds.enabled` is true in `~/.config/elto/theme.json`.
Note: the lock screen runs in its own process; if it cannot import Sound.qml, drop the lock hook rather than spawn a process.
