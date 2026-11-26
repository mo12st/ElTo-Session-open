# elto-windowlist

Standalone Wayland helper that prints window events as JSON lines and
accepts `activate <uuid>` commands on stdin.

Events are sourced from the `org_kde_plasma_window_management` protocol.

## Build dependencies

- libwayland-dev
- wayland-scanner
- plasma-wayland-protocols

## Build

    make

## Run

    ./elto-windowlist

## Event types (one example line each)

An "add" event carries only the uuid; the title and app id arrive as
separate "title" and "appid" events right after it. "flags" is the raw
state bit field from the protocol.

    {"event":"add","uuid":"a1b2c3d4"}
    {"event":"title","uuid":"a1b2c3d4","title":"Terminal"}
    {"event":"appid","uuid":"a1b2c3d4","appid":"org.kde.konsole"}
    {"event":"state","uuid":"a1b2c3d4","flags":1}
    {"event":"close","uuid":"a1b2c3d4"}

## stdin commands

    activate a1b2c3d4

## Status

UNVERIFIED — pending VM test.
