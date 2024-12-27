#!/bin/bash

set -o errexit  # Exit when a command fails
set -o pipefail # Exit when a command in a pipeline fails
set -o nounset  # Exit when using undeclared variables

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

runInstall() {
    local default_user=$(getent passwd 1000 | cut --delimiter ":" --fields 1)

    # --------------------------------------------------
    # Update package list
    cat "$config_dir/apt/sources.list" | tee /etc/apt/sources.list > /dev/null
    # cat "$config_dir/apt/testing.list" | tee /etc/apt/sources.list.d/testing.list > /dev/null

    apt update
    apt upgrade --yes
    apt full-upgrade --yes

    # --------------------------------------------------
    # Install required packages
    apt install --yes \
        bash-completion \
        curl \
        git \
        gpg \
        htop \
        nvme-cli \
        rsync \
        xz-utils

    # --------------------------------------------------
    # Install firmware packages
    apt install --yes \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-realtek \
        linux-headers-amd64
    
    # --------------------------------------------------
    # Install docker
    curl --silent --show-error "https://download.docker.com/linux/debian/gpg" \
        | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/docker.gpg" > /dev/null
    printf "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
        | tee "/etc/apt/sources.list.d/docker.list" > /dev/null

    apt update
    apt install --yes \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    cat "$config_dir/docker/daemon.json" | tee "/etc/docker/daemon.json" > /dev/null
    systemctl restart docker > /dev/null

    # # --------------------------------------------------
    # # install fancontroll
    apt install --yes \
        build-essential \
        fancontrol \
        lm-sensors \
        make
    
    git clone --quiet "https://github.com/Stonyx/QNAP-EC" "/tmp/QNAP-EC"
    (
        cd "/tmp/QNAP-EC"
        make install > /dev/null
    )
    rm --recursive --force "/tmp/QNAP-EC"

    cat "$config_dir/fancontrol/fancontrol" | tee "/etc/fancontrol" > /dev/null
    systemctl restart fancontrol > /dev/null

    cat "$config_dir/fancontrol/modul.conf" | tee "/etc/modules-load.d/fancontrol.conf" > /dev/null
    systemctl restart systemd-modules-load > /dev/null

    # --------------------------------------------------
    # Install imagemagick
    apt install --yes \
        bc \
        imagemagick
    
    # --------------------------------------------------
    # Install mdadm
    apt install --yes \
        mdadm
    
    # --------------------------------------------------
    # Install ntp
    apt install --yes \
        ntp
    
    cat "$config_dir/ntp/ntp.conf" | tee "/etc/ntp.conf" > /dev/null
    systemctl restart ntp > /dev/null

    # --------------------------------------------------
    # Install nvidia drivers
    curl --silent --show-error "https://nvidia.github.io/libnvidia-container/gpgkey" \
        | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/nvidia-container-toolkit.gpg" > /dev/null
    printf 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/nvidia-container-toolkit.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH) /' \
        | tee "/etc/apt/sources.list.d/nvidia-container-toolkit.list" > /dev/null

    apt update
    apt install --yes \
        nvidia-driver \
        nvidia-container-toolkit
    
    cat "$config_dir/docker/daemon-nvidia.json" | tee "/etc/docker/daemon.json" > /dev/null
    systemctl restart docker > /dev/null

    # --------------------------------------------------
    # Install restic
    apt install --yes \
        restic

    # --------------------------------------------------
    # Install samba
    apt install --yes \
        samba \
        smbclient

    cat "$config_dir/samba/smb.conf" | tee "/etc/samba/smb.conf" > /dev/null
    systemctl restart smbd > /dev/null

    # --------------------------------------------------
    # Install ssh
    apt install --yes \
        openssh-client \
        openssh-server
    
    cat "$config_dir/ssh/sshd_config" | tee "/etc/ssh/sshd_config"              > /dev/null
    cat "$config_dir/ssh/banner.txt"  | tee "/etc/ssh/banner.txt"               > /dev/null
    cat "$config_dir/ssh/qnap.conf"   | tee "/etc/ssh/sshd_config.d/qnap.conf"  > /dev/null
    systemctl restart ssh > /dev/null

    local ssh_dir="/home/$default_user/.ssh"
    mkdir --parents "$ssh_dir"
    cat "$config_dir/ssh/authorized_keys" | tee "$ssh_dir/authorized_keys" > /dev/null
    chown --recursive "$default_user:$default_user" "$ssh_dir"
    chmod 700 "$ssh_dir"
    chmod 600 "$ssh_dir/authorized_keys"

    # --------------------------------------------------
    # Install telegraf
    curl --silent --show-error "https://repos.influxdata.com/influxdata-archive.key" \
        | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/influxdata.gpg" > /dev/null
    echo 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/influxdata.gpg] https://repos.influxdata.com/debian stable main' \
        | tee "/etc/apt/sources.list.d/influxdata.list" > /dev/null

    apt update
    apt install --yes \
        telegraf
    
    usermod --append --groups docker telegraf

    cat "$config_dir/telegraf/telegraf-nvmecli"  | tee "/etc/sudoers.d/telegraf-nvmecli"  > /dev/null
    cat "$config_dir/telegraf/telegraf-smartctl" | tee "/etc/sudoers.d/telegraf-smartctl" > /dev/null

    cat "$config_dir/telegraf/telegraf.conf" | tee "/etc/telegraf/telegraf.conf" > /dev/null
    systemctl restart telegraf > /dev/null
    return 0
}

