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


# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

# get device slave
slave_name="$(device_slave $HOSTNAME)"
if [ $? -ne 0 ]; then
    /usr/local/bin/notification-push.sh "etherwake" "error" "job failed (unable to get device slave)!"
    exit 1
fi

job_duration=$(($SECONDS - runtime))
/usr/local/bin/notification-push.sh "etherwake" "success" "job finished successfully (runtime: $duration sec)!"
exit 0
