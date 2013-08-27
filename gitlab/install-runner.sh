#!/usr/bin/env bash

## ========================
## Settings
## ========================

# Webproxy (just comment out the two following lines, if no proxy should be used)
#PROXY_HTTP=""
#PROXY_HTTPS=""
#PROXY_FTP=""

GITLABCI_HOST="localhost"
GITLABCI_PORT="9292"
GITLABCI_HTTP="http://localhost:9292/"

## ========================
## Configure proxy
## ========================

# configure proxy for APT and export it to environment
if [[ $PROXY_HTTP ]]; then
	export http_proxy=$PROXY_HTTP
fi
if [[ $PROXY_HTTPS ]]; then
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
## Install GitLab CI Runner
## ========================

aptitude install -y libicu-dev

# create gitlab_ci_runner user
adduser --disabled-login --gecos 'GitLab-CI-Runner' gitlab_ci_runner

# export proxy variables to vagrant user (if proxy is set)
if [[ $PROXY_HTTP ]]; then
	echo "export http_proxy=$PROXY_HTTP" >> /home/gitlab_ci_runner/.bashrc
fi
if [[ $PROXY_HTTPS ]]; then
	echo "export https_proxy=$PROXY_HTTPS" >> /home/gitlab_ci_runner/.bashrc
fi

# add ssh key from gitlab_ci machine to known_hosts
mkdir /home/gitlab_ci_runner/.ssh
ssh-keyscan -H $GITLABCI_HOST >> /home/gitlab_ci_runner/.ssh/known_hosts
chmod 700 /home/gitlab_ci_runner/.ssh

cd /home/gitlab_ci_runner

git clone https://github.com/gitlabhq/gitlab-ci-runner.git
cd gitlab-ci-runner

bundle install
chown -R gitlab_ci_runner:gitlab_ci_runner /home/gitlab_ci_runner

sudo -u gitlab_ci_runner -H bundle exec ./bin/install

cp lib/support/init.d/gitlab_ci_runner /etc/init.d/gitlab-ci-runner
chmod +x /etc/init.d/gitlab-ci-runner
update-rc.d gitlab-ci-runner defaults 21
service gitlab-ci-runner start

## ========================
## Exit
## ========================

exit 0
