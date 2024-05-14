#                       ,,    ,,                ,,
#   .g8""8q.     mm     db  `7MM              `7MM                                        mm
# .dP'    `YM.   MM           MM                MM                                        MM
# dM'      `MM mmMMmm `7MM    MM  .gP"Ya        MM   ,6"Yb.`7M'   `MF',pW"Wq.`7MM  `7MM mmMMmm ,pP"Ybd
# MM        MM   MM     MM    MM ,M'   Yb       MM  8)   MM  VA   ,V 6W'   `Wb MM    MM   MM   8I   `"
# MM.      ,MP   MM     MM    MM 8M""""""       MM   ,pm9MM   VA ,V  8M     M8 MM    MM   MM   `YMMMa.
# `Mb.    ,dP'   MM     MM    MM YM.    ,       MM  8M   MM    VVV   YA.   ,A9 MM    MM   MM   L.   I8
#   `"bmmd"'     `Mbmo.JMML..JMML.`Mbmmd'     .JMML.`Moo9^Yo.  ,V     `Ybmd9'  `Mbod"YML. `MbmoM9mmmP'
#       MMb                                                   ,V
#        `bood'                                            OOb"


from libqtile import layout
from libqtile.config import Match


def load_layout_theme(colors: dict):
    layout_theme = {
        "border_width": 2,
        "margin": 7,
        "border_focus": colors["highlight"],
        "border_normal": colors["darkerForground"],
        "single_border_width": 2,
    }
    return layout_theme


def load_layout(colors: dict):
    layout_theme = load_layout_theme(colors)
    layouts = [
        layout.Columns(**layout_theme),
        layout.Max(**layout_theme),
        layout.Bsp(**layout_theme),
        layout.MonadTall(**layout_theme),
        layout.Floating(),
        # layout.Stack(num_stacks=2),
        # layout.Matrix(),
        # layout.MonadWide(),
        # layout.RatioTile(),
        # layout.Tile(),
        # layout.TreeTab(),
        # layout.VerticalTile(),
        # layout.Zoomy(),
    ]
    return layouts


def load_floating_layout(colors: dict):
    floating_layout = layout.Floating(
        border_width=2,
        single_border_width=2,
        border_focus=colors["highlight"],
        border_normal=colors["darkerForground"],
        float_rules=[
            # Run the utility of `xprop` to see the wm class and name of an X client.
            *layout.Floating.default_float_rules,
            Match(wm_class="confirmreset"),  # gitk
            Match(wm_class="makebranch"),  # gitk
            Match(wm_class="maketag"),  # gitk
            Match(wm_class="ssh-askpass"),  # ssh-askpass
            Match(title="branchdialog"),  # gitk
            Match(title="pinentry"),  # GPG key password entry
        ],
    )
    return floating_layout
