#!/bin/bash
# CAVA script for waybar
# Requires cava to be installed

# Temporary config file
config_file="/tmp/waybar_cava_config"
echo "
[general]
bars = 8
sleep_timer = 10
[input]
method = pulse
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
" > "$config_file"

# Run cava and map output to bar characters
# The sed command replaces the numeric output with Unicode characters
# for a smooth visual bar effect.
cava -p "$config_file" | sed -u 's/;//g;s/0/ /g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g'
