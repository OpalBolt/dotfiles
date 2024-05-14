#                       ,,    ,,
#   .g8""8q.     mm     db  `7MM              `7MMF' `YMM'
# .dP'    `YM.   MM           MM                MM   .M'
# dM'      `MM mmMMmm `7MM    MM  .gP"Ya        MM .d"     .gP"Ya `7M'   `MF',pP"Ybd
# MM        MM   MM     MM    MM ,M'   Yb       MMMMM.    ,M'   Yb  VA   ,V  8I   `"
# MM.      ,MP   MM     MM    MM 8M""""""       MM  VMA   8M""""""   VA ,V   `YMMMa.
# `Mb.    ,dP'   MM     MM    MM YM.    ,       MM   `MM. YM.    ,    VVV    L.   I8
#   `"bmmd"'     `Mbmo.JMML..JMML.`Mbmmd'     .JMML.   MMb.`Mbmmd'    ,V     M9mmmP'
#       MMb                                                          ,V
#        `bood'                                                   OOb"

from libqtile.lazy import lazy
from libqtile.config import Key, Group
from libqtile import qtile


def define_all_keys(mod: str, terminal: str):
    keys = [
        # ------
        # Focus
        # ------
        # Keys used to switch focus between windows
        Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
        Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
        Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
        Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
        Key(
            [mod], "space", lazy.layout.next(), desc="Move window focus to other window"
        ),
        # ------
        # Move
        # ------
        Key(
            [mod, "shift"],
            "h",
            lazy.layout.shuffle_left(),
            desc="Move window to the left",
        ),
        Key(
            [mod, "shift"],
            "l",
            lazy.layout.shuffle_right(),
            desc="Move window to the right",
        ),
        Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
        Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
        # ------
        # Size
        # ------
        # Grow windows. If current window is on the edge of screen and direction
        # will be to screen edge - window would shrink.
        Key(
            [mod, "control"],
            "h",
            lazy.layout.grow_left(),
            desc="Grow window to the left",
        ),
        Key(
            [mod, "control"],
            "l",
            lazy.layout.grow_right(),
            desc="Grow window to the right",
        ),
        Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
        Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
        Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
        # ------
        # Layout mgmt
        # ------
        # Toggle between split and unsplit sides of stack.
        # Split = all windows displayed
        # Unsplit = 1 window displayed, like Max layout, but still with multiple stack panes
        Key(
            [mod, "shift"],
            "Return",
            lazy.layout.toggle_split(),
            desc="Toggle between split and unsplit sides of stack",
        ),
        Key([mod], "Tab", lazy.next_layout(), desc="Toggle between layouts"),
        Key([mod, "shift"], "q", lazy.window.kill(), desc="Kill focused window"),
        Key(
            [mod],
            "f",
            lazy.window.toggle_fullscreen(),
            desc="Toggle fullscreen on the focused window",
        ),
        Key(
            [mod, "shift"],
            "f",
            lazy.window.toggle_floating(),
            desc="Toggle floating on the focused window",
        ),
        # ------
        # Qtile management
        # ------
        Key([mod, "control"], "r", lazy.reload_config(), desc="Reload the config"),
        Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
        # ------
        # Launch apps
        # ------
        Key([mod], "r", lazy.spawncmd(), desc="Spawn a command using a prompt widget"),
        Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    ]

    # Add key bindings to switch VTs in Wayland.
    # We can't check qtile.core.name in default config as it is loaded before qtile is started
    # We therefore defer the check until the key binding is run by using .when(func=...)
    for vt in range(1, 8):
        keys.append(
            Key(
                ["control", "mod1"],
                f"f{vt}",
                lazy.core.change_vt(vt).when(func=lambda: qtile.core.name == "wayland"),
                desc=f"Switch to VT{vt}",
            )
        )

    groups = [Group(i) for i in "123456789"]

    for i in groups:
        keys.extend(
            [
                # mod1 + group number = switch to group
                Key(
                    [mod],
                    i.name,
                    lazy.group[i.name].toscreen(),
                    desc="Switch to group {}".format(i.name),
                ),
                # mod1 + shift + group number = switch to & move focused window to group
                Key(
                    [mod, "shift"],
                    i.name,
                    # lazy.window.togroup(i.name, switch_group=True),
                    lazy.window.togroup(i.name),
                    desc="Switch to & move focused window to group {}".format(i.name),
                ),
                # Or, use below if you prefer not to switch to that group.
                # # mod1 + shift + group number = move focused window to group
                # Key([mod, "shift"], i.name, lazy.window.togroup(i.name),
                #     desc="move focused window to group {}".format(i.name)),
            ]
        )
    return keys
