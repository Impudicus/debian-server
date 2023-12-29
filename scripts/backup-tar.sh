#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

source_dir="/etc/docker"
backup_dir="/pool/backup/onetime_$(date +'%Y-%m-%d')"

# ========================= ========================= =========================
# MAIN

mkdir -p "$backup_dir" || exit 1

for subdir in "$source_dir"/*; do
    if ! [ -d "$subdir" ]; then
        echo "ERROR: Invalid directory $subdir!"
        continue
    fi

    container_name=$(basename "$subdir")

    echo "INFO: Running Backup of '$container_name' to '$backup_dir/$container_name.tar' ..."
    tar cvf "$backup_dir/$container_name.tar" $subdir || exit 1
    echo "INFO: -> Backup finished."

done

# ========================= ========================= =========================
echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "--------------------------------------------------"
exit 0