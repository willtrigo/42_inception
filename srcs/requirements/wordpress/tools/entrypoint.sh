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

log_debug() {
    echo "[DEBUG] $*" >&2
}

# Parse the DB host and port
DB_HOST="${WORDPRESS_DB_HOST%:*}"
DB_PORT="${WORDPRESS_DB_HOST#*:}"
if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT="3306"
fi

# Read the password from the secret file
log_info "Reading database password from secret..."
DB_PASSWORD="$(cat /run/secrets/db_password)"
log_debug "Password length: ${#DB_PASSWORD} characters"

# Debug: Show connection details (without password)
log_info "WordPress Database Configuration:"
log_info "  DB Host: ${DB_HOST}"
log_info "  DB Port: ${DB_PORT}"
log_info "  DB Name: ${WORDPRESS_DB_NAME}"
log_info "  DB User: ${WORDPRESS_DB_USER}"
log_info "  Domain: ${DOMAIN_NAME}"

# Wait for MariaDB to be ready with extensive debugging
log_info "Waiting for MariaDB to be ready..."

TIMEOUT=60
COUNTER=0

while true; do
    # Method 1: Direct TCP connection
    if nc -z "${DB_HOST}" "${DB_PORT}" 2>/dev/null; then
        log_info "TCP connection to ${DB_HOST}:${DB_PORT} successful"
        
        # Method 2: MySQL client connection with proper host/port separation
        if mariadb \
            --host="${DB_HOST}" \
            --port="${DB_PORT}" \
            --user="${WORDPRESS_DB_USER}" \
            --password="${DB_PASSWORD}" \
            --ssl=0 \
            --connect-timeout=5 \
            --execute="SELECT 1;" 2>/dev/null; then
            
            log_info "MariaDB is ready and accepting connections!"
            break
        else
            ERROR_OUTPUT=$(mariadb \
                --host="${DB_HOST}" \
                --port="${DB_PORT}" \
                --user="${WORDPRESS_DB_USER}" \
                --password="${DB_PASSWORD}" \
                --ssl=0 \
                --connect-timeout=5 \
                --execute="SELECT 1;" 2>&1)
            log_warn "MySQL connection failed: ${ERROR_OUTPUT}"
        fi
    else
        log_warn "TCP connection to ${DB_HOST}:${DB_PORT} failed"
    fi
    
    COUNTER=$((COUNTER + 1))
    if [ ${COUNTER} -ge ${TIMEOUT} ]; then
        log_error "MariaDB connection timeout after ${TIMEOUT} seconds"
        log_error "Check if MariaDB is running and credentials are correct"
        exit 1
    fi
    
    log_info "Waiting for MariaDB... (${COUNTER}/${TIMEOUT})"
    sleep 2
done

# Additional wait to ensure MariaDB is fully initialized
sleep 3

# Check if database exists and is accessible with SSL disabled
log_info "Verifying database accessibility..."
if mariadb \
    --host="${DB_HOST}" \
    --port="${DB_PORT}" \
    --user="${WORDPRESS_DB_USER}" \
    --password="${DB_PASSWORD}" \
    --ssl=0 \
    --execute="USE ${WORDPRESS_DB_NAME}; SELECT 'Database accessible' as status;" 2>/dev/null; then
    
    log_info "Database '${WORDPRESS_DB_NAME}' is accessible"
else
    log_error "Database '${WORDPRESS_DB_NAME}' is not accessible"
    exit 1
fi

# Configure WordPress database connection
if [ ! -f /var/www/html/wp-config.php ]; then
    log_info "Creating wp-config.php..."
    
    wp config create \
        --path=/var/www/html \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --skip-check \
        --force \
        --allow-root
    
    log_info "wp-config.php created successfully"
    
    # Add SSL disable to wp-config.php to prevent SSL issues
    echo "// Disable SSL for database connections" >> /var/www/html/wp-config.php
    echo "define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_COMPRESS);" >> /var/www/html/wp-config.php
else
    log_info "wp-config.php already exists"
fi

# Install WordPress if not already installed
if ! wp core is-installed --path=/var/www/html --allow-root 2>/dev/null; then
    log_info "Installing WordPress..."
    
    wp core install \
        --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception Site" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="$(cat /run/secrets/wp_admin_password)" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
    
    log_info "WordPress installed successfully"
    
    # Create additional user
    log_info "Creating additional user..."
    wp user create \
        --path=/var/www/html \
        wpuser \
        "user@${DOMAIN_NAME}" \
        --user_pass="${DB_PASSWORD}" \
        --role=editor \
        --allow-root
    
    log_info "Additional user created"
else
    log_info "WordPress is already installed."
fi

# Apply extra config if provided
if [ -n "${WORDPRESS_CONFIG_EXTRA:-}" ] && ! grep -q "WP_DEBUG" /var/www/html/wp-config.php; then
    log_info "Applying extra WordPress configuration..."
    echo "${WORDPRESS_CONFIG_EXTRA}" >> /var/www/html/wp-config.php
fi

# Fix permissions
chown -R www-data:www-data /var/www/html
chmod 755 /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;

log_info "WordPress setup complete."

# Start PHP-FPM
exec "$@"
