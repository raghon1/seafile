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

	EXISTING_DB=true
	MYSQL_HOST=$(docker inspect  -f '{{ .NetworkSettings.IPAddress }}' mariadb)
	MYSQL_ROOT_USER=root

	CCNET_DB_NAME=${fqdn}-ccnet
	SEAFILE_DB_NAME=${fqdn}-seafile
	SEAHUB_DB_NAME=${fqdn}-seahub
	SEAHUB_ADMIN_EMAIL=admin@${fqdn}
	SEAFILE_IP=${fqdn}.seafile.demo.docker
	
	DELETE_DATA_DIR=false

	S3QL_STORAGE=ams01.objectstorage.service.networklayer.com
	S3QL_STORAGE_CONTAINER=fs
	S3QL_STORAGE_FS=${fqdn}
	S3QL_COMPRESS=zlib
	S3QL_FSPASSWD=optionalpassword
	S3QL_MOUNT_POINT=/data
	S3QL_TYPE=swift

	EMAIL_USE_TLS=$EMAIL_USE_TLS
	EMAIL_HOST=$EMAIL_HOST
	EMAIL_PORT=$EMAIL_PORT
	EMAIL_HOST_USER=$EMAIL_HOST_USER
	EMAIL_HOST_PASSWORD=$EMAIL_HOST_PASSWORD
	DEFAULT_FROM_EMAIL=$DEFAULT_FROM_EMAIL

	restore_latest=false
	restore_prog=true
	restore_data=false
	restore_sql=false
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
	 -e "MYSQL_USER=$MYSQL_USER" \
	 -e "MYSQL_PASSWORD=$MYSQL_PASSWORD" \
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

	if [ "$AUTOCONF" == "true" ] ; then
		mk_mysql_user
		create_dbtables
	fi
	echo $AUTOCONF

	docker run $init \
	 --name "${server}"  \
	 ${extra_docker_opts} \
	 -v /root/.s3ql/authinfo2:/root/.s3ql/authinfo2:ro \
	 -v /root/.cloudwalker/secret:/root/.cloudwalker/secret:ro \
	 -h $server \
	 --cap-add mknod \
	 --cap-add sys_admin \
	 --device=/dev/fuse \
	 --link mariadb:mysql-container \
	 --volumes-from nginx \
	 -e fcgi=true \
	 -e autonginx=true \
	 -e autoconf=$AUTOCONF \
	 -e delete_data_dir=$DELETE_DATA_DIR \
	 -e "CCNET_IP=$CCNET_IP"\
	 -e "EXISTING_DB=$EXISTING_DB" \
	 -e "MYSQL_HOST=$MYSQL_HOST" \
	 -e "MYSQL_USER=$MYSQL_USER" \
	 -e "MYSQL_PASSWORD=$MYSQL_PASSWORD" \
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
	 -e restore_latest=$restore_latest \
	 -e restore_prog=$restore_prog \
	 -e restore_data=$restore_data \
	 -e restore_sql=$restore_sql \
	$docker_image $shell $([ -n "$extra" ] && echo \"$extra\")
}

mk_mysql_user() {

	exists=1
	while [ "$exists" -eq 1 ] ; do
		randuser=$(pwgen  --no-capitalize -n1 -B 15)
		exists=$(mysql -Ns -h$MYSQL_HOST -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$randuser')")
	done
	MYSQL_USER=$randuser
	MYSQL_PASSWORD=$(pwgen  --no-capitalize -n1 -B 25)
	mysql -P3306 -h $MYSQL_HOST -e "create user '$MYSQL_USER'@'%' identified by '$MYSQL_PASSWORD';"
}

rm_database() {
	server=$1
	dbusers=$(mysql -Ns -h $MYSQL_HOST -Dmysql -e "select user from db where db='${fqdn}-ccnet';")
	for dbuser in $dbusers ; do
		mysql -h$MYSQL_HOST -Dmysql -e "drop user '${dbuser}'@'%'"
		mysql -h$MYSQL_HOST -Dmysql -e "drop user '${dbuser}'@'localhost'"
	done
	mysql -Dmysql -h$MYSQL_HOST -e "drop database \`${fqdn}-seafile\`"
	mysql -Dmysql -h$MYSQL_HOST -e "drop database \`${fqdn}-seahub\`"
	mysql -Dmysql -h$MYSQL_HOST -e "drop database \`${fqdn}-ccnet\`"
}

mk_mysql_cred() {
	DBPASSWORD=$(docker logs mariadb 2>/dev/null | awk -F= '$1=="MARIADB_PASS" {print $2}')
	umask 0377
	cat << !! > $HOME/.my.cnf
[client]
user="root"
pass="$DBPASSWORD"
!!
}

create_dbtables() {
	
	mysql -P3306 -h $MYSQL_HOST -e "create database \`${fqdn}-ccnet\`;create database \`${fqdn}-seafile\`; create database \`${fqdn}-seahub\`;"

	mysql -P3306 -h $MYSQL_HOST -e "GRANT ALL PRIVILEGES ON \`${fqdn}-ccnet\`.* to \`$MYSQL_USER\`@\`%\`;"
	mysql -P3306 -h $MYSQL_HOST -e "GRANT ALL PRIVILEGES ON \`${fqdn}-seafile\`.* to \`$MYSQL_USER\`@\`%\`;"
	mysql -P3306 -h $MYSQL_HOST -e "GRANT ALL PRIVILEGES ON \`${fqdn}-seahub\`.* to \`$MYSQL_USER\`@\`%\`;"
}



rm_docker() {
	server=$1
	docker stop $server $server-data
	docker rm $server $server-data
}

backup() {
	if [ "$backup" == "true" ] ; then
		docker exec -i $server "/etc/my_init.d/03_backup.sh"
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
	docker run -h skydns -d -p 172.17.42.1:53:53/udp --name skydns crosbymichael/skydns -nameserver 10.0.80.11:53 -domain docker
	docker pull crosbymichael/skydock
	docker run -h skydock -d -v /var/run/docker.sock:/docker.sock --name skydock crosbymichael/skydock -ttl 30 -environment $environment -s /docker.sock -domain docker -name skydns
	docker run -h nginx -d --name nginx -p 443:443 -p 80:80 -v /opt/seafile/nginx raghon/nginx:latest
	docker run -h mariadb -d --name mariadb guilhem30/mariadb:latest
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

while getopts "BCD:CDI:PRFSbcdfrq" option; do
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
	P) mk_mysql_cred;;
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
		restore_latest=true
		restore_data=false
		
		orig_server=$server
		[ "$create" == "true" -a -n "$server" ] && make_s3ql_docker $server-data
		unset extra
		unset shell
		AUTOCONF="false"

		restore_latest=false
	 	extra_docker_opts="--volumes-from $orig_server-data"
		init="-d" 
		make_seafile_docker $orig_server
		exit 0
	fi
	

	[ "$rm" == "true" -a -n "$server" ] && (rm_docker $server ; rm_database $server)
	[ "$create" == "true" -a -n "$server" -a "$debug" == "true" ] && make_seafile_docker $server debug
	if [ "$create" == "true" -a -n "$server" ] ; then
		init="-it"
		servername=$server
		DELETE_DATA_DIR=true
		make_seafile_docker $servername-data
		extra_docker_opts="--volumes-from $servername-data"
		init="-d"
		AUTOCONF="false"
		DELETE_DATA_DIR=false
		make_seafile_docker $servername
	fi
	
	docker logs ${server} 2> /dev/null | grep -i "Successfully created seafile admin" | awk '{print $5" "$8}'
	exit
done
