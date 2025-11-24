#!/bin/ash
set -euo pipefail

# Guards: Env + secrets (fail-fast; MYSQL_* vars)
: "${MYSQL_DATABASE:?Error: MYSQL_DATABASE unset}"
: "${MYSQL_USER:?Error: MYSQL_USER unset}"
test -s /run/secrets/db_root_password || { echo "Error: /run/secrets/db_root_password empty/missing" >&2; exit 1; }
test -s /run/secrets/db_password || { echo "Error: /run/secrets/db_password empty/missing" >&2; exit 1; }

ROOT_PWD="$(cat /run/secrets/db_root_password)"
DB_PWD="$(cat /run/secrets/db_password)"

# Init only if fresh (your idempotent datadir check)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB (first run)..."

    # Temp server (your pattern: skip-net, silent; PID trap)
    mariadbd --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock > /dev/null 2>&1 &
    PID=$!

    # Wait with timeout (your loop; fixed infinite: 60s cap)
    echo "Waiting for temp mariadbd (timeout 60s)..."
    TIMEOUT=60; ELAPSED=0
    until mariadb-admin --silent --socket=/run/mysqld/mysqld.sock ping; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        [ "$ELAPSED" -ge "$TIMEOUT" ] && { echo "Error: Temp mariadbd startup timeout" >&2; kill $PID; exit 1; }
    done

    # Secure root accounts
    echo "Securing root accounts..."
    mariadb --socket=/run/mysqld/mysqld.sock -u root <<EOF
USE mysql;
-- Update localhost root user
UPDATE user SET plugin='mysql_native_password', authentication_string=PASSWORD('${ROOT_PWD}') WHERE User='root' AND Host='localhost';
-- Create or update root@'%'
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${ROOT_PWD}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

    # App DB/user
    echo "Creating DB '${MYSQL_DATABASE}' and user '${MYSQL_USER}'..."
    mariadb --socket=/run/mysqld/mysqld.sock -u root -p"${ROOT_PWD}" <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF

    # Shutdown temp
    echo "Shutting down temp mariadbd..."
    kill $PID
    wait $PID 2>/dev/null || true
    rm -f /run/mysqld/mysqld.sock

    echo "MariaDB init complete."
else
    echo "MariaDB data exists; skipping init."
fi

# Exec main daemon (no need for password re-application if initialization is correct)
echo "Starting MariaDB main daemon..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql
