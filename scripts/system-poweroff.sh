#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

notification()
{
    /usr/local/bin/notification-push.sh "powerstate" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

notification "info" "system shutting down!"
exit $?
