# Developer documentation

This guide explains how to set up, build, run and maintain the Inception stack.

## Set up the environment from scratch

### Prerequisites

On a Debian virtual machine:

```bash
sudo apt update
sudo apt install make git ca-certificates curl
```

Install Docker Engine and the Compose plugin by following the [official Debian instructions](https://docs.docker.com/engine/install/debian/). Then allow your user to run Docker without `sudo`:

```bash
sudo usermod -aG docker $USER   # log out and back in afterwards
docker compose version          # check that the plugin works
```

### Repository layout

```
.
├── Makefile
├── README.md / USER_DOC.md / DEV_DOC.md
├── secrets/                       # git-ignored
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                       # git-ignored
    ├── docker-compose.yml
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.conf
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/wordpress_entrypoint.sh
        └── mariadb/
            ├── Dockerfile
            ├── conf/mariadb-server.cnf
            └── tools/mariadb_entrypoint.sh
```

### Configuration files

`srcs/.env` and the `secrets/` folder are excluded from Git (`.gitignore`), so you must create them after cloning.

**`srcs/.env`**

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=jhauvill

DOMAIN_NAME=jhauvill.42.fr
WP_TITLE=Inception

WP_ADMIN_USER=jhauvill
WP_ADMIN_EMAIL=jhauvill@42.fr
WP_USER=wpauthor
WP_USER_EMAIL=wpauthor@42.fr
```

`WP_ADMIN_USER` must not contain `admin` or `administrator`, in any case.

**`secrets/`**: one password per file, with no trailing spaces:

```bash
mkdir -p secrets
printf '%s' 'CHANGE_ME' > secrets/db_password.txt
printf '%s' 'CHANGE_ME' > secrets/db_root_password.txt
printf '%s' 'CHANGE_ME' > secrets/wp_admin_password.txt
printf '%s' 'CHANGE_ME' > secrets/wp_user_password.txt
```

Avoid `/`, `&` and quotes in `db_password.txt`: the WordPress entrypoint inserts it into `wp-config.php` with `sed`.

### Domain name

```bash
make hosts    # adds "127.0.0.1 jhauvill.42.fr" to /etc/hosts if it is missing
```

### Using another login

Replace `jhauvill` in:

- `LOGIN` in the `Makefile`
- the two `device:` paths in `srcs/docker-compose.yml`
- `DOMAIN_NAME` (and the user names if you like) in `srcs/.env`

## Build and launch the project

```bash
make
```

`make` (target `all` → `up`) does the following:

1. `check`: fails with a clear message if `srcs/.env` or any secret file is missing.
2. `setup`: creates `/home/jhauvill/data/mariadb` and `/home/jhauvill/data/wordpress`.
3. Runs `docker compose -f srcs/docker-compose.yml -p inception up -d --build`, which builds the three images (`mariadb:1.0`, `wordpress:1.0`, `nginx:1.0`) and starts them.

### Makefile targets

| Target | Command run | Notes |
|--------|-------------|-------|
| `all` / `up` | `compose up -d --build` | Default target |
| `build` | `compose build` | Build the images only |
| `down` | `compose down` | Remove containers and network, keep volumes and data |
| `stop` / `start` | `compose stop` / `compose start` | Pause or resume without removing |
| `ps` | `compose ps` | Container status |
| `logs` | `compose logs -f` | Follow all logs |
| `clean` | `compose down --rmi all -v` | Also remove the images and Docker volume objects; host data in `/home/jhauvill/data` stays |
| `fclean` | `clean` + `sudo rm -rf /home/jhauvill/data` + `docker builder prune -af` | Full reset, **deletes all data** |
| `re` | `fclean` + `all` | Rebuild from scratch |
| `hosts` | appends to `/etc/hosts` | Run once per machine |

### Startup sequence

1. **mariadb**: on the first start (empty `/var/lib/mysql`), the entrypoint initialises the data directory and starts a temporary server. It then creates the database and the `MYSQL_USER` user, sets the root password from the secrets, stops the temporary server and `exec`s `mariadbd` as PID 1. On later starts it goes straight to `mariadbd`.
2. **wordpress**:
   - Downloads WordPress with WP-CLI if `index.php` is missing.
   - Generates `wp-config.php`.
   - Waits up to 60 s for MariaDB.
   - Runs `wp core install` with the admin account if WordPress is not installed, and creates the author user if it does not exist.
   - Gives the files to `nobody` and `exec`s `php-fpm84 --nodaemonize`.
3. **nginx**: serves `/var/www/localhost/htdocs` (the same `wordpress_data` volume) and forwards `.php` requests to `wordpress:9000` with FastCGI.

`depends_on` only orders the start-up. The wait loop in the WordPress entrypoint is what actually guarantees that the database is ready.

## Manage containers and volumes

```bash
# Status and logs
docker ps
docker compose -f srcs/docker-compose.yml -p inception ps
docker logs -f mariadb

# Open a shell in a container
docker exec -it wordpress sh
docker exec -it mariadb mariadb -u root -p           # root password: secrets/db_root_password.txt

# Rebuild a single service after editing its Dockerfile
docker compose -f srcs/docker-compose.yml -p inception up -d --build nginx

# Inspect the network and the volumes
docker network inspect inception_inception
docker volume ls
docker volume inspect inception_mariadb_data inception_wordpress_data

# Test the restart policy
docker kill wordpress && sleep 3 && docker ps
```

Docker prefixes network and volume names with the project name (`-p inception`): for example, `inception_mariadb_data`.

## Where data is stored and how it persists

| Named volume | Mounted in | Stored on the host |
|--------------|-----------|--------------------|
| `mariadb_data` | `mariadb:/var/lib/mysql` | `/home/jhauvill/data/mariadb` |
| `wordpress_data` | `wordpress:/var/www/localhost/htdocs` and `nginx:/var/www/localhost/htdocs` | `/home/jhauvill/data/wordpress` |

Both are **named volumes** declared in `docker-compose.yml`. They use the `local` driver with `driver_opts` (`type: none`, `o: bind`, `device: ...`), which tells Docker where to keep the data on the host.

- The data survives `make down`, `make stop`, container crashes and VM reboots.
- `make clean` removes the Docker volume objects, but the files under `/home/jhauvill/data` stay. The next `make` reattaches them, so the site and database come back unchanged.
- Only `make fclean` / `make re` delete `/home/jhauvill/data`, using `sudo` because the files belong to the container users.

Because the entrypoints skip setup when data already exists, editing `.env` or `secrets/` does not change an existing installation. Run `make re` to reinstall with the new values.
