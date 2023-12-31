#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

user_token="uc8joh6vaszypwuvrprbyqfqgpwobb"

case "$1" in
    certbot)    app_token="acnh3tbb38s9xmjwt6p4id9zvv2bny" ;;
    etherwake)  app_token="asdpr25tei6i5969mcodw1ynsu7jp3" ;;
    nextcloud)  app_token="asdpr25tei6i5969mcodw1ynsu7jp3" ;;
    plex-image-cleanup) app_token="a45ergc1dorqzwcwr2bphps5rqpha6" ;;
    plex-meta-manager)  app_token="a45ergc1dorqzwcwr2bphps5rqpha6" ;;
    powerstate) app_token="asdpr25tei6i5969mcodw1ynsu7jp3" ;;
    restic)     app_token="a6iygdoubnpy2hq2ggwiou4pxrwbf2" ;;
    smartmon)   app_token="asdpr25tei6i5969mcodw1ynsu7jp3" ;;
esac

case "$2" in
    error)  message="<font color="#bf616a"><b>$3</b></font>" ;;
    warn)   message="<font color="#ebcb8b"><b>$3</b></font>" ;;
    info)   message="<font color="#5e81ac"><b>$3</b></font>" ;;
    fine)   message="<font color="#a3be8c"><b>$3</b></font>" ;;
    okay)   message="$3" ;;
esac

# ========================= ========================= =========================
# MAIN

if [[ -z $1 ]] || [[ -z $2 ]] || [[ -z $3 ]]; then
    echo "ERROR: Missing parameter for script $0"
    exit 1
fi

/usr/bin/curl -s \
    --form-string "token=$app_token" \
    --form-string "user=$user_token" \
    --form-string "html=1" \
    --form-string "title=$1 on $HOSTNAME" \
    --form-string "message=$message" \
    https://api.pushover.net/1/messages.json &> /dev/null
exit $?
