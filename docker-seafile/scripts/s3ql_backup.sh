#!/bin/bash

# Abort entire script if any command fails

[ ! -n "${S3QL_BACKUP}" ] && S3QL_BACKUP="par01.objectstorage.service.networklayer.com"

if [ -n "${MYSQL_HOST}" ] ; then
	db_string="-h $MYSQL_HOST"

	cat << !! >/root/.my.cnf
[client]
user=${MYSQL_USER}
password=${MYSQL_PASSWORD}
!!
fi

# store my pid in /var/run/s3qlbackup.pid

lock=/var/run/s3qlbackup.pid

if [ -f /var/run/s3qlbackup.pid ] ; then
	pid=$(cat $lock)
	if ps -p $pid >/dev/null 2>&1 ; then
		# backup is running, exit this job
		exit 1
	fi
fi
echo $$ >$lock

# Backup destination  (storage url)
storage_url="${S3QL_TYPE}://${S3QL_BACKUP}/${S3QL_STORAGE_CONTAINER}/${S3QL_STORAGE_FS}/"

# Make a database dump to /data before new rsync
dbs=$(mysql $db_string -Ns -e "show databases" | egrep -v 'information_schema|performance_schema')
mkdir -p /data/db-dump
tar cf /data/db-dump.pre /data/db-dump
echo Backing up database
for db in $dbs; do
	echo -n "$db "
	mysqldump $db_string --opt $db > /data/db-dump/$db.sql
	echo
done

# Recover cache if e.g. system was shut down while fs was mounted
fsck.s3ql --batch "$storage_url"
signal=$?

if [ $signal -eq 18 ] ; then
        echo "filestem not in use"
        mkfs.s3ql --plain -L $S3QL_STORAGE_CONTAINER --max-obj-size 10240 $storage_url
fi

# Create a temporary mountpoint and mount file system
mountpoint="/tmp/s3ql_backup_$$"
mkdir "$mountpoint"
mount.s3ql "$storage_url" "$mountpoint"

# Make sure the file system is unmounted when we are done
# Note that this overwrites the earlier trap, so we
# also delete the lock file here.
trap "cd /; umount.s3ql '$mountpoint'; rmdir '$mountpoint'; rm -f '$lock'" EXIT

# Figure out the most recent backup
cd "$mountpoint"
last_backup=`python <<EOF
import os
import re
backups=sorted(x for x in os.listdir('.') if re.match(r'^[\\d-]{10}_[\\d:]{8}$', x))
if backups:
    print backups[-1]
EOF`

# Duplicate the most recent backup unless this is the first backup
new_backup=`date "+%Y-%m-%d_%H:%M:%S"`
if [ -n "$last_backup" ]; then
    echo "Copying $last_backup to $new_backup..."
    s3qlcp "$last_backup" "$new_backup"

    # Make the last backup immutable
    # (in case the previous backup was interrupted prematurely)
    s3qllock "$last_backup"
fi

# ..and update the copy
rsync -aHAXx --delete-during --delete-excluded --partial -v \
    --exclude /.cache/ \
    --exclude /.s3ql/ \
    --exclude /.thumbnails/ \
    --exclude /tmp/ \
    "/data" "$mountpoint//$new_backup/"

# Make the new backup immutable
s3qllock "$new_backup"

# Expire old backups

# Note that expire_backups.py comes from contrib/ and is not installed
# by default when you install from the source tarball. If you have
# installed an S3QL package for your distribution, this script *may*
# be installed, and it *may* also not have the .py ending.
expire_backups --use-s3qlrm 1 7 14 31 90 180 360
