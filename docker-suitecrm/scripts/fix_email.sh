#!/bin/bash
#

# Get updated email credentials from global 
# secret file

[ -f /root/.cloudwalker/secret ] && . /root/.cloudwalker/secret

if grep EMAIL_HOST /opt/seafile/seahub_settings.py >/dev/null ; then
        sed -i \
                -e "s/^EMAIL_USE_TLS.*/EMAIL_USE_TLS = '$EMAIL_USE_TLS'/" \
                -e "s/^EMAIL_HOST .*/EMAIL_HOST = '$EMAIL_HOST'/" \
                -e "s/^EMAIL_PORT .*/EMAIL_PORT = '$EMAIL_PORT'/" \
                -e "s/^EMAIL_HOST_USER .*/EMAIL_HOST_USER = '$EMAIL_HOST_USER'/" \
                -e "s/^EMAIL_HOST_PASSWORD .*/EMAIL_HOST_PASSWORD = '$EMAIL_HOST_PASSWORD'/" \
                -e "s/^DEFAULT_FROM_EMAIL .*/DEFAULT_FROM_EMAIL = '$DEFAULT_FROM_EMAIL'/" \
        /opt/seafile/seahub_settings.py
else
        cat << !! >> /opt/seafile/seahub_settings.py
EMAIL_USE_TLS = '$EMAIL_USE_TLS'
EMAIL_HOST = '$EMAIL_HOST'
EMAIL_PORT = '$EMAIL_PORT'
EMAIL_HOST_USER = '$EMAIL_HOST_USER'
EMAIL_HOST_PASSWORD = '$EMAIL_HOST_PASSWORD'
DEFAULT_FROM_EMAIL = '$DEFAULT_FROM_EMAIL'
!!
fi
