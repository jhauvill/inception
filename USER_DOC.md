# User documentation

This guide explains how to use the Inception stack as an end user or administrator.

## Services provided

| Service | What it does | Reachable from outside? |
|---------|--------------|-------------------------|
| **nginx** | Web server and single entrypoint. Serves the site over HTTPS (TLSv1.2 / TLSv1.3) on port 443. | Yes, port 443 only |
| **wordpress** | The WordPress website, executed by php-fpm. | No (internal, port 9000) |
| **mariadb** | The database holding posts, pages, users and settings. | No (internal, port 3306) |

The website is available at **https://jhauvill.42.fr**. Plain `http://` (port 80) is not served.

## Start and stop the project

Run these commands from the root of the repository:

| Command | Effect |
|---------|--------|
| `make` | Builds the images if needed and starts all the containers |
| `make stop` | Stops the containers without removing them |
| `make start` | Restarts containers previously stopped with `make stop` |
| `make down` | Stops and removes the containers and the network; **data is kept** |
| `make re` | Deletes everything, including the data, and rebuilds from scratch |

The first start takes a little longer: WordPress is downloaded and installed automatically.

The first time you use the project on a machine, run `make hosts` once so that `jhauvill.42.fr` points to the VM.

## Access the website and the administration panel

- **Website**: https://jhauvill.42.fr
- **Administration panel**: https://jhauvill.42.fr/wp-admin

The certificate is self-signed, so the browser shows a security warning the first time. Choose "Advanced" and then "Accept the risk / Continue".

Two WordPress accounts exist:

| Account | Role | Can do |
|---------|------|--------|
| `jhauvill` | Administrator | Everything: settings, themes, plugins, users |
| `wpauthor` | Author | Write and publish their own posts |

## Locate and manage credentials

Credentials are stored locally and are **never committed to Git**.

| What | Where |
|------|-------|
| WordPress administrator password | `secrets/wp_admin_password.txt` |
| WordPress author password | `secrets/wp_user_password.txt` |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |
| User names, emails, domain, database name | `srcs/.env` |

The passwords are only applied when the site and the database are created for the first time. To change one later:

- **WordPress users**: change the password in the admin panel (Users → Profile), or run
  `docker exec wordpress wp user update jhauvill --user_pass='NEW_PASSWORD' --allow-root`.
  Update the matching file in `secrets/` too, to keep a reference.
- **To apply every value from `secrets/` and `.env` again**: run `make re`. This **erases the site and the database** and reinstalls them with the current files.

## Check that the services are running

**Container status**

```bash
make ps
```

All three containers (`nginx`, `wordpress`, `mariadb`) should be `Up`, and only `nginx` should publish a port (`0.0.0.0:443->443/tcp`).

**Logs**

```bash
make logs                  # all services, live (Ctrl+C to quit)
docker logs wordpress      # one service
```

When the stack is healthy, the WordPress log ends with `Starting PHP-FPM...`.

**Website over HTTPS only**

```bash
curl -kI https://jhauvill.42.fr    # expected: an HTTP response (200 or 302)
curl -I http://jhauvill.42.fr      # expected: "Connection refused"
```

Browsers may silently switch `http://` to `https://` on their own. Use `curl` to check what the server really does.

**TLS version**

```bash
openssl s_client -connect jhauvill.42.fr:443 -tls1_2 </dev/null   # accepted
openssl s_client -connect jhauvill.42.fr:443 -tls1_1 </dev/null   # refused
```

**Database**

```bash
docker exec -it mariadb mariadb -u jhauvill -p wordpress
# enter the password from secrets/db_password.txt, then:
SHOW TABLES;
```

**WordPress users**

```bash
docker exec wordpress wp user list --allow-root
```
