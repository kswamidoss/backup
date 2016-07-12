#!/bin/bash

#
# Name: hl_rsync.sh
#
# Description: make rsync backups with hard links
#
# Usage: 
#   1. create and mount backup volume, e.g. /mnt/home_backup
#   2. create .rsync directory for exclude file and log files
#      $ mkdir -p /mnt/home_backup/.rsync
#      $ echo "" > /mnt/home_backup/.rsync/exclude
#
#   3. call this script
#      $ ./hl_rsync.sh SRC_DIR DEST_DIR

BIN_DATE=`which date`
BIN_ECHO=`which echo`
BIN_DF=`which df`
BIN_RSYNC=`which rsync`
BIN_MV=`which mv`
BIN_RM=`which rm`
BIN_LN=`which ln`
BIN_TAR=`which tar`


DATE=`$BIN_DATE "+%Y-%m-%dT%H_%M_%S"`

function usage {
    echo "usage: $0 SRC_DIR DEST_DIR"
    exit $1
}


[ "Z$1" == 'Z' ] && echo "arg 1 SRC_DIR required, exiting" && usage -1
[ "Z$2" == 'Z' ] && echo "arg 2 DEST_DIR required, exiting" && usage -2


SRC_DIR=$1
DEST_DIR=$2

DIFF_RSYNC_LOG="$DEST_DIR/.rsync/diff_rsync.log"
RSYNC_LOG="$DEST_DIR/.rsync/rsync-$DATE.log"

EXCLUDE_FILE="$DEST_DIR/.rsync/exclude"
DEST_INPROGRESS="$DEST_DIR/inprogress-$DATE"
DEST_BACKUP="$DEST_DIR/backup-$DATE"
DEST_LATEST="$DEST_DIR/backup-latest"          # the latest complete backup (i.e. before this run)


# echo a message to stdout and log file
function myecho {
    NOW=`$BIN_DATE "+%Y-%m-%d %H:%M:%S"`

    $BIN_ECHO "$NOW $@"
    [ -w $DIFF_RSYNC_LOG ] && $BIN_ECHO "$NOW $@" >> $DIFF_RSYNC_LOG
}


myecho "Hello"

myecho "Checking $DEST_DIR mount"
DF_OUT=`$BIN_DF -h | grep $DEST_DIR`
DF_CODE=$?

[ $DF_CODE -ne 0 ] && myecho "$DEST_DIR is not mounted, exiting" && exit $DF_CODE


myecho "Running rsync from $SRC_DIR to $DEST_INPROGRESS, excluding from $EXCLUDE_FILE...please see $RSYNC_LOG for details"
RSYNC_OUT=`$BIN_RSYNC -azP --log-file $RSYNC_LOG --delete --delete-excluded --exclude-from=$EXCLUDE_FILE --link-dest=$DEST_LATEST $SRC_DIR $DEST_INPROGRESS/`
RSYNC_CODE=$?

[ $RSYNC_CODE -ne 0 ] && myecho "rsync error, exiting, please see $RSYNC_LOG for details" && exit $RSYNC_CODE


myecho "moving inprogress to backup"
$BIN_MV $DEST_INPROGRESS $DEST_BACKUP


myecho "removing latest sym-link"
$BIN_RM -f $DEST_LATEST


# now we are the latest complete backup
myecho "creating new latest sym-link"
$BIN_LN -s $DEST_BACKUP $DEST_LATEST


myecho "compressing $RSYNC_LOG to ${RSYNC_LOG}.tgz"
$BIN_TAR zcf "${RSYNC_LOG}.tgz" $RSYNC_LOG

myecho "removing $RSYNC_LOG"
$BIN_RM $RSYNC_LOG

