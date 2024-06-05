#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

validateAssetNames() {
    find "${work_dir}" \
        -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \
        | while read -r file; do

        local file_name=$(basename "${file}")
        local file_dir=$(dirname "${file}")
        local file_ext=${file##*.}
        local file_parent_dir=$(basename "$(dirname "$file")")

        # matching filenames
        local valid_poster_regex="^poster$"
        local valid_season_regex="^Season[0-9]{2}$"
        if [[ "${file_name%.*}" =~ ${valid_poster_regex} || "${file_name%.*}" =~ ${valid_season_regex} ]]; then
            # filename meets requirements
            continue
        fi

        # invalid filenames
        local invalid_season_regex_space=".*Season ?([0-9]{1,2})*"
        local invalid_season_regex_nospace=".*Season([0-9]{1,2})*"
        if [[ "${file_name%.*}" =~ ${invalid_season_regex_space} || "${file_name%.*}" =~ ${invalid_season_regex_nospace} ]]; then
            local asset_name=$(printf "Season%02.f.%s" "${BASH_REMATCH[1]}" "${file_ext}")
            mv "${file}" "${file_dir}/${asset_name}"

            printf "${script_name}: » season '${file_parent_dir}/${file_name}' renamed to '${asset_name}'\n"
            continue
        fi

        local invalid_background_regex=".*Backdrop*"
        if [[ "${file_name%.*}" =~ ${invalid_background_regex} ]]; then
            local asset_name=$(printf "background.%s" "${file_ext}")
            mv "${file}" "${file_dir}/${asset_name}"

            printf "${script_name}: » background '${file_parent_dir}/${file_name}' renamed to '${asset_name}'\n"
            continue
        fi

        local invalid_specials_regex=".*Specials*"
        if [[ "${file_name%.*}" =~ ${invalid_specials_regex} ]]; then
            local asset_name=$(printf "Season00.%s" "${file_ext}")
            mv "${file}" "${file_dir}/${asset_name}"

            printf "${script_name}: » specials '${file_parent_dir}/${file_name}' renamed to '${asset_name}'\n"
            continue
        fi

        # local invalid_poster_regex=".*\([0-9]{4}\).*"
        # if [[ "${file_name%.*}" =~ ${invalid_poster_regex} ]]; then
        #     local asset_name=$(printf "poster.%s" "${file_ext}")
        #     mv "${file}" "${file_dir}/${asset_name}"
            
        #     printf "${script_name}: » poster '${file_parent_dir}/${file_name}' renamed to '${asset_name}'\n"
        #     continue
        # fi

        printLog "error" "Invalid filename '${file_parent_dir}/${file_name}'."
    done
}

validateAssetDimensions() {
    find "${work_dir}" \
        -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) \
        | while read -r file; do

        local file_name=$(basename "${file}")
        local file_dir=$(dirname "${file}")
        local file_ext=${file##*.}
        local file_parent_dir=$(basename "$(dirname "$file")")

        local image_dimension=$(identify -format "%wx%h" "$file")
        local image_width=$(identify -format "%w" "$file")
        local image_height=$(identify -format "%h" "$file")
        local image_aspect_ratio=$((image_width * 100 / image_height))

        # poster
        if [[ "${image_aspect_ratio}" -lt 100 ]]; then
            if [[ "${image_dimension}" == '1000x1500' && "${file_ext}" == 'jpg' ]]; then
                # poster meets requirements
                continue
            fi

            local new_file="${file%.*}.jpg"
            convert "${file}" -resize 1000x1500 -quality 95 "${new_file}"
            rm --force "${file%.*}.png" "${file%.*}.jpeg" > /dev/null

            printf "${script_name}: » poster '${file_parent_dir}/${file_name}' resized\n"
            continue
        fi

        # tilecard
        if [[ "${image_aspect_ratio}" -gt 100 ]]; then
            if [[ "${image_dimension}" == '1280x720' && "${file_ext}" == 'jpg' ]]; then
                # tilecard meets requirements
                continue
            fi

            local new_file="${file%.*}.jpg"
            convert "${file}" -resize 1280x720 -quality 95 "${new_file}"
            rm --force "${file%.*}.png" "${file%.*}.jpeg" > /dev/null

            printf "${script_name}: » tilecard '${file_parent_dir}/${file_name}' resized\n"
            continue
        fi
    done
}

validateAssetMissing() {
    for subdir in "${work_dir}"/*; do
        if [[ ! -d "${subdir}" ]]; then
            printLog "error" "Invalid directory '${subdir}', skipped."
            continue
        elif [[ "${subdir}" == './lost+found' ]]; then
            printLog "info" "System directory '${subdir}', skipped."
            continue
        fi

        local dir_name=$(basename "${subdir}")
        local parent_dir=$(basename "$(dirname "$subdir")")

        # poster
        local asset_name='poster.jpg'
        if [[ ! -f "${subdir}/${asset_name}" ]]; then
            printf "${script_name}: » poster for '${dir_name}' missing\n"
        else
            continue
        fi

        # season
        for file in "${subdir}"/*; do
            if [[ ! -f "${file}" ]]; then
                # invalid file
                continue
            fi

            local file_name=$(basename "${file}")
            local file_ext=${file##*.}

            local episode_regex=".*S([0-9]{2})E([0-9]{2}).*"
            if [[ "${file_name%.*}" =~ ${episode_regex} ]]; then
                local asset_name=$(printf "Season%02.f.jpg" "${BASH_REMATCH[1]}")
                if [[ ! -f "${subdir}/${asset_name}" ]]; then
                    printf "${script_name}: » season for '${dir_name}' missing\n"
                    break
                fi
            fi
        done
    done
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            printf "${script_name}: \e[41m${log_text}\e[0m\n" >&2
            ;;
        okay)
            printf "${script_name}: \e[42m${log_text}\e[0m\n" >&1
            ;;
        info)
            printf "${script_name}: \e[44m${log_text}\e[0m\n" >&1
            ;;
        *)
            printf "${script_name}: ${log_text}\n" >&1
            ;;
    esac
}
printHelp() {
    printf "Usage: ${script_name} [OPTIONS]\n"
    printf "Options:\n"
    printf "  -h, --help            Print this help message.\n"
    printf "  -m, --missing         Lookup missing assets.\n"
    printf "  -n, --name            Validate asset names.\n"
    printf "  -s, --size            Validate asset dimensions.\n"
    printf "\n"
    printf "Paths:\n"
    printf "  movies                Run operations on '/mnt/pool1/movies'.\n"
    printf "  series                Run operations on '/mnt/pool1/series'.\n"
    printf "\n"
}

main() {
    # pre-checks
    if [[ "${EUID}" -ne 0 ]]; then
        printLog "error" "Script has to be run with root user privileges."
        exit 1
    fi

    # variables
    work_dir=''
    action_validatemissing=''
    action_validatename=''
    action_validatedimensions=''

    # parameters
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            movies)
                work_dir='/mnt/pool1/movies'
                break
                ;;
            series)
                work_dir='/mnt/pool1/series'
                break
                ;;
            -m | --missing)
                action_validatemissing='true'
                shift
                ;;
            -n | --name)
                action_validatename='true'
                shift
                ;;
            -s | --size)
                action_validatedimensions='true'
                shift
                ;;
            -h | --help)
                printHelp
                exit 0
                ;;
            *)
                printLog "error" "Unknown option '${1}', use --help for further information."
                exit 1
                ;;
        esac
    done

    if [[ ! "${work_dir}" ]]; then
        printLog "error" "Missing working directory, use --help for further information."
        exit 1
    elif [[ ! "${action_validatemissing}" && ! "${action_validatename}" && ! "${action_removesamples}" && ! "${action_validatedimensions}" ]]; then
        printLog "error" "No action selected, use --help for further information."
        exit 1
    fi

    # run
    printLog "text" "Config loaded: Using '${work_dir}' as working directory."

    if [[ "${action_validatename}" ]]; then
        printLog "info" "Task running: Validate asset naming convention ..."
        validateAssetNames
        printLog "okay" "Task completed: Asset naming convention validated."
        sleep 1
    fi

    if [[ "${action_validatedimensions}" ]]; then
        printLog "info" "Task running: Validate asset dimensions ..."
        validateAssetDimensions
        printLog "okay" "Task completed: Asset dimensions validated."
        sleep 1
    fi

    if [[ "${action_validatemissing}" ]]; then
        printLog "info" "Task running: Validate missing assets ..."
        validateAssetMissing
        printLog "okay" "Task completed: Missing assets validated."
        sleep 1
    fi

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "Job finished successfully. Runtime: ${job_duration}."
    exit 0
}

main "$@"
