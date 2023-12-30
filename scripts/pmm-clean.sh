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

notification()
{
    /usr/local/bin/notification-push.sh "nextcloud" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

# check container runstates
container_status "plex"
if [ $? -eq 0 ]; then
    notification "error" "job failed (plex not running)!"
    exit 1
fi

container_status "plex-meta-manager"
if [ $? -ne 0 ]; then
    notification "error" "job failed (plex-meta-manager already running)!"
    exit 1
fi

container_status "plex-image-cleanup"
if [ $? -ne 0 ]; then
    notification "error" "job failed (plex-image-cleanup already running)!"
    exit 1
fi

# run container: plex-image-cleanup
container_start "plex-image-cleanup"
if [ $? -ne 0 ]; then
    notification "error" "job failed (unable to start plex-image-cleanup)!"
    exit 1
fi

# check container runstate every 15sec for 60min: plex-image-cleanup
starttime=$SECONDS
endtime=$(( SECONDS + 3600 ))

while [ $SECONDS -lt $endtime ]; do

    container_status "plex-image-cleanup"
    if [ $? -eq 0 ]; then
        job_duration=$(($SECONDS - runtime))
        notification "okay" "job finished successfully (runtime: $job_duration sec)!"
        exit 0
    else
        sleep 15
    fi
done

job_duration=$(($SECONDS - runtime))
notification "error" "job failed (timeout: $job_duration sec)!"
exit 1
