#!/bin/bash

FOLDER_PATH="/Applications/AegisCore/Tweaks"  

while true; do
    if [ -n "$(find "$FOLDER_PATH" -name '*.sh' -print -quit)" ]; then
        sh_file=$(find "$FOLDER_PATH" -name '*.sh' -print -quit)
        echo "Found .sh file: $sh_file"
        chmod +x "$sh_file"
        "$sh_file"
        break
    fi
    sleep 10
done
