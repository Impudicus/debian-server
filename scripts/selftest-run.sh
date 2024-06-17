#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

checkContainerRunstate() {
    local attempt=1
    local max_attempts=${max_attemts}
    while [ ${attempt} -le ${max_attempts} ]; do



        sleep ${max_waittime}

        attempt=$((attempt + 1))
    done

    return 1
}

checkServiceRunstate() {
    local attempt=1
    local max_attempts=${max_attemts}
    while [ ${attempt} -le ${max_attempts} ]; do

        local service_name="$1"
        local result=$(systemctl is-active ${service_name})
        if [[ "${result}" ]]; then
            return 0
        fi

        sleep ${max_waittime}

        attempt=$((attempt + 1))
    done

    return 1
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[41m${log_text}\e[0m\n" >&2
            ;;
        okay)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[42m${log_text}\e[0m\n" >&1
            ;;
        info)
            /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
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
    max_attemts=3
    max_waittime=30
    error_count=0

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

    # check services
    checkServiceRunstate "docker"
    if [[ $? -ne 0 ]]; then
        printLog "error" "Selftest failed. Reason: Service 'docker' is inactive."
        exit 1
    fi

    # check docker containers
    local containers=$(docker ps -a --format "{{.Names}}")
    if [[ ! "$containers" ]]; then
        printLog "error" "Selftest failed. Reason: No containers found."
        exit 1
    fi

    for container in $containers; do
        checkContainerRunstate "$container"
        if [[ $? -ne 0 ]]; then
            printLog "warn" "Selftest failing. Reason: Container '${container}' not running."
            error_count=$((error_count + 1))
        fi
    done


    sleep 1


    if [[ $error_count -eq 0 ]]; then
        local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
        printLog "okay" "Selftest successfull without errors. Runtime: ${job_duration}."
    else
        local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
        printLog "warn" "Selftest successfull with errors. Runtime: ${job_duration}."
    fi
    exit 0
}

main "$@"
