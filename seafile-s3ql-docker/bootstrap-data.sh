#!/bin/sh

# Note: Don't set "-u" here; we might check for unset environment variables!
set -e

# Create Filesystem on objectStorage

if [ "$INITFS" == "true" ] ; then
	mkfs.s3ql --plain -L "$CUSTOMER" --max-obj-size 10240 swift://$STORAGE/fs/$CUSTOMER/
fi
mkdir -p /opt/seafile/seafile-data
mount.s3ql --log /root/.s3ql/mount.log --compress zlib swift://$STORAGE/fs/$CUSTOMER/ /opt/seafile/seafile-data

# Generate the TLS certificate for our Seafile server instance.
SEAFILE_CERT_PATH=/etc/nginx/certs
mkdir -p "$SEAFILE_CERT_PATH"
openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
    -subj "/C=US/ST=World/L=World/O=seafile/CN=$SEAFILE_DOMAIN_NAME" \
    -keyout "$SEAFILE_CERT_PATH/seafile.key" \
    -out "$SEAFILE_CERT_PATH/seafile.crt"
chmod 600 "$SEAFILE_CERT_PATH/seafile.key"
chmod 600 "$SEAFILE_CERT_PATH/seafile.crt"

# Use some sensible defaults.
if [ -z "$SEAFILE_DOMAIN_NAME" ]; then
    SEAFILE_DOMAIN_NAME=127.0.0.1
fi
if [ -z "$SEAFILE_DOMAIN_PORT" ]; then
    SEAFILE_DOMAIN_PORT=8080
fi

# Enable Seafile in the Nginx configuration. Nginx then will serve Seafile
# over HTTPS (TLS).
ln -f -s /etc/nginx/sites-available/seafile /etc/nginx/sites-enabled/seafile
rm -f /etc/nginx/sites-enabled/default
sed -i -e "s/%SEAFILE_DOMAIN_NAME%/"$SEAFILE_DOMAIN_NAME"/g" /etc/nginx/sites-available/seafile
sed -i -e "s/%SEAFILE_DOMAIN_PORT%/"$SEAFILE_DOMAIN_PORT"/g" /etc/nginx/sites-available/seafile

# Configure Nginx so that is doesn't show its version number in the HTTP headers.
sed -i -e "s/.*server_tokens.*/server_tokens off;/g" /etc/nginx/nginx.conf

# Patch Seahub's configuration to not run in daemonized mode. This is necessary
# for whatever reason to not letting it abort.
## @todo Fix this!
sed -i -e "s/.*daemon.*=.*/daemon = False/g" \
    /opt/seafile/seafile-server-*/runtime/seahub.conf

# Execute Seafile's configuration script for setting up the database.
#cd /opt/seafile/seafile-server-*
#./setup-seafile-mysql.sh
expect -f /tmp/init.expect /opt/seafile/seafile-server-*/setup-seafile-mysql.sh /opt/seafile/seafile-data/fs02

cd /opt/seafile/seafile-server-*
./seahub.sh stop
./seafile.sh stop

# After configuring Seafile, patch Seafile's CCNet configuration to point to our HTTPS site.
sed -i -e "s/.*SERVICE_URL.*=.*/SERVICE_URL = https:\/\/$SEAFILE_DOMAIN_NAME:$SEAFILE_DOMAIN_PORT/g" \
    /opt/seafile/ccnet/ccnet.conf

# Also patch Seahub's configuration to use HTTPS for all downloads + uploads.
#echo "FILE_SERVER_ROOT = 'https://$SEAFILE_DOMAIN_NAME:$SEAFILE_DOMAIN_PORT/seafhttp'" \
#    >> /opt/seafile/seahub_settings.py
echo "EMAIL_USE_TLS = False" >> /opt/seafile/seahub_settings.py
echo "EMAIL_HOST = '127.0.0.1'" >> /opt/seafile/seahub_settings.py
echo "EMAIL_PORT = '25'" >> /opt/seafile/seahub_settings.py
echo "DEFAULT_FROM_EMAIL = 'post@cloudwalker.no'" >> /opt/seafile/seahub_settings.py

# Manually run Seafile to trigger the first-run configuration wizard.
./seafile.sh start
./seahub.sh start-fastcgi

# Shut down every again.
cd /opt/seafile/seafile-server-*
./seahub.sh stop
./seafile.sh stop

umount.s3ql /opt/seafile/seafile-data
