#!/usr/bin/env bash

## ========================
## Settings
## ========================

# Webproxy (just comment out the two following lines, if no proxy should be used)
#PROXY_HTTP=""
#PROXY_HTTPS=""

# Hadoop user and group
HADOOP_GROUP="hadoop"
HADOOP_USER="hadoop"

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
## Hadoop installation
## see http://hadoop.apache.org/docs/stable/single_node_setup.html
## ========================

# automatically accept Oracle License v1.1
echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections

# install Oracle Java PPA
aptitude install -y python-software-properties
sudo -E add-apt-repository -y ppa:webupd8team/java
aptitude update

# install Oracle Java 6 JDK and make it default Java environment
aptitude install -y oracle-java6-installer
update-java-alternatives -s java-6-oracle

# show Java VM information
java -version

# create group hadoop and user $HADOOP_USER
addgroup $HADOOP_GROUP
adduser --ingroup $HADOOP_GROUP --disabled-password --gecos "" $HADOOP_USER

# set password of $HADOOP_USER to $HADOOP_USER
echo -e "$HADOOP_USER\n$HADOOP_USER\n" | passwd $HADOOP_USER

# create an unencrpyted rsa keypair for user $HADOOP_USER and add it to its authorized keys
sudo -u $HADOOP_USER ssh-keygen -t rsa -P "" -f /home/$HADOOP_USER/.ssh/id_rsa
sudo -u $HADOOP_USER cp /home/$HADOOP_USER/.ssh/id_rsa.pub /home/$HADOOP_USER/.ssh/authorized_keys

# add localhost to $HADOOP_USER's SSH known hosts
sudo -u $HADOOP_USER touch /home/$HADOOP_USER/.ssh/known_hosts
ssh-keyscan -H localhost,127.0.0.1 >> /home/$HADOOP_USER/.ssh/known_hosts
ssh-keyscan -H localhost >> /home/$HADOOP_USER/.ssh/known_hosts
ssh-keyscan -H 127.0.0.1 >> /home/$HADOOP_USER/.ssh/known_hosts

# disable IPv6
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
cat /proc/sys/net/ipv6/conf/all/disable_ipv6

# download Hadoop
wget http://mirror.netcologne.de/apache.org/hadoop/core/hadoop-1.2.1/hadoop_1.2.1-1_x86_64.deb
dpkg -i hadoop_1.2.1-1_x86_64.deb

## ========================
## Hadoop configuration
## see http://hadoop.apache.org/docs/stable/single_node_setup.html
## ========================

# set JAVA_HOME variable to oracle java
sed -i /etc/hadoop/hadoop-env.sh -e 's/export JAVA_HOME=\/usr\/lib\/jvm\/java-6-sun/export JAVA_HOME=\/usr\/lib\/jvm\/java-6-oracle/g'

# format distributed file system
sudo -u $HADOOP_USER hadoop namenode -format

# configure Hadoop for pseudo-distributed operation
echo -e "<configuration>\n<property>\n<name>fs.default.name</name>\n<value>hdfs://localhost:9000</value>\n</property>\n</configuration>" > /etc/hadoop/core-site.xml
echo -e "<configuration>\n<property>\n<name>dfs.replication</name>\n<value>1</value>\n</property>\n</configuration>" > /etc/hadoop/hdfs-site.xml
echo -e "<configuration>\n<property>\n<name>mapred.job.tracker</name>\n<value>localhost:9001</value>\n</property>\n</configuration>" > /etc/hadoop/mapred-site.xml

# start Hadoop
sudo -u $HADOOP_USER start-all.sh

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

# display Hadoop user credentials
echo "============================================="
echo "Hadoop user username: $HADOOP_USER"
echo "Hadoop user password: $HADOOP_USER"
echo "============================================="

exit 0
