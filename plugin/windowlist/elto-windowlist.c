/*
 * elto-windowlist - standalone window-list helper for the ElTo session.
 *
 * Prints JSON-lines window events on stdout:
 *   {"event":"add","uuid":"..."}
 *   {"event":"title","uuid":"...","title":"..."}
 *   {"event":"appid","uuid":"...","appid":"..."}
 *   {"event":"state","uuid":"...","flags":N}
 *   {"event":"close","uuid":"..."}
 * Accepts "activate <uuid>" lines on stdin.
 *
 * Protocol: org_kde_plasma_window_management (plasma-wayland-protocols v16).
 * Based on spike/pwm.c. UNVERIFIED: not yet run inside a KWin VM.
 */

#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <unistd.h>
#include <wayland-client.h>

#include "plasma-window-management-client-protocol.h"

#define PWM_VERSION 16
#define MAX_UUID_LEN 128   /* uuids are 36 chars; reject anything longer */
#define MAX_CMD_LEN 1024   /* stdin line cap; longer lines are discarded */

struct window_entry {
    struct org_kde_plasma_window *window;
    char *uuid;
    struct window_entry *next;
};

static struct wl_display *display;
static struct org_kde_plasma_window_management *manager;
static struct window_entry *windows;

/* ---------- JSON helpers ---------- */

static void json_escape(const char *s)
{
    const unsigned char *p;
    for (p = (const unsigned char *)s; *p; p++) {
        switch (*p) {
        case '"':  fputs("\\\"", stdout); break;
        case '\\': fputs("\\\\", stdout); break;
        case '\n': fputs("\\n", stdout);  break;
        case '\r': fputs("\\r", stdout);  break;
        case '\t': fputs("\\t", stdout);  break;
        default:
            if (*p < 0x20)
                printf("\\u%04x", *p);
            else
                putchar(*p);
        }
    }
}

static void print_string_field(const char *key, const char *value)
{
    printf(",\"%s\":\"", key);
    json_escape(value);
    putchar('"');
}

static void print_event_head(const char *event, const char *uuid)
{
    printf("{\"event\":\"%s\",\"uuid\":\"", event);
    json_escape(uuid);
    putchar('"');
}

/* ---------- per-window listener ---------- */

static void title_changed(void *data, struct org_kde_plasma_window *w,
                          const char *title)
{
    struct window_entry *e = data;
    (void)w;
    print_event_head("title", e->uuid);
    print_string_field("title", title);
    fputs("}\n", stdout);
    fflush(stdout);
}

static void app_id_changed(void *data, struct org_kde_plasma_window *w,
                           const char *app_id)
{
    struct window_entry *e = data;
    (void)w;
    print_event_head("appid", e->uuid);
    print_string_field("appid", app_id);
    fputs("}\n", stdout);
    fflush(stdout);
}

static void state_changed(void *data, struct org_kde_plasma_window *w,
                          uint32_t flags)
{
    struct window_entry *e = data;
    (void)w;
    print_event_head("state", e->uuid);
    printf(",\"flags\":%u}\n", flags);
    fflush(stdout);
}

static void initial_state(void *data, struct org_kde_plasma_window *w)
{
    /* Individual events already arrived; nothing extra to print. */
    (void)data;
    (void)w;
}

static struct window_entry **find_link(const char *uuid)
{
    struct window_entry **p = &windows;
    while (*p && strcmp((*p)->uuid, uuid) != 0)
        p = &(*p)->next;
    return p;
}

static void unmapped(void *data, struct org_kde_plasma_window *w)
{
    struct window_entry *e = data;
    struct window_entry **p;
    (void)w;
    print_event_head("close", e->uuid);
    fputs("}\n", stdout);
    fflush(stdout);
    /* unlink first (by pointer, uuids could repeat), then destroy, then free */
    for (p = &windows; *p; p = &(*p)->next) {
        if (*p == e) {
            *p = e->next;
            break;
        }
    }
    org_kde_plasma_window_destroy(e->window);
    free(e->uuid);
    free(e);
}

