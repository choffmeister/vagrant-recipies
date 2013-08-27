#!/usr/bin/env bash

## ========================
## Settings
## ========================

# Webproxy (just comment out the two following lines, if no proxy should be used)
#PROXY_HTTP=""
#PROXY_HTTPS=""
#PROXY_FTP=""

# MySQL root password
MYSQL_ROOT_PASSWORD="root"

GITLAB_HOST="localhost"
GITLAB_PORT="8080"
GITLAB_HTTP="http://localhost:8080/"
GITLAB_HTTP_ESCAPED="http:\/\/localhost:8080\/"
GITLABCI_HOST="localhost"
GITLABCI_PORT="9292"
GITLABCI_HTTP="http://localhost:9292/"

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
if [[ $PROXY_FTP ]]; then
	export ftp_proxy=$PROXY_FTP
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

# upgrade git
add-apt-repository -y ppa:git-core/ppa
aptitude update
aptitude upgrade -y git

## ========================
## Install MySQL database
## ========================

# set MySQL root password to root
echo debconf mysql-server/root_password password $MYSQL_ROOT_PASSWORD | debconf-set-selections
echo debconf mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD | debconf-set-selections

# install MySQL
aptitude install -y mysql-server mysql-client libmysqlclient-dev

## ========================
## Install Ruby
## ========================

# install build tools
aptitude install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev

# install Ruby 2.0.0
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
cd ruby-2.0.0-p247
./configure
make
make install
gem install bundler --no-ri --no-rdoc

## ========================
## Install Postfix
## ========================

# set Postfix configuration
echo debconf postfix/mailname string '$GITLAB_HOST' | debconf-set-selections
echo debconf postfix/main_mailer_type string 'Internet Site' | debconf-set-selections

# install Postfix
aptitude install -y postfix

## ========================
## Install GitLab
## ========================

# create database
mysql -uroot -p$MYSQL_ROOT_PASSWORD < /vagrant/database-gitlab.sql

# install reStructured text support
aptitude install -y python-docutils

# create git user
adduser --disabled-login --gecos 'GitLab' git
cd /home/git

# install GitLab shell
git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
git checkout v1.7.0
cp config.yml.example config.yml
sed -i config.yml -e "s/gitlab_url: \"http:\/\/localhost\/\"/gitlab_url: \"$GITLAB_HTTP_ESCAPED\"/g"
chown -R git:git ./
sudo -u git -H ./bin/install

# install GitLab
cd /home/git
git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd gitlab
git checkout 6-0-stable
cp config/gitlab.yml.example config/gitlab.yml
sed -i config/gitlab.yml -e "s/    port: 80/    port: $GITLAB_PORT/g"

# Make sure GitLab can write to the needed directories
mkdir /home/git/gitlab-satellites
mkdir /home/git/repositories
mkdir public/uploads
mkdir tmp/pids/
mkdir tmp/sockets/
sudo chmod -R ug+rwX,o-rwx /home/git/repositories/
sudo chmod -R ug-s /home/git/repositories/
find /home/git/repositories/ -type d -print0 | sudo xargs -0 chmod g+s
chmod -R u+rwX public/uploads/
chmod -R u+rwX log/
chmod -R u+rwX tmp/

# Copy the example Unicorn config
cp config/unicorn.rb.example config/unicorn.rb

# configure git
sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "gitlab@$GITLAB_HOST"
sudo -u git -H git config --global core.autocrlf input

# configure database
cp config/database.yml.mysql config/database.yml
sed -i config/database.yml -e 's/username: root/username: gitlab/g'
sed -i config/database.yml -e 's/password: "secure password"/password: "gitlab"/g'
chmod o-rwx config/database.yml

# install
gem install charlock_holmes --version '0.6.9.4'
bundle install --deployment --without development test postgres aws

# set file owner
chown -R git:git /home/git

# bootstrap
echo yes | sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

# configure init script
cp lib/support/init.d/gitlab /etc/init.d/gitlab
chmod +x /etc/init.d/gitlab
update-rc.d gitlab defaults 21

# start gitlab
service gitlab start

# show info
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

## ========================
## Install GitLab CI
## ========================

# create database
mysql -uroot -p$MYSQL_ROOT_PASSWORD < /vagrant/database-gitlab_ci.sql

# create gitlab_ci user
adduser --disabled-login --gecos 'GitLab CI' gitlab_ci
cd /home/gitlab_ci

# install GitLab CI
git clone https://github.com/gitlabhq/gitlab-ci.git
cd gitlab-ci
git checkout 3-1-stable

# configure gitlab url into gitlab_ci
cp config/application.yml.example config/application.yml
sed -i config/application.yml -e "s/    - 'https:\/\/dev.gitlab.org\/'/    - '$GITLAB_HTTP_ESCAPED'/g"
sed -i config/application.yml -e "s/    - 'https:\/\/staging.gitlab.org\/'//g"

# configure gitlab_ci to listen on port 9292
cp config/puma.rb.example config/puma.rb
sed -i config/puma.rb -e "s/# bind 'tcp.*/bind 'tcp:\/\/0.0.0.0:$GITLABCI_PORT'/g"
sed -i config/puma.rb -e 's/bind "unix/# bind "unix/g'

mkdir -p tmp/sockets/
mkdir -p tmp/pids/
chmod -R u+rwX tmp/sockets/
chmod -R u+rwX tmp/pids/

# configure database
cp config/database.yml.mysql config/database.yml
sed -i config/database.yml -e 's/username: root/username: gitlab_ci/g'
sed -i config/database.yml -e 's/password: "secure password"/password: "gitlab_ci"/g'
chmod o-rwx config/database.yml

# install
bundle --without development test postgres --deployment

# set file owner
chown -R gitlab_ci:gitlab_ci /home/gitlab_ci

# bootstrap
sudo -u gitlab_ci -H bundle exec rake db:setup RAILS_ENV=production
sudo -u gitlab_ci -H bundle exec whenever -w RAILS_ENV=production

# configure init script
wget https://raw.github.com/gitlabhq/gitlab-ci/3-1-stable/lib/support/init.d/gitlab_ci -P /etc/init.d/
chmod +x /etc/init.d/gitlab_ci
update-rc.d gitlab_ci defaults 21

# start gitlab_ci
service gitlab_ci start

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
echo "GitLab admin username: root"
echo "GitLab admin password: 5iveL!fe"
echo "============================================="

exit 0
