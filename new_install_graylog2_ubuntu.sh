#! /bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com
#
#
# Ubuntu Install Script
#
set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/install_graylog2.err")
exec > >(tee "./graylog2/install_graylog2.log")
#
# Checking if running as root
# Do not run as root
#if [[ $EUID -eq 0 ]];then
#echo "$(tput setaf 1)DO NOT RUN AS ROOT or use SUDO"
#echo "Now exiting...Hit Return"
#echo "$(tput setaf 3)Run script as normal non-root user and without sudo$(tput sgr0)"
#exit 1
#fi
# Apache Settings
# change x.x.x.x to whatever your ip address is of the server you are installing on or let the script auto detect your IP
# which is the default
# SERVERNAME="x.x.x.x"
# SERVERALIAS="x.x.x.x"
#
#
echo "Detecting IP Address"
IPADDY="$(sudo ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo "Detected IP Address is $IPADDY"

SERVERNAME=$IPADDY
SERVERALIAS=$IPADDY

# Disable CD Sources in /etc/apt/sources.list
echo "Disabling CD Sources and Updating Apt Packages and Installing Pre-Reqs"
sed -i -e 's|deb cdrom:|# deb cdrom:|' /etc/apt/sources.list
apt-get -qq update

# Install Pre-Reqs
apt-get -y install git curl apache2 libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libcurl4-openssl-dev apache2-prefork-dev libapr1-dev build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config python-software-properties software-properties-common

# Install Oracle Java 7
# echo "Installing Oracle Java 7"
# add-apt-repository -y ppa:webupd8team/java
# apt-get -qq update
# echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections
# apt-get -y install oracle-java7-installer

#echo "Downloading Elasticsearch"
#sudo chown -R $USER:$USER /opt
#cd /opt
#git clone https://github.com/elasticsearch/elasticsearch-servicewrapper.git

# Install Java
apt-get -y install --force-yes openjdk-7-jre-headless

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
cd /opt
#wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.6.tar.gz
wget https://github.com/Graylog2/graylog2-server/releases/download/0.12.0/graylog2-server-0.12.0.tar.gz
wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.12.0/graylog2-web-interface-0.12.0.tar.gz

# Extract files
echo "Extracting Elasticsearch, Graylog2-Server and Graylog2-Web-Interface to /opt"
for f in *.tar.gz
do
tar zxf "$f"
done

# Create Symbolic Links
echo "Creating SymLinks for elasticsearch and graylog2-server"
#ln -s elasticsearch-0.20.6/ elasticsearch
#ln -s graylog2-server-0.11.0/ graylog2-server
ln -s graylog2-server-0.12.0/ graylog2-server

# Install elasticsearch
#echo "Installing elasticsearch"
#mv *servicewrapper*/service elasticsearch/bin/
#rm -Rf *servicewrapper*
#sudo /opt/elasticsearch/bin/service/elasticsearch install
#sudo ln -s `readlink -f elasticsearch/bin/service/elasticsearch` /usr/bin/elasticsearch_ctl
#sed -i -e 's|# cluster.name: elasticsearch|cluster.name: graylog2|' /opt/elasticsearch/config/elasticsearch.yml
#/etc/init.d/elasticsearch start

# Install Elasticsearch
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.5.deb
dpkg -i elasticsearch-0.90.5.deb

sed -i '$a\cluster.name: "default-cluster"' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\node.name: "elastic-master"' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\discovery.zen.ping.multicast.enabled: false' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\discovery.zen.ping.unicast.hosts: ["127.0.0.1:[9300-9400]"]' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\node.master: true' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\node.data: true' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\index.number_of_shards: 1' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\index.number_of_replicas: 0' /etc/elasticsearch/elasticsearch.yml
sed -i '$a\bootstrap.mlockall: true' /etc/elasticsearch/elasticsearch.yml
service elasticsearch restart

# Test elasticsearch
# curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

# Install mongodb
echo "Installing MongoDB"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | sudo tee /etc/apt/sources.list.d/10gen.list
apt-get -qq update
apt-get -y install mongodb-10gen