/* libwayland aborts if a listener member for a received event is NULL, so every
 * slot up to PWM_VERSION is set explicitly. Slots we do not use are no-ops with
 * the exact event signature. Order and types follow plasma-window-management.xml. */
static void w_virtual_desktop_changed(void *d, struct org_kde_plasma_window *w, int32_t n) { (void)d; (void)w; (void)n; }
static void w_themed_icon_name_changed(void *d, struct org_kde_plasma_window *w, const char *n) { (void)d; (void)w; (void)n; }
static void w_parent_window(void *d, struct org_kde_plasma_window *w, struct org_kde_plasma_window *p) { (void)d; (void)w; (void)p; }
static void w_geometry(void *d, struct org_kde_plasma_window *w, int32_t x, int32_t y, uint32_t ww, uint32_t h) { (void)d; (void)w; (void)x; (void)y; (void)ww; (void)h; }
static void w_icon_changed(void *d, struct org_kde_plasma_window *w) { (void)d; (void)w; }
static void w_pid_changed(void *d, struct org_kde_plasma_window *w, uint32_t pid) { (void)d; (void)w; (void)pid; }
static void w_virtual_desktop_entered(void *d, struct org_kde_plasma_window *w, const char *id) { (void)d; (void)w; (void)id; }
static void w_virtual_desktop_left(void *d, struct org_kde_plasma_window *w, const char *id) { (void)d; (void)w; (void)id; }
static void w_application_menu(void *d, struct org_kde_plasma_window *w, const char *a, const char *b) { (void)d; (void)w; (void)a; (void)b; }
static void w_activity_entered(void *d, struct org_kde_plasma_window *w, const char *id) { (void)d; (void)w; (void)id; }
static void w_activity_left(void *d, struct org_kde_plasma_window *w, const char *id) { (void)d; (void)w; (void)id; }
static void w_resource_name_changed(void *d, struct org_kde_plasma_window *w, const char *n) { (void)d; (void)w; (void)n; }

static const struct org_kde_plasma_window_listener window_listener = {
    .title_changed = title_changed,
    .app_id_changed = app_id_changed,
    .state_changed = state_changed,
    .virtual_desktop_changed = w_virtual_desktop_changed,
    .themed_icon_name_changed = w_themed_icon_name_changed,
    .unmapped = unmapped,
    .initial_state = initial_state,
    .parent_window = w_parent_window,
    .geometry = w_geometry,
    .icon_changed = w_icon_changed,
    .pid_changed = w_pid_changed,
    .virtual_desktop_entered = w_virtual_desktop_entered,
    .virtual_desktop_left = w_virtual_desktop_left,
    .application_menu = w_application_menu,
    .activity_entered = w_activity_entered,
    .activity_left = w_activity_left,
    .resource_name_changed = w_resource_name_changed,
};

/* ---------- manager listener ---------- */

static void window_with_uuid_cb(void *data,
                                struct org_kde_plasma_window_management *m,
                                uint32_t id, const char *uuid)
{
    struct org_kde_plasma_window *w;
    struct window_entry *e;
    (void)data;
    (void)m;
    (void)id;

    if (!uuid || strlen(uuid) > MAX_UUID_LEN)
        return;
    w = org_kde_plasma_window_management_get_window_by_uuid(manager, uuid);
    if (!w)
        return;
    e = calloc(1, sizeof(*e));
    if (!e) {
        org_kde_plasma_window_destroy(w);
        return;
    }
    e->uuid = strdup(uuid);
    if (!e->uuid) {
        free(e);
        org_kde_plasma_window_destroy(w);
        return;
    }
    e->window = w;
    e->next = windows;
    windows = e;
    org_kde_plasma_window_add_listener(w, &window_listener, e);

    print_event_head("add", e->uuid);
    fputs("}\n", stdout);
    fflush(stdout);
}

