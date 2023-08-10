#!/bin/bash
newbg=$("ls" -1 ~/Pictures/Backgrounds/*.* |  shuf | head -1)
#echo "test $newbg"
gsettings set org.gnome.desktop.background picture-uri $newbg
