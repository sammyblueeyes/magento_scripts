#!/bin/bash

REMOTE_SERVER=$1
REMOTE_BU_LOCATION=$2
LOCAL_BU_LOCATION=$3
LOG_FILE=$4

{
    echo "REMOTE_SERVER: $REMOTE_SERVER"
    echo "REMOTE_BU_LOCATION: $REMOTE_BU_LOCATION"
    echo "LOCAL_BU_LOCATION: $LOCAL_BU_LOCATION"
    echo "LOG_FILE: $LOG_FILE"
    echo ""
    echo ""

    /usr/bin/rsync --exclude=.git --exclude=.gitignore --delete -avzh "$REMOTE_SERVER":"$REMOTE_BU_LOCATION" "$LOCAL_BU_LOCATION"
    echo ""
    echo ""
    pushd "$LOCAL_BU_LOCATION"
    git add --all && git commit -m "Backup $(date +'%Y%m%d_%H%M%S')"
    popd
} 2>&1 >> "$LOG_FILE"
