#!/bin/bash

sslBaseDir="/etc/nginx/certs"
sslFullDir="${sslBaseDir}/${CCNET_IP}"
nginxConfFile="${CCNET_IP}.conf"

[ "${autonginx}" = 'true' ] || exit 0

if [ ! -d /etc/nginx ]
then
	echo "Nginx directory not found! Have you mounted a volume for seafile to write nginx config ?"
	exit 1
fi
if [ -f /etc/nginx/sites-available/"${nginxConfFile}" ]
then
	echo "Nginx configuration Found, no need to create it"
else
	cd /etc/nginx/sites-available/
	echo "No Nginx configuration found, Creating it from the template"
	mv /root/seafile.conf ./"${nginxConfFile}"
	mkdir -p $sslFullDir
	export RANDFILE="${sslFullDir}"/.rnd #fix openssl error when generating certificates
	openssl genrsa -out "${sslFullDir}"/$CCNET_IP.key 2048
	openssl req -new -x509 -key "${sslFullDir}"/$CCNET_IP.key -out "${sslFullDir}"/$CCNET_IP.crt -days 1825 -subj "/C=FR/ST=France/L=Paris/O=Phosphore/CN=$CCNET_IP" 
	sed -i "s/#SEAFILE IP#/$SEAFILE_IP/g" "${nginxConfFile}"
	sed -i "s/#SEAHUB PORT#/$SEAHUB_PORT/g" "${nginxConfFile}"
	sed -i "s/#FILESERVER PORT#/$FILESERVER_PORT/g" "${nginxConfFile}"
	sed -i "s/#DOMAIN NAME#/$CCNET_IP/g" "${nginxConfFile}"
	sed -i 's|#SSL CERTIFICATE#|'$sslFullDir/$CCNET_IP'.crt|g' "${nginxConfFile}"
	sed -i 's|#SSL KEY#|'$sslFullDir/$CCNET_IP'.key|g' "${nginxConfFile}"
	sed -i 's|#MEDIA DIR#|'${STATIC_FILES_DIR}${CCNET_IP}'|g' "${nginxConfFile}"
	ln -s /etc/nginx/sites-available/"${nginxConfFile}" /etc/nginx/sites-enabled/"${nginxConfFile}"
fi

