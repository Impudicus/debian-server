#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

container_status()
{
    result=$(/usr/bin/docker inspect -f "{{.State.Status}}" "$1")
    if [ "$result" = "running" ]; then
        return 1
    else
        return 0
    fi
}

notification()
{
    /usr/local/bin/notification-push.sh "nextcloud" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

container_status "nextcloud"
if [ $? -ne 0 ]; then
    notification "error" "job failed (certbot already running)!"
    exit 1
fi

job_duration=$(($SECONDS - runtime))
notification "error" "job failed (timeout: $job_duration sec)!"
exit 1
