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

install_state=$(dpkg -s "mdadm" | grep "Status" | cut -d " " -f4)
if [[ $install_state -ne "installed" ]]; then
    echo "ERROR: The package mdadm could not be found."
    echo "ERROR: Check the status of the system configuration."
    exit 1
fi


# ========================= ========================= =========================
# HANDLE USED ARRAYS

echo "--------------------------------------------------"
echo "INFO: Searching for RAID-Configuration ..."
used_volume=$(blkid | grep "md" | awk '{print $2}')
used_array=$(cat "/etc/mdadm/mdadm.conf" | grep "ARRAY")

if [ -n "$used_volume" ] && [ -n "$used_array" ]; then
    echo "INFO: RAID-Volume found!"
    echo "INFO: $used_array"
    echo "--------------------------------------------------"

else
    echo "INFO: No RAID-Configuration found!"
    exit 0
fi


# ========================= ========================= =========================
# HANDLE UNUSED ARRAYS

echo "--------------------------------------------------"
echo "INFO: Searching for RAID-Arrays ..."
unused_array=$(mdadm --examine --scan | grep 'ARRAY')

if [ -n "$unused_array" ]; then
    echo "INFO: Unconfigured RAID-Array found!"
    echo "INFO: $unused_array."
    echo "--------------------------------------------------"
    echo "Would you like to use the array?"

else
    echo "INFO: No RAID-Arrays found!"
    exit 0
fi