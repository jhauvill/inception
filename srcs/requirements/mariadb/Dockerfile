FROM alpine:3.23

RUN apk add --no-cache mariadb mariadb-client

COPY tools/mariadb_entrypoint.sh /usr/local/bin/
COPY conf/mariadb-server.cnf /etc/my.cnf.d/

RUN chmod +x /usr/local/bin/mariadb_entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/mariadb_entrypoint.sh"]