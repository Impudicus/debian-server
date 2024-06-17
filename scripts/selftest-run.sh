#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

checkContainerRunstate() {
    local attempt=1
    while [ ${attempt} -le ${max_attempts} ]; do

        local result=$(docker inspect --format "{{.State.Status}}" "${1}")
        if [[ "${result}" == 'running' ]]; then
            return 0
        fi

        sleep ${max_waittime}

        attempt=$((attempt + 1))
    done

    return 1
}

checkMountState() {
    local attempt=1
    while [ ${attempt} -le ${max_attempts} ]; do

        local result=$(mount | grep "on ${1}")
        if [[ "${result}" ]]; then
            return 0
        fi

        sleep ${max_waittime}

        attempt=$((attempt + 1))
    done

    return 1
}

checkServiceRunstate() {
    local attempt=1
    while [ ${attempt} -le ${max_attempts} ]; do

        local result=$(systemctl is-active ${1})
        if [[ ${result} ]]; then
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
    max_attempts=3
    max_waittime=10
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

    # check mount states
    local mountpoints=("/docker" "/mnt/pool1")
    if [[ ! "$mountpoints" ]]; then
        printLog "error" "Selftest failed. Reason: No mountpoints defined."
        exit 1
    fi

    for mountpoint in "${mountpoints[@]}"; do

        checkMountState "${mountpoint}"
        if [[ $? -ne 0 ]]; then
            printLog "warn" "Selftest failing. Reason: '${mountpoint}' not mounted."
            error_count=$((error_count + 1))
        fi
    done

    # check service runstates
    local services=("cron" "docker" "fancontrol" "nfs-server" "ntp" "ntpd" "mdadm" "smbd" "sshd")
    if [[ ! "$services" ]]; then
        printLog "error" "Selftest failed. Reason: No services defined."
        exit 1
    fi

    for service in "${services[@]}"; do
        checkServiceRunstate "${service}"
        if [[ $? -ne 0 ]]; then
            printLog "warn" "Selftest failing. Reason: Service '${service}' not running."
            error_count=$((error_count + 1))
        fi
    done

    # check container runstates
    local containers=$(docker ps -a --format "{{.Names}}")
    if [[ ! "$containers" ]]; then
        printLog "error" "Selftest failed. Reason: No containers found."
        exit 1
    fi

    for container in $containers; do
        checkContainerRunstate "${container}"
        if [[ $? -ne 0 ]]; then
            printLog "warn" "Selftest failing. Reason: Container '${container}' not running."
            error_count=$((error_count + 1))
        fi
    done

    # end
    if [[ $error_count -eq 0 ]]; then
        local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
        printLog "okay" "Selftest successfull without errors. Runtime: ${job_duration}."
    else
        local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
        printLog "warn" "Selftest successfull with errors. Runtime: ${job_duration}."
        printLog "error" "Selftest successfull with errors. Runtime: ${job_duration}."
        printLog "warn" "Selftest successfull with errors. Runtime: ${job_duration}."
        printLog "info" "Selftest successfull with errors. Runtime: ${job_duration}."
    fi
    exit 0
}

main "$@"
