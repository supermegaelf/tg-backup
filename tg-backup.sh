#!/bin/bash

read -p "Enter MySQL username: " MYSQL_USER
if [ -z "$MYSQL_USER" ]; then
    echo "Error: MySQL username cannot be empty"
    exit 1
fi

read -sp "Enter MySQL password: " MYSQL_PASSWORD
echo
if [ -z "$MYSQL_PASSWORD" ]; then
    echo "Error: MySQL password cannot be empty"
    exit 1
fi

read -p "Enter Telegram Bot Token: " TG_BOT_TOKEN
if [[ ! "$TG_BOT_TOKEN" =~ ^bot[0-9]+:[A-Za-z0-9_-]+$ ]]; then
    echo "Error: Invalid Telegram Bot Token format"
    exit 1
fi

read -p "Enter Telegram Chat ID: " TG_CHAT_ID
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
    if [[ "$db" == "marzban" ]]; then
        docker exec $MYSQL_CONTAINER_NAME mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
    fi
done

for db in $databases_shop; do
    if [[ "$db" == "shop" ]]; then
        docker exec marzban-shop-db-1 mariadb-dump -h 127.0.0.1 --force --opt --user="$MYSQL_USER" --password="$MYSQL_PASSWORD" --databases $db > /var/lib/marzban/mysql/db-backup/$db.sql
    fi
done

tar --exclude='/var/lib/marzban/mysql/*' --exclude='/var/lib/marzban/logs/*' \
    --exclude='/var/lib/marzban/access.log*' \
    --exclude='/var/lib/marzban/error.log*' \
    --exclude='/var/lib/marzban/xray-core/*' \
    -cf "$TEMP_DIR/backup-marzban.tar" \
    -C / \
    /opt/marzban/.env \
    /opt/marzban/ \
    /var/lib/marzban/
tar -rf "$TEMP_DIR/backup-marzban.tar" -C / /var/lib/marzban/mysql/db-backup/*
gzip "$TEMP_DIR/backup-marzban.tar"

curl -F chat_id="$TG_CHAT_ID" \
     -F caption=$'Main\n\nMarzban and Shop backup\n<code>188.245.93.215</code>\nhttps://dash.wetset.xyz/QVFy58j4ZS/' \
     -F parse_mode="HTML" \
     -F document=@"$BACKUP_FILE" \
     https://api.telegram.org/$TG_BOT_TOKEN/sendDocument \
&& rm -rf /var/lib/marzban/mysql/db-backup/*

rm -rf "$TEMP_DIR"
