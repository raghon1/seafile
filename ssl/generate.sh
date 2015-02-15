#!/bin/bash
#
# Lag priv cert, og generer signing request

dir=$(cd $(dirname $0) ; pwd)
dir_to=/var/tmp/ssl-generate
cd $dir

lag_req() {
	server=$1
	mkdir -p $dir_to/kunder/$server
	openssl req -config $dir/req.cfg -newkey rsa:2048 -nodes -keyout $dir_to/kunder/$server/$server.key -out $dir_to/kunder/$server/$server.csr
	chmod 600 $dir_to/kunder/$server/*
}

show_req() {
	server=$1
	echo "trykk enter for å vise signing request. Denne kopieres inn i control panelet til startssl.com eller andre ssl tilbydere."
	read enter
	cat $dir_to/kunder/$server/$server.csr
}

store_crt() {
	server=$1
	echo "Trykk enter for å åpne editoren vim, lim deretter inn certifikatet du har generert på startssl"
	echo "avslutt vim ved å taste: <escape> ZZ"
	read enter
	vim $dir_to/kunder/$server/$server.crt
}

copy_to_docker() {
	server=$1
	container=$2
	[ -z "$container" ] && container=$server
set -x
	cat $dir_to/kunder/$server/$server.crt | docker exec -i $container /bin/sh -c 'cat - > /etc/nginx/certs/seafile.crt'
	cat $dir_to/kunder/$server/$server.key | docker exec -i $container /bin/sh -c 'cat - > /etc/nginx/certs/seafile.key'
}


while getopts "C:c:h:s:" arg; do
  case $arg in
    h)
      echo "usage" 
      ;;
    s)
      server=$OPTARG
      lag_req $server
      show_req $server
      store_crt $server
      ;;
    C)
      container=$OPTARG
      ;;
    c)
      server=$OPTARG
      copy_to_docker $server $container
      ;;
  esac
done
