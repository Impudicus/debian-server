#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

work_dir="/pool1/download/complete/"

# ========================= ========================= =========================
# MAIN

# validate work_dir
if ! [ -d "$work_dir" ]; then
    echo "ERROR: job failed (work_dir not found)!"
    exit 1
fi

# remove files not mkv/mp4 and less then 1 GB
echo "--------------------------------------------------"
echo "INFO: Deleting files -1000 MB ..."
find "$work_dir" -type f -size -1000M ! -name "*.mkv" ! -name "*.mp4" -printf "%f\n" || exit 1
echo "done!"

# print files are mkv/mp4 and more then 7,5 GB
echo "--------------------------------------------------"
echo "INFO: Printing files +7500 MB ..."
find "$work_dir" -type f -size +7500M -printf "%f\n" -exec mv {} /pool1/download/makemkv \;
echo "done!"

# print files are mkv/mp4 and x264
echo "--------------------------------------------------"
echo "INFO: Printing files with codec x264 ..."
find "$work_dir" -type f -name "*x264*" -name "*AVC*" -printf "%f\n" -exec mv {} /pool1/download/makemkv \;
echo "done!"

echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "--------------------------------------------------"
exit 0