static void m_show_desktop_changed(void *d, struct org_kde_plasma_window_management *m, uint32_t st) { (void)d; (void)m; (void)st; }
static void m_window(void *d, struct org_kde_plasma_window_management *m, uint32_t id) { (void)d; (void)m; (void)id; }
static void m_stacking_order_changed(void *d, struct org_kde_plasma_window_management *m, struct wl_array *ids) { (void)d; (void)m; (void)ids; }
static void m_stacking_order_uuid_changed(void *d, struct org_kde_plasma_window_management *m, const char *u) { (void)d; (void)m; (void)u; }

static const struct org_kde_plasma_window_management_listener manager_listener = {
    .show_desktop_changed = m_show_desktop_changed,
    .window = m_window,
    .stacking_order_changed = m_stacking_order_changed,
    .stacking_order_uuid_changed = m_stacking_order_uuid_changed,
    .window_with_uuid = window_with_uuid_cb,
};

/* ---------- registry ---------- */

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface,
                            uint32_t version)
{
    (void)data;
    if (strcmp(interface, org_kde_plasma_window_management_interface.name) != 0)
        return;
    if (version > PWM_VERSION)
        version = PWM_VERSION;
    manager = wl_registry_bind(registry, name,
                               &org_kde_plasma_window_management_interface,
                               version);
    org_kde_plasma_window_management_add_listener(manager, &manager_listener,
                                                  NULL);
}

static void registry_global_remove(void *data, struct wl_registry *registry,
                                   uint32_t name)
{
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

/* ---------- stdin commands ---------- */

static void handle_command(char *line)
{
    char *nl = strchr(line, '\n');
    const char *uuid;
    struct window_entry *e;

    if (nl)
        *nl = '\0';
    if (strncmp(line, "activate ", 9) != 0)
        return;
    uuid = line + 9;
    if (!*uuid || strlen(uuid) > MAX_UUID_LEN)
        return;
    e = *find_link(uuid);
    if (!e)
        return;
    org_kde_plasma_window_set_state(e->window,
                                    ORG_KDE_PLASMA_WINDOW_MANAGEMENT_STATE_ACTIVE,
                                    ORG_KDE_PLASMA_WINDOW_MANAGEMENT_STATE_ACTIVE);
    wl_display_flush(display);
}

/* ---------- main ---------- */

int main(void)
{
    struct wl_registry *registry;
    struct pollfd fds[2];

    signal(SIGPIPE, SIG_IGN);
    display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "elto-windowlist: cannot connect to Wayland display\n");
        return 1;
    }
    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!manager) {
        fprintf(stderr,
                "elto-windowlist: org_kde_plasma_window_management not available\n");
        return 1;
    }
    wl_display_roundtrip(display); /* initial window set */

    fds[0].fd = wl_display_get_fd(display);
    fds[0].events = POLLIN;
    fds[1].fd = STDIN_FILENO;
    fds[1].events = POLLIN;

    for (;;) {
        int pr;
        while (wl_display_prepare_read(display) != 0)
            wl_display_dispatch_pending(display);
        wl_display_flush(display);
        pr = poll(fds, 2, -1);
        if (pr < 0) {
            wl_display_cancel_read(display);
            if (errno == EINTR)
                continue;
            break;
        }
        if (fds[0].revents & (POLLHUP | POLLERR | POLLNVAL)) {
            wl_display_cancel_read(display);
            break; /* compositor gone */
        }
        if (fds[0].revents & POLLIN) {
            if (wl_display_read_events(display) < 0)
                break;
        } else {
            wl_display_cancel_read(display);
        }
        if (wl_display_dispatch_pending(display) < 0)
            break;
        if (fds[1].fd >= 0 && (fds[1].revents & (POLLIN | POLLHUP | POLLERR))) {
            char line[MAX_CMD_LEN];
            if (!fgets(line, sizeof(line), stdin)) {
                fds[1].fd = -1; /* stdin closed: keep listing windows */
            } else if (!strchr(line, '\n') && !feof(stdin)) {
                int c; /* oversized line: discard the rest, ignore it */
                while ((c = getchar()) != '\n' && c != EOF)
                    ;
            } else {
                handle_command(line);
            }
        }
    }
    return 0;
}
