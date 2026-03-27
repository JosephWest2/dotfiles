#!/bin/bash

if pgrep -f "nerd-dictation begin" >/dev/null; then
    notify-send "Nerd Dictation Disabled"
    nerd-dictation end
else
    notify-send "Nerd Dictation Enabled"
    nerd-dictation begin --simulate-input-tool=WTYPE
fi
