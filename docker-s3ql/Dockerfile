FROM		phusion/baseimage
MAINTAINER	Ragnar Hongset  <ragnar.hongset@raghon.no>

ENV S3QL_VERSION 2.13

# Add S3QL FS

# Dependencies
RUN export DEBIAN_FRONTEND=noninteractive && \
	add-apt-repository ppa:nikratio/s3ql
RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update && \
	apt-get update && apt-get install -y \
	software-properties-common \
	s3ql

#RUN pip3 install defusedxml dugong requests pycrypto

# This module doesn't exist in ubuntu:14:04 default repo. Get it from bitbucket.
#RUN curl -L -o /usr/src/s3ql-${S3QL_VERSION}.tar.bz2 https://bitbucket.org/nikratio/s3ql/downloads/s3ql-${S3QL_VERSION}.tar.bz2
#RUN tar xvj -C /usr/src -f /usr/src/s3ql-${S3QL_VERSION}.tar.bz2
#WORKDIR /usr/src/s3ql-${S3QL_VERSION}
#RUN python3 setup.py build_ext --inplace
#RUN python3 setup.py install
#RUN rm -rf /usr/src/s3ql-${S3QL_VERSION} /usr/src/s3ql-${S3QL_VERSION}.tar.bz2
RUN apt-get remove -y python-setuptools python3-setuptools python3-dev python3-pip pkg-config gcc

# End S3QL FS


RUN ulimit -n 30000
# Config env variables

ENV S3QL_TYPE swift
ENV S3QL_STORAGE sng01.objectstorage.service.networklayer.com
ENV S3QL_STORAGE_CONTAINER fs
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

