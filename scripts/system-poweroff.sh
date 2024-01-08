#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

notification()
{
    /usr/local/bin/notification-push.sh "powerstate" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

notification "info" "system shutting down!"
if [ $? -ne 0 ]; then
    exit 1
fi

/usr/sbin/poweroff
if [ $? -ne 0 ]; then
    notification "error" "backup failed (error while shutting down)!"
    exit 1
fi
