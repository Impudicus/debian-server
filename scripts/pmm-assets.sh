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

if [ -z "$1" ]; then
    echo "ERROR: No media library selected."
    exit 1
fi

# ========================= ========================= =========================
# MOVIES

movie_media_path='/pool1/movies'
movie_asset_path='/pool1/assets/movies'

if [ "$1" = "movies" ]; then
    echo "INFO: Library $1 selected."
    echo "--------------------------------------------------------"
    echo "INFO: Step 1 of 4: Validate naming convention of media files."
    missing_file=0
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No invalid naming convention found.\e[0m\n"
    fi
    echo "--------------------------------------------------------"
    echo "INFO: Step 2 of 4: Validate duplicate media files."
    missing_file=0
    for subdir in "$movie_media_path"/*; do
        if ! [ -d "$subdir" ]; then
            echo "ERROR: Invalid directory $subdir!"
            exit 1
        fi

        movie_name=$(basename "$subdir")
        file_count=$(ls -l "$subdir" | wc -l)
        if [ $file_count -ne 2 ]; then
            printf "\e[31;1m Multiple Files for '${movie_name}'\e[0m\n"
            missing_file=1
        fi
    done
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No invalid naming convention found.\e[0m\n"
    fi
    echo "--------------------------------------------------------"
    echo "INFO: Step 3 of 4: Validate asset files for media files."
    missing_file=0
    for subdir in "$movie_media_path"/*; do
        if ! [ -d "$subdir" ]; then
            echo "ERROR: Invalid directory $subdir!"
            exit 1
        fi

        movie_name=$(basename "$subdir")
        asset_file="${movie_asset_path}/${movie_name}.jpg"
        if ! [ -f "$asset_file" ]; then
            printf "\e[31;1m Missing poster for '${movie_name}'\e[0m\n"
            missing_file=1
        fi
    done
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No missing posters found.\e[0m\n"
    fi
    echo "--------------------------------------------------------"
    echo "INFO: Step 4 of 4: Validate media files for asset files."
    missing_file=0
    for asset in "$movie_asset_path"/*; do
        if ! [ -f "$asset" ]; then
            echo "ERROR: Invalid file $asset!"
            exit 1
        fi

        asset_name=$(basename "$asset" .jpg)
        movie_dir="${movie_media_path}/${asset_name}"
        if ! [ -d "$movie_dir" ]; then
            printf "\e[31;1m Missing mediafile for '${asset_name}'\e[0m\n"
            missing_file=1
        fi
    done
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No missing mediafile found.\e[0m\n"
    fi
fi


# ========================= ========================= =========================
# SERIES

show_media_path='/pool1/series'
show_asset_path='/pool1/assets/series'

if [ "$1" = "series" ]; then
    echo "INFO: Library $1 selected."
    echo "--------------------------------------------------------"
    echo "INFO: Step 1 of 4: Validate naming convention of media files."
    missing_file=0
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No invalid naming convention found.\e[0m\n"
    fi
    echo "--------------------------------------------------------"
    echo "INFO: Step 2 of 4: Validate duplicate media files."
    missing_file=0
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No invalid naming convention found.\e[0m\n"
    fi
    echo "--------------------------------------------------------"
    echo "INFO: Step 3 of 4: Validate asset files for media files."
    missing_file=0
    for subdir in "$show_media_path"/*; do
        if ! [ -d "$subdir" ]; then
            echo "ERROR: Invalid directory $subdir!"
            exit 1
        fi

        # show-poster
        show_name=$(basename "$subdir")
        asset_file="${show_asset_path}/${show_name}.jpg"
        if ! [ -f "$asset_file" ]; then
            printf "\e[31;1m Missing poster for '${show_name}'\e[0m\n"
            missing_file=1
        fi

        # season-poster
        last_season=0
        for episode in "$subdir"/*; do
            if ! [ -f "$episode" ]; then
                echo "ERROR: Invalid directory $subdir!"
                exit 1
            fi
            episode_name=$(basename "$episode")
            season_id=$(echo "$episode_name" | grep -oP 'S\K\d+')
            asset_file="${show_asset_path}/${show_name}_Season${season_id}.jpg"
            if ! [ -f "$asset_file" ] && [[ "$season_id" -ne "$last_season" ]]; then
                printf "\e[31;1m Missing poster for '${show_name}_Season${season_id}'\e[0m\n"
                missing_file=1
                last_season=$season_id
            fi
        done
    done
    if [ $missing_file -eq 0 ]; then
        printf "\e[32;1m No missing posters found.\e[0m\n"
    fi
fi


# ========================= ========================= =========================
echo "--------------------------------------------------"
echo "INFO: Script executed successfully."
echo "--------------------------------------------------"
exit 0
