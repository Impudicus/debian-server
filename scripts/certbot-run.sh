#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

container_start()
{
    /usr/bin/docker start $1
    return $?
}
container_status()
{
    result=$(/usr/bin/docker inspect -f "{{.State.Status}}" "$1")
    if [ "$result" = "running" ]; then
        return 1
    else
        return 0
    fi
}

# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

# get container status: certbot
container_status "certbot"
if [ $? -eq 0 ]; then
    /usr/local/bin/notification-push.sh "certbot" "info" "job failed (certbot already running)!"
    exit 1
fi

job_duration=$(($SECONDS - runtime))
/usr/local/bin/notification-push.sh "certbot" "okay" "job finished successfully (runtime: $job_duration sec)!"
exit 0
