#!/bin/bash
#

docker_image="raghon/seafile"


# Global variables

global() {
	# get api credentials from config file
	server=${1%%.*}
	domain=${1#*.}
	[ "$domain" == "$server" ] && domain=cloudwalker.biz
	fqdn=${server}.${domain}

	. /root/.cloudwalker/secret
	AUTOCONF=true
	CCNET_IP=${fqdn}
	EXISTING_DB=false
	MYSQL_HOST=mariadb01.mariadb.demo.docker
	MYSQL_ROOT_USER=root
	MYSQL_USER=${fqdn}-admin
	MYSQL_ROOT_PASSWORD=$(docker logs mariadb01 2>/dev/null | awk -F= '$1=="MARIADB_PASS" {print $2}')
	CCNET_DB_NAME=${fqdn}-ccnet
	SEAFILE_DB_NAME=${fqdn}-seafile
	SEAHUB_DB_NAME=${fqdn}-seahub
	SEAHUB_ADMIN_EMAIL=admin@${fqdn}
	SEAFILE_IP=${fqdn}.seafile.demo.docker
	S3QL_STORAGE=ams01.objectstorage.service.networklayer.com
	S3QL_STORAGE_CONTAINER=fs
	#S3QL_LOGIN=api_user		# Read from configfile
	#S3QL_PASSWD=api_passwd		# Read from configfile
	S3QL_STORAGE_FS=${fqdn}
	S3QL_COMPRESS=zlib
	S3QL_FSPASSWD=optionalpassword
	S3QL_MOUNT_POINT=/data
	S3QL_TYPE=swift
}


make_s3ql_docker() {
	server=$1

	docker run $init \
	 --name "${server}"  \
	 --cap-add mknod \
	 --cap-add sys_admin \
	 --device=/dev/fuse \
	 ${extra_docker_opts} \
	 -v /root/.s3ql/authinfo2:/root/.s3ql/authinfo2:ro \
	 -h $server \
	 -e fcgi=true \
	 -e autonginx=true \
	 -e "CCNET_IP=$CCNET_IP"\
	 -e "EXISTING_DB=$EXISTING_DB" \
	 -e "MYSQL_HOST=$MYSQL_HOST" \
	 -e "MYSQL_ROOT_USER=$MYSQL_ROOT_USER" \
	 -e "MYSQL_USER=$MYSQL_USER" \
	 -e "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" \
	 -e "CCNET_DB_NAME=$CCNET_DB_NAME" \
	 -e "SEAFILE_DB_NAME=$SEAFILE_DB_NAME" \
	 -e "SEAHUB_DB_NAME=$SEAHUB_DB_NAME" \
	 -e "SEAHUB_ADMIN_EMAIL=$SEAHUB_ADMIN_EMAIL" \
	 -e "SEAFILE_IP=$SEAFILE_IP" \
	 -e S3QL_STORAGE=$S3QL_STORAGE \
	 -e S3QL_STORAGE_CONTAINER=$S3QL_STORAGE_CONTAINER \
	 -e S3QL_STORAGE_FS=$S3QL_STORAGE_FS \
	 -e S3QL_COMPRESS=$S3QL_COMPRESS \
	 -e S3QL_MOUNT_POINT=$S3QL_MOUNT_POINT \
	 -e S3QL_TYPE=swift \
	$docker_image $shell "$extra"
}

make_seafile_docker() {
	server=$1

	docker run $init \
	 --name "${server}"  \
	 ${extra_docker_opts} \
	 -v /root/.s3ql/authinfo2:/root/.s3ql/authinfo2:ro \
	 -h $server \
	 --cap-add mknod \
	 --cap-add sys_admin \
	 --device=/dev/fuse \
	 --link mariadb01:mysql-container \
	 --volumes-from nginx \
	 -e fcgi=true \
	 -e autonginx=true \
	 -e autoconf=$AUTOCONF \
	 -e "CCNET_IP=$CCNET_IP"\
	 -e "EXISTING_DB=$EXISTING_DB" \
	 -e "MYSQL_HOST=$MYSQL_HOST" \
	 -e "MYSQL_ROOT_USER=$MYSQL_ROOT_USER" \
	 -e "MYSQL_USER=$MYSQL_USER" \
	 -e "MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD" \
	 -e "CCNET_DB_NAME=$CCNET_DB_NAME" \
	 -e "SEAFILE_DB_NAME=$SEAFILE_DB_NAME" \
	 -e "SEAHUB_DB_NAME=$SEAHUB_DB_NAME" \
	 -e "SEAHUB_ADMIN_EMAIL=$SEAHUB_ADMIN_EMAIL" \
	 -e "SEAFILE_IP=$SEAFILE_IP" \
	 -e S3QL_STORAGE=$S3QL_STORAGE \
	 -e S3QL_STORAGE_CONTAINER=$S3QL_STORAGE_CONTAINER \
	 -e S3QL_STORAGE_FS=$S3QL_STORAGE_FS \
	 -e S3QL_COMPRESS=$S3QL_COMPRESS \
	 -e S3QL_MOUNT_POINT=$S3QL_MOUNT_POINT \
	 -e S3QL_TYPE=swift \
	$docker_image $shell $([ -n "$extra" ] && echo \"$extra\")
}

rm_database() {
	server=$1
	docker exec -i mariadb01 mysql -p$MYSQL_ROOT_PASSWORD -Dmysql -e "drop database \`${server}-seafile\`"
	docker exec -i mariadb01 mysql -p$MYSQL_ROOT_PASSWORD -Dmysql -e "drop database \`${server}-seahub\`"
	docker exec -i mariadb01 mysql -p$MYSQL_ROOT_PASSWORD -Dmysql -e "drop database \`${server}-ccnet\`"
	docker exec -i mariadb01 mysql -p$MYSQL_ROOT_PASSWORD -Dmysql -e "drop user \`${server}-admin\`"
}

rm_docker() {
	server=$1
	docker stop $server
	docker rm $server
}

backup() {
	if [ "$backup" == "true" ] ; then
		shell="/bin/sh -c " 
		date=$(date '+%d%m%Y-%H:%M')
		extra=" \
			if df -t fuse.s3ql /data ; then \
				tar zcf /data/seafile-${date}.tgz /opt/seafile ; \
				rm -f /data/seafile-latest.tgz
				ln -s /data/seafile-${date}.tgz /data/seafile-latest.tgz
				cd /data ; \
				s3qlcp seafile-data seafile-data.bkp.${date} ; \
				cd / && umount.s3ql /data ; \
			else \
				echo NOT ABLE TO BACKUP ; \
			fi ;\
			"

		docker exec -i $server "$extra"
		exit 0
	fi
}

usage() {
	echo "Usage: $0 [-I image/name ] [-crSfdc] server1 server2 etc

	- -c 		: create new docker container
	- -r 		: remove docker container, and delete from database
	- -I d/image    : docker image to use when creating docker 
	- -S		: Create temporary docker and start bash -o vi
	- -d		: Debug docker creation. Image is deleted on stop
	- -f		: Execute fsck.s3ql inside a temporary docker container
	- -F		: Delete s3ql filsystem
	- -C		: Connect console to running docker
	- -D		: Configure/update skydock and skydns
	- -B		: Backup seafile containers to data env
	- -R		: Restore seafile container
	"
	exit 1
}

init_skydns() {
	environment=$1
	docker stop skydns skydock
	docker rm skydns skydock
	docker pull crosbymichael/skydns
	docker run -d -p 172.17.42.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 10.0.80.11:53 -domain docker
	docker pull crosbymichael/skydock
	docker run -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment $environment -s /docker.sock -domain docker -name skydns
	docker run -d --name nginx -p 443:443 -p 80:80 guilhem30/nginx:latest
	docker run -d --name mariadb guilhem30/mariadb:latest
}

init="-d"
rm="false"
create="false"
s3ql_clear="false"
console="false"
skydns="false"
restore="false"
backup="false"
rebuildFromBckp="false"


OPTIND=1

while getopts "BCD:CDI:RFSbcdfrq" option; do
    case $option in
	D) skydns="true" ; environment="$OPTARG" ;;
        r) rm="true"  ;;
        c) create="true"  ;;
        I) docker_image="$OPTARG";;
        S) init="--rm -it" ; shell="bash -o vi" ;;
        d) init="--rm -it"  ;;
        f) init="--rm -it" ; shell="/bin/sh -c " ; extra="/etc/my_init.d/01_create_s3ql_fs && umount.s3ql --debug /data" ;;
	C) console="true" ;;
	F) s3ql_clear="true" ;;
	B) backup_disaster="true";;
	b) backup="true";;
	R) rebuildFromBckp="true";;
	Q) restore="true";;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

