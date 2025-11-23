#!/bin/bash
set -euo pipefail

# Validate env & secrets (fail-fast; no hardcoded fallbacks)
: "${MYSQL_DATABASE:?Error: MYSQL_DATABASE unset}"
: "${MYSQL_USER:?Error: MYSQL_USER unset}"
test -s /run/secrets/db_root_password || { echo "Error: /run/secrets/db_root_password empty/missing" >&2; exit 1; }
test -s /run/secrets/db_password || { echo "Error: /run/secrets/db_password empty/missing" >&2; exit 1; }

ROOT_PWD="$(cat /run/secrets/db_root_password)"
DB_PWD="$(cat /run/secrets/db_password)"

# Init only if fresh (idempotent: skips on upgrade/restart)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB (first run)..."

    # Generate insecure temp root (no pass); data dir owned by mysql
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql

    # Temp server start (local socket only; no net exposure)
    echo "Starting temp mysqld..."
    mysqld --daemonize --skip-networking --socket=/var/run/mysqld/mysqld.sock --user=mysql

    # Wait with timeout (prevent infinite loop; 60s max)
    echo "Waiting for temp mysqld (timeout 60s)..."
    timeout=60; elapsed=0
    while ! mariadb-admin --socket=/var/run/mysqld/mysqld.sock ping; do
        sleep 1
        ((elapsed++)) || true
        [ "$elapsed" -ge "$timeout" ] && { echo "Error: Temp mysqld startup timeout" >&2; exit 1; }
    done

    # Secure: Set auth plugin + root password (empty -> secret)
    echo "Securing root (plugin + password)..."
    mariadb -u root --socket=/var/run/mysqld/mysqld.sock << EOF
USE mysql;
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${ROOT_PWD}');
FLUSH PRIVILEGES;
EOF

    # Create app DB/user (with grants; use new root pass)
    echo "Creating DB '${MYSQL_DATABASE}' and user '${MYSQL_USER}'..."
    mariadb -u root -p"${ROOT_PWD}" --socket=/var/run/mysqld/mysqld.sock << EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    # Graceful shutdown (cleanup socket)
    echo "Shutting down temp mysqld..."
    mariadb-admin --socket=/var/run/mysqld/mysqld.sock shutdown
    rm -f /var/run/mysqld/mysqld.sock

    echo "MariaDB init complete."
else
    echo "MariaDB data exists; skipping init (upgrade mode)."
fi

# Exec main process (mysqld as USER mysql)
exec "$@"
