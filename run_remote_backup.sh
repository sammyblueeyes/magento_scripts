#!/bin/bash

BU_LOCATION=$1

DBHOST=$2
DBUSER=$3
DBPASS=$4
DBNAME=$5
REMOTE_HOST=$6

if [ $# -lt 6 ]; then 
    echo ERROR: not enough arguments passed to backup script
    exit -1
fi


cd $BU_LOCATION

echo --- Using the following configuration:
echo "    loc:    $BU_LOCATION"
echo "    host:   $DBHOST"
echo "    user:   $DBUSER"
echo "    pass:   $DBPASS"
echo "    db:     $DBNAME"
echo "    server: $REMOTE_HOST"


BU_FILE_NAME="data.sql"
BU_DIR_NAME=`date +"%Y%m%d_%H%M%S"`


echo --- Creating backup folder: $BU_DIR_NAME
if [ -d $BU_DIR_NAME ]; then
    echo ERROR: Backup directory $BU_DIR_NAME already exists
    exit -1
fi
mkdir $BU_DIR_NAME


echo --- Dumping the database to file
ssh $REMOTE_HOST "mysqldump -h $DBHOST -u $DBUSER -p$DBPASS $DBNAME > data.sql"


echo --- Validating remote backup file
SSH_OUTPUT=$(ssh $REMOTE_HOST "tail -1 $BU_FILE_NAME | grep -q 'Dump completed' && echo 1")
EXPORT_OK=`echo "$SSH_OUTPUT" | tail -1`
if [ "z$EXPORT_OK" != "z1" ]; then
    echo ERROR: Failed to successfully dump database.
    exit -1
fi


echo --- Deleting the old remote backup archive
SSH_OUTPUT=$(ssh $REMOTE_HOST "rm $BU_FILE_NAME.bz2")


echo --- Compressing remote backup file
SSH_OUTPUT=$(ssh $REMOTE_HOST "bzip2 $BU_FILE_NAME; ls $BU_FILE_NAME.bz2")
if [ "z$SSH_OUTPUT" != "z$BU_FILE_NAME.bz2" ]; then
    echo ERROR: Failed to compress the remote backup file
    exit -1
fi


echo --- Downloading the remote backup file
scp $REMOTE_HOST:$BU_FILE_NAME.bz2 $BU_DIR_NAME 2>&1 >/dev/null


echo --- Calculating md5sums
MD5SUM_REMOTE=$(ssh $REMOTE_HOST "md5sum $BU_FILE_NAME.bz2" | cut -d ' ' -f 1)
MD5SUM_LOCAL=$(md5sum $BU_DIR_NAME/$BU_FILE_NAME.bz2 | cut -d ' ' -f 1)


echo --- Compare local and remote md5sums: $MD5SUM_REMOTE vs $MD5SUM_LOCAL
if [ "$MD5SUM_LOCAL" != "$MD5SUM_REMOTE" ]; then
    echo ERROR: File download failed
    exit -1
fi


echo --- Backup completed successfully