[ "$skydns" == "true" ] && (init_skydns $environment )

[ -z "$1" ] && exit 0


for server in $* ; do
	global $server
	if [ "$console" == "true" ] ; then  
		exec docker exec -it $server bash -o vi
	fi

	if [ "$s3ql_clear" == "true" ] ; then  
		init="--rm -it" 
		shell="/bin/sh -c " 
		extra="/etc/my_init.d/01_create_s3ql_fs ; umount.s3ql --debug /data ; s3qladm clear ${S3QL_TYPE}://${S3QL_STORAGE}/${S3QL_STORAGE_CONTAINER}/${S3QL_STORAGE_FS}/"
		[ "$rm" == "true" -a -n "$server" ] && (rm_docker $server ; rm_database $server)
		[ "$create" == "true" -a -n "$server" -a "$debug" == "true" ] && make_s3ql_docker $server debug
		[ "$create" == "true" -a -n "$server" ] && make_s3ql_docker $server
		exit 0
	fi

	if [ "$backup" == "true" ] ; then
		backup $server
	fi
	if [ "$backup_disaster" == "true" ] ; then
	 	extra_docker_opts="--volumes-from $server"
		S3QL_STORAGE_FS=$server
		init="--rm -it" 
		shell="/bin/sh -c " 
		date=$(date '+%d%m%Y-%H:%M')
		extra="/etc/my_init.d/01_create_s3ql_fs ; \
			if df -t fuse.s3ql /data ; then \
				tar zcf /data/seafile-${date}.tgz /opt/seafile ; \
				rm -f /data/seafile-latest.tgz
				ln -s /data/seafile-${date}.tgz /data/seafile-latest.tgz
				cd /data ; \
				s3qlcp seafile-data seafile-data.bkp.${date} ; \
				cd / && umount.s3ql /data ; \
			else \
				echo NOT ABLE TO BACKUP ; \
			fi ;\
			bash -o vi \
			"

		server=$server-restore
		docker_image=raghon/s3ql
		[ "$create" == "true" -a -n "$server" ] && make_s3ql_docker $server
		exit 0
	fi
	if [ "$rebuildFromBckp" == "true" ] ; then
	#	docker_image=raghon/s3ql
	S3QL_STORAGE_FS=$server
	init="-it"
	if [ "$debug" == "true" ] ; then 
		init="--rm -it" 
	fi

	shell="/bin/sh -c " 
	date=$(date '+%d%m%Y-%H:%M')
	extra="/etc/my_init.d/01_create_s3ql_fs ; \
	       if df -t fuse.s3ql /data ; then \
	       tar zxf /data/seafile-latest.tgz -C / ; \
	       umount.s3ql /data
			else \
				echo NOT ABLE TO RESTORE ; \
			fi ;\
			echo \"\n\nPlease remember to unmount cleanly /data using umount.s3ql /data\" ; \
			cd / ; \
			bash -o vi; \
			"

		orig_server=$server
		[ "$create" == "true" -a -n "$server" ] && make_s3ql_docker $server-data
		unset extra
		unset shell
	 	extra_docker_opts="--volumes-from $orig_server-data"
		init="-d" 
		make_seafile_docker $orig_server
		exit 0
	fi
	

	[ "$rm" == "true" -a -n "$server" ] && (rm_docker $server ; rm_database $server)
	[ "$create" == "true" -a -n "$server" -a "$debug" == "true" ] && make_seafile_docker $server debug
	[ "$create" == "true" -a -n "$server" ] && make_seafile_docker $server

	docker logs ${server} 2> /dev/null | grep -i "Successfully created seafile admin" | awk '{print $5" "$8}'
	exit
done
