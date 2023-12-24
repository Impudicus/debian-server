#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

notification()
{
    /usr/local/bin/notification-push.sh "smartmon" "$1" "$2"
    exit 1
}

# ========================= ========================= =========================
# MAIN

notification "error" "$SMARTD_MESSAGE ($SMARTD_FAILTYPE)"
exit $?
