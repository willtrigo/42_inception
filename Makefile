# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: dande-je <dande-je@student.42sp.org.br>    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/11/23 14:13:45 by dande-je          #+#    #+#              #
#    Updated: 2025/11/23 19:15:01 by dande-je         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#******************************************************************************#
#                                   COLOR                                      #
#******************************************************************************#

COLOR_RESET   = \033[0m
COLOR_GREEN   = \033[32m
COLOR_YELLOW  = \033[33m
COLOR_RED     = \033[31m
COLOR_BLUE    = \033[34m

#******************************************************************************#
#                                PROJECT VARS                                  #
#******************************************************************************#

COMPOSE_PATH      := srcs/
COMPOSE_FILE      ?= $(COMPOSE_PATH)docker-compose.yml
PROJECT_NAME      ?= inception
USER              ?= $(shell whoami)
DOMAIN            ?= $(shell grep DOMAIN_NAME srcs/.env | cut -d '=' -f2-)
VOLUMES           := mariadb \
										 wordpress
VOLUMES_DIRECTORY := $(VOLUMES:%=/home/$(USER)/data/%)

#******************************************************************************#
#                              DOCKER COMMANDS                                 #
#******************************************************************************#

COMPOSE       = docker compose --project-name $(PROJECT_NAME) -f $(COMPOSE_FILE)
COMPOSE_V1    = docker-compose --project-name $(PROJECT_NAME) -f $(COMPOSE_FILE)
ifeq ($(shell command -v docker compose >/dev/null 2>&1; echo $$?), 1)
	COMPOSE = $(COMPOSE_V1)
endif

#******************************************************************************#
#                                   TARGETS                                    #
#******************************************************************************#
all: up

env-check:
	@if [ ! -f $(COMPOSE_PATH).env ]; then \
		echo "$(COLOR_RED)Error: .env missing. Run: cp .env.example .env && edit it. $(COLOR_RESET)"; \
		exit 1; \
	fi
	@grep -q "DOMAIN_NAME=" $(COMPOSE_PATH).env || (echo " $(COLOR_RED)Error: DOMAIN_NAME not set in .env.$(COLOR_RESET)" && exit 1)
	@echo "$(COLOR_GREEN)✓ .env validated. $(COLOR_RESET)"

up: env-check build
	$(COMPOSE) up -d --remove-orphans --no-recreate
	echo "$(COLOR_GREEN)✓ Infrastructure up: https://$(DOMAIN)$(COLOR_RESET)"

build:
	mkdir -p $(VOLUMES_DIRECTORY)
	$(COMPOSE) build --parallel --no-cache --pull

down:
	$(COMPOSE) down --remove-orphans --timeout 30
	echo "$(COLOR_YELLOW)Containers down; volumes intact.$(COLOR_RESET)"

clean: down
	$(COMPOSE) down --rmi local --volumes --remove-orphans --timeout 30
	docker system prune -f --filter label=project=$(PROJECT_NAME)
	echo "$(COLOR_YELLOW)Cleaned (volumes preserved).$(COLOR_RESET)"

fclean: clean
	docker volume prune -f --filter name=$(PROJECT_NAME)_*
	docker network prune -f --filter label=project=$(PROJECT_NAME)
	docker system prune -af --filter label=project=$(PROJECT_NAME)
	rm -rf /home/$(USER)/data/{wordpress,mariadb}
	echo "$(COLOR_RED)Full clean complete.$(COLOR_RESET)"

re: fclean build up

logs:
	$(COMPOSE) logs -f --tail=100

validate:
	$(COMPOSE) config --quiet
	$(COMPOSE) ps | grep -q healthy || (echo "$(COLOR_RED)Healthcheck failed!$(COLOR_RESET)" && exit 1)
	echo "$(COLOR_GREEN)Validation passed.$(COLOR_RESET)"

help:
	sed -n 's/^#\( [a-zA-Z_-]\+\):.*##\(.*\)$$/\1:\t\2/p' $(MAKEFILE_LIST) | column -t -s $$'\t'

.PHONY: all up down clean fclean re build logs help validate
.DEFAULT_GOAL := help
.SILENT:
.NOTPARALLEL:
