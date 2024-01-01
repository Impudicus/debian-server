#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

device_mac()
{
    if [ "$1" = "TS473a" ]; then
        echo "24:5e:be:6c:2e:fe"
        return 0
    fi
    if [ "$1" = "TS673a" ]; then
        echo "24:5e:be:7e:6b:87"
        return 0
    fi
    return 1
}
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
device_wakeup()
{
    /usr/sbin/etherwake -i "enp5s0" $1
    return $?
}

notification()
{
    /usr/local/bin/notification-push.sh "etherwake" "$1" "$2"
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

slave_mac=$(device_mac $slave_name)
if [ $? -ne 0 ]; then
    notification "error" "job failed (unable to lookup slave mac-address)!"
    exit 1
fi

device_wakeup $slave_mac
if [ $? -ne 0 ]; then
    notification "error" "job failed (error while running command)!"
    exit 1
fi

sleep 30

device_status $slave_name
if [ $? -eq 0 ]; then
    notification "error" "job failed (slave still offline)!"
    exit 1
fi

job_duration=$(($SECONDS - runtime))
notification "okay" "job finished successfully (runtime: $job_duration sec)!"
exit 0
