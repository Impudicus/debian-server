#!/bin/bash

# constants
readonly script_name=${BASH_SOURCE[0]}
readonly script_path=$(dirname $(realpath ${BASH_SOURCE[0]}))
readonly script_start=${SECONDS}

validateMediaDuplicates() {
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

        for file in "${subdir}"/*; do
            if [[ ! -f "${file}" ]]; then
                # invalid file
                continue
            fi

            local file_name=$(basename "${file}")
            local file_ext=${file##*.}

            echo "Im Ordner $dir_name liegt die Datei $file_name"
            return 0
        done
    done
}

validateMediaMissing() {
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

        local result=$(find "${subdir}" -type f \( -name "*.mkv" -o -name "*.mp4" \))
        if [[ ! "$result" ]]; then
            printf "${script_name}: » media file in '${dir_name}' missing\n"
        fi
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
    printf "  -d, --duplicates      Lookup duplicate media files.\n"
    printf "  -h, --help            Print this help message.\n"
    printf "  -m, --missing         Lookup missing media files.\n"
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
    action_validateduplicates=''
    action_validatemissing=''

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
            -d | --duplicates)
                action_validateduplicates='true'
                shift
                ;;
            -m | --missing)
                action_validatemissing='true'
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
    elif [[ ! "${action_validatemissing}" && ! "${action_validateduplicates}" ]]; then
        printLog "error" "No action selected, use --help for further information."
        exit 1
    fi

    # run
    printLog "text" "Config loaded: Using '${work_dir}' as working directory."

    if [[ "${action_validatemissing}" ]]; then
        printLog "info" "Task running: Validate missing media files ..."
        validateMediaMissing
        printLog "okay" "Task completed: Missing media files validated."
        sleep 1
    fi

    if [[ "${action_validateduplicates}" ]]; then
        printLog "info" "Task running: Validate duplicate media files ..."
        validateMediaDuplicates
        printLog "okay" "Task completed: Duplicate media files validated."
        sleep 1
    fi

    local job_duration=$(getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "Job finished successfully. Runtime: ${job_duration}."
    exit 0
}

main "$@"
