#!/bin/ash
set -euo pipefail

# Guards: Env + secrets (fail-fast; your vars as MYSQL_*)
: "${MYSQL_DATABASE:?Error: MYSQL_DATABASE unset}"
: "${MYSQL_USER:?Error: MYSQL_USER unset}"
test -s /run/secrets/db_root_password || { echo "Error: /run/secrets/db_root_password empty/missing" >&2; exit 1; }
test -s /run/secrets/db_password || { echo "Error: /run/secrets/db_password empty/missing" >&2; exit 1; }

ROOT_PWD="$(cat /run/secrets/db_root_password)"
DB_PWD="$(cat /run/secrets/db_password)"

# Init only if fresh (idempotent: skips on existing data/upgrade)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB (first run)..."

    # Temp server (your pattern: skip-net, silent; PID trap)
    mariadbd --user=mysql --skip-networking --socket=/var/run/mysqld/mysqld.sock > /dev/null 2>&1 &
    PID=$!

    # Wait with timeout (your loop; fixed infinite hang: 60s cap)
    echo "Waiting for temp mariadbd (timeout 60s)..."
    TIMEOUT=60; ELAPSED=0
    until mariadb-admin --silent --socket=/var/run/mysqld/mysqld.sock ping; do
        sleep 1
        ELAPSED=$((ELAPSED + 1))
        [ "$ELAPSED" -ge "$TIMEOUT" ] && { echo "Error: Temp mariadbd startup timeout" >&2; kill $PID; exit 1; }
    done

    # Secure root@'%' (your UPDATE plugin + CREATE/IDENTIFIED BY; pass from secret)
    echo "Securing root@'%' (plugin + password)..."
    mariadb -u root --socket=/var/run/mysqld/mysqld.sock -sse "
    USE mysql;
    UPDATE user SET plugin='mysql_native_password' WHERE User='root';
    CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${ROOT_PWD}';
    GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;"

    # App DB/user (your EXISTS check + creation; scoped GRANT DB.*)
    echo "Creating DB '${MYSQL_DATABASE}' and user '${MYSQL_USER}'..."
    if [ $(mariadb -u root -p"${ROOT_PWD}" -sse "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '${MYSQL_USER}');") -eq 0 ]; then
        mariadb -u root -p"${ROOT_PWD}" --socket=/var/run/mysqld/mysqld.sock -sse "
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        FLUSH PRIVILEGES;"
    fi

    # Shutdown temp (your kill; graceful rm socket)
    echo "Shutting down temp mariadbd..."
    kill $PID
    rm -f /var/run/mysqld/mysqld.sock

    echo "MariaDB init complete."
else
    echo "MariaDB data exists; skipping init (upgrade mode)."
fi

# Exec main (your pattern; datadir explicit)
exec mariadbd --user=mysql --datadir=/var/lib/mysql
