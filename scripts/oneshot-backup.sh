#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

runBackup() {
    (
        cd "${source_dir}"

        for subdir in ./*; do
            if [[ ! -d "${subdir}" ]]; then
                printLog "error" "Invalid directory '${subdir}', skipped."
                continue
            elif [[ "${subdir}" == './lost+found' ]]; then
                printLog "info" "System directory '${subdir}', skipped."
                continue
            fi

            local subdir_name=$(basename "${subdir}")
            local backup_name="${subdir_name}.tar.gz"
            # tar --create --gzip --file "${target_dir}/${backup_name}" "${subdir_name}"

            printf "${script_name}: » '${backup_name}' created\n"
        done
    )
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
    printf "Usage: ${script_name} [OPTIONS]\n"
    printf "Options:\n"
    printf "  -h, --help        Show this help message.\n"
    printf "\n"
}

main() {
    # pre-checks
    if [[ "${EUID}" -ne 0 ]]; then
        printLog "error" "Script has to be run with root user privileges."
        exit 1
    fi

    # variables
    source_dir='/docker'
    target_dir="/mnt/pool1/backup/onetime_$(date +'%Y-%m-%d_%H-%M-%S')"

    # parameters
    while [[ $# -gt 0 ]]; do
        case "${1}" in
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

    if [[ ! "${source_dir}" ]]; then
        printLog "error" "Missing source directory, use --help for further information."
        exit 1
    elif [[ ! "${target_dir}" ]]; then
        printLog "error" "Missing target directory, use --help for further information."
        exit 1
    fi

    # run
    printLog "text" "Config loaded: using '${source_dir}' as source directory."
    printLog "text" "Config loaded: using '${target_dir}' as target directory."

    mkdir --parents "${target_dir}"
    printLog "okay" "Task completed: target directory created."

    printLog "info" "Task completed: create backups ..."
    runBackup
    printLog "okay" "Task completed: backups created."

    printLog "okay" "Script executed successfully."
}

main "$@"
