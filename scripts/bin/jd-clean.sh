#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails
set -o nounset  # Exit when using undeclared variables

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

removeDummyFiles() {
    local work_dir="$1"
    find "$work_dir" \
        -type f \
        -size 0 \
        -not -path '*/\.*' \
        -delete \
        -printf "%f\n"
    return $?
}

removeEmptyFolders() {
    local work_dir="$1"
    find "$work_dir" \
        -type d \
        -empty \
        -delete \
        -printf "%f\n"
    return $?
}

removeJunkFiles() {
    local work_dir="$1"
    find "$work_dir" \
        -type f \
        \( \
            -iname "rushchk.log" -o \
            -iname "*.gif" -o \
            -iname "*.idx" -o \
            -iname "*.ifo" -o \
            -iname "*.jpg" -o \
            -iname "*.jpeg" -o \
            -iname "*.m2ts" -o \
            -iname "*.nfo" -o \
            -iname "*.png" -o \
            -iname "*.sfc" -o \
            -iname "*.sfv" -o \
            -iname "*.svg" -o \
            -iname "*.sub" -o \
            -iname "*.sup" -o \
            -iname "*.txt" -o \
            -iname "*.url" \
        \) \
        -delete \
        -printf "%f\n"
    return $?
}

removeSampleFiles() {
    local work_dir="$1"
    find "$work_dir" \
        -type f \
        -size -250M \
        \( \
            -iname "*sample*" -o \
            -iname "*trailer*" \
        \) \
        -delete \
        -printf "%f\n"
    return $?
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo "Options:"
    echo "  -h, --help                          Show this help message."
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

    # --------------------------------------------------
    # Variables
    local work_dirs=()

    # --------------------------------------------------
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local parameter="$1"
        case "$parameter" in
            all)
                work_dirs+=('/mnt/pool2/downloads/complete')
                work_dirs+=('/mnt/pool2/transcode/complete')
                break
                ;;
            downloads)
                work_dirs=('/mnt/pool2/downloads/complete')
                break
                ;;
            transcode)
                work_dirs=('/mnt/pool2/transcode/complete')
                break
                ;;
            -h|--help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown parameter '$parameter'; use --help for further information!"
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "${work_dirs[*]}" ]]; then
        printLog "error" "Missing work_dirs; use --help for further information!"
        exit 1
    fi

    # --------------------------------------------------
    for work_dir in "${work_dirs[@]}"; do
        printLog "info" "Workdir set to '$work_dir'."
        printLog "info" "Current job: Removing junk files ..."
        removeJunkFiles "$work_dir"

        printLog "info" "Current job: Removing sample files ..."
        removeSampleFiles "$work_dir"

        printLog "info" "Current job: Removing dummy files ..."
        removeDummyFiles "$work_dir"

        printLog "info" "Current job: Removing empty folders ..."
        removeEmptyFolders "$work_dir"
    done

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Script executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
