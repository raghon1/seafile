FROM		raghon1/s3ql
MAINTAINER 	Ragnar Hongset <raghon@raghon.no>
WORKDIR /opt/seafile
ENV SEAFILE_VERSION 4.4.1

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
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


#RUN useradd -d /opt/seafile -m seafile
#https://bintray.com/artifact/download/seafile-org/seafile/seafile-server_4.3.2_x86-64.tar.gz

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
	restore_sql=true \

