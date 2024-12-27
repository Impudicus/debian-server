#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

validateMissing() {
    local work_dir="/mnt/pool2/$1"
    find "$work_dir" -mindepth 1 -type d | while read -r dir; do
        # movie-/show-poster
        local asset_name=$(printf "poster.jpg")
        if ! [[ -f "$dir/$asset_name" ]]; then
            printLog "text" "$dir/$asset_name"
        fi

        # season-poster
        find "$dir" -type f -name "*.mkv" | while read -r file; do
            local file_name=$(basename "$file")
            local season_pattern="S([0-9]{2})E([0-9]{2})"
            if [[ $file_name =~ $season_pattern ]]; then
                local season_id="${BASH_REMATCH[1]}"
                local asset_name=$(printf "Season%02.f.jpg" "$season_id")
                if ! [[ -f "$dir/$asset_name" ]]; then
                    printLog "text" "$dir/$asset_name"
                    break
                fi
            fi
        done &
    done
    wait
    return 0
}

validateNames() {
    isValidFilename() {
        local file_name="$1"
        local pattern="poster|background|Season[0-9]{2}|S[0-9]{2}E[0-9]{2}"
        if ! [[ $file_name =~ $pattern ]]; then
            return 1
        fi
        return 0
    }

    # --------------------------------------------------
    local work_dir="/mnt/pool2/$1"
    find "$work_dir" -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" | while read -r file; do
        local file_name=$(basename "$file")
        local file_ext="${file_name##*.}"

        isValidFilename "$file_name" && continue

        # backdrop
        local backdrop_pattern="S[[:space:]]?([0-9]{1,2})[[:space:]]?E[[:space:]]?([0-9]{1,2})"
        if [[ $file_name =~ $backdrop_pattern ]]; then
            local asset_name=$(printf "S%02.fE%02.f.%s" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "$file_ext")
            mv "$file" "${file%/*}/$asset_name"
            printLog "text" "$file -> ${file%/*}/$asset_name"
            continue
        fi

        # season poster
        local season_pattern="Season[[:space:]]?([0-9]{1,2})"
        if [[ $file_name =~ $season_pattern ]]; then
            local asset_name=$(printf "Season%02.f.%s" "${BASH_REMATCH[1]}" "$file_ext")
            mv "$file" "${file%/*}/$asset_name"
            printLog "text" "$file -> ${file%/*}/$asset_name"
            continue
        fi

        # specials poster
        local specials_pattern="Specials|specials"
        if [[ $file_name =~ $specials_pattern ]]; then
            local asset_name=$(printf "Season00.%s" "$file_ext")
            mv "$file" "${file%/*}/$asset_name"
            printLog "text" "$file -> ${file%/*}/$asset_name"
            continue
        fi

        # movie-/show-poster
        local poster_pattern="([0-9]{4})"
        if [[ $file_name =~ $poster_pattern ]]; then
            local asset_name=$(printf "poster.%s" "$file_ext")
            mv "$file" "${file%/*}/$asset_name"
            printLog "text" "$file -> ${file%/*}/$asset_name"
            continue
        fi

        printLog "warn" "$file"
    done
    return 0
}

validateSize() {
    rescaleImage() {
        local file="$1"
        local width="$2"
        local height="$3"
        
        convert "$file" -resize "$width"x"$height" -quality 95 "${file%.*}.jpg" || {
            return 1
        }
        rm --force "${file%.*}.png" "${file%.*}.jpeg" 2> /dev/null || {
            return 1
        }
        return 0
    }

    # --------------------------------------------------
    local work_dir="/mnt/pool2/$1"
    find "$work_dir" -type f -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" | while read -r file; do
        local file_name=$(basename "$file")
        local file_ext="${file_name##*.}"

        local file_size=$(identify -format "%wx%h" "$file")
        local file_width=$(echo "$file_size" | cut --delimiter 'x' --fields 1)
        local file_height=$(echo "$file_size" | cut --delimiter 'x' --fields 2)
        local aspect_ratio=$(echo "scale=2; $file_width / $file_height" | bc)

        # movie-/show-poster (ratio < 1)
        if [[ $(echo "$aspect_ratio < 1" | bc) -eq 1 ]]; then
            if [[ $file_ext != "jpg" || $file_width -gt 1000 || $file_height -gt 1500 ]]; then
                rescaleImage "$file" 1000 1500
                printLog "text" "$file"
            fi
            continue
        fi

        # backgrounds (ratio > 1)
        if [[ $(echo "$aspect_ratio > 1" | bc) -eq 1 ]]; then
            if [[ $file_ext != "jpg" || $file_width -gt 1280 || $file_height -gt 720 ]]; then
                rescaleImage "$file" 1280 720
                printLog "text" "$file"
            fi
            continue
        fi

        printLog "warn" "$file"
    done
    return 0
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options] library"
    echo "Options:"
    echo "  -a, --all                           Run all options"
    echo "  -h, --help                          Show this help message."
    echo "  -m, --missing                       Validate missing assets."
    echo "  -n, --names                         Validate asset names."
    echo "  -s, --size                          Validate asset sizes."
    echo "Libraries:"
    echo "  movies                              Run tasks on movies."
    echo "  series                              Run tasks on series."
}
printLog() {
    local error_type="$1"
    local log_message="$2"

    case "$error_type" in
        error)
            echo -e "\e[91m[ERROR]\e[39m $log_message"
            ;;
        warn)
            echo -e "\e[93m[WARN]\e[39m $log_message"
            ;;
        info)
            echo -e "\e[96m[INFO]\e[39m $log_message"
            ;;
        success)
            echo -e "\e[92m[SUCCESS]\e[39m $log_message"
            ;;
        *)
            echo -e "$log_message"
            ;;
    esac
}

main() {
    # --------------------------------------------------
    # Prechecks
    getPackageInstallState "curl" || {
        printLog "error" "Package 'curl' not installed!"
        exit 1
    }

    # --------------------------------------------------
    # Variables
    local has_option=''
    local validate_missing=''
    local validate_names=''
    local validate_size=''
    local library=''

    # --------------------------------------------------
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local parameter="$1"
        case "$parameter" in
            movies)
                library='movies'
                break
                ;;
            series)
                library='series'
                break
                ;;
            -a|--all)
                validate_names='true'
                validate_size='true'
                has_option='true'
                ;;
            -m|--missing)
                validate_missing='true'
                has_option='true'
                ;;
            -n|--names)
                validate_names='true'
                has_option='true'
                ;;
            -s|--size)
                validate_size='true'
                has_option='true'
                ;;
            -h|--help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown parameter '$parameter'; use --help for further information!"
                exit 1
                ;;
        esac
        shift
    done

    if [[ -z "$library" ]]; then
        printLog "error" "Missing library; use --help for further information!"
        exit 1
    elif [[ -z "$has_option" ]]; then
        printLog "error" "Missing options; use --help for further information!"
        exit 1
    fi

    # --------------------------------------------------
    printLog "info" "Library set to '$library'."
    if [[ -n "$validate_size" ]]; then
        printLog "info" "Current job: Validate asset sizes ..."
        validateSize "$library"
    fi

    if [[ -n "$validate_names" ]]; then
        printLog "info" "Current job: Validate asset names ..."
        validateNames "$library"
    fi

    if [[ -n "$validate_missing" ]]; then
        printLog "info" "Current job: Validate missing assets ..."
        validateMissing "$library"
    fi

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Script executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
