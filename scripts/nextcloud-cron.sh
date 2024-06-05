#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

getContainerRunstate() {
    local container_name="${1}"
    local container_runstate=$(docker inspect --format "{{.State.Status}}" "${container_name}")
    if [[ "${container_runstate}" == 'running' ]]; then
        return 0
    else
        return 1
    fi
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            /usr/local/sbin/pushNotification.sh "nextcloud" "${log_type}" "${log_text}"
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

    # run
    local check_container='nextcloud'
    getContainerRunstate "${check_container}"
    if [[ $? -ne 0 ]]; then
        # printLog "error" "Job failed! Reason: Container '${check_container}' not running!"
        exit 1
    fi

    local container_name='nextcloud'
    docker exec -u www-data -t "${container_name}" php -f /var/www/html/cron.php
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Unable to run cronjob!"
        exit 1
    fi

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "Cronjob successfully run. Runtime: ${job_duration}."
    exit 0
}

main "$@"
