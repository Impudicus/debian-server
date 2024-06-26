#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

getContainerRunstate() {
    local container_name="${1}"
    local container_runstate=$(/usr/bin/docker inspect --format "{{.State.Status}}" "${container_name}")
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
            printf "${script_name}: \e[38;5;196m${log_text}\e[0m\n" >&1
            ;;
        okay)
            # /usr/local/sbin/pushNotification.sh "nextcloud" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;82m${log_text}\e[0m\n" >&1
            ;;
        warn)
            # /usr/local/sbin/pushNotification.sh "nextcloud" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;214m${log_text}\e[0m\n" >&1
            ;;
        info)
            # /usr/local/sbin/pushNotification.sh "nextcloud" "${log_type}" "${log_text}"
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
    local container_name='nextcloud'
    getContainerRunstate "${container_name}"
    if [[ $? -ne 0 ]]; then
        printLog "warn" "Cronjob failed! Reason: Container '${container_name}' not running!"
        exit 1
    fi
    
    /usr/bin/docker exec -u www-data -t "${container_name}" php -f /var/www/html/cron.php &> /dev/null
    if [[ $? -ne 0 ]]; then
        printLog "error" "Cronjob failed! Reason: Unable to run cronjob!"
        exit 1
    fi

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "Cronjob successfully executed. Runtime: ${job_duration}."
    exit 0
}

main "$@"
