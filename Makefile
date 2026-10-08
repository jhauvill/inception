NAME		= inception
LOGIN		= jhauvill
DATA_DIR	= /home/$(LOGIN)/data
COMPOSE		= docker compose -f srcs/docker-compose.yml -p $(NAME)

SECRETS		= secrets/db_password.txt \
			  secrets/db_root_password.txt \
			  secrets/wp_admin_password.txt \
			  secrets/wp_user_password.txt

all: up

# Make sure the git-ignored files are present
check:
	@test -f srcs/.env || { echo "Error: srcs/.env is missing"; exit 1; }
	@for f in $(SECRETS); do \
		test -f $$f || { echo "Error: $$f is missing"; exit 1; }; \
	done

# Host directories backing the named volumes
setup: check
	@mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress

# Add login.42.fr -> 127.0.0.1 to /etc/hosts (only once)
hosts:
	@grep -q "$(LOGIN).42.fr" /etc/hosts || \
		echo "127.0.0.1 $(LOGIN).42.fr" | sudo tee -a /etc/hosts

up: setup
	$(COMPOSE) up -d --build

build: setup
	$(COMPOSE) build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

# Remove containers, network, project images and Docker volumes
clean:
	$(COMPOSE) down --rmi all -v

# + persistent data on the host and build cache
fclean: clean
	sudo rm -rf $(DATA_DIR)
	docker builder prune -af

re: fclean all

.PHONY: all check setup hosts up build down stop start ps logs clean fclean re
