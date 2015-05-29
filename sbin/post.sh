#!/bin/bash
#

#docker_image="raghon1/seafilepro"
docker_image="raghon1/seafile"


# Global variables


restore_latest=false
restore_prog=false
restore_data=false
restore_sql=false

dir=$(cd $(dirname $0) ; pwd)


global() {
	# get api credentials from config file
	server=${1%%.*}
	domain=${1#*.}
	[ "$domain" == "$server" ] && domain=cloudwalker.biz
	fqdn=${server}.${domain}
	
	if [ $domain != "cloudwalker.biz" ] ; then
		case $server in
			*-data) server_name=${fqdn}-data;;
			*) server_name=${fqdn};;
		esac
	fi

	. /root/.cloudwalker/secret
	AUTOCONF=true
	CCNET_IP=${fqdn}

	EXISTING_DB=true
	MYSQL_IP=$(docker inspect  -f '{{ .NetworkSettings.IPAddress }}' mariadb)
	MYSQL_HOST=mysql-container
	MYSQL_ROOT_USER=root

	CCNET_DB_NAME=${fqdn}-ccnet
	SEAFILE_DB_NAME=${fqdn}-seafile
	SEAHUB_DB_NAME=${fqdn}-seahub
	SEAHUB_ADMIN_EMAIL=admin@${fqdn}
	SEAFILE_IP=${fqdn}.seafile.demo.docker
	
	DELETE_DATA_DIR=false

	S3QL_STORAGE=ams01.objectstorage.service.networklayer.com
	# finnes container fra før ? 
	if [ -z "$S3QL_STORAGE_CONTAINER" ] ; then
		$dir/addContainer.py -a CUSTOMER-$fqdn
		S3QL_STORAGE_CONTAINER=CUSTOMER-$fqdn
		S3QL_STORAGE_FS=${server}-seafile.s3ql
	else
		S3QL_STORAGE_FS=${fqdn}
	fi
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

	echo $server $server_name

	docker run $init \
	 --name "${server}"  \
	 ${extra_docker_opts} \
	 -v /root/.s3ql/authinfo2:/root/.s3ql/authinfo2:ro \
	 -v /root/.cloudwalker/secret:/root/.cloudwalker/secret:ro \
	 -h $server \
	 --cap-add mknod \
	 --cap-add sys_admin \
	 --device=/dev/fuse \
	 --link mariadb:$MYSQL_HOST \
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

	if [ $? -ne 0 ] ; then
		echo $?
	fi
}

