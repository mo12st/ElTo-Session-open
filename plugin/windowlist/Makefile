PLASMA_XML ?= /usr/share/plasma-wayland-protocols/plasma-window-management.xml
CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra
WAYLAND_CFLAGS := $(shell pkg-config --cflags wayland-client)
WAYLAND_LIBS := $(shell pkg-config --libs wayland-client)

all: elto-windowlist

plasma-window-management-client-protocol.h: $(PLASMA_XML)
	wayland-scanner client-header $(PLASMA_XML) $@

plasma-window-management-protocol.c: $(PLASMA_XML)
	wayland-scanner private-code $(PLASMA_XML) $@

elto-windowlist: elto-windowlist.c plasma-window-management-protocol.c plasma-window-management-client-protocol.h
	$(CC) $(CFLAGS) $(WAYLAND_CFLAGS) -o $@ elto-windowlist.c plasma-window-management-protocol.c $(WAYLAND_LIBS)

clean:
	rm -f elto-windowlist plasma-window-management-client-protocol.h plasma-window-management-protocol.c
