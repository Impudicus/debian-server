#!/bin/bash

set -o pipefail # Exit when a command in a pipeline fails

readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_TIME=$SECONDS

getPackageInstallState() {
    local package_name="$1"
    dpkg --list | grep --word-regexp "$package_name" > /dev/null
    return $?
}

plexGetRunstate() {
    local plex_url="http://127.0.0.1:32400/web/index.html"
    curl --silent --head --fail "$plex_url" | grep --quiet "200 OK"
    return $?
}

plexFetchSessions() {
    local plex_url="http://127.0.0.1:32400/status/sessions?X-Plex-Token=$PLEX_API_KEY"
    curl --silent --header "Accept: application/json" "$plex_url"
    return $?
}

printHelp() {
    echo "Usage: $SCRIPT_NAME [options]"
    echo "Options:"
    echo "  -h, --help                          Show this help message."
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

    plexGetRunstate || {
        printLog "error" "Plex Media Server not running!"
        exit 1
    }

    # --------------------------------------------------
    # Variables

    # --------------------------------------------------
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        local parameter="$1"
        case "$parameter" in
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

    # --------------------------------------------------
    source '/etc/environment' || {
        printLog "error" "Unable to load configuration file!"
        exit 1
    }

    local session_list=$(plexFetchSessions) || {
        printLog "error" "Unable to fetch Plex sessions!"
        exit 1
    }
    if [[ -z "$session_list" || "$session_list" == "null" ]]; then
        printLog "warn" "No active Plex sessions found."
    elif [[ $(echo "$session_list" | jq --compact-output '.MediaContainer.size') == "0" ]]; then
        printLog "info" "No active Plex sessions found."
    else
            echo "$session_list" | jq --compact-output '.MediaContainer.Metadata[]' | while read -r session; do 
            local user_name=$(echo "$session" | jq --raw-output '.User.title')
            local element_type=$(echo "$session" | jq --raw-output '.type')
            if [[ "$element_type" == "episode" ]]; then
                local show_title=$(echo "$session" | jq --raw-output '.grandparentTitle')
                local season=$(echo "$session" | jq --raw-output '.parentIndex')
                local episode=$(echo "$session" | jq --raw-output '.index')
                local episode_title=$(echo "$session" | jq --raw-output '.title')

                local viewOffset=$(echo "$session" | jq --raw-output '.viewOffset')
                local duration=$(echo "$session" | jq --raw-output '.duration')
                local percentage=$((viewOffset * 100 / duration))
                printLog "text" "User: $user_name, Show: $show_title, Season: $season, Episode: $episode, Title: $episode_title, Watched: $percentage%"
            elif [[ "$element_type" == "movie" ]]; then
                local title=$(echo "$session" | jq --raw-output '.title')
                local year=$(echo "$session" | jq --raw-output '.year')

                local viewOffset=$(echo "$session" | jq --raw-output '.viewOffset')
                local duration=$(echo "$session" | jq --raw-output '.duration')
                local percentage=$((viewOffset * 100 / duration))
                printLog "text" "User: $user_name, Title: $title, Year: $year, Watched: $percentage%"
            fi
        done
    fi

    # --------------------------------------------------
    local run_time=$((SECONDS - SCRIPT_TIME))
    printLog "success" "Script executed successfully. Run time: $run_time seconds."
    exit 0
}

main "$@"