# Install graylog2-server
echo "Installing graylog2-server"
cd graylog2-server-0.12.0/
cp /opt/graylog2-server/elasticsearch.yml{.example,}
ln -s /opt/graylog2-server/elasticsearch.yml /etc/graylog2-elasticsearch.yml
cp /opt/graylog2-server/graylog2.conf{.example,}
ln -s /opt/graylog2-server/graylog2.conf /etc/graylog2.conf
sed -i -e 's|mongodb_useauth = true|mongodb_useauth = false|' /opt/graylog2-server/graylog2.conf
# sed -i -e 's|elasticsearch_config_file = /etc/graylog2-elasticsearch.yml|elasticsearch_config_file = /etc/elasticsearch/elasticsearch.yml|' /opt/graylog2-server/graylog2.conf
# Create graylog2-server startup script
echo "Creating /etc/init.d/graylog2-server startup script"
(
cat <<'EOF'
#!/bin/sh
#
# graylog2-server: graylog2 message collector
#
# chkconfig: - 98 02
# description: This daemon listens for syslog and GELF messages and stores them in mongodb
#
CMD=$1
NOHUP=`which nohup`
JAVA_CMD=/usr/bin/java
GRAYLOG2_SERVER_HOME=/opt/graylog2-server
start() {
 echo "Starting graylog2-server ..."
$NOHUP $JAVA_CMD -jar $GRAYLOG2_SERVER_HOME/graylog2-server.jar > /var/log/graylog2.log 2>&1 &
}

stop() {
PID=`cat /tmp/graylog2.pid`
echo "Stopping graylog2-server ($PID) ..."
kill $PID
}

restart() {
echo "Restarting graylog2-server ..."
stop
start
}

case "$CMD" in
start)
start
;;
stop)
stop
;;
restart)
restart
;;
*)
echo "Usage $0 {start|stop|restart}"
RETVAL=1
esac
EOF
) | tee /etc/init.d/graylog2-server

# Make graylog2-server executable
chmod +x /etc/init.d/graylog2-server

# Start graylog2-server on bootup
echo "Making graylog2-server startup on boot"
update-rc.d graylog2-server defaults

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.12.0 graylog2-web-interface

# Install Ruby
echo "Installing Ruby"
apt-get -y install libgdbm-dev libffi-dev ruby1.9.3

# Install Ruby Gems
echo "Installing Ruby Gems"
cd /opt/graylog2-web-interface
gem install bundler --no-ri --no-rdoc
bundle install

# Set MongoDB Settings
echo "Configuring MongoDB"
echo "
production:
 host: localhost
 port: 27017
 username: grayloguser
 password: password123
 database: graylog2" | tee /opt/graylog2-web-interface/config/mongoid.yml

# Create MongoDB Users and Set Passwords
echo Creating MongoDB Users and Passwords
mongo admin --eval "db.addUser('admin', 'password123')"
mongo admin --eval "db.auth('admin', 'password123')"
mongo graylog2 --eval "db.addUser('grayloguser', 'password123')"
mongo graylog2 --eval "db.auth('grayloguser', 'password123')"

# Test Install
# cd /opt/graylog2-web-interface
# RAILS_ENV=production script/rails server

# Install Apache-passenger
echo Installing Apache-Passenger Modules
gem install passenger
/var/lib/gems/1.9.1/gems/passenger-4.0.21/bin/passenger-install-apache2-module --auto

# Add passenger modules for Apache2
echo "Adding Apache Passenger modules to /etc/apache2/httpd.conf"
echo "LoadModule passenger_module /var/lib/gems/1.9.1/gems/passenger-4.0.21/buildout/apache2/mod_passenger.so" | tee -a /etc/apache2/mods-available/passenger.load
echo "PassengerRoot /var/lib/gems/1.9.1/gems/passenger-4.0.21" | tee -a /etc/apache2/mods-available/passenger.conf
echo "PassengerRuby /usr/bin/ruby1.9.1" | tee -a /etc/apache2/mods-available/passenger.conf

# Enable passenger modules
a2enmod passenger

# Restart Apache2
echo "Restarting Apache2"
service apache2 restart
# If apache fails and complains about unable to load mod_passenger.so check and verify that your passengerroot version matches

# Configure Apache virtualhost
echo "Configuring Apache VirtualHost"
echo "
<VirtualHost *:80>
ServerName ${SERVERNAME}
ServerAlias ${SERVERALIAS}
DocumentRoot /opt/graylog2-web-interface/public

#Allow from all
Options -MultiViews

ErrorLog /var/log/apache2/error.log
LogLevel warn
CustomLog /var/log/apache2/access.log combined
</VirtualHost>" | tee /etc/apache2/sites-available/graylog2

# Enable virtualhost
echo "Enabling Apache VirtualHost Settings"
a2dissite 000-default
a2ensite graylog2
service apache2 reload

# Restart apache
echo "Restarting Apache2"
service apache2 restart

