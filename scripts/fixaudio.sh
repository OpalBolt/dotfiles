#!/bin/sh
pkill -9 pipewire-pulse && pkill -9 pipewire
sleep 1
systemctl --user restart pipewire-pulse.socket
systemctl --user restart pipewire-pulse.service
systemctl --user restart pipewire.service
systemctl --user restart pipewire.socket
