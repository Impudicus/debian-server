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
setContainerRunstate() {
    local container_name="${1}"
    local container_runstate="${2}"
    if [[ "${container_runstate}" == 'start'  ]]; then
        docker start "${container_name}" &> /dev/null
        return $?
    elif [[ "${container_runstate}" == 'stop'  ]]; then
        docker stop "${container_name}" &> /dev/null
        return $?
    else
        return 1
    fi
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            pushNotification.sh "kometa" "${log_type}" "${log_text}"
            printf "${script_name}: \e[41m${log_text}\e[0m\n" >&2
            ;;
        okay)
            pushNotification.sh "kometa" "${log_type}" "${log_text}"
            printf "${script_name}: \e[42m${log_text}\e[0m\n" >&1
            ;;
        info)
            pushNotification.sh "kometa" "${log_type}" "${log_text}"
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
    local check_container='plex'
    getContainerRunstate "${check_container}"
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Container '${check_container}' not running!"
        exit 1
    fi

    local check_container='kometa'
    getContainerRunstate "${check_container}"
    if [[ $? -eq 0 ]]; then
        printLog "error" "Job failed! Reason: Container '${check_container}' already running!"
        exit 1
    fi

    local check_container='imagemaid'
    getContainerRunstate "${check_container}"
    if [[ $? -eq 0 ]]; then
        printLog "error" "Job failed! Reason: Container '${check_container}' still running!"
        exit 1
    fi

    local start_container='kometa'
    setContainerRunstate "${start_container}" 'start'
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Unable to start container '${start_container}'!"
        exit 1
    fi

    local endtime=$((SECONDS + 3600))   # 30min
    while [[ $SECONDS -lt $endtime ]]; do
        sleep 10

        local check_container='kometa'
        getContainerRunstate "${check_container}"
        if [[ $? -ne 0 ]]; then
            local job_duration=$(getJobDuration.sh $script_start $SECONDS)
            printLog "okay" "Job finished successfully. Runtime: ${job_duration}."
            exit 0
        fi
    done

    local job_duration=$(getJobDuration.sh $script_start $SECONDS)
    printLog "error" "Job failed! Reason: Timeout after ${job_duration}!"
    exit 1
}

main "$@"
