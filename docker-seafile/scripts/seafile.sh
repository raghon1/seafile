#!/bin/sh

add2sed=""
[ "${autostart}" = 'true' -a -x /opt/seafile/seafile-server-latest/seafile.sh ] || exit 0

# Fix Database IP
sed -i 's/^host =.*/host = mysql-container/' /data/seafile-data/seafile.conf
sed -i 's/^HOST =.*/HOST = mysql-container/' /opt/seafile/ccnet/ccnet.conf
sed -i "s/'HOST':.*/'HOST': 'mysql-container',/" /opt/seafile/seahub_settings.py

sed -i '/^SERVICE_URL.*/{h;s/=.*/= \"https:\/\/'$CCNET_IP'\"/};${x;/^$/{s//SERVICE_URL = \"https:\/\/'$CCNET_IP'\/seafhttp\"/;H};x}' /opt/seafile/ccnet/ccnet.conf

cd /opt/seafile

sed -i '/^FILE_SERVER_ROOT/{h;s/=.*/= \"https:\/\/'$CCNET_IP'\/seafhttp\"/};${x;/^$/{s//FILE_SERVER_ROOT = \"https:\/\/'$CCNET_IP'\/seafhttp\"/;H};x}' seahub_settings.py

sed -i '/^LOGO_PATH/{h;s/=.*/= \"custom\/logo.png\"/};${x;/^$/{s//LOGO_PATH = \"custom\/logo.png\"/;H};x}' seahub_settings.py
sed -i '/^BRANDING_CSS/{h;s/=.*/= \"custom\/custom.css\"/};${x;/^$/{s//BRANDING_CSS = \"custom\/custom.css\"/;H};x}' seahub_settings.py
sed -i '/^DESKTOP_CUSTOM_LOGO/{h;s/=.*/= \"custom\/logo.png\"/};${x;/^$/{s//DESKTOP_CUSTOM_LOGO = \"custom\/logo.png\"/;H};x}' seahub_settings.py
sed -i '/^DESKTOP_CUSTOM_BRAND/{h;s/=.*/= \"Cloudwalker AS\"/};${x;/^$/{s//DESKTOP_CUSTOM_BRAND = \"Cloudwalker AS\"/;H};x}' seahub_settings.py
sed -i '/^TIME_ZONE/{h;s/=.*/= \"Europe\/Oslo\"/};${x;/^$/{s//TIME_ZONE = \"Europe\/Oslo\"/;H};x}' seahub_settings.py
sed -i '/^SITE_NAME/{h;s/=.*/= \"Cloudwalker Fildeling\"/};${x;/^$/{s//SITE_NAME = \"Cloudwalker Fildeling\"/;H};x}' seahub_settings.py
sed -i '/^SITE_TITLE/{h;s/=.*/= \"Cloudwalker Fildeling\"/};${x;/^$/{s//SITE_TITLE = \"Cloudwalker Fildeling\"/;H};x}' seahub_settings.py
sed -i '/^FILE_PREVIEW_MAX_SIZE/{h;s/=.*/= 30 * 1024 * 1024/};${x;/^$/{s//FILE_PREVIEW_MAX_SIZE = 30 * 1024 * 1024/;H};x}' seahub_settings.py
sed -i '/^SESSION_COOKIE_AGE/{h;s/=.*/= 60 * 60 * 24 * 7 * 2/};${x;/^$/{s//SESSION_COOKIE_AGE = 60 * 60 * 24 * 7 * 2/;H};x}' seahub_settings.py

sed -i '/^ENABLE_THUMBNAIL/{h;s/=.*/= True/};${x;/^$/{s//ENABLE_THUMBNAIL = True/;H};x}' seahub_settings.py
sed -i '/^THUMBNAIL_ROOT/{h;s/=.*/= \"\/opt\/seafile\/seahub-data\/thumbnail\/thumb\/\"/};${x;/^$/{s//THUMBNAIL_ROOT = \"\/opt\/seafile\/seahub-data\/thumbnail\/thumb\/\"/;H};x}' seahub_settings.py
	
