#!/bin/bash
set -euo pipefail

# Wait for DB
until wp db check --allow-root; do
  echo "Waiting for MariaDB..."
  sleep 2
done

# Install/upgrade WP
wp core download --allow-root --force || true
wp core install --allow-root \
  --url="https://${DOMAIN_NAME}" \
  --title="Inception Site" \
  --admin_user="${WORDPRESS_ADMIN_USER}" \
  --admin_password="$(cat /run/secrets/wp_admin_password)" \
  --admin_email="${WORDPRESS_ADMIN_EMAIL}" \
  --skip-email

# Create non-admin user
wp user create --allow-root wpuser "${WORDPRESS_ADMIN_EMAIL}" \
  --user_pass="$(cat /run/secrets/db_password)" \
  --role=editor

# Apply extra config
echo "${WORDPRESS_CONFIG_EXTRA}" >> /var/www/html/wp-config.php

exec "$@"
