#!/bin/sh

[ "${autostart}" = 'true' ] || exit 0

exec nginx -g "daemon off;"
