#!/bin/bash

getJobDuration() {
    local script_start="${1}"
    local duration=$((SECONDS - script_start))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    local result=""

    (( hours > 0 )) && result+="${hours} hours"
    (( minutes > 0 )) && result+="${result:+, }${minutes} minutes"
    (( seconds > 0 )) && result+="${result:+, }${seconds} seconds"

    return "${result}"
}
