#!/bin/sh

# Stop the script at the first command that fails
set -e

mkdir -p /var/www/localhost/htdocs
cd /var/www/localhost/htdocs

# --- Read secrets ---
DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

# --- Download WordPress ---
if [ ! -f index.php ]; then
    echo "Downloading WordPress..."
    php -d memory_limit=256M /usr/local/bin/wp core download --allow-root
fi

# --- Generate wp-config.php ---
if [ ! -f wp-config.php ]; then
    echo "Creating wp-config.php..."
    cp wp-config-sample.php wp-config.php

    sed -i "s/database_name_here/$MYSQL_DATABASE/" wp-config.php
    sed -i "s/username_here/$MYSQL_USER/" wp-config.php
    sed -i "s/password_here/$DB_PASSWORD/" wp-config.php
    sed -i "s/localhost/mariadb/" wp-config.php
fi

# --- Wait for MariaDB (60 seconds max) ---
echo "Waiting for MariaDB..."
i=0
until mariadb -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" -e "SELECT 1;" "$MYSQL_DATABASE" > /dev/null 2>&1; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
        echo "MariaDB unreachable after 60 seconds."
        exit 1
    fi
    echo "MariaDB not ready yet..."
    sleep 1
done
echo "MariaDB is ready."

# --- Install WordPress ---
if ! wp core is-installed --allow-root; then
    echo "Installing WordPress..."
    wp core install \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_ADMIN_USER" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="$WP_ADMIN_EMAIL" \
        --skip-email \
        --allow-root
fi

# --- Create the standard user ---
if ! wp user get "$WP_USER" --allow-root > /dev/null 2>&1; then
    echo "Creating standard user..."
    wp user create "$WP_USER" "$WP_USER_EMAIL" \
        --user_pass="$WP_USER_PASSWORD" \
        --role=author \
        --allow-root
fi

# --- Permissions for php-fpm (its workers run as nobody) ---
chown -R nobody:nobody /var/www/localhost/htdocs

echo "Starting PHP-FPM..."
exec php-fpm84 --nodaemonize
