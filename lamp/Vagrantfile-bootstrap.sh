#!/usr/bin/env bash

## ========================
## Settings
## ========================

# Webproxy (just comment out the two following lines, if no proxy should be used)
PROXY_HTTP=""
PROXY_HTTPS=""

## ========================
## Permission
## ========================

# assert that this script is run with root rights
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

## ========================
## Configure proxy
## ========================

# configure proxy for APT and export it to environment
if [[ $PROXY_HTTP ]]; then
	echo "Acquire::http::Proxy \"$PROXY_HTTP\";" >> /etc/apt/apt.conf.d/01proxy
	export http_proxy=$PROXY_HTTP
fi
if [[ $PROXY_HTTPS ]]; then
	echo "Acquire::https::Proxy \"$PROXY_HTTPS\";" >> /etc/apt/apt.conf.d/01proxy
	export https_proxy=$PROXY_HTTPS
fi

## ========================
## Install basics
## ========================

aptitude update
aptitude install -y vim python-software-properties git

## ========================
## Install LAMP server
## ========================

# set MySQL root password to root
echo debconf mysql-server/root_password password root | debconf-set-selections
echo debconf mysql-server/root_password_again password root | debconf-set-selections

# install Apache, MySQL and PHP5
aptitude install -y apache2 php5 php5-mysql mysql-server

# exit
exit 0
