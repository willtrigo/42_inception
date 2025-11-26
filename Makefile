# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    Makefile                                           :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: dande-je <dande-je@student.42sp.org.br>    +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2025/11/23 14:13:45 by dande-je          #+#    #+#              #
#    Updated: 2025/11/26 01:22:22 by dande-je         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #

#******************************************************************************#
#                                   COLOR                                      #
#******************************************************************************#

RED                             := \033[0;31m
GREEN                           := \033[0;32m
YELLOW                          := \033[0;33m
PURPLE                          := \033[0;35m
CYAN                            := \033[0;36m
RESET                           := \033[0m

#******************************************************************************#
#                                PROJECT VARS                                  #
#******************************************************************************#

COMPOSE_PATH      := srcs/
COMPOSE_FILE      ?= $(COMPOSE_PATH)docker-compose.yml
PROJECT_NAME      ?= inception
USER              ?= $(shell whoami)
DOMAIN            ?= $(shell grep DOMAIN_NAME srcs/.env 2>/dev/null | cut -d '=' -f2-)
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
#                                  FUNCTION                                    #
#******************************************************************************#

define env_check
	@if [ ! -f $(COMPOSE_PATH).env ]; then \
		printf "$(RED)Error: .env missing. Run: cp .env.example .env && edit it.$(RESET)\n"; \
		exit 1; \
	fi
	@grep -q "DOMAIN_NAME=" $(COMPOSE_PATH).env || \
		(printf "$(RED)Error: DOMAIN_NAME not set in .env.$(RESET)\n" && exit 1)
	@printf "$(GREEN)✓ .env validated.$(RESET)\n"
endef

define build
	@printf "$(YELLOW)Creating host volume directories...$(RESET)\n"
	@mkdir -p $(VOLUMES_DIRECTORY)
	@printf "$(YELLOW)Setting permissions (sudo required)...$(RESET)\n"
	@sudo chown -R $(USER):$(USER) $(VOLUMES_DIRECTORY)
	@sudo chmod -R 755 $(VOLUMES_DIRECTORY)
	@printf "$(GREEN)✓ Volume directories ready$(RESET)\n"
	@printf "$(YELLOW)Building Docker images...$(RESET)\n"
	@$(COMPOSE) build --parallel --no-cache --pull
	@printf "$(GREEN)✓ Build complete$(RESET)\n"
endef

define up
	@printf "$(YELLOW)Ensuring volume directories exist...$(RESET)\n"
	@mkdir -p $(VOLUMES_DIRECTORY)
	@printf "$(YELLOW)Starting containers...$(RESET)\n"
	@$(COMPOSE) up -d --remove-orphans
	@printf "$(GREEN)✓ Infrastructure up: https://$(DOMAIN)$(RESET)\n"
endef

define down
	@printf "$(YELLOW)Stopping containers...$(RESET)\n"
	@$(COMPOSE) down --remove-orphans --timeout 30
	@printf "$(YELLOW)✓ Containers down; volumes intact.$(RESET)\n"
endef

define stop
	@printf "$(YELLOW)Stopping containers...$(RESET)\n"
	@$(COMPOSE) stop
	@printf "$(YELLOW)✓ Containers stopped; volumes intact.$(RESET)\n"
endef

define clean
	@printf "$(YELLOW)Cleaning containers and images...$(RESET)\n"
	@$(COMPOSE) down --rmi local --volumes --remove-orphans --timeout 30
	@docker system prune -f --filter label=project=$(PROJECT_NAME) 2>/dev/null || true
	@printf "$(YELLOW)✓ Cleaned (volumes preserved).$(RESET)\n"
endef

define fclean
	@printf "$(YELLOW)Performing full cleanup...$(RESET)\n"
	@$(COMPOSE) down --remove-orphans --timeout 30 2>/dev/null || true
	@printf "$(YELLOW)Removing Docker volumes...$(RESET)\n"
	@docker volume ls -q -f "name=$(PROJECT_NAME)" 2>/dev/null | xargs -r docker volume rm -f 2>/dev/null || true
	@printf "$(YELLOW)Pruning Docker resources...$(RESET)\n"
	@docker network prune -f 2>/dev/null || true
	@docker system prune -af 2>/dev/null || true
	@printf "$(YELLOW)Removing host volume directories (sudo required)...$(RESET)\n"
	@sudo rm -rf $(VOLUMES_DIRECTORY) 2>/dev/null || true
	@printf "$(RED)✓ Full clean complete.$(RESET)\n"
endef

define logs
	@$(COMPOSE) logs -f --tail=100
endef

define ps
	@$(COMPOSE) ps
endef

define validate
	@$(COMPOSE) config --quiet
	@$(COMPOSE) ps | grep -q healthy || \
		(printf "$(RED)Healthcheck failed!$(RESET)\n" && exit 1)
	@printf "$(GREEN)✓ Validation passed.$(RESET)\n"
endef

define help
	grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "$(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
endef

#******************************************************************************#
#                                   TARGETS                                    #
#******************************************************************************#

.DEFAULT_GOAL := help

all: build up ## Build and start all services

env-check:
	$(call env_check)

build: env-check ## Build Docker images with validation
	$(call build)

up: ## Start containers in detached mode
	$(call up)

down: ## Stop and remove containers
	$(call down)

stop: ## Stop containers without removing
	$(call stop)

clean: down ## Remove containers and prune system
	$(call clean)

fclean: clean ## Full cleanup including volumes and data
	$(call fclean)

re: fclean all ## Rebuild everything from scratch

logs: ## Display container logs (follow mode)
	$(call logs)

ps: ## List running containers
	$(call ps)

validate: ## Validate configuration and health
	$(call validate)

help: ## Display available targets with descriptions
	$(call help)

.PHONY: all build env-check up down stop clean fclean re logs ps validate help
.SILENT:
.NOTPARALLEL:
