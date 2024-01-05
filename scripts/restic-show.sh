#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt


backup_show()
{
    /usr/bin/restic \
        -r "sftp:$1:$2" \
        snapshots \
        --password-file "/root/.config/restic/password"
    return $?
}


connect_check()
{
    /usr/bin/ssh -q \
        root@$1 \
        "echo Fine"
    return $?
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


notification()
{
    /usr/local/bin/notification-push.sh "restic" "$1" "$2"
    return $?
}


repository_check()
{
    /usr/bin/restic \
        -r "sftp:$1:$2" \
        check \
        --password-file "/root/.config/restic/password" \
        1> /dev/null 2> /dev/null
    return $?
}


# ========================= ========================= =========================
# MAIN

job_runtime=$SECONDS

slave_name="$(device_slave $HOSTNAME)"
if [ $? -ne 0 ]; then
    echo "ERROR: lookup failed (unable to get device slave)!"
    exit 1
fi

device_status $slave_name
if [ $? -ne 0 ]; then
    echo "ERROR: lookup failed (slave not online)!"
    exit 1
fi

connect_check $slave_name
if [ $? -ne 0 ]; then
    echo "ERROR: lookup failed (unable to connect to slave)!"
    exit 1
fi

current_year=$(date +"%Y")
repository="/pool1/backup/$HOSTNAME-$current_year"

repository_check $slave_name $repository
if [ $? -ne 0 ]; then
    echo "ERROR: lookup failed (unable to locate repository on slave)!"
    exit 1
fi

backup_show $slave_name $repository
if [ $? -ne 0 ]; then
    echo "ERROR: lookup failed (error while looking up backup)!"
    exit 1
fi

job_duration=$(($SECONDS - runtime))
echo "INFO: lookup finished successfully (runtime: $job_duration sec)!"
exit 0
