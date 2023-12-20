#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script must be run as root."
   exit 1
fi

os_release=$(cat "/etc/os-release" | grep "VERSION_CODENAME" | cut -d "=" -f2 )
if [[ $os_release -ne "bookworm" ]]; then
    echo "ERROR: The operating system $os_release is not supported."
    exit 1
fi

if ! [ -d $PWD/config ]; then
    echo "ERROR: The config-folder is missing in current work dir."
    exit 1
fi


# ========================= ========================= =========================
# UPDATE SYSTEM

# add repositories
cat "$PWD/config/apt/sources.list" > "/etc/apt/sources.list" || exit 1

# update repositories
apt update || exit 1

# update system
apt upgrade -y || exit 1


# ========================= ========================= =========================
# FIRMWARE

# update repositories
apt update || exit 1

# install requirements
apt install -y --no-install-recommends \
    curl \
    gnupg \
    wget \
    xz-utils \
    || exit 1

# install sys-tools
apt install -y --no-install-recommends \
    bash-completion \
    openssh-client \
    openssh-server \
    rsync \
    || exit 1


# ========================= ========================= =========================
# BASIC CONFIG

# bashrc
cp "$PWD/config/.bashrc" "$HOME/.bashrc" || exit 1

# scripts
cp "$PWD/scripts/notification-push.sh" "/usr/local/bin" || exit 1
chmod 755 /usr/local/bin/*.sh || exit 1


# ========================= ========================= =========================
# CRON

# config
cp "$PWD/config/crontab" "/etc/crontab" || exit 1

# restart
service cron restart || exit 1


# ========================= ========================= =========================
# DOCKER CE

# add repositories
cp "$PWD/config/apt/docker.list" "/etc/apt/sources.list.d" || exit 1

# add gpg-key
curl -fsSL "https://download.docker.com/linux/debian/gpg" | gpg --dearmor -o "/etc/apt/keyrings/docker.gpg" || exit 1

# install
apt update || exit 1
apt install -y \
    docker-ce \
    docker-ce-cli \
    || exit 1

# config
cp "$PWD/config/docker/daemon.json" "/etc/docker/daemon.json" || exit 1

# restart service
service docker restart || exit 1


# ========================= ========================= =========================
# NETWORK

# disable ipv6
cp "$PWD/config/rules/disable-all-ipv6.conf" "/etc/sysctl.d/disable-all-ipv6.conf" || exit 1
chmod 644 "/etc/sysctl.d/disable-all-ipv6.conf" || exit 1
sysctl -p "/etc/sysctl.d/disable-all-ipv6.conf" || exit 1


# ========================= ========================= =========================
# NTP

# install
apt update || exit 1
apt install -y --no-install-recommends \
    ntp \
    || exit 1

# config
cp "$PWD/config/ntp/ntp.conf" "/etc/ntp.conf" || exit 1

# restart service
service ntpsec restart || exit 1


# ========================= ========================= =========================
# OPEN-SSH

# config
cp "$PWD/config/ssh/sshd_config" "/etc/ssh/sshd_config" || exit 1
cp "$PWD/config/ssh/hetzner.conf" "/etc/ssh/sshd_config.d" || exit 1

# restart service
service sshd restart || exit 1


# ========================= ========================= =========================
# RESTIC

# install
apt update || exit 1
apt install -y --no-install-recommends \
    restic \
    || exit 1

# config
mkdir -p "~/.config/restic" || exit 1
cat "KJDPAmm3Xje6j2HRSNK4" > "~/.config/restic/password" || exit 1


# ========================= ========================= =========================
# UFW

# install
apt update || exit 1
apt install -y \
    ufw \
    || exit 1

# create rules
ufw limit ssh/tcp || exit 1
ufw default deny incoming || exit 1
ufw default allow outgoing || exit 1

# enable ufw
ufw enable || exit 1


# ========================= ========================= =========================
# CLEANUP

# remove message-of-the-day
rm -rf \
    /etc/motd \
    /etc/update-motd.d/* \
    || exit 1

# cleanup apt
apt autoremove -y || exit 1
apt clean || exit 1


# ========================= ========================= =========================
echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "INFO: System restart pending."
echo "--------------------------------------------------"
exit 0
