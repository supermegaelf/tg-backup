#!/bin/bash

read -p "MySQL username (default is marzban, press Enter to use default): " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-marzban}
if [ -z "$MYSQL_USER" ]; then
    echo "Error: MySQL username cannot be empty"
    exit 1
fi

read -sp "MySQL password: " MYSQL_PASSWORD
echo
if [ -z "$MYSQL_PASSWORD" ]; then
    echo "Error: MySQL password cannot be empty"
    exit 1
fi

read -p "Telegram Bot Token: " TG_BOT_TOKEN
if [[ ! "$TG_BOT_TOKEN" =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
    echo "Error: Invalid Telegram Bot Token format"
    exit 1
fi

read -p "Telegram Chat ID: " TG_CHAT_ID
if [[ ! "$TG_CHAT_ID" =~ ^-?[0-9]+$ ]]; then
    echo "Error: Invalid Telegram Chat ID format"
    exit 1
fi

TEMP_DIR=$(mktemp -d)
if [ ! -d "$TEMP_DIR" ]; then
    echo "Error: Failed to create temporary directory"
    exit 1
fi
BACKUP_FILE="$TEMP_DIR/backup-marzban.tar.gz"

MYSQL_CONTAINER_NAME="marzban-mariadb-1"
if ! docker ps -q -f name="$MYSQL_CONTAINER_NAME" | grep -q .; then
    echo "Error: Container $MYSQL_CONTAINER_NAME is not running"
    rm -rf "$TEMP_DIR"
    exit 1
fi

databases_marzban=$(docker exec $MYSQL_CONTAINER_NAME mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | tr -d "| " | grep -v Database)
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve marzban databases"
    rm -rf "$TEMP_DIR"
    exit 1
fi

databases_shop=$(docker exec marzban-shop-db-1 mariadb -h 127.0.0.1 --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null | tr -d "| " | grep -v Database)
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve shop databases"
    rm -rf "$TEMP_DIR"
    exit 1
fi

for db in $databases_marzban; do
    if [[ "$db" ==
