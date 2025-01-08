#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

validateConfiguration() {
    local config_file="$1"
    local required_keys=(
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "RESTIC_REPOSITORY"
        "RESTIC_PASSWORD"
    )

    if ! [[ -f "$config_file" ]]; then
        return 1
    fi
    for key in "${required_keys[@]}"; do
        if ! grep --quiet --word-regexp "$key" "$config_file"; then
            return 1
        fi
    done
    return 0
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options] <repository>"
    echo "Options:"
    echo "  -h, --help          Show this help message."
}
printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            push-notification.sh 'restic' "$error_type" "$log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            push-notification.sh 'restic' "$error_type" "$log_message"
            ;;
        info)
            echo -e "\e[96m[INFO]\e[39m $log_message"
            ;;
        success)
            echo -e "\e[92m[SUCCESS]\e[39m $log_message"
            push-notification.sh 'restic' "$error_type" "$log_message"
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

    getPackageInstallState "restic" || {
        printLog "error" "Package 'restic' not installed!"
        exit 1
    }

    # --------------------------------------------------
    # Variables
    local config_file='/etc/environment'
    local repository=''

    # --------------------------------------------------
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local parameter="$1"
        case "$parameter" in
            -h|--help)
                printHelp
                exit 0
                ;;
            *)
                repository="$parameter"
                if [[ -z "$repository" ]]; then
                    printLog "error" "Missing repository; use --help for further information!"
                    exit 1
                elif ! [[ -d $(dirname "$repository") ]]; then
                    printLog "error" "Repository directory does not exist; use --help for further information!"
                    exit 1
                fi
                break
                ;;
        esac
        shift
    done

    # --------------------------------------------------
    printLog "info" "Current job: Validating configuration file..."
    validateConfiguration "$config_file" || {
        printLog "error" "Init failed! Configuration file is invalid!"
        exit 1
    }

    printLog "info" "Current job: Importing configuration file..."
    source "$config_file" || {
        printLog "error" "Init failed! Unable to import configuration file!"
        exit 1
    }
    repository=${repository:-$RESTIC_REPOSITORY} || {
        printLog "error" "Init failed! Repository not provided!"
        exit 1
    }

    printLog "info" "Current job: Initializing restic repository '$repository'..."
    restic init --repo "$repository" || {
        printLog "error" "Init failed! Unable to initialize restic repository!"
        exit 1
    }

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Init executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
