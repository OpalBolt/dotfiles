#                       ,,    ,,
#   .g8""8q.     mm     db  `7MM               .M"""bgd
# .dP'    `YM.   MM           MM              ,MI    "Y
# dM'      `MM mmMMmm `7MM    MM  .gP"Ya      `MMb.      ,p6"bo `7Mb,od8 .gP"Ya   .gP"Ya `7MMpMMMb.  ,pP"Ybd
# MM        MM   MM     MM    MM ,M'   Yb       `YMMNq. 6M'  OO   MM' "',M'   Yb ,M'   Yb  MM    MM  8I   `"
# MM.      ,MP   MM     MM    MM 8M""""""     .     `MM 8M        MM    8M"""""" 8M""""""  MM    MM  `YMMMa.
# `Mb.    ,dP'   MM     MM    MM YM.    ,     Mb     dM YM.    ,  MM    YM.    , YM.    ,  MM    MM  L.   I8
#   `"bmmd"'     `Mbmo.JMML..JMML.`Mbmmd'     P"Ybmmd"   YMbmd' .JMML.   `Mbmmd'  `Mbmmd'.JMML  JMML.M9mmmP'
#       MMb
#        `bood'

import initbars
from libqtile.config import Screen
from libqtile import bar, widget


def load_screens(colors):
    screens = [
        Screen(
            wallpaper="/home/mads/HQ Ghibli Wallpapers/Spirited Away/04.png",
            wallpaper_mode="fill",
            top=initbars.load_bars(colors),
        ),
    ]
    return screens