runConfig() {
    local default_user=$(getent passwd 1000 | cut --delimiter ":" --fields 1)

    # --------------------------------------------------
    # Configure cron
    cat "$config_dir/cron/crontab" | tee "/etc/crontab" > /dev/null
    systemctl restart cron > /dev/null

    # --------------------------------------------------
    # Copy dotfiles
    cat "$config_dir/.bash_aliases" \
        | tee "/home/$default_user/.bash_aliases" \
        | tee "/root/.bash_aliases" > /dev/null
    cat "$config_dir/.bashrc" \
        | tee "/home/$default_user/.bashrc" \
        | tee "/root/.bashrc" > /dev/null
    cat "$config_dir/.profile" \
        | tee "/home/$default_user/.profile" \
        | tee "/root/.profile" > /dev/null
    
    # --------------------------------------------------
    # Configure environment
    cat "$config_dir/environment" | tee "/etc/environment" > /dev/null

    # --------------------------------------------------
    # Add grub theme
    if [[ -n "$optional_grub_theme" ]]; then
        local grub_dir="/boot/grub/themes/$optional_grub_theme"
        mkdir --parents "$grub_dir"

        local download_url="https://github.com/AdisonCavani/distro-grub-themes/releases/download/v3.2/$optional_grub_theme.tar"
        curl --location --output "/tmp/$optional_grub_theme.tar" "$download_url"
        tar --extract --file "/tmp/$optional_grub_theme.tar" --directory "$grub_dir"
        rm --force "/tmp/$optional_grub_theme.tar"

        cat "$config_dir/grub" | tee "/etc/default/grub" > /dev/null
        echo "GRUB_THEME=\"$grub_dir/theme.txt\"" | tee --append "/etc/default/grub" > /dev/null
        update-grub > /dev/null
    fi

    # --------------------------------------------------
    # Configure network
    cat "$config_dir/network/hosts" | tee "/etc/hosts" > /dev/null
    sed --in-place "s/changeme/$HOSTNAME/g" "/etc/hosts"

    cat "$config_dir/network/resolv.conf" | tee "/etc/resolv.conf" > /dev/null
    
    cat "$config_dir/network/interfaces" | tee "/etc/network/interfaces"        > /dev/null
    cat "$config_dir/network/qnap"       | tee "/etc/network/interfaces.d/qnap" > /dev/null
    systemctl enable networking > /dev/null

    # --------------------------------------------------
    # Add scripts
    cp "$config_dir/../scripts/bin/"*.sh "/usr/local/bin/"
    chown root:root "/usr/local/bin/"*.sh
    chmod 755 "/usr/local/bin/"*.sh

    cp "$config_dir/../scripts/sbin/"*.sh "/usr/local/sbin/"
    chown root:root "/usr/local/sbin/"*.sh
    chmod 755 "/usr/local/sbin/"*.sh

    # --------------------------------------------------
    # Configure sudo
    echo "$default_user ALL=(ALL) NOPASSWD: ALL" | tee "/etc/sudoers.d/default-user-no-password" > /dev/null

    # --------------------------------------------------
    # Configure systemd
    cp "$config_dir/systemd/"*.service "/etc/systemd/system/"
    cp "$config_dir/systemd/"*.timer   "/etc/systemd/system/"
    systemctl daemon-reload > /dev/null

    systemctl enable debian-powerstate.service > /dev/null
    systemctl restart debian-selftest.service > /dev/null

    systemctl enable debian-selftest.timer > /dev/null
    systemctl restart debian-selftest.timer > /dev/null
    return 0
}

runCleanup() {
    apt purge --yes \
        exim4*

    apt autoremove --yes
    apt clean
    return 0
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo "Options:"
    echo "  -h, --help          Show this help message."
}
printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            ;;
        info)
            echo -e "\e[96m[INFO]\e[39m $log_message"
            ;;
        success)
            echo -e "\e[92m[SUCCESS]\e[39m $log_message"
            ;;
        *)
            echo "$log_message"
            ;;
    esac
}

main() {
    # --------------------------------------------------
    # Prechecks
    if [[ "$EUID" -ne 0 ]]; then
        printLog "error" "Script must be run with root privileges!"
        exit 1
    fi

    # --------------------------------------------------
    # Variables
    readonly config_dir="./config"
    readonly optional_grub_theme='debian'

    # --------------------------------------------------
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local parameter="$1"
        case "$parameter" in
            -h|--help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown parameter '$parameter'; use --help for further information!"
                exit 1
                ;;
        esac
        shift
    done

    if ! [[ -d "$config_dir" ]]; then
        printLog "error" "Configuration directory '$config_dir' not found!"
        exit 1
    fi

    # --------------------------------------------------
    printLog "info" "Current task: Installing packages..."
    runInstall

    printLog "info" "Current task: Configuring packages..."
    runConfig

    printLog "info" "Current task: Cleaning up..."
    runCleanup

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Script executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
