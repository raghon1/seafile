#!/bin/bash

sslBaseDir="/etc/nginx/certs"
sslFullDir="${sslBaseDir}/${CCNET_IP}"
nginxConfFile="${CCNET_IP}.conf"
SEAFILE_IP=$(hostname -I | sed 's/ //')

[ "${autonginx}" = 'true' ] || exit 0

if [ ! -d /etc/nginx ]
then
        echo "Nginx directory not found! Have you mounted a volume for seafile to write nginx config ?"
        exit 1
fi


cd /etc/nginx/sites-available/
mkdir -p $sslFullDir
sed -e "s/#SEAFILE IP#/$SEAFILE_IP/g" \
        -e "s/#SEAHUB PORT#/$SEAHUB_PORT/g" \
        -e "s/#FILESERVER PORT#/$FILESERVER_PORT/g" \
        -e "s/#DOMAIN NAME#/$CCNET_IP/g" \
        -e 's|#SSL CERTIFICATE#|'$sslFullDir/$CCNET_IP'.crt|g' \
        -e 's|#SSL KEY#|'$sslFullDir/$CCNET_IP'.key|g' \
        -e 's|#MEDIA DIR#|'${STATIC_FILES_DIR}${CCNET_IP}'|g' \
        /root/seafile.conf > "${nginxConfFile}"

if [ ! -f "${sslFullDir}/$CCNET_IP.key" ] ; then
        export RANDFILE="${sslFullDir}"/.rnd #fix openssl error when generating certificates
        openssl genrsa -out "${sslFullDir}"/$CCNET_IP.key 2048
        openssl req -new -x509 -key "${sslFullDir}"/$CCNET_IP.key -out "${sslFullDir}"/$CCNET_IP.crt -days 1825 -subj "/C=FR/ST=France/L=Paris/O=Phosphore/CN=$CCNET_IP"
fi

[ ! -f "/etc/nginx/sites-enabled/${nginxConfFile}" ] && ln -s /etc/nginx/sites-available/"${nginxConfFile}" /etc/nginx/sites-enabled/"${nginxConfFile}"

# Tell nginx to restart
touch "/etc/nginx/sites-available/${nginxConfFile}.restart"
