#!/bin/ash
set -euo pipefail

# Enhanced logging
log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_warn() {
    echo "[WARN] $*"
}

# Environment validation
: "${MYSQL_DATABASE:?Error: MYSQL_DATABASE not set}"
: "${MYSQL_USER:?Error: MYSQL_USER not set}"

# Secret validation and reading (as root, we can read them)
if [ ! -s /run/secrets/db_root_password ]; then
    log_error "/run/secrets/db_root_password is empty or missing"
    exit 1
fi

if [ ! -s /run/secrets/db_password ]; then
    log_error "/run/secrets/db_password is empty or missing"
    exit 1
fi

# Read secrets into variables (root can read them)
ROOT_PWD="$(cat /run/secrets/db_root_password)"
DB_PWD="$(cat /run/secrets/db_password)"

# Check if initialization is needed
DATADIR="/var/lib/mysql"
INIT_FLAG="${DATADIR}/.mariadb_initialized"

# Ensure proper ownership of data directories
chown -R mysql:mysql "${DATADIR}" /run/mysqld /var/log/mysql

if [ ! -f "${INIT_FLAG}" ]; then
    log_info "First run detected - initializing MariaDB..."
    
    # Install database if directory is empty
    if [ ! -d "${DATADIR}/mysql" ]; then
        log_info "Installing MariaDB system tables..."
        
        # Install with auth_socket disabled to avoid PAM issues
        su-exec mysql mariadb-install-db \
            --user=mysql \
            --basedir=/usr \
            --datadir="${DATADIR}" \
            --skip-test-db \
            --auth-root-authentication-method=normal \
            2>&1 | grep -v "auth_pam_tool" | grep -v "Operation not permitted" || true
        
        log_info "System tables installed successfully"
    fi
    
    # Start temporary server for initialization
    log_info "Starting temporary MariaDB server..."
    su-exec mysql mariadbd \
        --user=mysql \
        --datadir="${DATADIR}" \
        --skip-networking \
        --socket=/run/mysqld/mysqld.sock \
        --pid-file=/run/mysqld/init.pid \
        2>&1 | grep -v "auth_pam_tool" | grep -v "Operation not permitted" &
    
    TEMP_PID=$!
    
    # Wait for server to be ready
    log_info "Waiting for temporary server to start (max 60s)..."
    TIMEOUT=60
    COUNTER=0
    
    while ! mariadb-admin ping --socket=/run/mysqld/mysqld.sock --silent 2>/dev/null; do
        sleep 1
        COUNTER=$((COUNTER + 1))
        
        if [ ${COUNTER} -ge ${TIMEOUT} ]; then
            log_error "Temporary server failed to start within ${TIMEOUT} seconds"
            
            # Show error log if available
            if [ -f /var/log/mysql/error.log ]; then
                log_error "Error log contents:"
                tail -50 /var/log/mysql/error.log >&2
            fi
            
            # Try to kill the process
            if kill -0 ${TEMP_PID} 2>/dev/null; then
                kill -TERM ${TEMP_PID} 2>/dev/null || true
                wait ${TEMP_PID} 2>/dev/null || true
            fi
            
            exit 1
        fi
        
        # Check if process is still running
        if ! kill -0 ${TEMP_PID} 2>/dev/null; then
            log_error "Temporary server process died unexpectedly"
            
            if [ -f /var/log/mysql/error.log ]; then
                log_error "Error log contents:"
                tail -50 /var/log/mysql/error.log >&2
            fi
            
            exit 1
        fi
    done
    
    log_info "Temporary server is ready"
    
    # Secure installation and create users
    log_info "Running secure installation..."
    
    mariadb --socket=/run/mysqld/mysqld.sock <<-EOSQL
		-- Remove anonymous users
		DELETE FROM mysql.user WHERE User='';
		
		-- Remove remote root (we'll recreate it properly)
		DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
		
		-- Remove test database
		DROP DATABASE IF EXISTS test;
		DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
		
		-- Set root password for localhost
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PWD}';
		
		-- Create root user for remote access
		CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${ROOT_PWD}';
		GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
		
		-- Create application database
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
		
		-- Create application user
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PWD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		
		-- Flush privileges
		FLUSH PRIVILEGES;
	EOSQL
    
    log_info "Database initialization completed successfully"
    
    # Shutdown temporary server gracefully
    log_info "Shutting down temporary server..."
    if ! mariadb-admin shutdown --socket=/run/mysqld/mysqld.sock 2>/dev/null; then
        log_warn "Failed to shutdown gracefully, forcing..."
        kill -TERM ${TEMP_PID} 2>/dev/null || true
    fi
    
    # Wait for shutdown
    wait ${TEMP_PID} 2>/dev/null || true
    
    # Clean up socket
    rm -f /run/mysqld/mysqld.sock /run/mysqld/init.pid
    
    # Mark as initialized
    su-exec mysql touch "${INIT_FLAG}"
    log_info "Initialization complete"
else
    log_info "Database already initialized, skipping setup"
fi

# Start MariaDB server as mysql user
log_info "Starting MariaDB server as mysql user..."
exec su-exec mysql mariadbd --user=mysql --datadir="${DATADIR}" --console 2>&1 | grep -v "auth_pam_tool" | grep -v "Operation not permitted" || true
