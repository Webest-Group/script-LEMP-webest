#!/bin/bash

# Các đường dẫn và biến
WEB_ROOT="/var/www"
PANEL_VERSION="1.0.0"
PANEL_SCRIPT="/usr/local/bin/webestvps"
NGINX_CONF="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"
MYSQL_ROOT_PASS="$(cat /root/.my.cnf | grep password | cut -d'=' -f2)" 