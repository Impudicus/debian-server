#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

notification()
{
    /usr/local/bin/notification-push.sh "poweroff" "$1" "$2"
    exit 1
}

# ========================= ========================= =========================
# MAIN

/usr/sbin/poweroff
if [ $? -eq 0 ]; then
    notification "error" "job failed (unable to poweroff)!"
    exit 1
else
    notification "okay" "system shutting down!"
    exit 1
fi
