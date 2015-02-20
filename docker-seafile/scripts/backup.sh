#!/bin/bash
#

[ "${autoconf}" == 'true' ] && exit 0

date=$(date '+%d%m%Y-%H:%M')
bkpdir=${SEAFILE_DATA}-backup
prog=${date}/prog.cpio
sql=${date}/sql
data=${date}/data
dbs="ccnet seafile seahub"
sf=/opt/seafile

if df -t fuse.s3ql /data >/dev/null 2>&1 ; then
	mkdir -p ${bkpdir}/$date ${bkpdir}/$sql
	echo mkdir -p ${bkpdir}/$date ${bkpdir}/$sql

	find /etc/nginx/certs/$CCNET_IP $sf/ccnet $sf/conf $sf/logs $sf/pids $sf/seafile-server* $sf/seahub* $sf/nginx/${CCNET_IP} | cpio -o | gzip > ${bkpdir}/$prog
	s3qlcp ${SEAFILE_DATA} ${bkpdir}/$data


	for db in $dbs; do
		db=$CCNET_IP-$db
		set -x
		mysqldump -h $MYSQL_HOST -u$MYSQL_USER -p$MYSQL_PASSWORD --opt $db > ${bkpdir}/${sql}/$db.sql
		set -
	done

	rm -f ${bkpdir}/latest
	ln -s ${bkpdir}/${date} ${bkpdir}/latest

	# Clean old backups
	keep=$(ls -1tra ${bkpdir}/ | grep -v latest | tail -5)
	for i in $(ls -1tra ${bkpdir}/ | grep -v latest) ; do
		if echo "$keep" | grep $i >/dev/null ; then
			continue
		fi
		s3qlrm "$bkpdir/$i"
	done

else
	echo NOT ABLE TO BACKUP 
fi
