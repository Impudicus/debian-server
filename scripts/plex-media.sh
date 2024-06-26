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

        local file_count=$(find "${subdir}" -type f -iname "${dir_name}*.mkv" | wc -l)
        if [[ ${file_count} -gt 1 ]]; then
            printf "${script_name}: » '${dir_name}' has multiple media files\n"
        fi
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

        local file_count=$(find "${subdir}" -type f -iname "${dir_name}*.mkv" | wc -l)
        if [[ ${file_count} -eq 0 ]]; then
            printf "${script_name}: » '${dir_name}' has no media files\n"
        fi
    done
}

printLog() {
    local log_type="${1}"
    local log_text="${2}"

    case "${log_type}" in
        error)
            # /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;196m${log_text}\e[0m\n" >&1
            ;;
        okay)
            # /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;82m${log_text}\e[0m\n" >&1
            ;;
        warn)
            # /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;214m${log_text}\e[0m\n" >&1
            ;;
        info)
            # /usr/local/sbin/pushNotification.sh "debian" "${log_type}" "${log_text}"
            printf "${script_name}: \e[38;5;21m${log_text}\e[0m\n" >&1
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

    local job_duration=$(/usr/local/sbin/getJobDuration.sh $script_start $SECONDS)
    printLog "okay" "Job finished successfully. Runtime: ${job_duration}."
    exit 0
}

main "$@"
