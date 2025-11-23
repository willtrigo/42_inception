#!/bin/bash
set -euo pipefail

# Init DB if needed
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "Initializing MariaDB..."
  mysqld --initialize-insecure --user=mysql
  echo "Starting initial mysqld..."
  mysqld --daemonize --skip-networking --socket=/var/run/mysqld/mysqld.sock
  echo "Waiting for mysqld..."
  while ! mariadb-admin ping --socket=/var/run/mysqld/mysqld.sock; do sleep 1; done

  # Secure install
  mariadb -u root --socket=/var/run/mysqld/mysqld.sock << EOF
USE mysql;
UPDATE user SET plugin='mysql_native_password' WHERE User='root';
FLUSH PRIVILEGES;
EOF

  # Create DB & users
  ROOT_PWD="$(cat /run/secrets/db_root_password)"
  DB_PWD="$(cat /run/secrets/db_password)"
  mariadb -u root -p"${ROOT_PWD}" --socket=/var/run/mysqld/mysqld.sock << EOF
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

  # Shutdown initial
  mariadb-admin shutdown --socket=/var/run/mysqld/mysqld.sock
  rm -f /var/run/mysqld/mysqld.sock
fi

exec "$@"
