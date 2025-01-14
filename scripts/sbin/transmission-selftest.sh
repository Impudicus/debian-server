#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | awk '{print $2}' | grep --line-regexp "$package_name" > /dev/null
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
            push-notification.sh 'transmission' "$error_type" "$log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            push-notification.sh 'transmission' "$error_type" "$log_message"
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
    readonly config_file='/mnt/docker/transmission/config/settings.json'
    readonly max_attempts=1
    readonly max_waittime=0

    # --------------------------------------------------
    getContainer "gluetun" || {
        printLog "warn" "Selftest failed! Container 'gluetun' not found!"
        exit 1
    }
    getContainerRunstate "gluetun" || {
        printLog "error" "Selftest failed! Container 'gluetun' not running!"
        exit 1
    }

    getContainer "transmission" || {
        printLog "warn" "Selftest failed! Container 'transmission' not found!"
        exit 1
    }
    getContainerRunstate "transmission" || {
        printLog "error" "Selftest failed! Container 'transmission' not running!"
        exit 1
    }
    
    if ! [[ -f "$config_file" ]]; then
        printLog "error" "Selftest failed! Config file not found!"
        exit 1
    fi

    # --------------------------------------------------
    local old_port=$(grep --only-matching --perl-regexp '(?<="peer-port": )\d+' "$config_file")
    if [[ -z "$old_port" ]]; then
        printLog "error" "Selftest failed! Unable to get old port!"
        exit 1
    fi

    local new_port=$(docker exec --interactive gluetun cat /tmp/gluetun/forwarded_port)
    if [[ -z "$new_port" ]]; then
        printLog "error" "Selftest failed! Unable to get new port!"
        exit 1
    fi
    
    if [[ "$old_port" -eq "$new_port" ]]; then
        printLog "info" "Selftest skipped. Ports already match!"
        exit 0
    fi

    # --------------------------------------------------
    docker stop transmission > /dev/null || {
        printLog "error" "Selftest failed! Unable to stop container 'transmission'!"
        exit 1
    }

    sed --in-place "s/\"peer-port\": $old_port,/\"peer-port\": $new_port,/" "$config_file" || {
        printLog "error" "Selftest failed! Unable to change port in config file!"
        exit 1
    }

    docker start transmission > /dev/null || {
        printLog "error" "Selftest failed! Unable to start container 'transmission'!"
        exit 1
    }

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Selftest executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
