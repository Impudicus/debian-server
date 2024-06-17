#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

runBackups() {
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
            local backup_name="${subdir_name}.tar"
            tar --create --file "${target_dir}/${backup_name}" "${subdir_name}"

            printf "${script_name}: » '${backup_name}' created\n"
        done
    )
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;196m${log_text}\e[0m\n" >&1
            ;;
        okay)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;82m${log_text}\e[0m\n" >&1
            ;;
        warn)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;214m${log_text}\e[0m\n" >&1
            ;;
        info)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;21m${log_text}\e[0m\n" >&1
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
    printLog "text" "Config loaded: Using '${source_dir}' as source directory."
    printLog "text" "Config loaded: Using '${target_dir}' as target directory."

    mkdir --parents "${target_dir}"
    printLog "okay" "Task completed: Target directory created."

    printLog "info" "Task running: Create backups ..."
    runBackups
    printLog "okay" "Task completed: Backups created."

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "One-Time-Backup successfully created. Runtime: ${job_duration}."
    exit 0
}

main "$@"
