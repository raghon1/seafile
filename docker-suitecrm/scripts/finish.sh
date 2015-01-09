#!/bin/bash
#

# finished confifuring seafile

if [ "$autoconf" == "true" ] ; then
	killall -u seafile
	umount.s3ql $S3QL_MOUNT_POINT
	kill 1
fi