mk_mysql_user() {

	exists=1
	while [ "$exists" -eq 1 ] ; do
		randuser=$(pwgen  --no-capitalize -n1 -B 15)
		exists=$(mysql -Ns -h$MYSQL_IP -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$randuser')")
	done
	MYSQL_USER=$randuser
	MYSQL_PASSWORD=$(pwgen  --no-capitalize -n1 -B 25)
	mysql -P3306 -h $MYSQL_IP -e "create user '$MYSQL_USER'@'%' identified by '$MYSQL_PASSWORD';"
}

rm_database() {
	server=$1
	dbusers=$(mysql -Ns -h $MYSQL_IP -Dmysql -e "select user from db where db='${fqdn}-ccnet';")
	for dbuser in $dbusers ; do
		mysql -h$MYSQL_IP -Dmysql -e "drop user '${dbuser}'@'%'"
		mysql -h$MYSQL_IP -Dmysql -e "drop user '${dbuser}'@'localhost'"
	done
	mysql -Dmysql -h$MYSQL_IP -e "drop database \`${fqdn}-seafile\`"
	mysql -Dmysql -h$MYSQL_IP -e "drop database \`${fqdn}-seahub\`"
	mysql -Dmysql -h$MYSQL_IP -e "drop database \`${fqdn}-ccnet\`"
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
	
	mysql -P3306 -h $MYSQL_IP -e "create database \`${fqdn}-ccnet\`;create database \`${fqdn}-seafile\`; create database \`${fqdn}-seahub\`;"
	[ $? -ne 0 ] && exit 1

	mysql -P3306 -h $MYSQL_IP -e "GRANT ALL PRIVILEGES ON \`${fqdn}-ccnet\`.* to \`$MYSQL_USER\`@\`%\`;"
	mysql -P3306 -h $MYSQL_IP -e "GRANT ALL PRIVILEGES ON \`${fqdn}-seafile\`.* to \`$MYSQL_USER\`@\`%\`;"
	mysql -P3306 -h $MYSQL_IP -e "GRANT ALL PRIVILEGES ON \`${fqdn}-seahub\`.* to \`$MYSQL_USER\`@\`%\`;"
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

	EMAIL_USE_TLS=True
	EMAIL_HOST='smtp.sendgrid.net'
	EMAIL_PORT='587'
	EMAIL_HOST_USER='emailadm'
	EMAIL_HOST_PASSWORD='PAssord'
	DEFAULT_FROM_EMAIL='noreply@cloudwalker.no'

	S3QL_STORAGE=ams01.objectstorage.service.networklayer.com
	S3QL_API_USER=brukernavn:name
	S3QL_API_PASSWD=langtpassord
	S3QL_FSPASSWD=optionalpassword
	S3QL_MOUNT_POINT=/data
	S3QL_TYPE=swift


	docker run -h nginx -d --restart always --name nginx -p 443:443 -p 80:80 -v /opt/seafile/nginx raghon1/nginx:latest
	MYSQL_ROOT_PASSWORD=$(docker run --name mariadb -it --restart always raghon1/mariadb  | nawk -F= '/^MARIADB_PASS/ {print $2}')
	docker start mariadb


	echo -n EMAIL_USE_TLS = True/False : 
	read ans_EMAIL_USE_TLS ; [ -n "$ans_EMAIL_USE_TLS" ] && EMAIL_USE_TLS=$ans_EMAIL_USE_TLS

        echo -n EMAIL_HOST = $EMAIL_HOST :
	read ans_EMAIL_HOST ; [ -n "$ans_EMAIL_HOST" ] && EMAIL_HOST=$ans_EMAIL_HOST
        echo -n EMAIL_PORT = $EMAIL_PORT :
	read ans_EMAIL_PORT ; [ -n "$ans_EMAIL_PORT" ] && EMAIL_PORT=$ans_EMAIL_PORT
        echo -n EMAIL_HOST_USER = $EMAIL_HOST_USER :
	read ans_EMAIL_HOST_USER ; [ -n "$ans_EMAIL_HOST_USER" ] && EMAIL_HOST_USER=$ans_EMAIL_HOST_USER
        echo -n EMAIL_HOST_PASSWORD = $EMAIL_HOST_PASSWORD :
	read ans_EMAIL_HOST_PASSWORD ; [ -n "$ans_EMAIL_HOST_PASSWORD" ] && EMAIL_HOST_PASSWORD=$ans_EMAIL_HOST_PASSWORD
        echo -n DEFAULT_FROM_EMAIL = $DEFAULT_FROM_EMAIL :
	read ans_DEFAULT_FROM_EMAIL ; [ -n "$ans_DEFAULT_FROM_EMAIL" ] && DEFAULT_FROM_EMAIL=$ans_DEFAULT_FROM_EMAIL

        echo -n S3QL_STORAGE = $S3QL_STORAGE :
	read ans_S3QL_STORAGE ; [ -n "$ans_S3QL_STORAGE" ] && S3QL_STORAGE=$ans_S3QL_STORAGE
        echo -n S3QL_API_USER = $S3QL_API_USER :
	read ans_S3QL_API_USER ; [ -n "$ans_S3QL_API_USER" ] && S3QL_API_USER=$ans_S3QL_API_USER
        echo -n S3QL_API_PASSWD = $S3QL_API_PASSWD :
	read ans_S3QL_API_PASSWD ; [ -n "$ans_S3QL_API_PASSWD" ] && S3QL_API_PASSWD=$ans_S3QL_API_PASSWD
        echo -n S3QL_FSPASSWD = $S3QL_FSPASSWD :
	read ans_S3QL_FSPASSWD ; [ -n "$ans_S3QL_FSPASSWD" ] && S3QL_FSPASSWD=$ans_S3QL_FSPASSWD
        echo -n S3QL_MOUNT_POINT = $S3QL_MOUNT_POINT :
	read ans_S3QL_MOUNT_POINT ; [ -n "$ans_S3QL_MOUNT_POINT" ] && S3QL_MOUNT_POINT=$ans_S3QL_MOUNT_POINT
        echo -n S3QL_TYPE = $S3QL_TYPE :
	read ans_S3QL_TYPE ; [ -n "$ans_S3QL_TYPE" ] && S3QL_TYPE=$ans_S3QL_TYPE


	umask 0377
	cat << MQSQL > /root/.my.cnf
[client]
user=root
password=$MYSQL_ROOT_PASSWORD
MQSQL

mkdir -p /root/.cloudwalker /root/.s3ql
	cat << CW >/root/.cloudwalker/secret
EMAIL_USE_TLS="$EMAIL_USE_TLS"
EMAIL_HOST="$EMAIL_HOST"
EMAIL_PORT="$EMAIL_PORT"
EMAIL_HOST_USER="$EMAIL_HOST_USER"
EMAIL_HOST_PASSWORD="$EMAIL_HOST_PASSWORD"
DEFAULT_FROM_EMAIL="$DEFAULT_FROM_EMAIL"
S3QL_STORAGE="$S3QL_STORAGE"
S3QL_API_USER="$S3QL_API_USER"
S3QL_API_PASSWD="$S3QL_API_PASSWD"
S3QL_FSPASSWD="$S3QL_FSPASSWD"
S3QL_MOUNT_POINT="$S3QL_MOUNT_POINT"
S3QL_TYPE="$S3QL_TYPE"
CW

	cat << S3QL > /root/.s3ql/authinfo2
[swift]
storage-url: $S3QL_TYPE://
backend-login: $S3QL_API_USER
backend-password: $S3QL_API_PASSWD
fs-passphrase: $S3QL_FSPASSWD
S3QL

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
modify="false"
fsck="false"
upgrade="false"
list_docers="false"


OPTIND=1

while getopts "BCD:DFI:PRSTUbcdflmo:rqt" option; do
    case $option in
	B) backup_disaster="true";;
	C) console="true" ;;
	D) skydns="true" ; environment="$OPTARG" ;;
	F) s3ql_clear="true" ;;
        I) docker_image="$OPTARG";;
	P) mk_mysql_cred;;
	Q) restore="true";;
	R) rebuildFromBckp="true";;
        S) init="--rm -it" ; shell="bash -o vi" ;;
	U) upgrade="true";;
	b) backup="true";;
        c) create="true"  ;;
        d) init="--rm -it"  ;;
        #f) init="--rm -it" ; shell="/bin/sh -c " ; extra="/etc/my_init.d/01_create_s3ql_fs && umount.s3ql --debug /data" ;;
        f) fsck=true;;
	l) list_docers=true;;
	m) modify="true";;
	o) echo $OPTARG;
	   case "$OPTARG" in
		sql) restore_sql="true";;
		prog) restore_prog="true";;
		data) restore_data="true";;
		latest) restore_latest="true";;
		object=*) S3QL_STORAGE_CONTAINER=${OPTARG##*=};;
	   esac
   	   ;;
        r) rm="true"  ;;
	t) timemachine=true
	   extra_docker_opts="-p 548";;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

