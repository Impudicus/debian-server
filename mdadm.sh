#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

runConfig() {
    # configured
    printLog "info" "Looking for configured RAID-Volumes ..."
    local used_volume=$(blkid | grep "md0" | awk '{print $2}')
    local used_config=$(cat "/proc/mdstat" | grep "md0")
    if [[ "${used_config}" && "${used_volume}"  ]]; then
        printLog "okay" "Configured RAID-Volume '${used_config}' found."
        read -p "${script_name}: Would you like to add volume to fstab? Usage: <YES|no> " add_volume
        if [[ "${add_volume}" == 'YES' ]]; then
            local volume_uuid=$(echo "${used_volume}" | cut --delimiter '"' --fields 2)
            echo "UUID=${volume_uuid} /mnt/pool1 ext4 defaults 0 3" >> --append "/etc/fstab"

            systemctl daemon-reload

            mkdir --parents /mnt/pool1

            printLog "okay" "RAID-Volume added to fstab."
            printLog "text" "System restart pending."
            exit 0
        fi

        read -p "${script_name}: Would you like to remove volume from config? Usage: <YES|no> " del_volume
        if [[ "${del_volume}" == 'YES' ]]; then
            cat "${config_dir}/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf"
            
            update-initramfs -u

            printLog "okay" "RAID-Volume removed from config."
            printLog "text" "System restart pending."
            exit 0
        fi

        printLog "text" "No action selected, no changes have been made."
        exit 0
    else
        printLog "text" "No RAID-Volumes found."
    fi

    # UNconfigured
    printLog "info" "Looking for unconfigured RAID-Arrays ..."
    local unused_array=$(mdadm --examine --scan | grep 'ARRAY')
    if [[ "${unused_array}" ]]; then
        printLog "okay" "Unconfigured RAID-Array '${unused_array}' found."
        read -p "${script_name}: Would you like to add array to config? Usage: <YES|no> " add_array
        if [[ "${add_array}" == 'YES' ]]; then
            cat "${config_dir}/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf"
            mdadm --detail --scan >> "/etc/mdadm/mdadm.conf"

            update-initramfs -u

            printLog "okay" "RAID-Array added to config."
            printLog "text" "System restart pending."
            exit 0
        fi

        printLog "text" "No action selected, no changes have been made."
        exit 0
    else
        printLog "text" "No RAID-Arrays found."
    fi
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
    printf "Usage: ${script_name} [OPTIONS] Version\n"
    printf "Options:\n"
    printf "  -h, --help       Show this help message.\n"
    printf "\n"
}

main() {
    # pre-checks
    if [[ "${EUID}" -ne 0 ]]; then
        printLog "error" "Script has to be run with root user privileges."
        exit 1
    fi

    config_dir="${script_path}/config"
    if [[ ! -d "${config_dir}" ]]; then
        printLog "error" "Unable to find config folder in the specified directory."
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
    runConfig

    printLog "okay" "Script executed successfully."
}

main "$@"
