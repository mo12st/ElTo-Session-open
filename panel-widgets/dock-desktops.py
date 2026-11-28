#!/usr/bin/env python3
"""Virtual desktops for the dock pager: read them from KWin, and switch between them.

KWin publishes them on the session bus at org.kde.KWin /VirtualDesktopManager, interface
org.kde.KWin.VirtualDesktopManager: `count`, `current` (the id of the desktop in use) and
`desktops` (position, id, name for each one). Quickshell has no D-Bus property binding, so this
helper reads them with dbus-send, which ships with the dbus package: nothing a Plasma session does
not already have.

    dock-desktops.py             print the desktops, one record per line
    dock-desktops.py switch N    make desktop N (1-based, as drawn) the current one

Records, parsed by DockDesktops.qml:

    count <n>
    current <id>
    desktop <position> <id> <name>
    error <text>                 KWin did not answer, so the dock draws no pager

The dock calls this every two seconds and after every switch. Nothing here changes KWin state
unless `switch` is asked for, and a switch only sets the `current` property.
"""
import re
import subprocess
import sys

SERVICE = "org.kde.KWin"
PATH = "/VirtualDesktopManager"
IFACE = "org.kde.KWin.VirtualDesktopManager"
PROPS = "org.freedesktop.DBus.Properties"

UINT = re.compile(r"uint32\s+(\d+)")
STR = re.compile(r'string\s+"((?:[^"\\]|\\.)*)"')


def call(*args):
    cmd = ["dbus-send", "--session", "--print-reply", "--dest=" + SERVICE, PATH] + list(args)
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.SubprocessError) as exc:
        return None, str(exc)
    if out.returncode != 0:
        return None, (out.stderr or out.stdout).strip().replace("\n", " ") or "dbus-send failed"
    return out.stdout, None


def get(name):
    return call(PROPS + ".Get", "string:" + IFACE, "string:" + name)


def unescape(text):
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            out.append({"n": "\n", "t": "\t", '"': '"', "\\": "\\"}.get(text[i + 1], text[i + 1]))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def parse_desktops(text):
    """Return [(position, id, name)] sorted by position.

    A struct prints as one `struct { ... }` block. The declared type is (uss), so the uint is the
    position and the two strings are id and name; the order check below keeps a build that lists
    them differently from losing every desktop.
    """
    rows = []
    for block in text.split("struct {")[1:]:
        body = block.split("}")[0]
        position = UINT.search(body)
        strings = STR.findall(body)
        if position and len(strings) >= 2:
            rows.append((int(position.group(1)), unescape(strings[0]), unescape(strings[1])))
        elif len(strings) >= 3:
            try:
                rows.append((int(strings[2]), unescape(strings[0]), unescape(strings[1])))
            except ValueError:
                pass
    rows.sort(key=lambda row: row[0])
    return rows


def read_current():
    text, err = get("current")
    if err:
        return ""
    match = STR.search(text)
    if match:
        return unescape(match.group(1))
    match = UINT.search(text)
    return match.group(1) if match else ""


def print_desktops():
    text, err = get("desktops")
    if err:
        print("error " + err)
        return 1
    rows = parse_desktops(text)
    print("count %d" % len(rows))
    print("current " + read_current())
    for position, desktop_id, name in rows:
        print("desktop %d %s %s" % (position, desktop_id, name))
    return 0


def switch(target):
    text, err = get("desktops")
    if err:
        print("error " + err)
        return 1
    rows = parse_desktops(text)
    desktop_id = target
    if target.isdigit():
        for position, candidate, _name in rows:
            if position + 1 == int(target):
                desktop_id = candidate
                break
    # `current` is a string id on Plasma 6; an older build takes a uint index instead
    attempts = ["variant:string:" + desktop_id]
    if target.isdigit():
        attempts.append("variant:uint32:" + target)
    for attempt in attempts:
        _out, err = call(PROPS + ".Set", "string:" + IFACE, "string:current", attempt)
        if not err:
            print("ok " + desktop_id)
            return 0
    print("error switch refused for " + target)
    return 1


def main(argv):
    if len(argv) >= 3 and argv[1] == "switch":
        return switch(argv[2])
    return print_desktops()


if __name__ == "__main__":
    sys.exit(main(sys.argv))
