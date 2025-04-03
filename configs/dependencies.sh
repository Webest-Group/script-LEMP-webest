#!/bin/bash

# Danh sách các gói cần cài đặt
BASIC_PACKAGES=(
    "curl"
    "wget"
    "git"
    "unzip"
)

NGINX_PACKAGES=(
    "nginx"
)

MARIADB_PACKAGES=(
    "mariadb-server"
    "mariadb-client"
)

PHP_PACKAGES=(
    "software-properties-common"
    "php8.1-fpm"
    "php8.1-mysql"
    "php8.1-curl"
    "php8.1-gd"
    "php8.1-mbstring"
    "php8.1-xml"
    "php8.1-zip"
    "php8.1-intl"
)

OTHER_PACKAGES=(
    "redis-server"
    "supervisor"
) 