#!/bin/bash

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
    cat "$CONFIG_DIR/apt/sources.list" | tee /etc/apt/sources.list > /dev/null
    # cat "$CONFIG_DIR/apt/testing.list" | tee /etc/apt/sources.list.d/testing.list > /dev/null

    apt update || exit 1
    apt upgrade --yes || exit 1
    apt full-upgrade --yes || exit 1

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
        xz-utils \
        || exit 1

    # --------------------------------------------------
    # Install firmware packages
    apt install --yes \
        firmware-linux \
        firmware-linux-nonfree \
        firmware-misc-nonfree \
        firmware-realtek \
        linux-headers-amd64 \
        || exit 1
    
    # --------------------------------------------------
    # Install docker
    curl --silent --show-error "https://download.docker.com/linux/debian/gpg" \
        | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/docker.gpg" > /dev/null || exit 1
    printf "deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
        | tee "/etc/apt/sources.list.d/docker.list" > /dev/null || exit 1

    apt update || exit 1
    apt install --yes \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin \
        || exit 1

    cat "$CONFIG_DIR/docker/daemon.json" | tee "/etc/docker/daemon.json" > /dev/null || exit 1
    systemctl restart docker > /dev/null || exit 1

    # # --------------------------------------------------
    # # install fancontroll
    # apt install --yes \
    #     build-essential \
    #     fancontrol \
    #     lm-sensors \
    #     make \
    #     || exit 1
    
    # git clone --quiet "https://github.com/Stonyx/QNAP-EC" "/tmp/QNAP-EC" || exit 1
    # (
    #     cd "/tmp/QNAP-EC" || exit 1
    #     make install > /dev/null || exit 1
    # )
    # rm --recursive --force "/tmp/QNAP-EC" || exit 1

    # cat "$CONFIG_DIR/fancontrol/fancontrol" | tee "/etc/fancontrol" > /dev/null || exit 1
    # systemctl restart fancontrol > /dev/null || exit 1

    # cat "$CONFIG_DIR/fancontrol/modul.conf" | tee "/etc/modules-load.d/fancontrol.conf" > /dev/null || exit 1
    # systemctl restart systemd-modules-load > /dev/null || exit 1

    # --------------------------------------------------
    # Install imagemagick
    apt install --yes \
        imagemagick \
        || exit 1
    
    # --------------------------------------------------
    # Install mdadm
    apt install --yes \
        mdadm \
        || exit 1
    
    # --------------------------------------------------
    # Install ntp
    apt install --yes \
        ntp \
        || exit 1
    
    cat "$CONFIG_DIR/ntp/ntp.conf" | tee "/etc/ntp.conf" > /dev/null || exit 1
    systemctl restart ntp > /dev/null || exit 1

    # --------------------------------------------------
    # Install nvidia drivers
    curl --silent --show-error "https://nvidia.github.io/libnvidia-container/gpgkey" \
        | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/nvidia-container-toolkit.gpg" > /dev/null || exit 1
    printf 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/nvidia-container-toolkit.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/$(ARCH) /' \
        | tee "/etc/apt/sources.list.d/nvidia-container-toolkit.list" > /dev/null || exit 1

    apt update || exit 1
    apt install --yes \
        nvidia-driver \
        nvidia-container-toolkit \
        || exit 1
    
    cat "$CONFIG_DIR/docker/daemon-nvidia.json" | tee "/etc/docker/daemon.json" > /dev/null || exit 1
    systemctl restart docker > /dev/null || exit 1

    # --------------------------------------------------
    # Install restic
    apt install --yes \
        restic \
        || exit 1

    # --------------------------------------------------
    # Install samba
    apt install --yes \
        samba \
        smbclient \
        || exit 1

    cat "$CONFIG_DIR/samba/smb.conf" | tee "/etc/samba/smb.conf" > /dev/null || exit 1
    systemctl restart smbd > /dev/null || exit 1

    # --------------------------------------------------
    # Install ssh
    apt install --yes \
        openssh-client \
        openssh-server \
        || exit 1
    
    cat "$CONFIG_DIR/ssh/sshd_config" | tee "/etc/ssh/sshd_config"              > /dev/null || exit 1
    cat "$CONFIG_DIR/ssh/banner.txt"  | tee "/etc/ssh/banner.txt"               > /dev/null || exit 1
    cat "$CONFIG_DIR/ssh/qnap.conf"   | tee "/etc/ssh/sshd_config.d/qnap.conf"  > /dev/null || exit 1
    systemctl restart ssh > /dev/null || exit 1

    local ssh_dir="/home/$default_user/.ssh"
    mkdir --parents "$ssh_dir" || exit 1
    cat "$CONFIG_DIR/ssh/authorized_keys" | tee "$ssh_dir/authorized_keys" > /dev/null || exit 1
    chown --recursive "$default_user:$default_user" "$ssh_dir" || exit 1
    chmod 700 "$ssh_dir" || exit 1
    chmod 600 "$ssh_dir/authorized_keys" || exit 1

    # --------------------------------------------------
    # Install telegraf
    curl --silent --show-error "https://repos.influxdata.com/influxdata-archive.key" \
        | gpg --dearmor --yes --output "/etc/apt/trusted.gpg.d/influxdata.gpg" > /dev/null || exit 1
    echo 'deb [arch=amd64 signed-by=/etc/apt/trusted.gpg.d/influxdata.gpg] https://repos.influxdata.com/debian stable main' \
        | tee "/etc/apt/sources.list.d/influxdata.list" > /dev/null || exit 1

    apt update || exit 1
    apt install --yes \
        telegraf \
        || exit 1
    
    usermod --append --groups docker telegraf || exit 1

    cat "$CONFIG_DIR/telegraf/telegraf-nvmecli"  | tee "/etc/sudoers.d/telegraf-nvmecli"  > /dev/null || exit 1
    cat "$CONFIG_DIR/telegraf/telegraf-smartctl" | tee "/etc/sudoers.d/telegraf-smartctl" > /dev/null || exit 1

    cat "$CONFIG_DIR/telegraf/telegraf.conf" | tee "/etc/telegraf/telegraf.conf" > /dev/null || exit 1
    systemctl restart telegraf > /dev/null || exit 1
    return 0
}

