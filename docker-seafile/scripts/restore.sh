#!/bin/bash
#

[ "${restore_latest}" != 'true' ] && exit 0


date=$(date '+%d%m%Y-%H:%M')
bkpdir=${SEAFILE_DATA}-backup
archive=latest
prog=${archive}/prog.cpio
sql=${archive}/sql
data=${archive}/data
dbs="ccnet seafile seahub"
sf=/opt/seafile


restore() {
	# Stop runit from unmounting /data
	mv /etc/service/seafile/finish /etc/service/seafile/finish.rm
	/etc/my_init.d/01_create_s3ql_fs

	cd /opt/seafile
	if df -t fuse.s3ql /data >/dev/null 2>&1 ; then
		if [ "$restore_prog" == "true" ] ; then
			gzip -cd ${bkpdir}/$prog | cpio -idm
		fi

		if [ "$restore_data" == "true" ] ; then
			mv ${SEAFILE_DATA} ${SEAFILE_DATA}.orig.${date}
			s3qlcp ${bkpdir}/$data ${SEAFILE_DATA}
		fi


		if [ "$restore_sql" == "true" ] ; then
		for db in $dbs; do
			db=$CCNET_IP-$db
			mysql -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD $db < ${bkpdir}/${sql}/$db.sql
		done

	else
		echo NOT ABLE TO RESTORE
	fi

	mv /etc/service/seafile/finish.rm /etc/service/seafile/finish
}

if [ $# -gt 0 ] ; then
	echo interactive
	cd $bkpdir
	backups=$(ls -1trah | nl)
	echo "$backups"
	echo -n "Choose backup to restore "
	read backup
	archive=$(echo "$backups" | grep -w $backup | awk '{print $2}')
	echo Starting to restore $archive
	restore
else 
	restore
fi
