#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

runInstall() {
    # apt update
    apt update
    apt upgrade --yes
    apt full-upgrade --yes

    # install requirements
    apt install --yes \
        build-essential \
        libglvnd-dev \
        pkg-config \
        make
    
    # blacklist-nouveau
    local blacklist_file="/etc/modprobe.d/blacklist-nouveau.conf"
    if [[ ! -f "${blacklist_file}" ]]; then
        cat "${config_dir}/nvidia/blacklist-nouveau.conf" > "${blacklist_file}"
        chmod 644 "${blacklist_file}"

        update-initramfs -u > /dev/null

        printLog "okay" "Nouveau drivers disabled."
        printLog "text" "System restart pending."
        printLog "text" "Rerun script after reboot."
        exit 0
    else
        printLog "info" "Nouveau drivers disabled."
        sleep 1
    fi

    # install custom driver
    if [[ ! -d "/usr/lib/firmware/nvidia/${install_version}" ]]; then
        local driver_name="NVIDIA-Linux-x86_64-${install_version}"
        local driver_url="https://de.download.nvidia.com/XFree86/Linux-x86_64/${install_version}/${driver_name}.run"
        
        wget "${driver_url}" --output-document "/tmp/${driver_name}.run"
        chmod 755 "/tmp/${driver_name}.run"

        bash "/tmp/${driver_name}.run" --target "/tmp/${driver_name}"
        rm --recusive --force "/tmp/${driver_name}.run" "/tmp/${driver_name}"

        printLog "okay" "Custom drivers installed."
        printLog "text" "System restart pending."
        printLog "text" "Rerun script after reboot."
        exit 0
    else
        printLog "info" "Custom drivers installed."
        sleep 1
    fi

    # install docker toolkit
    local package_name="docker-ce"
    local package_installed=$(dpkg --list | grep --quiet --word-regexp "${package_name}" && echo "installed")
    if [[ ! "${package_installed}" ]]; then
        printLog "error" "Unable to find dpkg-package '${package_name}'."
        printLog "text" "Check apt for missing packages and rerun the script."
        exit 1
    fi
    local package_name="nvidia-container-toolkit"
    local package_installed=$(dpkg --list | grep --quiet --word-regexp "${package_name}" && echo "installed")
    if [[ ! "${package_installed}" ]]; then
        curl --silent --show-error "https://nvidia.github.io/libnvidia-container/gpgkey" | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/nvidia-container-toolkit.gpg"
        cat "${config_dir}/apt/nvidia-container-toolkit.list" > "/etc/apt/sources.list.d/nvidia-container-toolkit.list"
        apt update
        apt install --yes \
            nvidia-container-toolkit

        cat "${config_dir}/nvidia/daemon.json" > "/etc/docker/daemon.json"
        systemctl restart docker

        printLog "okay" "Nvidia-container-toolkit installed."
        printLog "text" "System restart pending."
        printLog "text" "Rerun script after reboot."
        exit 0
    else
        printLog "info" "Nvidia-container-toolkit installed."
        sleep 1
    fi
}

runCleanup() {
    apt autoremove --yes
    apt clean
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
    printf "Versions:\n"
    printf " beta               Install latest beta release.\n"
    printf " latest             Install latest production branch.\n"
    printf " 470                Install legacy 470.xx series.\n"
    printf " 390                Install legacy 390.xx series.\n"
    printf " 340                Install legacy 340.xx series.\n"
    printf " 304                Install legacy 304.xx series.\n"
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
    install_version=''

    # parameters
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            beta)
                install_version='550.40.07'
                break
                ;;
            latest)
                install_version='550.54.14'
                break
                ;;
            470)
                install_version='470.239.06'
                break
                ;;
            390)
                install_version='390.157'
                break
                ;;
            340)
                install_version='340.108'
                break
                ;;
            304)
                install_version='304.137'
                break
                ;;
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

    if [[ ! "${install_version}" ]]; then
        printLog "error" "Missing version, use --help for further information."
        exit 1
    fi

    # run
    runInstall
    runCleanup

    printLog "okay" "Script executed successfully."
}

main "$@"
