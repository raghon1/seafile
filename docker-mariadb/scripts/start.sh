#!/bin/bash
# Starts up MariaDB within the container.

# Stop on error
set -e

DATA_DIR=/data

init_db_data() {
  # Echo out info to later obtain by running `docker logs container_name`

  # test if DATA_DIR has content
  if [[ ! "$(ls -A $DATA_DIR)" ]]; then
      echo "Initializing MariaDB at $DATA_DIR"
      # Copy the data that we generated within the container to the empty DATA_DIR.
      cp -R /var/lib/mysql/* $DATA_DIR
  fi

  # Ensure mysql owns the DATA_DIR
  chown -R mysql $DATA_DIR
  chown root $DATA_DIR/debian*.flag
}

init_db_user() {
  USER=${USER:-root}
  PASS=${PASS:-$(pwgen -s -1 16)}

  echo "MARIADB_USER=$USER"
  echo "MARIADB_PASS=$PASS"
  echo "MARIADB_DATA_DIR=$DATA_DIR"

  # Create the superuser.
  mysql -u root << EOF
	DELETE FROM mysql.user ;
	FLUSH PRIVILEGES;
	CREATE USER 'root'@'%' IDENTIFIED BY '${PASS}' ;
	GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
	FLUSH PRIVILEGES;
EOF

}

wait_for_mysql_and_run_post_start_action() {
  # Wait for mysql to finish starting up first.
  while [[ ! -e /var/run/mysqld/mysqld.sock ]] ; do
	echo "venter på mysqld socket"
	inotifywait -q -e create /var/run/mysqld/ >> /dev/null

  done

}

firstrun="false"
if [[ ! -d $DATA_DIR/mysql ]]; then
  firstrun="true"
  init_db_data
  nohup /usr/bin/mysqld_safe &
  wait_for_mysql_and_run_post_start_action 
  init_db_user 
  killall -u mysql
  while [[ -e /var/run/mysqld/mysqld.sock ]] ; do
	echo "venter på shutdown"
	sleep 2
  done
  exit 0
fi

rm -f /var/run/mysqld/mysqld.sock
# Start MariaDB
echo "Starting MariaDB..."
exec /usr/bin/mysqld_safe
