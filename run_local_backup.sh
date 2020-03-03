#!/bin/bash

set -eu -o pipefail

if [ $# -lt 5 ]; then 
    echo ""
    echo "ERROR: not enough arguments passed to backup script"
    echo "Usage:"
    echo "   $0 <bu_location> <dbhost> <dbuser> <dbpass> <dbname>"
    echo ""
    exit -1
fi

BU_LOCATION=$1
DBHOST=$2
DBUSER=$3
DBPASS=$4
DBNAME=$5

cd "$BU_LOCATION"

echo "--- Using the following configuration:"
echo "    loc:    $BU_LOCATION"
echo "    host:   $DBHOST"
echo "    user:   $DBUSER"
echo "    pass:   $DBPASS"
echo "    db:     $DBNAME"


BU_FILE_NAME="data.sql"
BU_DIR_NAME=$(date +"%Y%m%d_%H%M%S")


echo "--- Creating backup folder: $BU_DIR_NAME"
if [ -d "$BU_DIR_NAME" ]; then
    echo "ERROR: Backup directory $BU_DIR_NAME already exists"
    exit -1
fi
mkdir "$BU_DIR_NAME"
cd "$BU_DIR_NAME"


echo "--- Dumping the database to file"
PARAMS=(-h "$DBHOST")
[ -n "$DBUSER" ] && PARAMS+=("-u $DBUSER")
[ -n "$DBPASS" ] && PARAMS+=("-p$DBPASS")
PARAMS+=("$DBNAME")
echo "    mysqldump " "${PARAMS[@]}"
mysqldump "${PARAMS[@]}" > data.sql


echo "--- Validating remote backup file"
CMD_OUTPUT=$(tail -1 $BU_FILE_NAME | grep -q 'Dump completed' && echo 1)
EXPORT_OK=$(echo "$CMD_OUTPUT" | tail -1)
if [ "z$EXPORT_OK" != "z1" ]; then
    echo "ERROR: Failed to successfully dump database."
    exit -1
fi


echo "--- Compressing remote backup file"
CMD_OUTPUT=$(bzip2 $BU_FILE_NAME; ls $BU_FILE_NAME.bz2)
if [ "z$CMD_OUTPUT" != "z$BU_FILE_NAME.bz2" ]; then
    echo "ERROR: Failed to compress the remote backup file"
    exit -1
fi

echo "--- Backup completed successfully"
