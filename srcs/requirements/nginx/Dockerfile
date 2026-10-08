FROM alpine:3.23

# Domain passed by docker-compose (build args), read from srcs/.env
ARG DOMAIN_NAME

RUN apk add --no-cache nginx openssl \
    && mkdir -p /etc/nginx/ssl /run/nginx

# Self-signed certificate generated at build time (no password, nothing secret)
RUN openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.crt \
    -subj "/C=FR/ST=Normandie/L=Le Havre/O=42/OU=42/CN=${DOMAIN_NAME}"

# Replace Alpine's default.conf (which listens on port 80)
COPY conf/nginx.conf /etc/nginx/http.d/default.conf
RUN sed -i "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" /etc/nginx/http.d/default.conf

EXPOSE 443

# nginx in the foreground: it is PID 1, no infinite loop
CMD ["nginx", "-g", "daemon off;"]
