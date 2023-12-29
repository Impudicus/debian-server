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
# VOLUME

echo "INFO: Searching for RAID-VOLUMES ..."
old_volume=$(blkid | grep "md0" | awk '{print $2}')

if [ -n "$old_volume" ]; then
    echo "INFO: RAID-Volume found!"
    echo "INFO: $old_volume."
    echo "--------------------------------------------------"
    echo "Would you like to write RAID-Volume to fstab?"

    read -p "Usage: <YES|no> " add_volume
    if [ "$add_volume" = "YES" ]; then

        # create mountpoint/syslinks
        mkdir -p "/mnt/pool1" || exit 1
        ln -s "/mnt/pool1" "/pool1" || exit 1

        # add raid-volume to fstab
        volume_uuid=$(echo $old_volume | cut -d '"' -f2)
        echo "UUID=$volume_uuid /mnt/pool1 ext4 defaults,nofail,discard 0 0" >> "/etc/fstab" || exit 1
        systemctl daemon-reload || exit 1

        echo "--------------------------------------------------"
        echo "INFO: RAID-Volume added to fstab."
        echo "INFO: System restart pending."
        echo "--------------------------------------------------"
        exit 0

    fi
    echo "--------------------------------------------------"
    echo "INFO: RAID-Volume not added."
    echo "--------------------------------------------------"
    echo "Would you like to format the RAID-Volume?"

    read -p "Usage: <YES|no> " format_volume
    if [ "$format_volume" = "YES" ]; then

        # print warning
        echo "WARNING: RAID-Volume will be formated!! All files will be lost!!"
        for ((i=10; i>0; i--)); do
            echo "WARNING: Changes will be applied in $i seconds!!"
            echo "         Press CTRL + C to cancel the operation!!"
            sleep 1
        done

        # format raid-volume
        mkfs.ext4 "/dev/md0" || exit 1

        # set reserved space to 0%
        tune2fs -m 0 "/dev/md0" || exit 1

        echo "--------------------------------------------------"
        echo "INFO: RAID-Volume formated as ext4."
        echo "INFO: System restart pending."
        echo "--------------------------------------------------"
        exit 0

    fi
    echo "--------------------------------------------------"
    echo "INFO: RAID-Volume not formated."
    echo "INFO: No configuration changes made."
else
    echo "INFO: No RAID-Volume found!"
fi


# ========================= ========================= =========================
# CONFIG

echo "--------------------------------------------------"
echo "INFO: Searching for RAID-Configurations ..."
used_array=$(cat /etc/mdadm/mdadm.conf | grep ARRAY | awk '{print $2}')

if [[ $used_array == "/dev/md/${HOSTNAME}:0" ]]; then
    echo "INFO: RAID-Configuration found!"
    echo "INFO: $used_array."
    echo "--------------------------------------------------"
    echo "Would you like to remove the RAID-Configuration?"

    read -p "Usage: <YES|no> " remove_configuration
    if [ "$remove_configuration" = "YES" ]; then

        # write raid-array to mdadm.conf
        cat "$PWD/config/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf" || exit 1

        # update initramfs
        update-initramfs -u || exit 1

        echo "--------------------------------------------------"
        echo "INFO: RAID-Configuration removed."
        echo "--------------------------------------------------"
        exit 0
    fi
    echo "--------------------------------------------------"
    echo "INFO: RAID-Configuration not removed"
    echo "INFO: No configuration changes made."
    exit 0
else
    echo "INFO: No RAID-Configurations found!"
fi


# ========================= ========================= =========================
# ARRAY

echo "--------------------------------------------------"
echo "INFO: Searching for unused RAID-Arrays ..."
unused_array=$(mdadm --examine --scan | grep 'ARRAY')

if [ -n "$unused_array" ]; then
    echo "INFO: Unused RAID-Array found!"
    echo "INFO: $unused_array."
    echo "--------------------------------------------------"
    echo "Would you like to use the array?"

    read -p "Usage: <YES|no> " keep_array
    if [ "$keep_array" = "YES" ]; then

        # write raid-array to mdadm.conf
        cat "$PWD/config/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf" || exit 1
        mdadm --detail --scan >> "/etc/mdadm/mdadm.conf" || exit 1

        # update initramfs
        update-initramfs -u || exit 1

        echo "--------------------------------------------------"
        echo "INFO: RAID-Array applied."
        echo "INFO: System restart pending."
        echo "--------------------------------------------------"
        exit 0
    fi
    echo "--------------------------------------------------"
    echo "INFO: RAID-Array not applied."
    echo "--------------------------------------------------"
    echo "Would you like to delete the array?"

    read -p "Usage: <YES|no> " del_array
    if [ "$del_array" = "YES" ]; then

        echo "WARNING: RAID configuration will be deleted!! All files will be lost!!"
        for ((i=10; i>0; i--)); do
            echo "WARNING: Changes will be applied in $i seconds!!"
            echo "         Press CTRL + C to cancel the operation!!"
            sleep 1
        done

        # delete old raid-configuration
        mdadm --stop /dev/md* || exit 1

        # clear disks
        mdadm --zero-superblock /dev/sd[a-f] || exit 1

        # write raid-array to mdadm.conf
        cat "$PWD/config/mdadm/mdadm.conf" > "/etc/mdadm/mdadm.conf" || exit 1

        # update initramfs
        update-initramfs -u || exit 1

        echo "--------------------------------------------------"
        echo "INFO: RAID configuration purged. Disks cleared."
        echo "INFO: System restart pending."
        echo "--------------------------------------------------"
        exit 0
    fi
    echo "--------------------------------------------------"
    echo "INFO: RAID-Array not deleted."
    echo "INFO: No configuration changes made."
else
    echo "INFO: No RAID-Arrays found!"
fi


# ========================= ========================= =========================
echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "INFO: System restart pending."
echo "--------------------------------------------------"
exit 0
