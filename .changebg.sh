#!/bin/bash
newbg=$(ls -1 ~/Pictures/Backgrounds/*.* |  shuf | head -1)
lastbg=cat '~/.config/bglast.conf'

while [$newbg = $lastbg]
do
    newbg=$(ls -1 ~/Pictures/Backgrounds/*.* |  shuf | head -1)
done
$newbg > ~/.config/bglast.conf
echo "$newbg First new BG"
echo "$lastbg last BG"

gsettings set org.gnome.desktop.background picture-uri $newbg