if ! grep Norsk seafile-server-latest/seahub/seahub/settings.py >/dev/null ; then
	sed -i '/Nederlands/a\ \ \ \ \('\''nb_NO'\'', gettext_noop('\''Norsk'\'')),' seafile-server-latest/seahub/seahub/settings.py
fi

if ! egrep '^CACHES'  /opt/seafile/seahub_settings.py >/dev/null ; then
cat << MEM >> /opt/seafile/seahub_settings.py
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
    'LOCATION': '127.0.0.1:11211',
    }
}
MEM
fi


#Move seahub dir to Volume and make symbolic link
mkdir -p ${STATIC_FILES_DIR}${CCNET_IP}
if [ ! -d ${STATIC_FILES_DIR}${CCNET_IP}/media ] ; then
	mv /opt/seafile/seafile*-server-${SEAFILE_VERSION}/seahub/media ${STATIC_FILES_DIR}${CCNET_IP}
	cp -rp ${STATIC_FILES_DIR}${CCNET_IP}/media/assets/scripts/i18n/sv ${STATIC_FILES_DIR}${CCNET_IP}/media/assets/scripts/i18n/nb-no
fi
if [ ! -h /opt/seafile/seafile-server-latest/seahub/media ] ; then
	rm -rf /opt/seafile/seafile-server-latest/seahub/media
	ln -s ${STATIC_FILES_DIR}${CCNET_IP}/media /opt/seafile/seafile-server-latest/seahub/media
fi

# Workaround because django seems to lack support for nb-no (problem at the profile page)
sed -i 's/raise KeyError("Unknown language code %r." % lang_code)/return LANG_INFO["en"]/'  /opt/seafile/seafile-server-latest/seahub/thirdpart/Django-1.5.12-py2.6.egg/django/utils/translation/__init__.py


#Move avatars to nginx Volume and make symbolic link
if [ -d /opt/seafile/seahub-data/avatars ] ; then
	[ -h ${STATIC_FILES_DIR}${CCNET_IP}/media/avatars ] && rm -f ${STATIC_FILES_DIR}${CCNET_IP}/media/avatars
	[ ! -d ${STATIC_FILES_DIR}${CCNET_IP}/media/avatars ] && mv /opt/seafile/seahub-data/avatars ${STATIC_FILES_DIR}${CCNET_IP}/media/
	rm -rf /opt/seafile/seahub-data/avatars
	ln -s ${STATIC_FILES_DIR}${CCNET_IP}/media/avatars /opt/seafile/seahub-data/avatars
fi

if [ ! -d /opt/seafile/nginx/$CCNET_IP/media/custom ] ; then
	cp -rp /opt/seafile/seahub-data/custom /opt/seafile/nginx/$CCNET_IP/media/custom
fi
cp -rp /opt/seafile/seahub-data/custom/nb_NO/LC_MESSAGES/* /opt/seafile/seafile-server-latest/seahub/locale/nb_NO/LC_MESSAGES
cp -rp /opt/seafile/seahub-data/custom/nb_NO/LC_MESSAGES/* /opt/seafile/seafile-server-latest/seahub/locale/nb/LC_MESSAGES
cd /opt/seafile/seafile-server-latest/seahub/locale/nb_NO/LC_MESSAGES
msgfmt -o djangojs.mo djangojs.po
msgfmt -o django.mo django.po
cd -
cd /opt/seafile/seafile-server-latest/seahub/locale/nb/LC_MESSAGES
msgfmt -o djangojs.mo djangojs.po
msgfmt -o django.mo django.po
chown -R seafile:seafile /opt/seafile/seafile-server-latest/seahub/locale
cd -

chown -R seafile:seafile ${STATIC_FILES_DIR}
chown -h seafile:seafile /opt/seafile/seafile-*server-${SEAFILE_VERSION}/seahub/media
chown -h seafile:seafile /opt/seafile/seahub-data/avatars

su -c "/opt/seafile/seafile-server-latest/seafile.sh start" seafile

# Script should not exit unless seafile died
while pgrep -f "seafile-controller" 2>&1 >/dev/null; do
	sleep 10;
done

exit 0
