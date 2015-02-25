## s3ql docker image

Install the following::
	
	apt-get install git vim tmux curl mariadb-client
	apt-get install linux-image-extra-`uname -r`

Install docker from docker repo::

	curl -sSL https://get.docker.com/ubuntu/ | sudo sh

	mkdir GIT ; cd GIT
	git clone https://github.com/raghon1/seafile.git
	cd seafile
	docker build -t "raghon/s3ql" docker/s3ql
	docker build -t "raghon/seafile" docker/seafile
	docker build -t "raghon/nginx" docker-nginx
	docker build -t "raghon/mariadb" docker-mariadb

Opprett authinfo2::

	mkdir ~/s3ql
	cat << !!
	[swift]
	storage-url: swift://
	backend-login: bruker
	backend-password: passord
	fs-passphrase: backendpassord
	!!

Opprett .cloudwalker/secret

	mkdir ~/.cloudwalker
	cat << !! > secret
	EMAIL_USE_TLS = True
	EMAIL_HOST = 'smtp.sendgrid.net'
	EMAIL_PORT = '587'
	EMAIL_HOST_USER = 'EamilBruker'
	EMAIL_HOST_PASSWORD = 'PAssord'
	DEFAULT_FROM_EMAIL = 'noreply@cloudwalker.no'
	!!





