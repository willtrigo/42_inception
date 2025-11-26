#!/bin/ash
set -euo pipefail

echo "[INFO] Starting MariaDB initialization..."

# Read secrets
ROOT_PWD="$(cat /run/secrets/db_root_password)"
DB_PWD="$(cat /run/secrets/db_password)"

# Set ownership
chown -R mysql:mysql /var/lib/mysql /run/mysqld
chmod 755 /run/mysqld

DATADIR="/var/lib/mysql"

# Initialize if data directory is empty
if [ -z "$(ls -A ${DATADIR})" ]; then
    echo "[INFO] Initializing MariaDB database..."
    
    # Install system tables
    mariadb-install-db \
        --user=mysql \
        --datadir="${DATADIR}" \
        --skip-test-db \
        --rpm
    
    echo "[INFO] Starting temporary server for setup..."
    
    # Start temporary server
    mariadbd --user=mysql --datadir="${DATADIR}" --skip-networking --socket=/run/mysqld/mysqld.sock &
    TEMP_PID=$!
    
    # Wait for server to start
    sleep 5
    for i in {1..30}; do
        if mariadb --socket=/run/mysqld/mysqld.sock -e "SELECT 1" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    
    echo "[INFO] Setting up users and database..."
    
    # Setup database and users
    mariadb --socket=/run/mysqld/mysqld.sock <<-EOSQL
        ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PWD}';
        DELETE FROM mysql.user WHERE User='';
        DROP DATABASE IF EXISTS test;
        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
        CREATE USER 'root'@'%' IDENTIFIED BY '${ROOT_PWD}';
        GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
        FLUSH PRIVILEGES;
EOSQL
    
    echo "[INFO] Shutting down temporary server..."
    mariadb-admin --socket=/run/mysqld/mysqld.sock -uroot -p"${ROOT_PWD}" shutdown
    wait $TEMP_PID
    
    echo "[INFO] MariaDB initialization completed successfully"
else
    echo "[INFO] Using existing database"
fi

echo "[INFO] Starting MariaDB server..."
exec mariadbd --user=mysql --datadir="${DATADIR}"
