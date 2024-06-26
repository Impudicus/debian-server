#!/bin/bash

main() {
    local start_time="${1}"
    local end_time="${2}"

    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    local result=""

    (( hours > 0 )) && result+="${hours} hours"
    (( minutes > 0 )) && result+="${result:+, }${minutes} minutes"
    (( seconds > 0 )) && result+="${result:+, }${seconds} seconds"

    echo "${result}"
    return 0
}

main "$@"
