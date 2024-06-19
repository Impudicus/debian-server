#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

getTarget() {
    local device_name="${1}"
    case "${device_name}" in
        TS473a | ts473a)
            target_hostname='TS673a'
            target_ip_address='192.168.0.222'
            target_mac_address='24:5e:be:7e:6b:87'
            return 0
            ;;
        TS673a | ts673a)
            target_hostname='TS473a'
            target_ip_address='192.168.0.221'
            target_mac_address='24:5e:be:6c:2e:fe'
            return 0
            ;;
    esac
    return 1
}

getTargetRunstate() {
    local target_ip_address="${1}"
    ping -c 1 "${target_ip_address}" &> /dev/null
    return $?
}
setTargetRunstate() {
    local target_mac_address="${1}"
    wakeonlan "${target_mac_address}" &> /dev/null
    return $?
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            /usr/local/sbin/pushNotification.sh "wakeonlan" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;196m${log_text}\e[0m\n" >&1
            ;;
        okay)
            /usr/local/sbin/pushNotification.sh "wakeonlan" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;82m${log_text}\e[0m\n" >&1
            ;;
        warn)
            /usr/local/sbin/pushNotification.sh "wakeonlan" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;214m${log_text}\e[0m\n" >&1
            ;;
        info)
            /usr/local/sbin/pushNotification.sh "wakeonlan" "${log_type}" "${log_text}"
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

    local package_name="wakeonlan"
    local package_installed=$(dpkg-query --show --showformat='${db:Status-Status}' "${package_name}" 2>/dev/null)
    if [[ ! "${package_installed}" ]]; then
        printLog "error" "Unable to find dpkg-package '${package_name}'."
        printLog "text" "Check apt for missing packages and rerun the script."
        exit 1
    fi

    # variables
    option_force=''

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
    getTarget "${HOSTNAME}"
    if [[ $? -ne 0 ]]; then
        printLog "error" "Job failed!<br>Reason: Unable to identify target!"
        exit 1
    fi

    local attempt=1
    local max_attempts=4
    while [ ${attempt} -le ${max_attempts} ]; do
        setTargetRunstate "${target_mac_address}"
        if [[ $? -ne 0 ]]; then
            printLog "error" "Job failed!<br>Reason: Unable to wakeup target!"
            exit 1
        fi

        sleep 30

        getTargetRunstate "${target_ip_address}"
        if [[ $? -eq 0 ]]; then
            local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
            printLog "okay" "Target '${target_hostname}' woken up.<br>Runtime: ${job_duration}."
            exit 0
        fi

        attempt=$((attempt + 1))
    done

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "error" "Job failed!<br>Reason: Timeout after ${job_duration}!"
    exit 1
}

main "$@"
