FROM		phusion/baseimage
MAINTAINER	Ragnar Hongset  <ragnar.hongset@raghon.no>

ENV S3QL_VERSION 2.12

# Add S3QL FS

# Dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
	add-apt-repository ppa:nikratio/s3ql

RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get update && apt-get install -y \
	software-properties-common \
	ca-certificates \
	s3ql

RUN apt-get clean
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# End S3QL FS


RUN ulimit -n 30000
# Config env variables

ENV S3QL_TYPE swift
ENV S3QL_STORAGE ams01.objectstorage.service.networklayer.com
ENV S3QL_BACKUP par01.objectstorage.service.networklayer.com
ENV S3QL_STORAGE_CONTAINER customer-fqdn
ENV S3QL_STORAGE_FS my_filesystem
ENV S3QL_COMPRESS zlib
ENV S3QL_MOUNT_POINT /opt/seafile
ENV S3QL_LOGIN myuser
ENV S3QL_PASSWD myobjectpassword
ENV S3QL_FSPASSWD password


RUN mkdir -p /etc/my_init.d

#Adding all our scripts
COPY scripts/create_s3ql_fs /etc/my_init.d/01_create_s3ql_fs
COPY scripts/rc.local_shutdown /etc/rc.local_shutdown
COPY scripts/my_init /sbin/my_init

#VOLUME /opt/seafile

# Baseimage init process
#ENTRYPOINT ["/sbin/my_init"]

