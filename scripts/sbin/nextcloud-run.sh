#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

getContainer() {
    local container_name="$1"
    docker ps --all --format '{{.Names}}' | grep --word-regexp "$container_name" > /dev/null
    return $?
}
getContainerRunstate() {
    local container_name="$1"
    docker inspect --format "{{.State.Running}}" "$container_name" | grep --quiet "true"
    return $?
}

printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            push-notification.sh 'nextcloud' "$error_type" "$log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            push-notification.sh 'nextcloud' "$error_type" "$log_message"
            ;;
        info)
            echo -e "\e[96m[INFO]\e[39m $log_message"
            ;;
        success)
            echo -e "\e[92m[SUCCESS]\e[39m $log_message"
            ;;
        *)
            echo "$log_message"
            ;;
    esac
}

main() {
    # --------------------------------------------------
    # Prechecks
    if [[ "$EUID" -ne 0 ]]; then
        printLog "error" "Script must be run with root privileges!"
        exit 1
    fi

    getPackageInstallState "docker-ce" || {
        printLog "error" "Package 'docker-ce' not installed!"
        exit 1
    }

    # --------------------------------------------------
    # Variables

    # --------------------------------------------------
    getContainer "nextcloud" || {
        printLog "error" "Job failed! Container 'nextcloud' not found!"
        exit 1
    }
    getContainerRunstate "nextcloud" || {
        printLog "error" "Job failed! Container 'nextcloud' not running!"
        exit 1
    }

    # --------------------------------------------------
    docker exec --user www-data nextcloud php --file /var/www/html/cron.php || {
        printLog "error" "Job failed! Error while executing cron.php!"
        exit 1
    }

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Job executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
