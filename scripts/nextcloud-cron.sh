#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

container_exec()
{
    /usr/bin/docker exec -u $3 -t $1 $2
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

container_status "nextcloud"
if [ $? -eq 0 ]; then
    notification "error" "job failed (nextcloud not running)!"
    exit 1
fi

# run cronjob: nextcloud
container_exec "nextcloud" "php -f /var/www/html/cron.php" "www-data"
if [ $? -ne 0 ]; then
    notification "error" "job failed (error while running command)!"
    exit 1
fi

exit 0
