#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

removeEmptyFolders() {
    find "${work_dir}" \
        -type d -empty \
         -delete -printf "${script_name}: » '%f' removed\n"
}

removeJunk() {
    local file_extensions=("idx" "ifo" "jpg" "jpeg" "m2ts" "nfo" "png" "sfv" "srt" "sub" "sup" "txt" "url")
    for file_extension in "${file_extensions[@]}"; do
        find "${work_dir}" \
            -type f -iname "*.$file_extension" \
             -delete -printf "${script_name}: » '%f' removed\n"
    done
}

removeSamples() {
    local file_extensions=("mkv" "mp4")
    for file_extension in "${file_extensions[@]}"; do
        find "${work_dir}" \
            -type f -iname "*sample*.$file_extension" -size -100M \
             -delete -printf "${script_name}: » '%f' removed\n"
    done
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            printf "${script_name}: \e[41m${log_text}\e[0m\n" >&2
            ;;
        okay)
            printf "${script_name}: \e[42m${log_text}\e[0m\n" >&1
            ;;
        info)
            printf "${script_name}: \e[44m${log_text}\e[0m\n" >&1
            ;;
        *)
            printf "${script_name}: ${log_text}\n" >&1
            ;;
    esac
}

printHelp() {
    printf "Usage: ${script_name} [TASKS] Path\n"
    printf "Tasks:\n"
    printf "      --all         Run all of the following tasks.\n"
    printf "  -e, --empty       Remove empty folders.\n"
    printf "  -h, --help        Print this help message.\n"
    printf "  -j, --junk        Remove junk files.\n"
    printf "  -s, --sample      Remove sample files.\n"
    printf "\n"
    printf "Paths:\n"
    printf "  downloads         Run operations on '/mnt/pool1/downloads/complete'.\n"
    printf "  transcode         Run operations on '/mnt/pool1/downloads/transcode'.\n"
    printf "\n"
}

main() {
    # pre-checks
    if [[ "${EUID}" -ne 0 ]]; then
        printLog "error" "Script has to be run with root user privileges."
        exit 1
    fi

    # variables
    work_dir='/mnt/pool1/downloads/complete'
    action_removeemptyfolders=''
    action_removejunk=''
    action_removesamples=''

    # parameters
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            downloads)
                work_dir='/mnt/pool1/downloads/complete'
                break
                ;;
            transcode)
                work_dir='/mnt/pool1/downloads/transcode'
                break
                ;;
            --all)
                action_removeemptyfolders='true'
                action_removejunk='true'
                action_removesamples='true'
                shift
                ;;
            -e | --empty)
                action_removeemptyfolders='true'
                shift
                ;;
            -j | --junk)
                action_removejunk='true'
                shift
                ;;
            -s | --sample)
                action_removesamples='true'
                shift
                ;;
            -h | --help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown option '${1}', use --help for further information."
                exit 1
                ;;
        esac
    done

    if [[ ! "${work_dir}" ]]; then
        printLog "error" "Missing working directory, use --help for further information."
        exit 1
    elif [[ ! "${action_removeemptyfolders}" && ! "${action_removejunk}" && ! "${action_removesamples}" ]]; then
        printLog "error" "No action selected, use --help for further information."
        exit 1
    fi

    # run
    printLog "text" "Config loaded: using '${work_dir}' as working directory."

    if [[ "${action_removejunk}" ]]; then
        printLog "info" "Task running: remove junk files ..."
        removeJunk
        printLog "okay" "Task completed: junk files removed."
        sleep 1
    fi

    if [[ "${action_removesamples}" ]]; then
        printLog "info" "Task running: remove sample files ..."
        removeSamples
        printLog "okay" "Task completed: sample files removed."
        sleep 1
    fi

    if [[ "${action_removeemptyfolders}" ]]; then
        printLog "info" "Task running: remove empty folders ..."
        removeEmptyFolders
        printLog "okay" "Task completed: empty folders removed."
        sleep 1
    fi

    printLog "okay" "Script executed successfully."
    exit 0
}

main "$@"
