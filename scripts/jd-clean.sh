#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

work_dir="/pool1/downloads/complete/"
trcd_dir="/pool1/downloads/makemkv"

# ========================= ========================= =========================
# MAIN

if ! [ -d "$work_dir" ]; then
    echo "ERROR: job failed (work_dir not found)!"
    exit 1
fi

# remove files not mkv/mp4 and less then 1 GB
echo "--------------------------------------------------"
echo "INFO: Deleting files -500 MB ..."
find "$work_dir" -type f -size -500M -printf "%f\n" -delete || exit 1
echo "done!"

# print files are mkv/mp4 and more then 7,5 GB
echo "--------------------------------------------------"
echo "INFO: Moving files +7500 MB ..."
find "$work_dir" -type f -size +7500M -printf "%f\n" -exec mv {} $trcd_dir \;
echo "done!"

# print files are mkv/mp4 and x264
echo "--------------------------------------------------"
echo "INFO: Moving files with codec x264 ..."
find "$work_dir" -type f -name "*x264*" -name "*AVC*" -printf "%f\n" -exec mv {} $trcd_dir \;
echo "done!"

# remove empty folders
echo "--------------------------------------------------"
echo "INFO: Deleting files -1000 MB ..."
find "$work_dir" -type d -empty -delete || exit 1
echo "done!"

echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "--------------------------------------------------"
exit 0
