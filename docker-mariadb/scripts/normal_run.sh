pre_start_action() {
  # Cleanup previous sockets
  rm -f /var/run/mysqld/mysqld.sock
}

post_start_action() {
  : # No-op
}
