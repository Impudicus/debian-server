#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
# set -o errexit  # exit on error
# set -o pipefail # return exit status on pipefail

getContainerRunstate() {
    local result=$(/usr/bin/docker inspect --format "{{.State.Status}}" "${1}")
    if [[ "${result}" == 'running' ]]; then
        return 0
    else
        return 1
    fi
}
setContainerRunstate() {
    if [[ "${2}" == 'start'  ]]; then
        docker start "${1}" &> /dev/null
        return $?
    elif [[ "${2}" == 'stop'  ]]; then
        docker stop "${1}" &> /dev/null
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
            /usr/local/sbin/pushNotification.sh "transmission" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;196m${log_text}\e[0m\n" >&1
            ;;
        okay)
            /usr/local/sbin/pushNotification.sh "transmission" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;82m${log_text}\e[0m\n" >&1
            ;;
        warn)
            # /usr/local/sbin/pushNotification.sh "transmission" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;214m${log_text}\e[0m\n" >&1
            ;;
        info)
            # /usr/local/sbin/pushNotification.sh "transmission" "${log_type}" "${log_text}"
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
    setting_file='/docker/transmission/config/settings.json'

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
    local container_name='gluetun'
    getContainerRunstate "${container_name}"
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Container '${container_name}' not running!"
        exit 1
    fi

    if [[ ! -f "${setting_file}" ]]; then
        printLog "error" "Job failed! Reason: No such file 'settings.json'!"
        exit 1
    fi

    local new_port=$(docker logs gluetun | grep 'port forwarded' | tail -n 1 | awk '{print $NF}')
    if [[ ! "${new_port}" =~ ^[0-9]{5}$ ]]; then
        printLog "error" "Job failed! Reason: Unable to grep new exposed port!"
        exit 1
    fi

    local old_port=$(grep -oP '"peer-port": \K[0-9]+' "${setting_file}")
    if [[ ! "${old_port}" =~ ^[0-9]{5}$ ]]; then
        printLog "error" "Job failed! Reason: Unable to grep current exposed port!"
        exit 1
    fi

    if [[ ${old_port} == ${new_port} ]]; then
        local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
        printLog "info" "Transmission exposed port matching. Runtime: ${job_duration}."
        exit 0
    fi

    local container_name='transmission'
    setContainerRunstate "${container_name}" 'stop'
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Unable to stop container '${container_name}'!"
        exit 1
    fi

    sed -i "s/\"peer-port\": ${old_port}/\"peer-port\": ${new_port}/" "${setting_file}"
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Unable to change configuration!"
        exit 1
    fi

    local container_name='transmission'
    setContainerRunstate "${container_name}" 'start'
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed! Reason: Unable to start container '${container_name}'!"
        exit 1
    fi

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "Transmission exposed port changed. Runtime: ${job_duration}."
    exit 0
}

main "$@"
