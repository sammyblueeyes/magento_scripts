#!/bin/bash
set -e

BU_LOCATION=$1

DBHOST=$2
DBUSER=$3
DBPASS=$4
DBNAME=$5
REMOTE_HOST=$6
RECIPIENTS=$7

if [ $# -lt 7 ]; then 
    echo "ERROR: not enough arguments passed to backup script"
    exit 1
fi


cd "$BU_LOCATION"

echo "--- Using the following configuration:"
echo "    loc:    $BU_LOCATION"
echo "    host:   $DBHOST"
echo "    user:   $DBUSER"
echo "    pass:   $DBPASS"
echo "    db:     $DBNAME"
echo "    server: $REMOTE_HOST"


BU_FILE_NAME="data.sql"
BU_DIR_NAME=$(date +"%Y%m%d_%H%M%S")


echo "--- Creating backup folder: $BU_DIR_NAME"
if [ -d "$BU_DIR_NAME" ]; then
    echo "ERROR: Backup directory $BU_DIR_NAME already exists"
    exit 2
fi
mkdir "$BU_DIR_NAME"


echo "--- Dumping the database to file"
command="mysqldump -h $DBHOST -u $DBUSER -p$DBPASS $DBNAME"
# shellcheck disable=SC2029
ssh "$REMOTE_HOST" "$command > data.sql"


echo "--- Validating remote backup file"
command="tail -1 $BU_FILE_NAME"
# shellcheck disable=SC2029
SSH_OUTPUT=$(ssh "$REMOTE_HOST" "$command" | grep -q 'Dump completed' && echo 1)
EXPORT_OK=$(echo "$SSH_OUTPUT" | tail -1)
if [ "z$EXPORT_OK" != "z1" ]; then
    echo "ERROR: Failed to successfully dump database."
    exit 3
fi


echo "--- Deleting the old remote backup archive"
# shellcheck disable=SC2029
SSH_OUTPUT=$(ssh "$REMOTE_HOST" "rm $BU_FILE_NAME.bz2")


echo "--- Compressing remote backup file"
# shellcheck disable=SC2029
SSH_OUTPUT=$(ssh "$REMOTE_HOST" "bzip2 $BU_FILE_NAME; ls $BU_FILE_NAME.bz2")
if [ "z$SSH_OUTPUT" != "z$BU_FILE_NAME.bz2" ]; then
    echo "ERROR: Failed to compress the remote backup file"
    exit 4
fi


echo "--- Downloading the remote backup file"
scp "$REMOTE_HOST:$BU_FILE_NAME.bz2" "$BU_DIR_NAME" >/dev/null 2>&1


echo "--- Calculating md5sums"
# shellcheck disable=SC2029
MD5SUM_REMOTE=$(ssh "$REMOTE_HOST" "md5sum $BU_FILE_NAME.bz2" | cut -d ' ' -f 1)
MD5SUM_LOCAL=$(md5sum "$BU_DIR_NAME/$BU_FILE_NAME.bz2" | cut -d ' ' -f 1)


echo "--- Compare remote and local md5sums: $MD5SUM_REMOTE vs $MD5SUM_LOCAL"
if [ "$MD5SUM_LOCAL" != "$MD5SUM_REMOTE" ]; then
    echo "ERROR: File download failed"
    exit 5
fi


echo "--- Sending e-mail"
subject="VoodooRabbit Backup $(date --rfc-3339=ns)"
local_file="$BU_DIR_NAME/$BU_FILE_NAME.bz2"
file_size=$(du -h "$local_file" | cut -f 1)
body="Backup file $local_file is $file_size"
# shellcheck disable=SC2086
{
    echo "Subject: $subject"
    echo "$body"
} | ssmtp $RECIPIENTS


echo "--- Backup completed successfully"
