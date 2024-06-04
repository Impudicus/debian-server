#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

getTargetVariables() {
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
            *)
                return 1
                ;;
        esac
}

checkTargetConnection() {
    local target_name="${1}"
    ssh -q -o BatchMode=true "root@${target_name}" "exit"
    return $?
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
    getTargetVariables "${HOSTNAME}"
    if [[ $? -ne 0 ]]; then
        printLog "info" "Job failed! Reason: Unable to find target stats!"
        exit 1
    fi

    checkTargetConnection "${target_hostname}"
    if [[ $? -ne 0 ]]; then
        printLog "info" "Job failed! Reason: Unable to etablish connection to '${target_hostname}'!"
        exit 1
    fi

    printLog "okay" "Script executed successfully."
    exit 0
}

main "$@"
