#!/bin/bash
# Copyright 2023 by Philipp Hildebrandt


# ========================= ========================= =========================
# MAIN

/usr/local/bin/notification-push.sh "smartmon" "error" "$SMARTD_MESSAGE ($SMARTD_FAILTYPE)"
exit $?
