#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

# configurations
set -o errexit  # exit on error
set -o pipefail # return exit status on pipefail

runInstall() {
    # apt config
    cat "${config_dir}/apt/bookworm.list" > "/etc/apt/sources.list"

    # apt update
    apt update
    apt upgrade --yes
    apt full-upgrade --yes

    # install requirements
    apt install --yes \
        bash-completion \
        curl \
        git \
        gpg \
        rsync \
        wget \
        xz-utils

    # install firmware
    apt install --yes \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-realtek \
        linux-headers-amd64

    # install docker
    curl --silent --show-error "https://download.docker.com/linux/debian/gpg" | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/docker.gpg"
    cat "${config_dir}/apt/docker.list" > "/etc/apt/sources.list.d/docker.list"
    apt update
    apt install --yes \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    
    cat "${config_dir}/docker/daemon.json" > "/etc/docker/daemon.json"
    systemctl restart docker

    # install fancontrol
    apt install --yes \
        build-essential \
        fancontrol \
        lm-sensors \
        make

    git clone "https://github.com/Stonyx/QNAP-EC" "/tmp/QNAP-EC"
    (
        cd "/tmp/QNAP-EC"
        make install > /dev/null 2> /dev/null
    )
    rm --recursive --force "/tmp/QNAP-EC"

    cat "${config_dir}/fancontrol/fancontrol.conf" > "/etc/fancontrol.conf"
    cat "${config_dir}/fancontrol/modules.conf" > "/etc/modules-load.d/fancontrol.conf"
    systemctl restart fancontrol

    # install mdadm
    apt install --yes \
        mdadm

    cat "${config_dir}/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf"

    # install nfs
    apt install --yes \
        nfs-kernel-server \
        nfs-common

    cat "${config_dir}/nfs/exports" > "/etc/exports"
    systemctl restart nfs-server

    # install ntp
    apt install --yes \
        ntp

    cat "${config_dir}/ntp/ntp.conf" > "/etc/ntp.conf"
    systemctl restart ntp

    # install openssh
    apt install --yes \
        openssh-client \
        openssh-server

    cat "${config_dir}/openssh/banner.txt" > "/etc/ssh/banner.txt"

    cat "${config_dir}/openssh/sshd.config" > "/etc/ssh/sshd_config"
    cat "${config_dir}/openssh/qnap.conf" > "/etc/ssh/sshd_config.d/qnap.conf"
    systemctl restart ssh

    # install restic
    apt install --yes \
        restic

    mkdir --parents "/root/.config/restic"
    cat "${config_dir}/restic/password" > "/root/.config/restic/password"
    cat "${config_dir}/restic/repository-${HOSTNAME}" > "/root/.config/restic/repository"

    # install samba
    apt install --yes \
        samba \
        smbclient

    cat "${config_dir}/samba/smb.conf" > "/etc/samba/smb.conf"
    sed -i "s/workgroup = WORKGROUP/workgroup = ${HOSTNAME}/" "/etc/samba/smb.conf"

    systemctl restart smbd

    # install wakeonlan
    apt install --yes \
        wakeonlan
}

runConfig() {
    local default_user=$(cat "/etc/passwd" | grep "1000" | cut --delimiter ':' --fields 1)

    # blacklist onboard-qnap-hdd
    cat "${config_dir}/rules/bluetooth-hci.rules" > "/etc/udev/rules.d/bluetooth-hci.rules"
    chmod 644 "/etc/udev/rules.d/bluetooth-hci.rules"

    update-initramfs -u > /dev/null

    # config cron
    cat "${config_dir}/cron/crontab" > "/etc/crontab"

    systemctl restart cron

    # config network
    cat "${config_dir}/network/interfaces" > "/etc/network/interfaces"
    cat "${config_dir}/network/${HOSTNAME}" > "/etc/network/interfaces.d/${HOSTNAME}"

    cat "${config_dir}/network/hosts" > "/etc/hosts"
    cat "${config_dir}/network/resolv.conf" > "/etc/resolv.conf"

    systemctl restart networking

    # config network - disable ipv6
    cat "${config_dir}/rules/disable-ipv6.conf" > "/etc/sysctl.d/disable-ipv6.conf"
    chmod 644 "/etc/sysctl.d/disable-ipv6.conf"
    
    sysctl --system

    # config sudo
    echo "${default_user} ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/default-user-no-password"

    # config user   
    cat "${config_dir}/.bash_aliases" > "/home/${default_user}/.bash_aliases"
    cat "${config_dir}/.bashrc" > "/home/${default_user}/.bashrc"

    # config user - root
    cat "${config_dir}/.bash_aliases" > "/root/.bash_aliases"
    cat "${config_dir}/.bashrc" > "/root/.bashrc"
}

runCleanup() {
    apt remove --purge --yes \
        exim4 \
        exim4-base \
        exim4-config \
        exim4-daemon-light

    apt autoremove --yes > /dev/null
    apt clean > /dev/null
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
    runInstall
    runConfig
    runCleanup

    printLog "okay" "Script executed successfully."
}

main "$@"
