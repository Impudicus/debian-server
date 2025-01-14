#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | awk '{print $2}' | grep --line-regexp "$package_name" > /dev/null
    return $?
}

getContainerRunstate() {
    local container_name="$1"
    local attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        if docker inspect --format "{{.State.Running}}" "$container_name" | grep --quiet "true"; then
            return 0
        elif docker inspect --format "{{.State.Status}}" "$container_name" | grep --quiet "exited" && \
             docker inspect --format "{{.State.ExitCode}}" "$container_name" | grep --quiet "0"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep $max_waittime
    done
    return 1
}

getMountState() {
    local mount_point="$1"
    local attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        if mountpoint --quiet "$mount_point"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep $max_waittime
    done
    return 1
}

getRaidState() {
    local raid_array="$1"
    local attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        if mdadm --detail "$raid_array" | grep --quiet --word-regexp "State : clean"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep $max_waittime
    done
    return 0
}

getRaidPersistence() {
    local raid_array="$1"
    local attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        if mdadm --detail "$raid_array" | grep --quiet --word-regexp "Persistent : Superblock is persistent"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep $max_waittime
    done
    return 0
}

getServiceRunstate() {
    local service_name="$1"
    local attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        if systemctl is-enabled "$service_name.service" 2> /dev/null | grep --quiet --word-regexp "disabled"; then
            return 0
        elif systemctl is-active "$service_name.service" 2> /dev/null | grep --quiet --word-regexp "active"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep $max_waittime
    done
    return 1
}

getTimerRunstate() {
    local timer_name="$1"
    local attempts=0

    while [[ $attempts -lt $max_attempts ]]; do
        if systemctl is-enabled "$timer_name.timer" 2> /dev/null | grep --quiet --word-regexp "disabled"; then
            return 0
        elif systemctl is-active "$timer_name.timer" 2> /dev/null | grep --quiet --word-regexp "active"; then
            return 0
        fi
        attempts=$((attempts + 1))
        sleep $max_waittime
    done
    return 1
}

printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            push-notification.sh 'debian' "$error_type" "$log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            push-notification.sh 'debian' "$error_type" "$log_message"
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

    getPackageInstallState "mdadm" || {
        printLog "error" "Package 'mdadm' not installed!"
        exit 1
    }
    

    # --------------------------------------------------
    # Variables
    readonly max_attempts=1
    readonly max_waittime=0

    # --------------------------------------------------
    printLog "info" "Current selftest: Checking docker containers..."
    local docker_containers=$(docker ps --all --format "{{.Names}}")
    if [[ -z "$docker_containers" ]]; then
        printLog "warn" "Selftest failing! No containers found!"
        sleep 1
    else
        for docker_container in $docker_containers; do
            getContainerRunstate "$docker_container" || {
                printLog "error" "Selftest failing! Container '$docker_container' stopped!"
            }
        done
    fi

    printLog "info" "Current selftest: Checking mount points..."
    local mount_points=("/" "/mnt/pool1" "/mnt/pool2")
    if [[ -z "$mount_points" ]]; then
        printLog "warn" "Selftest failing! No mount points found!"
        sleep 1
    else
        for mount_point in "${mount_points[@]}"; do
            getMountState "$mount_point" || {
                printLog "error" "Selftest failing! Mount point '$mount_point' not mounted!"
            }
        done
    fi

    printLog "info" "Current selftest: Checking RAID status..."
    local raid_arrays=$(mdadm --detail --scan | grep --only-matching "/dev/md/[0-9]")
    if [[ -z "$raid_arrays" ]]; then
        printLog "warn" "Selftest failing! No RAID arrays found!"
        sleep 1
    else
        for raid_array in $raid_arrays; do
            getRaidState "$raid_array" || {
                printLog "error" "Selftest failing! RAID array '$raid_array' not clean!"
            }
            getRaidPersistence "$raid_array" || {
                printLog "error" "Selftest failing! RAID array '$raid_array' not persistent!"
            }
        done
    fi

    printLog "info" "Current selftest: Checking services..."
    local system_services=("debian-powerstate" "telegraf")
    if [[ -z "$system_services" ]]; then
        printLog "warn" "Selftest failing! No services found!"
        sleep 1
    else
        for system_service in "${system_services[@]}"; do
            getServiceRunstate "$system_service" || {
                printLog "error" "Selftest failing! Service '$system_service' not running!"
            }
        done
    fi

    printLog "info" "Current selftest: Checking timers..."
    local system_timers=("debian-selftest" "nextcloud" "restic" "transmission-selftest")
    if [[ -z "$system_timers" ]]; then
        printLog "warn" "Selftest failing! No timers found!"
        sleep 1
    else
        for system_timer in "${system_timers[@]}"; do
            getTimerRunstate "$system_timer" || {
                printLog "error" "Selftest failing! Timer '$system_timer' not running!"
            }
        done
    fi

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Selftest executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
