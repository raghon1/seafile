USER=${USER:-root}
PASS=${PASS:-$(pwgen -s -1 16)}

pre_start_action() {
  # Echo out info to later obtain by running `docker logs container_name`
  echo "MARIADB_USER=$USER"
  echo "MARIADB_PASS=$PASS"
  echo "MARIADB_DATA_DIR=$DATA_DIR"

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

post_start_action() {
set -x

  # Create the superuser.
  mysql -u root << EOF
	DELETE FROM mysql.user ;
	FLUSH PRIVILEGES;
	CREATE USER 'root'@'%' IDENTIFIED BY '${PASS}' ;
	GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
	FLUSH PRIVILEGES;
EOF

  rm /firstrun
}
