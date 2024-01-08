#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

notification()
{
    /usr/local/bin/notification-push.sh "powerstate" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

/usr/sbin/poweroff
if [ $? -ne 0 ]; then
    notification "error" "backup failed (error while shutting down)!"
    exit 1
else
    notification "info" "system shutting down!"
    exit 0
fi
