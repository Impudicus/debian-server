#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

getAppToken() {
    local app_name="$1"
    case "$app_name" in
        debian)
            echo "asdpr25tei6i5969mcodw1ynsu7jp3"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

getMessageSound() {
    local message_type="$1"
    case "$message_type" in
        error|warn)
            echo "pushover"
            ;;
        info|success)
            echo "none"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

formatMessage() {
    local message_type="$1"
    local message_text="$2"
    case "$message_type" in
        error)
            echo "<span style='color:#DB4437'>$message_text</span>"
            ;;
        warn)
            echo "<span style='color:#F4B400'>$message_text</span>"
            ;;
        info)
            echo "<span style='color:#4285F4'>$message_text</span>"
            ;;
        success)
            echo "<span style='color:#0F9D58'>$message_text</span>"
            ;;
        *)
            return 1
            ;;
    esac
    return 0
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options] <app_name> <message_type> <message_text>"
    echo "Options:"
    echo "  -h, --help          Show this help message."
}
printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
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
    getPackageInstallState "curl" || {
        printLog "error" "Package 'curl' not installed!"
        exit 1
    }

    # --------------------------------------------------
    # Variables
    local app_name=''
    local message_type=''
    local message_text=''
    local user_token='uc8joh6vaszypwuvrprbyqfqgpwobb'

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
                app_name="$1"
                if [[ -z "$app_name" ]]; then
                    printLog "error" "Missing parameter 'app_name'; use --help for further information!"
                    exit 1
                fi

                message_type="$2"
                if [[ -z "$message_type" ]]; then
                    printLog "error" "Missing parameter 'message_type'; use --help for further information!"
                    exit 1
                fi

                message_text="$3"
                if [[ -z "$message_text" ]]; then
                    printLog "error" "Missing parameter 'message_text'; use --help for further information!"
                    exit 1
                fi

                break
                ;;
        esac
        shift
    done

    # --------------------------------------------------
    local app_token=$(getAppToken "$app_name")
    if [[ -z "$app_token" ]]; then
        printLog "error" "Invalid parameter 'app_name'; use --help for further information!"
        exit 1
    fi

    local message_sound=$(getMessageSound "$message_type")
    if [[ -z "$message_sound" ]]; then
        printLog "error" "Invalid parameter 'message_type'; use --help for further information!"
        exit 1
    fi

    local message_text=$(formatMessage "$message_type" "$message_text")
    if [[ -z "$message_text" ]]; then
        printLog "error" "Invalid parameter 'message_type'; use --help for further information!"
        exit 1
    fi

    curl \
        --silent \
        --form-string "token=$app_token" \
        --form-string "user=$user_token" \
        --form-string "html=1" \
        --form-string "sound=$message_sound" \
        --form-string "title=$app_name on $HOSTNAME" \
        --form-string "message=$(echo $message_text | sed -E 's/([!.] )/\1<br>/g')" \
        https://api.pushover.net/1/messages.json > /dev/null
    exit 0
}

main "$@"
