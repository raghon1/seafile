FROM phusion/baseimage
# Initially was based on work of Alessandro Viganò and Andreas Löffler
MAINTAINER ragnar.hongset@raghon.no

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y ca-certificates \
                       nginx \
                       python2.7-mysqldb python-setuptools python-simplejson python-imaging \
                       sqlite3 expect sendmail

# Add S3QL FS

RUN apt-get update -qq
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y wget

# Dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-setuptools python3-dev python3-pip pkg-config
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y sqlite3 libsqlite3-dev
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y python3-apsw python3.4-llfuse
RUN pip3 install defusedxml dugong requests pycrypto

# This module doesn't exist in ubuntu:14:04 default repo. Get it from bitbucket. 
RUN wget -nv -O /usr/src/s3ql-2.12.tar.bz2  https://bitbucket.org/nikratio/s3ql/downloads/s3ql-2.12.tar.bz2
RUN tar xvj -C /usr/src -f /usr/src/s3ql-2.12.tar.bz2
WORKDIR /usr/src/s3ql-2.12
RUN python3 setup.py build_ext --inplace
RUN python3 setup.py install

# End S3QL FS

ENV SERVER_NAME example
ENV SERVER_ADDR seafile.example.com
ENV ADMIN_EMAIL admin@example.com
ENV ADMIN_PASSWORD changeme!

RUN mkdir /opt/seafile
WORKDIR /opt/seafile
RUN curl -L -O https://bitbucket.org/haiwen/seafile/downloads/seafile-server_4.0.5_x86-64.tar.gz
RUN tar xzf seafile-server_*
RUN mkdir installed
RUN mv seafile-server_* installed


# Install DnsMasq service.
#RUN mkdir /etc/service/dnsmasq
#ADD service-dnsmasq.sh /etc/service/dnsmasq/run

# Install Seafile service.
RUN mkdir /etc/service/seafile
ADD service-seafile-run.sh /etc/service/seafile/run
ADD service-seafile-stop.sh /etc/service/seafile/stop

# Install Seahub service.
RUN mkdir /etc/service/seahub
ADD service-seahub-run.sh /etc/service/seahub/run
ADD service-seahub-stop.sh /etc/service/seahub/stop

ADD init.expect /tmp/init.expect

# Install Nginx.
RUN mkdir /etc/service/nginx
ADD service-nginx.sh /etc/service/nginx/run
ADD seafile-nginx.conf /etc/nginx/sites-available/seafile

# Expose needed ports.
EXPOSE 10001 12001 8000 8082

RUN mkdir /opt/seafile/logs

VOLUME /etc
VOLUME /opt/seafile
VOLUME /etc/service/seafile
VOLUME /etc/service/seahub

ADD bootstrap-data.sh /usr/local/sbin/bootstrap
ADD mount_init /sbin/mount_init
CMD /sbin/mount_init
EXPOSE 22
