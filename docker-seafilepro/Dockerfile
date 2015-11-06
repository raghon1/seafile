FROM		raghon1/s3ql
MAINTAINER 	Ragnar Hongset <raghon@raghon.no>
WORKDIR /opt/seafile
ENV SEAFILE_VERSION 4.4.3

# Based on the fine work of Guilhem Berna  <guilhem.berna@gmail.com>

COPY src/seafile-pro-server-latest.tar.gz /opt/seafile/seafile-pro-server-latest.tar.gz
RUN apt-get update && apt-get install -y \
	ca-certificates \
	python2.7 \
	python-setuptools \
	python-simplejson \
	python-imaging \
	sqlite3 \
	rsync \
	pwgen \
	python-memcache \
	gettext \
	mariadb-client \
	python-mysqldb \
	openjdk-7-jre \
	poppler-utils \
	libpython2.7 \
	python-pip \
	libreoffice \
	libreoffice-script-provider-python && \ 
	ulimit -n 30000 && \
	tar zxf seafile-pro-server-latest.tar.gz && \
	rm -f seafile-pro-server-latest.tar.gz && \
	mkdir -p logs && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
	useradd -d /opt/seafile -m seafile

# Config env variables
ENV 	autostart=true \
	autoconf=true \
	autonginx=false \
	fcgi=false \
	CCNET_PORT=10001 \
	CCNET_NAME=my-seafile \
	SEAFILE_PORT=12001 \
	FILESERVER_PORT=8082 \
	EXISTING_DB=false \
	MYSQL_HOST=mysql-container \
	MYSQL_PORT=3306 \
	MYSQL_USER=seafileuser \
	SEAHUB_ADMIN_EMAIL=seaadmin@sea.com \
	CCNET_DB_NAME=ccnet-db \
	SEAFILE_DB_NAME=seafile-db \
	SEAHUB_DB_NAME=seahub-db \
	SEAHUB_PORT=8000 \
	SEAFILE_DATA=/data/seafile-data \
	STATIC_FILES_DIR=/opt/seafile/nginx/ \
	#=Email congiguration \
	EMAIL_AUTOCONF=True \
	EMAIL_USE_TLS=True \
	EMAIL_HOST='smtp.sendgrid.net' \
	EMAIL_PORT='587' \
	EMAIL_HOST_USER='mail-admin' \
	EMAIL_HOST_PASSWORD='password' \
	DEFAULT_FROM_EMAIL='noreply@foo.com' \
	#=Control seafile restore \
	restore_latest=false \
	restore_prog=true \
	restore_data=true \
	restore_sql=true

#removing default seafile installation scripts to replace them with our own
#RUN rm seafile-pro-server-${SEAFILE_VERSION}/check_init_admin.py
#RUN rm seafile-pro-server-${SEAFILE_VERSION}/setup-seafile-mysql.py

RUN mkdir -p /etc/my_init.d

#Adding all our scripts
COPY scripts/02_permissions /etc/my_init.d/02_permissions.sh
COPY scripts/setup-seafile-mysql.sh /etc/my_init.d/03_setup-seafile-mysql.sh
COPY scripts/fix_email.sh /etc/my_init.d/04_fix_email.sh
COPY scripts/create_nginx_config.sh /etc/my_init.d/90_create_nginx_config.sh
COPY scripts/finish.sh /etc/my_init.d/99_finish.sh
RUN mkdir -p /usr/local/bin
COPY scripts/s3ql_backup.sh /usr/local/bin/s3ql_backup.sh
COPY scripts/restore.sh /etc/my_init.d/02_restore.sh

#COPY scripts/check_init_admin.py /opt/seafile/seafile-pro-server-${SEAFILE_VERSION}/check_init_admin.py
#COPY scripts/setup-seafile-mysql.py /opt/seafile/seafile-pro-server-${SEAFILE_VERSION}/setup-seafile-mysql.py

COPY nginx.conf /root/seafile.conf
RUN chown -R seafile:seafile /opt/seafile

# Seafile daemons
RUN mkdir /etc/service/seafile /etc/service/seahub
COPY scripts/seafile.sh /etc/service/seafile/run
COPY scripts/seahub.sh /etc/service/seahub/run
COPY scripts/seafile-stop.sh /etc/service/seafile/finish
COPY scripts/seahub-stop.sh /etc/service/seahub/finish

COPY scripts/seafile.crontab /root/seafile.crontab
COPY scripts/seafile_debian.sh /opt/seafile/

RUN crontab /root/seafile.crontab

RUN mkdir -p /opt/seafile/seahub-data/custom
COPY scripts/custom /opt/seafile/seahub-data/custom
RUN chown -R seafile:seafile /opt/seafile/seahub-data

VOLUME /root/.s3ql /opt/seafile
EXPOSE 8000 8082

# Baseimage init process
#ENTRYPOINT ["/sbin/my_init"]
