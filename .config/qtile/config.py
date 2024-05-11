#                       ,,    ,,                                                 ,...,,
#   .g8""8q.     mm     db  `7MM                .g8"""bgd                      .d' ""db
# .dP'    `YM.   MM           MM              .dP'     `M                      dM`
# dM'      `MM mmMMmm `7MM    MM  .gP"Ya      dM'       ` ,pW"Wq.`7MMpMMMb.   mMMmm`7MM  .P"Ybmmm
# MM        MM   MM     MM    MM ,M'   Yb     MM         6W'   `Wb MM    MM    MM    MM :MI  I8
# MM.      ,MP   MM     MM    MM 8M""""""     MM.        8M     M8 MM    MM    MM    MM  WmmmP"
# `Mb.    ,dP'   MM     MM    MM YM.    ,     `Mb.     ,'YA.   ,A9 MM    MM    MM    MM 8M
#   `"bmmd"'     `Mbmo.JMML..JMML.`Mbmmd'       `"bmmmd'  `Ybmd9'.JMML  JMML..JMML..JMML.YMMMMMb
#       MMb                                                                             6'     dP
#        `bood'                                                                         Ybmmmd'

# --------------------
# Imports
# --------------------

import os
import keys
from libqtile import bar, layout, widget
from libqtile.config import Click, Drag, Match, Screen
from libqtile.lazy import lazy
from pathlib import Path

# --------------------
# Auto fetching variables
# --------------------
home = str(Path.home())  # Fetches the home location
platform = int(
    os.popen("cat /sys/class/dmi/id/chassis_type").read()
)  # Finds the type of system that is running

# --------------------
# Manual set vriables
# --------------------
mod = "mod4"
terminal = "kitty"
keys.define_all_keys(mod, terminal)


layouts = [
    layout.Columns(border_focus_stack=["#d75f5f", "#8f3d3d"], border_width=4),
    layout.Max(),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    # layout.Bsp(),
    # layout.Matrix(),
    # layout.MonadTall(),
    # layout.MonadWide(),
    # layout.RatioTile(),
    # layout.Tile(),
    # layout.TreeTab(),
    # layout.VerticalTile(),
    # layout.Zoomy(),
]

widget_defaults = dict(
    font="sans",
    fontsize=12,
    padding=3,
)
extension_defaults = widget_defaults.copy()

screens = [
    Screen(
        bottom=bar.Bar(
            [
                widget.CurrentLayout(),
                widget.GroupBox(),
                widget.Prompt(),
                widget.WindowName(),
                widget.Chord(
                    chords_colors={
                        "launch": ("#ff0000", "#ffffff"),
                    },
                    name_transform=lambda name: name.upper(),
                ),
                widget.TextBox("default config", name="default"),
                widget.TextBox("Press &lt;M-r&gt; to spawn", foreground="#d75f5f"),
                # NB Systray is incompatible with Wayland, consider using StatusNotifier instead
                # widget.StatusNotifier(),
                widget.Systray(),
                widget.Clock(format="%Y-%m-%d %a %I:%M %p"),
                widget.QuickExit(),
            ],
            24,
            # border_width=[2, 0, 2, 0],  # Draw top and bottom borders
            # border_color=["ff00ff", "000000", "ff00ff", "000000"]  # Borders are magenta
        ),
        # You can uncomment this variable if you see that on X11 floating resize/moving is laggy
        # By default we handle these events delayed to already improve performance, however your system might still be struggling
        # This variable is set to None (no cap) by default, but you can set it to 60 to indicate that you limit it to 60 events per second
        # x11_drag_polling_rate = 60,
    ),
]

# Drag floating layouts.
mouse = [
    Drag(
        [mod],
        "Button1",
        lazy.window.set_position_floating(),
        start=lazy.window.get_position(),
    ),
    Drag(
        [mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()
    ),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: list
follow_mouse_focus = True
bring_front_click = False
floats_kept_above = True
cursor_warp = False
floating_layout = layout.Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
    ]
)
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

# If things like steam games want to auto-minimize themselves when losing
# focus, should we respect this or not?
auto_minimize = True

# When using the Wayland backend, this can be used to configure input devices.
wl_input_rules = None

# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