if [ "$list_docers" == "true" ] ; then
	docker ps --no-trunc=false | awk 'BEGIN {printf "\t%-20s %s\n", "NAME","IMAGE"} !/NAMES|ID/ {printf "\t%-20s %s\n", $NF,$2}'
	exit 0
fi

[ "$skydns" == "true" ] && (init_skydns $environment )

[ -z "$1" ] && exit 0


for server in $* ; do
	global $server
	if [ "$console" == "true" ] ; then  
		exec docker exec -it $server_name bash -o vi
	fi


	if [ "$fsck" == "true" ] ; then  
        	init="--rm -it"
		shell="/bin/sh -c "
		extra="/etc/my_init.d/01_create_s3ql_fs && umount.s3ql --debug /data"
		[ "$create" == "true" -a -n "$server" -a "$debug" == "true" ] && make_s3ql_docker $server debug
		[ "$create" == "true" -a -n "$server" ] && make_s3ql_docker $server
		exit 0
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
		docker_image=raghon1/s3ql
		[ "$create" == "true" -a -n "$server" ] && make_s3ql_docker $server
		exit 0
	fi
	if [ "$rebuildFromBckp" == "true" ] ; then
		#	docker_image=raghon1/s3ql
		S3QL_STORAGE_FS=$fqdn
		init="-it"
		if [ "$debug" == "true" ] ; then 
			init="--rm -it" 
		fi

		shell="/bin/sh -c " 
		extra="/etc/my_init.d/02_restore.sh"

		servername=$server
		[ "$create" == "true" -a -n "$server" ] && make_seafile_docker $server-data
		unset extra
		unset shell
		AUTOCONF="false"

		restore_latest=false
		extra_docker_opts="$extra_docker_opts --restart=always --volumes-from $servername-data"
		init="-d" 
		make_seafile_docker $servername
		exit 0
	fi
	

	[ "$rm" == "true" -a -n "$server" ] && (rm_docker $server_name ; rm_database $server_name)
	[ "$create" == "true" -a -n "$server" -a "$debug" == "true" ] && make_seafile_docker $server debug
	if [ "$create" == "true" -a -n "$server" ] ; then
		init="-it"
		#servername=$server
		make_seafile_docker $server_name-data
		extra_docker_opts="$extra_docker_opts --restart=always --volumes-from ${server_name}-data"
		init="-d"
		AUTOCONF="false"
		DELETE_DATA_DIR=false
		make_seafile_docker $server_name
	fi
	if [ "$modify" == "true"  -o  "$upgrade" == "true" ] ; then
		# Get environment variables from running docker

		mkdir -p /data/$server
		docker exec -i $server env | egrep 'CCNET|MYSQL|SEA|restore|S3QL|fcgi' > /data/$server/env
		. /data/$server/env

		docker stop $server
		docker rename $server $server-old
		servername=$server
		extra_docker_opts="$extra_docker_opts --restart=always --volumes-from $servername-data"
		init="-d"
		AUTOCONF="false"
		DELETE_DATA_DIR=false
		make_seafile_docker $servername
	fi
	
	docker logs ${server} 2> /dev/null | grep -i "Successfully created seafile admin" | awk '{print $5" "$8}'
	exit
done
