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

# update repositories
apt update || exit 1

# update system
apt upgrade -y || exit 1


# ========================= ========================= =========================
# INSTALL FIRMWARE

# install requirements
apt update || exit 1
apt install -y --no-install-recommends \
    linux-headers-$(uname -r) \
    build-essential \
    libglvnd-dev \
    pkg-config \
    || exit 1


# ========================= ========================= =========================
# DISABLE DEFAULT DRIVERS

if ! [ -f "/etc/modprobe.d/blacklist-nouveau.conf" ]; then

    # create blacklist
    cp "$PWD/config/nvidia/blacklist-nouveau.conf" "/etc/modprobe.d" || exit 1
    chmod 644 "/etc/modprobe.d/blacklist-nouveau.conf" || exit 1

    # update initramfs
    update-initramfs -u || exit 1

    echo "--------------------------------------------------"
    echo "INFO: Nouveau drivers disabled."
    echo "INFO: System restart pending."
    echo "--------------------------------------------------"
    exit 0
fi


# ========================= ========================= =========================
# INSTALL CUSTOM DRIVERS

latest_driver_version="470.199.02"
latest_driver_url="https://de.download.nvidia.com/XFree86/Linux-x86_64/${latest_driver_version}/NVIDIA-Linux-x86_64-${latest_driver_version}.run"

if ! [ -d "/usr/lib/firmware/nvidia/${latest_driver_version}" ]; then

    # download driver
    wget "${latest_driver_url}" || exit 1
    chmod 755 "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}.run" || exit 1

    # install driver
    bash "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}.run" --target "/tmp/NVIDIA-Linux-x86_64-${latest_driver_version}" || exit 1

    # remove driver & temp-folder
    rm -rf \
        "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}.run" \
        "/tmp/NVIDIA-Linux-x86_64-${latest_driver_version}" \
        || exit 1

    echo "--------------------------------------------------"
    echo "INFO: Custom drivers installed."
    echo "INFO: System restart pending."
    echo "--------------------------------------------------"
    exit 0
fi


# ========================= ========================= =========================
# DOCKER CE RUNTIME

# add repositories
cp "$PWD/config/apt/nvidia.list" "/etc/apt/sources.list.d" || exit 1

# add gpg-key
curl -fsSL "https://nvidia.github.io/nvidia-docker/gpgkey" | gpg --dearmor -o "/etc/apt/keyrings/nvidia-docker.gpg" || exit 1

# install
apt update || exit 1
apt install -y --no-install-recommends \
    nvidia-container-toolkit \
    || exit 1

# config
cat "$PWD/config/nvidia/daemon.json" > "/etc/docker/daemon.json" || exit 1

# restart service
service docker restart || exit 1


# ========================= ========================= =========================
# CLEANUP

# cleanup apt
apt autoremove -y || exit 1
apt clean || exit 1


# ========================= ========================= =========================
echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "INFO: System restart pending."
echo "--------------------------------------------------"
exit 0
