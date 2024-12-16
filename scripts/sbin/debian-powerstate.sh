#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            push-notification.sh 'debian' "$error_type" "$log_message"
            ;;
        info)
            echo -e "\e[96m[INFO]\e[39m $log_message"
            push-notification.sh 'debian' "$error_type" "$log_message"
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

    # --------------------------------------------------
    # Variables
    local power_state="$1"

    # --------------------------------------------------
    if [[ -z "$power_state" ]]; then
        printLog "error" "Missing argument 'power_state'!"
        exit 1
    fi

    case "$power_state" in
        poweron)
            printLog "info" "System powered on."
            ;;
        poweroff)
            printLog "warn" "System powered off."
            ;;
        *)
            printLog "error" "Invalid power_state '$power_state'!"
            exit 1
            ;;
    esac
    exit 0
}

main "$@"
