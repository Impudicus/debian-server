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

output_error()
{
    /usr/local/bin/notification-push.sh "certbot" "error" "$1"
    exit 1
}
output_info()
{
    /usr/local/bin/notification-push.sh "certbot" "info" "$1"
    exit 1
}
output_okay()
{
    /usr/local/bin/notification-push.sh "certbot" "none" "$1"
    exit 0
}

# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

container_status "certbot"
if [ $? -ne 0 ]; then
    output_info "job failed (certbot already running)!"
fi

container_start "certbot"
if [ $? -ne 0 ]; then
    output_error "job failed (unable to start container)!"
fi

# check container runstate every 10sec for 5min: certbot
starttime=$SECONDS
endtime=$(( SECONDS + 300 ))

while [ $SECONDS -lt $endtime ]; do

    container_status "certbot"
    if [ $? -eq 0 ]; then

        job_duration=$(($SECONDS - runtime))
        output_okay "job finished successfully (runtime: $job_duration sec)!"
    else
        sleep 10
    fi
done

job_duration=$(($SECONDS - runtime))
output_error "job failed (timeout: $job_duration sec)!"
exit 0
