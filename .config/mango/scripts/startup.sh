#!/bin/sh
# Mango session startup.
#
# Wayland compositors don't put WAYLAND_DISPLAY / XDG_CURRENT_DESKTOP /
# XDG_SESSION_TYPE into the systemd --user manager or the D-Bus activation
# environment automatically, so user units and D-Bus-activated services
# can't see them unless we hand them over explicitly. This must run before
# anything below that depends on those variables.
dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE DISPLAY

# graphical-session.target itself refuses manual starts (RefuseManualStart=yes),
# so WantedBy=graphical-session.target units only come up when something
# actually reaches it (e.g. a login manager). Start the units we need directly.
systemctl --user start voxtype.service

# easyeffects ships a GNOME-only XDG autostart entry
# (~/.config/autostart/com.github.wwmm.easyeffects.desktop), so
# systemd-xdg-autostart-generator's unit for it never runs under mango.
# Start it directly in the background instead.
easyeffects --hide-window --service-mode &
