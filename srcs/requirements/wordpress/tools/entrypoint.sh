#!/bin/ash
set -euo pipefail

# Read the password from the secret file
DB_PASSWORD="$(cat /run/secrets/db_password)"
# Export it to the environment variable WP-CLI expects for connection
export WORDPRESS_DB_PASSWORD="${DB_PASSWORD}"
# --------------------------------------------------------------------------

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
# wp db check now has all required credentials via environment variables
while ! wp db check --path=/var/www/html --allow-root 2>/dev/null; do
    echo "Waiting for MariaDB..."
    sleep 2
done

# Configure WordPress database connection
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Creating wp-config.php..."
    wp config create \
        --path=/var/www/html \
        --allow-root \
        --dbname="${WORDPRESS_DB_NAME}" \
        --dbuser="${WORDPRESS_DB_USER}" \
        --dbpass="${WORDPRESS_DB_PASSWORD}" \
        --dbhost="${WORDPRESS_DB_HOST}" \
        --skip-check \
        --force
fi

# Install WordPress if not already installed
if ! wp core is-installed --path=/var/www/html --allow-root; then
    echo "Installing WordPress..."
    wp core install \
        --path=/var/www/html \
        --allow-root \
        --url="https://${DOMAIN_NAME}" \
        --title="Inception Site" \
        --admin_user="${WORDPRESS_ADMIN_USER}" \
        --admin_password="$(cat /run/secrets/wp_admin_password)" \
        --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
        --skip-email

    # Create additional user
    echo "Creating additional user..."
    wp user create \
        --path=/var/www/html \
        --allow-root \
        wpuser \
        "user@${DOMAIN_NAME}" \
        --user_pass="${WORDPRESS_DB_PASSWORD}" \
        --role=editor
else
    echo "WordPress is already installed."
fi

# Apply extra config if provided
if [ -n "${WORDPRESS_CONFIG_EXTRA:-}" ]; then
    echo "Applying extra WordPress configuration..."
    echo "${WORDPRESS_CONFIG_EXTRA}" >> /var/www/html/wp-config.php
fi

# Fix permissions
chown -R www-data:www-data /var/www/html

echo "WordPress setup complete."
exec "$@"
