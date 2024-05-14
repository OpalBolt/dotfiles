#                       ,,    ,,
#   .g8""8q.     mm     db  `7MM              `7MM"""Yp,
# .dP'    `YM.   MM           MM                MM    Yb
# dM'      `MM mmMMmm `7MM    MM  .gP"Ya        MM    dP  ,6"Yb.  `7Mb,od8 ,pP"Ybd
# MM        MM   MM     MM    MM ,M'   Yb       MM"""bg. 8)   MM    MM' "' 8I   `"
# MM.      ,MP   MM     MM    MM 8M""""""       MM    `Y  ,pm9MM    MM     `YMMMa.
# `Mb.    ,dP'   MM     MM    MM YM.    ,       MM    ,9 8M   MM    MM     L.   I8
#   `"bmmd"'     `Mbmo.JMML..JMML.`Mbmmd'     .JMMmmmd9  `Moo9^Yo..JMML.   M9mmmP'
#       MMb

from libqtile import bar, widget


def load_bars(colors: dict):
    return bar.Bar(
        [
            widget.CurrentLayout(),
            widget.GroupBox(),
            widget.WindowName(),
            widget.KeyboardLayout(
                fmt="⌨  Kbd: {}",
            ),
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
            widget.Clock(format="%Y-%m-%d %a %I:%M %p"),
            widget.QuickExit(),
        ],
        30,  # "Thickness of the bar"
        border_width=[0, 0, 0, 0],
        border_color=[colors["darkBackground"]],
        margin=[15, 60, 6, 60],
    )
