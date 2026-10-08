FROM alpine:3.23

RUN apk add --no-cache \
    php84 \
    php84-fpm \
    php84-mysqli \
    php84-intl \
    php84-mbstring \
    php84-openssl \
    php84-xml \
    php84-zip \
    php84-phar \
    mariadb-client \
    curl

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php84/php-fpm.d/
COPY tools/wordpress_entrypoint.sh /usr/local/bin

RUN chmod +x /usr/local/bin/wordpress_entrypoint.sh

ENTRYPOINT ["/usr/local/bin/wordpress_entrypoint.sh"]