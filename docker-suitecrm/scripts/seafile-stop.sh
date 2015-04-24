#!/bin/bash
#

# stop seafile and seahub

sf=/opt/seafile/seafile-server-latest

$sf/seahub.sh stop
$sf/seafile.sh stop

umount.s3ql $S3QL_MOUNT_POINT
