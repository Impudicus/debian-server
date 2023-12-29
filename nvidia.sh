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
# DISABLE DEFAULT DRIVERS

if ! [ -f "/etc/modprobe.d/nouveau-blacklist.conf" ]; then

    # create blacklist
    cp "$PWD/config/nvidia/nouveau-blacklist.conf" "/etc/modprobe.d" || exit 1

    # update initramfs
    update-initramfs -u || exit 1

    echo "--------------------------------------------------"
    echo "INFO: Nouveau drivers disabled."
    echo "INFO: System restart pending."
    echo "--------------------------------------------------"
    exit 0
fi


# ========================= ========================= =========================
# UPDATE SYSTEM

# update repositories
apt update || exit 1

# update system
apt upgrade -y || exit 1


# ========================= ========================= =========================
# INSTALL FIRMWARE

# update repositories
apt update || exit 1

# install requirements
apt update || exit 1
apt install -y --no-install-recommends \
    libc-dev \
    libc6-dev \
    gcc \
    make \
    linux-headers-amd64 \
    || exit 1


# ========================= ========================= =========================
# INSTALL CUSTOM DRIVERS

latest_driver_version="535.146.02"
latest_driver_url="https://de.download.nvidia.com/XFree86/Linux-x86_64/${latest_driver_version}/NVIDIA-Linux-x86_64-${latest_driver_version}.run"

if ! [ -d "/usr/lib/firmware/nvidia/${latest_driver_version}" ]; then

    # download driver
    wget "${latest_driver_url}" || exit 1
    chmod 755 "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}.run" || exit 1

    # install driver
    bash "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}.run" --target "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}" || exit 1

    # remove driver & temp-folder
    rm -rf \
        "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}.run" \
        "$PWD/NVIDIA-Linux-x86_64-${latest_driver_version}" \
        || exit 1

fi


# ========================= ========================= =========================
echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "INFO: System restart pending."
echo "--------------------------------------------------"
exit 0