# Now we need to modify some things to get rsyslog to forward to graylog. this is useful for ESXi syslog format to be correct.
echo "Updating graylog2.conf, rsyslog.conf"
sed -i -e 's|syslog_listen_port = 514|syslog_listen_port = 10514|' /etc/graylog2.conf
sed -i -e 's|mongodb_password = 123|mongodb_password = password123|' /etc/graylog2.conf
sed -i -e 's|#$ModLoad immark|$ModLoad immark|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imudp|$ModLoad imudp|' /etc/rsyslog.conf
sed -i -e 's|#$UDPServerRun 514|$UDPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imtcp|$ModLoad imtcp|' /etc/rsyslog.conf
sed -i -e 's|#$InputTCPServerRun 514|$InputTCPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|*.*;auth,authpriv.none|#*.*;auth,authpriv.none|' /etc/rsyslog.d/50-default.conf
# echo '$template GRAYLOG2,"<%PRI%>1 %timegenerated:::date-rfc3339% %HOSTNAME% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | sudo tee /etc/rsyslog.d/32-graylog2.conf
#echo '$template GRAYLOG2,"<%PRI%>1 %timegenerated:::date-rfc3339% %FROMHOST% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | sudo tee /etc/rsyslog.d/32-graylog2.conf
#echo '$ActionForwardDefaultTemplate GRAYLOG2' | tee -a  /etc/rsyslog.d/32-graylog2.conf
#echo '$PreserveFQDN on' | tee -a  /etc/rsyslog.d/32-graylog2.conf
#echo '*.err;*.crit;*.alert;*.emerg;cron.*;auth,authpriv.* @localhost:10514' | sudo tee -a  /etc/rsyslog.d/32-graylog2.conf
# Log syslog levels info and above
# echo '*.info @localhost:10514' | tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '*.* @localhost:5544' | tee -a /etc/rsyslog.d/50-default.conf

#Fixing issue with secret_token in /opt/graylog2-web-interface/config/initializers/secret_token.rb
sed -i -e "s|Graylog2WebInterface::Application.config.secret_token = 'CHANGE ME'|Graylog2WebInterface::Application.config.secret_token = 'b356d1af93673e37d6e21399d033d77c15354849fdde6d83fa0dca19608aa71f2fcd9d1f2784fb95e9400d8eeaf6dd9584d8d35b8f0b5c231369a70aac5e5777'|" /opt/graylog2-web-interface/config/initializers/secret_token.rb

chown -R root:root /opt/elasticsearch*
chown -R root:root /opt/graylog2*
chown -R www-data:www-data /opt/graylog2-web-interface
chown -R www-data:www-data /opt/graylog2-web-interface/

# Cleaning up /opt
echo "Cleaning up"
# rm /opt/elasticsearch*.tar.gz
rm /opt/graylog2-server*.tar.gz
rm /opt/graylog2-web-interface*.tar.gz

# Restart All Services
echo "Restarting All Services Required for Graylog2 to work"
service elasticsearch restart
service mongodb restart
service graylog2-server restart
service rsyslog restart
service apache2 restart

# Install Logstash 
gem install fpm
cd ~
git clone https://github.com/Yuav/logstash-packaging.git --depth=1
cd logstash-packaging
./package.sh
cd ..
dpkg -i logstash_*.deb
sed -i -e 's|export JAVA_HOME=/usr/lib/jvm/default-java|export JAVA_HOME=/usr/lib/jvm/java-7-openjdk-amd64|' /etc/init.d/logstash
(
cat <<'EOF'
input {
udp {
type => "syslog"
port => "5544"
}
}


filter {
grep {
type => "syslog"
match => [ "@message", "dhclient:" ]
negate => true
}
}

output {
elasticsearch {
embedded => false
host => "127.0.0.1"
}
output {
  stdout { }
  gelf {
    facility => "logstash-gelf"
    host => '127.0.0.1'
  }
}
EOF
) | sudo tee /etc/logstash/logstash.conf

rm /etc/logstash/syslog.conf

service logstash restart

# Install and configure the Kibana frontend
cd /opt
git clone --branch=kibana-ruby https://github.com/rashidkpc/Kibana.git
cd /opt/Kibana
sed -i 's#KibanaHost =.*#KibanaHost = "0.0.0.0"#' KibanaConfig.rb
sed -i 's#KibanaPort =.*#KibanaPort = 8080#' KibanaConfig.rb
gem install bundler
bundle install

# Create Kibana conf file
tee -a /etc/init/kibana.conf <<EOF
# Kibana
#

description Kibana:"logstash frontend"

start on virtual-filesystems
stop on runlevel [06]

respawn
respawn limit 5 30

chdir /opt/Kibana

console log

script
  exec ruby kibana.rb
end script
EOF

initctl reload-configuration
start kibana

# All Done
echo "Installation has completed!!"
echo "Browse to IP address of this Graylog2 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://$IPADDY"
echo "You Entered $SERVERNAME During Install"
echo "Browse to http://$SERVERNAME If Different"
echo "Browse to http://$IPADDY:8080 to access Kibana/logstash"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
