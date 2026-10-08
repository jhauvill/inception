*This project has been created as part of the 42 curriculum by jhauvill.*

# Inception

## Description

Inception is a system administration project: it sets up a small web infrastructure made of several Docker containers, all built from scratch with custom Dockerfiles, orchestrated with Docker Compose and running inside a virtual machine.

The stack serves a WordPress website over HTTPS at `https://jhauvill.42.fr`:

- **NGINX** is the only entrypoint, listening on port 443 with TLSv1.2/TLSv1.3 only.
- **WordPress + php-fpm** runs the PHP application (no web server in this container).
- **MariaDB** stores the WordPress database.

Each service runs in its own container, built from `alpine:3.23` (the penultimate stable Alpine release). Data persists in two Docker named volumes stored under `/home/jhauvill/data` on the host, and the containers talk to each other through a dedicated Docker bridge network.

```
                 Host (VM)                                Docker network "inception"
  browser ──── 443/TLS ────►  ┌──────────┐  FastCGI :9000  ┌─────────────────┐  SQL :3306  ┌─────────┐
                              │  nginx   │ ──────────────► │ wordpress + fpm │ ──────────► │ mariadb │
                              └────┬─────┘                 └────────┬────────┘             └────┬────┘
                                   └──── wordpress_data ────────────┘              mariadb_data ┘
                                   (/home/jhauvill/data/wordpress)        (/home/jhauvill/data/mariadb)
```

## Instructions

### Requirements

- A Linux virtual machine (developed on Debian) with `sudo`
- Docker Engine and the Docker Compose plugin (`docker compose`)
- `make`

### Configuration

Passwords and environment variables are not committed to Git. Before the first run, create:

- `srcs/.env` with the non-secret configuration (domain name, database name, WordPress user names and emails)
- `secrets/db_password.txt`, `secrets/db_root_password.txt`, `secrets/wp_admin_password.txt`, `secrets/wp_user_password.txt`, each containing one password

The exact content is described in [DEV_DOC.md](DEV_DOC.md). `make` refuses to start and tells you which file is missing if one of them is absent.

### Run

```bash
make hosts   # once: maps jhauvill.42.fr to 127.0.0.1 in /etc/hosts
make         # creates the data folders, builds the images and starts the stack
```

Then open `https://jhauvill.42.fr` (the certificate is self-signed, so the browser shows a warning to accept).

Other useful targets: `make down`, `make stop`, `make start`, `make ps`, `make logs`, `make clean`, `make fclean`, `make re`. See [USER_DOC.md](USER_DOC.md) for day-to-day usage and [DEV_DOC.md](DEV_DOC.md) for development details.

## Project description

### How Docker is used

Every service has its own `Dockerfile` in `srcs/requirements/<service>/`. No ready-made image is pulled except the `alpine:3.23` base image. The images are tagged `<service>:1.0` (never `latest`) and built by `docker compose`, which the `Makefile` calls.

Each container runs a single foreground process as PID 1, with no `tail -f`, `sleep infinity` or `while true`:

- `nginx` runs `nginx -g "daemon off;"`.
- `wordpress` runs an entrypoint script that prepares WordPress, then `exec`s `php-fpm84 --nodaemonize`.
- `mariadb` runs an entrypoint script that initialises the database on first start, then `exec`s `mariadbd`.

All containers use `restart: always` so they come back after a crash.

### Sources included in the project

| Path | Role |
|------|------|
| `Makefile` | Checks config files, creates data folders, builds and runs the stack |
| `srcs/docker-compose.yml` | Services, named volumes, secrets and network |
| `srcs/.env` | Non-secret configuration (git-ignored) |
| `secrets/*.txt` | Passwords, mounted as Docker secrets (git-ignored) |
| `srcs/requirements/nginx/` | Dockerfile, self-signed certificate generation, server config (TLS + FastCGI to `wordpress:9000`) |
| `srcs/requirements/wordpress/` | Dockerfile (PHP 8.4, php-fpm, WP-CLI), php-fpm pool config, entrypoint that downloads, configures and installs WordPress and creates the two users |
| `srcs/requirements/mariadb/` | Dockerfile, server config, entrypoint that creates the database and user and sets the root password on first start |

### Main design choices

- **Alpine 3.23** for small images and fast builds.
- **WP-CLI** to install and configure WordPress non-interactively, so the site is ready without going through the web installer.
- **Idempotent entrypoints**: the setup steps check whether WordPress or the database already exist, so restarting a container never reinstalls or overwrites data.
- **Passwords as Docker secrets** read from `/run/secrets/` at runtime; non-sensitive values in `.env`.
- **Self-signed certificate generated at build time** for the domain read from `.env`.
- **Two WordPress users**: an administrator (`jhauvill`, which contains no "admin") and a standard user with the `author` role.

### Virtual Machines vs Docker

A virtual machine emulates a whole computer and runs its own kernel on top of a hypervisor, so it is strongly isolated but heavy: it takes gigabytes of disk and memory and boots in tens of seconds. A Docker container shares the host kernel and only isolates processes using namespaces and cgroups. It starts in about a second, uses little memory and is described by a reproducible `Dockerfile`, but its isolation is weaker than a VM's. In this project both are used together: the VM provides an isolated environment, and Docker splits the services inside it.

### Secrets vs Environment Variables

Environment variables are convenient for configuration, but they are visible to anyone who can run `docker inspect`, they are inherited by every child process and they often end up in logs. Docker secrets are mounted as files in `/run/secrets/` only in the containers that declare them, and they never appear in the image or in `docker inspect`. This project keeps non-sensitive settings (domain, user names, database name) in `.env` and every password in `secrets/`. Both are excluded from Git.

### Docker Network vs Host Network

With `network: host`, a container shares the host's network stack directly: no isolation, every port it opens is open on the host, and services cannot be reached by name. A user-defined bridge network (`inception` here) gives the containers a private network with built-in DNS, so `wordpress` can reach `mariadb:3306` by name. Only the ports explicitly published are reachable from outside. Here that is just `443` on `nginx`; MariaDB and php-fpm stay internal.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary host path into a container. It depends on the host's directory layout and is not managed by Docker. A named volume is a Docker-managed object: it has a name, can be listed and inspected with `docker volume`, and is declared once in `docker-compose.yml` and shared between services by name. This project uses two named volumes (`mariadb_data` and `wordpress_data`). Their `local` driver is configured to store the data in `/home/jhauvill/data/...` so it is easy to find on the host, as required by the subject.

## Resources

### Documentation

- [Docker documentation](https://docs.docker.com/)
- [Dockerfile best practices](https://docs.docker.com/build/building/best-practices/)
- [Docker Compose file reference](https://docs.docker.com/reference/compose-file/)
- [Docker volumes](https://docs.docker.com/engine/storage/volumes/)
- [Secrets in Docker Compose](https://docs.docker.com/compose/how-tos/use-secrets/)
- [Docker bridge networks](https://docs.docker.com/engine/network/drivers/bridge/)
- [NGINX: configuring HTTPS servers](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [NGINX: ngx_http_fastcgi_module](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html)
- [PHP-FPM configuration](https://www.php.net/manual/en/install.fpm.configuration.php)
- [WP-CLI commands](https://developer.wordpress.org/cli/commands/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [Alpine Linux wiki](https://wiki.alpinelinux.org/)

