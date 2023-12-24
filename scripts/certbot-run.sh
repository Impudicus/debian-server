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
    /usr/local/bin/notification-push.sh "certbot" "$1" "$2"
    exit 1
}

# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

container_status "certbot"
if [ $? -ne 0 ]; then
    notification "error" "job failed (certbot already running)!"
fi

container_start "certbot"
if [ $? -ne 0 ]; then
    notification "error" "job failed (unable to start container)!"
fi

# check container runstate every 10sec for 5min: certbot
starttime=$SECONDS
endtime=$(( SECONDS + 300 ))

while [ $SECONDS -lt $endtime ]; do

    container_status "certbot"
    if [ $? -eq 0 ]; then
        job_duration=$(($SECONDS - runtime))
        notification "okay" "job finished successfully (runtime: $job_duration sec)!"
    else
        sleep 10
    fi
done

job_duration=$(($SECONDS - runtime))
notification "error" "job failed (timeout: $job_duration sec)!"
exit 0
