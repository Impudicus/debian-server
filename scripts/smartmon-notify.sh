#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt

notification()
{
    /usr/local/bin/notification-push.sh "smartmon" "$1" "$2"
    return $?
}

# ========================= ========================= =========================
# MAIN

notification "error" "$SMARTD_MESSAGE ($SMARTD_FAILTYPE)"
exit $?
