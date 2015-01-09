#!/bin/sh

[ "${autostart}" = 'true' -a -x /opt/seafile/seafile-server-latest/seafile.sh ] || exit 0


if [ `grep -c "FILE_SERVER_ROOT" /opt/seafile/seahub_settings.py` -eq 0 ] && [ "${fcgi}" = 'true' ]; then
#Configure seafile for fastcgi with nginx over https
	echo "FILE_SERVER_ROOT = 'https://$CCNET_IP/seafhttp'" >> /opt/seafile/seahub_settings.py
	sed -i "s/^SERVICE_URL.*/SERVICE_URL = https:\/\/$CCNET_IP/g" /opt/seafile/ccnet/ccnet.conf
#Move seahub dir to Volume and make symbolic link
	mkdir -p ${STATIC_FILES_DIR}${CCNET_IP}
	cp -R /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media ${STATIC_FILES_DIR}${CCNET_IP}
	rm -R /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media
	ln -s ${STATIC_FILES_DIR}${CCNET_IP}/media /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media
#Move avatars to Volume and make symbolic link
	rm ${STATIC_FILES_DIR}${CCNET_IP}/media/avatars
	cp -R /opt/seafile/seahub-data/avatars ${STATIC_FILES_DIR}${CCNET_IP}/media/
	rm -R /opt/seafile/seahub-data/avatars
	ln -s ${STATIC_FILES_DIR}${CCNET_IP}/media/avatars /opt/seafile/seahub-data/avatars

	chown -R seafile:seafile ${STATIC_FILES_DIR}
	chown -h seafile:seafile /opt/seafile/seafile-server-${SEAFILE_VERSION}/seahub/media
	chown -h seafile:seafile /opt/seafile/seahub-data/avatars
fi

su -c "/opt/seafile/seafile-server-latest/seafile.sh start" seafile

# Script should not exit unless seafile died
while pgrep -f "seafile-controller" 2>&1 >/dev/null; do
	sleep 10;
done

exit 1
