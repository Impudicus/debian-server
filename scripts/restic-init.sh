#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

device_slave()
{
    if [ "$1" = "TS473a" ]; then
        echo "TS673a"
        return 0
    fi
    if [ "$1" = "TS673a" ]; then
        echo "TS473a"
        return 0
    fi
    return 1
}
device_status()
{
    timeout=2
    result=$(/usr/bin/ping -c 1 -W $timeout $1 >/dev/null;)
    return $result
}

notification()
{
    /usr/local/bin/notification-push.sh "restic" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

slave_name="$(device_slave $HOSTNAME)"
if [ $? -ne 0 ]; then
    notification "error" "job failed (unable to get device slave)!"
    exit 1
fi

device_status $slave_name
if [ $? -eq 0 ]; then
    notification "info" "job failed ('$slave_name' already online)!"
    exit 1
fi



job_duration=$(($SECONDS - runtime))
notification "okay" "job finished successfully (runtime: $job_duration sec)!"
exit 0
