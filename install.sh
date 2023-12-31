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
apt upgrade || exit 1


# ========================= ========================= =========================
# FIRMWARE

# install requirements
apt update || exit 1
apt install -y --no-install-recommends \
    curl \
    gnupg \
    wget \
    xz-utils \
    || exit 1

# install firmware
apt update || exit 1
apt install -y --no-install-recommends \
    firmware-atheros \
    firmware-linux \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    firmware-realtek \
    || exit 1

# install sys-tools
apt update || exit 1
apt install -y --no-install-recommends \
    bash-completion \
    rsync \
    || exit 1


# ========================= ========================= =========================
# BASIC CONFIG

# bashrc
cat "$PWD/config/.bashrc" > "$HOME/.bashrc" || exit 1

# hostname
cat "$PWD/config/hosts" > "/etc/hosts" || exit 1

# scripts
cp $PWD/scripts/notification-*.sh "/usr/local/bin" && \
chmod 755 /usr/local/bin/notification-*.sh || exit 1

cp $PWD/scripts/system-*.sh "/usr/local/bin" && \
chmod 755 /usr/local/bin/system-*.sh || exit 1


# ========================= ========================= =========================
# CRON

# config
cat "$PWD/config/crontab" > "/etc/crontab" || exit 1

# cron.d
cp "$PWD/cron.d/poweroff" "/etc/cron.d" || exit 1

# restart
service cron restart || exit 1


# ========================= ========================= =========================
# DEVICE CONTROL

# onboard usb-stick
cp "$PWD/config/rules/disable-on-board-stick.rules" "/etc/udev/rules.d/" || exit 1
chmod 644 "/etc/udev/rules.d/disable-on-board-stick.rules" || exit 1
udevadm control --reload-rules || exit 1

# onboard soundcard
cp "$PWD/config/rules/blacklist-snd-hda-intel.conf" "/etc/modprobe.d/" || exit 1
chmod 644 "/etc/modprobe.d/blacklist-snd-hda-intel.conf" || exit 1
update-initramfs -u || exit 1



# ========================= ========================= =========================
# DOCKER CE

# add repositories
cp "$PWD/config/apt/docker.list" "/etc/apt/sources.list.d" || exit 1

# add gpg-key
curl -fsSL "https://download.docker.com/linux/debian/gpg" | gpg --dearmor -o "/etc/apt/keyrings/docker.gpg" || exit 1

# install
apt update || exit 1
apt install -y --no-install-recommends \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    || exit 1

# config
cat "$PWD/config/docker/daemon.json" > "/etc/docker/daemon.json" || exit 1

# syslink
ln -sf "/etc/docker" "/docker" || exit 1

# restart service
service docker restart || exit 1


# ========================= ========================= =========================
# ETHERWAKE

# install
apt update || exit 1
apt install -y --no-install-recommends \
    etherwake \
    || exit 1

# cron.d
cp "$PWD/cron.d/etherwake" "/etc/cron.d" || exit 1

# scripts
cp $PWD/scripts/etherwake-*.sh "/usr/local/bin" && \
chmod 755 /usr/local/bin/etherwake-*.sh || exit 1


# ========================= ========================= =========================
# FANCONTROL

# install
apt update || exit 1
apt install -y --no-install-recommends \
    build-essential \
    fancontrol \
    lm-sensors \
    || exit 1

# clone repository
git clone https://github.com/Stonyx/QNAP-EC || exit 1
cd QNAP-EC || exit 1
make install || exit 1

# config
cat "$PWD/config/fancontrol/$HOSTNAME" > "/etc/fancontrol" || exit 1
cat "$PWD/config/fancontrol/modules.conf" > "/etc/modules-load.d/modules.conf" || exit 1

# restart service
service fancontrol restart || exit 1


# ========================= ========================= =========================
# GRUB

# unzip
mkdir -p "/boot/grub/themes/debian" || exit 1
tar -xf "$PWD/config/grub/debian.tar" -C "/boot/grub/themes/debian" || exit 1

# config
cat "$PWD/config/grub/grub" > "/etc/default/grub" || exit 1

# update grub
update-grub || exit 1


# ========================= ========================= =========================
# MDADM

# install
apt update || exit 1
apt install -y --no-install-recommends \
    mdadm \
    || exit 1

# config
cat "$PWD/config/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf" || exit 1


# ========================= ========================= =========================
# NETWORK

# config
cat "$PWD/config/network/interfaces" > "/etc/network/interfaces" || exit 1
cp "$PWD/config/network/$HOSTNAME" "/etc/network/interfaces.d" || exit 1

# disable ipv6
cp "$PWD/config/rules/disable-all-ipv6.conf" "/etc/sysctl.d" && \
chmod 644 "/etc/sysctl.d/disable-all-ipv6.conf" || exit 1
sysctl -p "/etc/sysctl.d/disable-all-ipv6.conf" || exit 1

# resolv.conf
cat "$PWD/config/network/resolv.conf" > "/etc/resolv.conf" || exit 1


# ========================= ========================= =========================
# NTP

# install
apt update || exit 1
apt install -y --no-install-recommends \
    ntp \
    || exit 1

# config
cat "$PWD/config/ntp/ntp.conf" > "/etc/ntp.conf" || exit 1

# restart service
service ntpsec restart || exit 1


# ========================= ========================= =========================
# OPEN-SSH

# install
apt update || exit 1
apt install -y --no-install-recommends \
    openssh-client \
    openssh-server \
    || exit 1

# config
cat "$PWD/config/ssh/sshd_config" > "/etc/ssh/sshd_config" || exit 1
cp "$PWD/config/ssh/qnap.conf" "/etc/ssh/sshd_config.d" || exit 1

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
mkdir -p "$HOME/.config/restic" || exit 1
cp "$PWD/config/restic/password" "$HOME/.config/restic" || exit 1

# cron.d
cp "$PWD/cron.d/restic" "/etc/cron.d" || exit 1

# scripts
cp $PWD/scripts/restic-*.sh "/usr/local/bin" && \
chmod 755 /usr/local/bin/restic-*.sh || exit 1


# ========================= ========================= =========================
# SAMBA

# install
apt update || exit 1
apt install -y --no-install-recommends \
    samba \
    || exit 1

# config
# cat "$PWD/config/samba/$HOSTNAME.conf" > "/etc/samba/smb.conf" || exit 1

# create samba user
# smbpasswd -a debian || exit 1

# restart service
service samba restart || exit 1


# ========================= ========================= =========================
# SYSTEM SERVICES

# config
cp "$PWD/config/systemd/system-poweron.service" "/etc/systemd/system" || exit 1

# reload daemon
systemctl daemon-reload || exit 1

# enable service
systemctl enable system-poweron.service || exit 1


# ========================= ========================= =========================
# SMARTMON

# install
apt update || exit 1
apt install -y --no-install-recommends \
    smartmontools \
    || exit 1

# config
cat "$PWD/config/smart/smartd.conf" > "/etc/smartd.conf" || exit 1

# create log
mkdir -p "/var/log/smartmon/" && \
touch "/var/log/smartmon/smartmon.prom" || exit 1

# cron.d
cp "$PWD/cron.d/smartmon" "/etc/cron.d" || exit 1

# scripts
cp $PWD/scripts/smartmon-*.sh "/usr/local/bin" && \
chmod 755 /usr/local/bin/smartmon-*.sh || exit 1


# ========================= ========================= =========================
# UFW

# install
apt update || exit 1
apt install -y --no-install-recommends \
    ufw \
    || exit 1

# create rules
ufw allow samba || exit 1
ufw allow ssh || exit 1
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
