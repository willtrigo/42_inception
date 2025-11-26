#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

echo -e "${CYAN}=== Inception Project Setup ===${RESET}\n"

# Get user
USER=$(whoami)

# Check if .env exists
if [ ! -f "srcs/.env" ]; then
    echo -e "${RED}Error: srcs/.env not found!${RESET}"
    echo -e "${YELLOW}Please create it from the example:${RESET}"
    echo "cp srcs/.env.example srcs/.env"
    echo "Then edit srcs/.env with your values"
    exit 1
fi

echo -e "${GREEN}✓ Found srcs/.env${RESET}"

# Check secrets directory
if [ ! -d "secrets" ]; then
    echo -e "${YELLOW}Creating secrets directory...${RESET}"
    mkdir -p secrets
fi

# Check secret files
SECRETS_MISSING=0

if [ ! -f "secrets/db_root_password.txt" ]; then
    echo -e "${YELLOW}Creating secrets/db_root_password.txt...${RESET}"
    openssl rand -base64 32 > secrets/db_root_password.txt
    SECRETS_MISSING=1
fi

if [ ! -f "secrets/db_password.txt" ]; then
    echo -e "${YELLOW}Creating secrets/db_password.txt...${RESET}"
    openssl rand -base64 32 > secrets/db_password.txt
    SECRETS_MISSING=1
fi

if [ ! -f "secrets/wp_admin_password.txt" ]; then
    echo -e "${YELLOW}Creating secrets/wp_admin_password.txt...${RESET}"
    openssl rand -base64 32 > secrets/wp_admin_password.txt
    SECRETS_MISSING=1
fi

# Set proper permissions on secrets
chmod 644 secrets/*.txt
echo -e "${GREEN}✓ Secret files ready (permissions: 644)${RESET}"

if [ $SECRETS_MISSING -eq 1 ]; then
    echo -e "${CYAN}\nGenerated passwords:${RESET}"
    echo -e "  Root password:  $(cat secrets/db_root_password.txt)"
    echo -e "  DB password:    $(cat secrets/db_password.txt)"
    echo -e "  Admin password: $(cat secrets/wp_admin_password.txt)"
    echo -e "${YELLOW}\nNote: Save these passwords securely!${RESET}\n"
fi

# Create data directories
echo -e "${YELLOW}Creating data directories...${RESET}"
mkdir -p /home/${USER}/data/wordpress
mkdir -p /home/${USER}/data/mariadb

# Set permissions
echo -e "${YELLOW}Setting permissions (may require sudo)...${RESET}"
sudo chown -R ${USER}:${USER} /home/${USER}/data
sudo chmod -R 755 /home/${USER}/data

echo -e "${GREEN}✓ Data directories ready${RESET}"

# Check /etc/hosts
DOMAIN=$(grep DOMAIN_NAME srcs/.env | cut -d'=' -f2)
if ! grep -q "${DOMAIN}" /etc/hosts; then
    echo -e "${YELLOW}\nAdd this line to /etc/hosts:${RESET}"
    echo -e "  ${CYAN}127.0.0.1  ${DOMAIN}${RESET}"
    echo -e "\nRun: ${YELLOW}sudo nano /etc/hosts${RESET}"
else
    echo -e "${GREEN}✓ Domain ${DOMAIN} found in /etc/hosts${RESET}"
fi

echo -e "\n${GREEN}=== Setup Complete ===${RESET}"
echo -e "\nNext steps:"
echo -e "  1. ${CYAN}make build${RESET}  - Build Docker images"
echo -e "  2. ${CYAN}make up${RESET}     - Start containers"
echo -e "  3. ${CYAN}make logs${RESET}   - Watch logs"
echo -e "\nAccess your site at: ${CYAN}https://${DOMAIN}${RESET}\n"
