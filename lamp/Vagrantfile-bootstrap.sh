#!/usr/bin/env bash

## ========================
## Settings
## ========================

# Webproxy (just comment out the two following lines, if no proxy should be used)
#PROXY_HTTP=""
#PROXY_HTTPS=""

# MySQL root password
MYSQL_ROOT_PASSWORD="root"

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

# update packages
aptitude update

# install packages
aptitude install -y vim
aptitude install -y curl
aptitude install -y git
aptitude install -y python-software-properties

## ========================
## Install LAMP server
## ========================

# set MySQL root password to root
echo debconf mysql-server/root_password password $MYSQL_ROOT_PASSWORD | debconf-set-selections
echo debconf mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD | debconf-set-selections

# install Apache, MySQL and PHP5
aptitude install -y apache2 php5 php5-mysql mysql-server
a2enmod rewrite
service apache2 restart

# make MySQL listen on all devices
sed -i /etc/mysql/my.cnf -e 's/127\.0\.0\.1/0\.0\.0\.0/g'
service mysql restart

# install common used extensions
aptitude install -y php5-intl php-apc php5-xdebug

## ========================
## Install some PEAR tools
## ========================

# install PEAR
aptitude install -y php-pear

# configure proxy for PEAR
if [[ $PROXY_HTTP ]]; then
	pear config-set http_proxy $PROXY_HTTP
fi

# install PHPUnit and PHP_CodeCoverage
pear config-set auto_discover 1
pear channel-discover pear.phpunit.de
pear channel-discover components.ez.no
pear install --alldeps pear.phpunit.de/PHPUnit
pear install --alldeps phpunit/PHP_CodeCoverage

# install PHP_CodeSniffer
pear install --alldeps PHP_CodeSniffer

## ========================
## Install composer
## ========================

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

## ========================
## Exit
## ========================

# set password of vagrant user to vagrant
echo -e "vagrant\nvagrant\n" | passwd vagrant

# export proxy variables to vagrant user (if proxy is set)
if [[ $PROXY_HTTP ]]; then
	echo "export http_proxy=$PROXY_HTTP" >> /home/vagrant/.bashrc
fi
if [[ $PROXY_HTTPS ]]; then
	echo "export https_proxy=$PROXY_HTTPS" >> /home/vagrant/.bashrc
fi

# display MySQL root credentials
echo "============================================="
echo "MySQL root username: root"
echo "MySQL root password: $MYSQL_ROOT_PASSWORD"
echo "============================================="

exit 0
