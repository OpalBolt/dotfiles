#                       ,,    ,,
#   .g8""8q.     mm     db  `7MM              `7MMF' `YMM'
# .dP'    `YM.   MM           MM                MM   .M'
# dM'      `MM mmMMmm `7MM    MM  .gP"Ya        MM .d"     .gP"Ya `7M'   `MF'`7MMpMMMb.pMMMb.   ,6"Yb. `7MMpdMAo.
# MM        MM   MM     MM    MM ,M'   Yb       MMMMM.    ,M'   Yb  VA   ,V    MM    MM    MM  8)   MM   MM   `Wb
# MM.      ,MP   MM     MM    MM 8M""""""       MM  VMA   8M""""""   VA ,V     MM    MM    MM   ,pm9MM   MM    M8
# `Mb.    ,dP'   MM     MM    MM YM.    ,       MM   `MM. YM.    ,    VVV      MM    MM    MM  8M   MM   MM   ,AP
#   `"bmmd"'     `Mbmo.JMML..JMML.`Mbmmd'     .JMML.   MMb.`Mbmmd'    ,V     .JMML  JMML  JMML.`Moo9^Yo. MMbmmd'
#       MMb                                                          ,V                                  MM
#        `bood'                                                   OOb"                                 .JMML.

from libqtile.backend.wayland import InputConfig
# from libqtile.backend.wayland.inputs import InputConfig


def load_keymap(lang: str):
    wl_input_rules = {
        "type:keyboard": InputConfig(
            # kb_options="caps:swapescape,altwin:swap_alt_win",
            kb_layout=lang,
            kb_repeat_rate=50,
            kb_repeat_delay=250,
        ),
    }
    return wl_input_rules