runConfig() {
    local default_user=$(getent passwd 1000 | cut --delimiter ":" --fields 1)

    # --------------------------------------------------
    # Configure cron
    cat "$CONFIG_DIR/cron/crontab" | tee "/etc/crontab" > /dev/null || exit 1
    systemctl restart cron > /dev/null || exit 1

    # --------------------------------------------------
    # Copy dotfiles
    cat "$CONFIG_DIR/.bash_aliases" \
        | tee "/home/$default_user/.bash_aliases" \
        | tee "/root/.bash_aliases" > /dev/null || exit 1
    cat "$CONFIG_DIR/.bashrc" \
        | tee "/home/$default_user/.bashrc" \
        | tee "/root/.bashrc" > /dev/null || exit 1
    cat "$CONFIG_DIR/.profile" \
        | tee "/home/$default_user/.profile" \
        | tee "/root/.profile" > /dev/null || exit 1
    
    # --------------------------------------------------
    # Configure environment
    cat "$CONFIG_DIR/environment" | tee "/etc/environment" > /dev/null || exit 1

    # --------------------------------------------------
    # Add grub theme
    if [[ -n "$optional_grub_theme" ]]; then
        local grub_dir="/boot/grub/themes/$optional_grub_theme"
        mkdir --parents "$grub_dir" || exit 1

        local download_url="https://github.com/AdisonCavani/distro-grub-themes/releases/download/v3.2/$optional_grub_theme.tar"
        curl --location --output "/tmp/$optional_grub_theme.tar" "$download_url" || exit 1
        tar --extract --file "/tmp/$optional_grub_theme.tar" --directory "$grub_dir" || exit 1
        rm --force "/tmp/$optional_grub_theme.tar" || exit 1

        cat "$CONFIG_DIR/grub" | tee "/etc/default/grub" > /dev/null || exit 1
        echo "GRUB_THEME=\"$grub_dir/theme.txt\"" | tee --append "/etc/default/grub" > /dev/null || exit 1
        update-grub || exit 1
    fi

    # --------------------------------------------------
    # Configure network
    cat "$CONFIG_DIR/network/hosts" | tee "/etc/hosts" > /dev/null || exit 1
    sed --in-place "s/changeme/$HOSTNAME/g" "/etc/hosts" || exit 1

    cat "$CONFIG_DIR/network/resolv.conf" | tee "/etc/resolv.conf" > /dev/null || exit 1
    
    cat "$CONFIG_DIR/network/interfaces" | tee "/etc/network/interfaces"        > /dev/null || exit 1
    cat "$CONFIG_DIR/network/qnap"       | tee "/etc/network/interfaces.d/qnap" > /dev/null || exit 1
    systemctl enable networking > /dev/null || exit 1

    # --------------------------------------------------
    # Add scripts
    cp "$CONFIG_DIR/../scripts/bin/"*.sh "/usr/local/bin/" 
    chown root:root "/usr/local/bin/"*.sh
    chmod 755 "/usr/local/bin/"*.sh

    cp "$CONFIG_DIR/../scripts/sbin/"*.sh "/usr/local/sbin/"
    chown root:root "/usr/local/sbin/"*.sh
    chmod 755 "/usr/local/sbin/"*.sh
    
    # --------------------------------------------------
    # Configure sudo
    echo "$default_user ALL=(ALL) NOPASSWD: ALL" | tee "/etc/sudoers.d/default-user-no-password" > /dev/null || exit 1

    # --------------------------------------------------
    # Configure systemd
    cp "$CONFIG_DIR/systemd/"*.service "/etc/systemd/system/"
    cp "$CONFIG_DIR/systemd/"*.timer   "/etc/systemd/system/"
    systemctl daemon-reload > /dev/null || exit 1

    systemctl enable debian-powerstate.service > /dev/null || exit 1
    systemctl restart debian-selftest.service > /dev/null || exit 1

    systemctl enable debian-selftest.timer > /dev/null || exit 1
    systemctl restart debian-selftest.timer > /dev/null || exit 1
    return 0
}

runCleanup() {
    # Remove unnecessary packages
    apt purge --yes \
        exim4* \
        || exit 1

    # Remove orphaned packages and clean up package cache
    apt autoremove --yes || exit 1
    apt clean || exit 1
    return 0
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo "Options:"
    echo "  -h, --help                          Show this help message."
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
    readonly CONFIG_DIR="./config"
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

    if ! [[ -d "$CONFIG_DIR" ]]; then
        printLog "error" "Configuration directory '$CONFIG_DIR' not found!"
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
