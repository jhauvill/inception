#!/bin/sh

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

if [ -z "$( ls -A '/var/lib/mysql' )" ]; then
    mariadb-install-db --datadir=/var/lib/mysql --user=mysql

    chown -R mysql:mysql /var/lib/mysql

    mariadbd --user=mysql --skip-networking &

    until mysqladmin ping >/dev/null 2>&1; do
        echo "waiting for mariadb..."
        sleep 1
    done
    
    # creating database
    MYSQL_ADMIN_PASSWORD="$(cat '/run/secrets/db_root_password')"
    MYSQL_PASSWORD="$(cat '/run/secrets/db_password')"
    
    
    mysql -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};"
    mysql -e "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';"
    mysql -e "FLUSH PRIVILEGES;"
    
    # change root password
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ADMIN_PASSWORD}';"

    echo "shuting down temporary server"
    MYSQL_PWD="$MYSQL_ADMIN_PASSWORD" mysqladmin -u root shutdown
fi

exec mariadbd --user=mysql