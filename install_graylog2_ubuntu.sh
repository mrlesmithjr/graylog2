#! /bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com
#
#
# Ubuntu Install Script
#
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/install_graylog2.err")
exec > >(tee "./graylog2/install_graylog2.log")
#
# Checking if running as root
# Do not run as root
txtrst=$(tput sgr0) # Text reset
txtred=$(tput setaf 1) # Red
if [[ $EUID -eq 0 ]];then
echo "DO NOT RUN AS ROOT or use SUDO"
echo "Now exiting...Hit Return"
echo "Run script as normal non-root user and without sudo"
exit 1
fi
txtrst=$(tput sgr0) # Text reset
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
sudo sed -i -e 's|deb cdrom:|# deb cdrom:|' /etc/apt/sources.list
sudo apt-get -qq update

# Install Pre-Reqs
sudo apt-get -y install git curl apache2 libcurl4-openssl-dev apache2-prefork-dev libapr1-dev libcurl4-openssl-dev apache2-prefork-dev libapr1-dev build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config python-software-properties software-properties-common

# Install Oracle Java 7
echo "Installing Oracle Java 7"
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get -qq update
sudo echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections
sudo apt-get -y install oracle-java7-installer

echo "Downloading Elasticsearch"
git clone https://github.com/elasticsearch/elasticsearch-servicewrapper.git
sudo chown -R $USER:$USER /opt
cd /opt
git clone https://github.com/elasticsearch/elasticsearch-servicewrapper.git

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.6.tar.gz
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
ln -s elasticsearch-0.20.6/ elasticsearch
#ln -s graylog2-server-0.11.0/ graylog2-server
ln -s graylog2-server-0.12.0/ graylog2-server

# Install elasticsearch
echo "Installing elasticsearch"
mv *servicewrapper*/service elasticsearch/bin/
rm -Rf *servicewrapper*
sudo /opt/elasticsearch/bin/service/elasticsearch install
sudo ln -s `readlink -f elasticsearch/bin/service/elasticsearch` /usr/bin/elasticsearch_ctl
sed -i -e 's|# cluster.name: elasticsearch|cluster.name: graylog2|' /opt/elasticsearch/config/elasticsearch.yml
/etc/init.d/elasticsearch start

# Test elasticsearch
# curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

# Install mongodb
echo "Installing MongoDB"
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | sudo tee /etc/apt/sources.list.d/10gen.list
sudo apt-get -qq update
sudo apt-get -y install mongodb-10gen

# Install graylog2-server
echo "Installing graylog2-server"
cd graylog2-server-0.12.0/
cp /opt/graylog2-server/elasticsearch.yml{.example,}
sudo ln -s /opt/graylog2-server/elasticsearch.yml /etc/graylog2-elasticsearch.yml
cp /opt/graylog2-server/graylog2.conf{.example,}
sudo ln -s /opt/graylog2-server/graylog2.conf /etc/graylog2.conf
sed -i -e 's|mongodb_useauth = true|mongodb_useauth = false|' /opt/graylog2-server/graylog2.conf

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
) | sudo tee /etc/init.d/graylog2-server

# Make graylog2-server executable
sudo chmod +x /etc/init.d/graylog2-server

# Start graylog2-server on bootup
echo "Making graylog2-server startup on boot"
sudo update-rc.d graylog2-server defaults

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.12.0 graylog2-web-interface

# Install Ruby
echo "Installing Ruby"
sudo apt-get -y install libgdbm-dev libffi-dev
\curl -L https://get.rvm.io | bash -s stable
source $HOME/.rvm/scripts/rvm
rvm install 1.9.2

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
passenger-install-apache2-module --auto

# Add passenger modules for Apache2
echo "Adding Apache Passenger modules to /etc/apache2/httpd.conf"
echo "LoadModule passenger_module $HOME/.rvm/gems/ruby-1.9.2-p320/gems/passenger-3.0.18/ext/apache2/mod_passenger.so" | sudo tee -a /etc/apache2/mods-available/passenger.load
echo "PassengerRoot $HOME/.rvm/gems/ruby-1.9.2-p320/gems/passenger-3.0.18" | sudo tee -a /etc/apache2/mods-available/passenger.conf
echo "PassengerRuby $HOME/.rvm/wrappers/ruby-1.9.2-p320/ruby" | sudo tee -a /etc/apache2/mods-available/passenger.conf

# Enable passenger modules
sudo a2enmod passenger

# Restart Apache2
echo "Restarting Apache2"
sudo /etc/init.d/apache2 restart
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
</VirtualHost>" | sudo tee /etc/apache2/sites-available/graylog2

# Enable virtualhost
echo "Enabling Apache VirtualHost Settings"
sudo a2dissite 000-default
sudo a2ensite graylog2
sudo service apache2 reload

# Restart apache
echo "Restarting Apache2"
sudo /etc/init.d/apache2 restart

# Now we need to modify some things to get rsyslog to forward to graylog. this is useful for ESXi syslog format to be correct.
echo "Updating graylog2.conf, rsyslog.conf"
sudo sed -i -e 's|syslog_listen_port = 514|syslog_listen_port = 10514|' /etc/graylog2.conf
sudo sed -i -e 's|mongodb_password = 123|mongodb_password = password123|' /etc/graylog2.conf
sudo sed -i -e 's|#$ModLoad immark|$ModLoad immark|' /etc/rsyslog.conf
sudo sed -i -e 's|#$ModLoad imudp|$ModLoad imudp|' /etc/rsyslog.conf
sudo sed -i -e 's|#$UDPServerRun 514|$UDPServerRun 514|' /etc/rsyslog.conf
sudo sed -i -e 's|#$ModLoad imtcp|$ModLoad imtcp|' /etc/rsyslog.conf
sudo sed -i -e 's|#$InputTCPServerRun 514|$InputTCPServerRun 514|' /etc/rsyslog.conf
sudo sed -i -e 's|*.*;auth,authpriv.none|#*.*;auth,authpriv.none|' /etc/rsyslog.d/50-default.conf
echo '$template GRAYLOG2,"<%PRI%>1 %timegenerated:::date-rfc3339% %HOSTNAME% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | sudo tee /etc/rsyslog.d/32-graylog2.conf
echo '$ActionForwardDefaultTemplate GRAYLOG2' | sudo tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '$PreserveFQDN on' | sudo tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '*.err;*.crit;*.alert;*.emerg;cron.*;auth,authpriv.* @localhost:10514' | sudo tee -a  /etc/rsyslog.d/32-graylog2.conf

#Fixing issue with secret_toke in /opt/graylog2-web-interface/config/initializers/secret_token.rb
sudo sed -i -e "s|Graylog2WebInterface::Application.config.secret_token = 'CHANGE ME'|Graylog2WebInterface::Application.config.secret_token = 'b356d1af93673e37d6e21399d033d77c15354849fdde6d83fa0dca19608aa71f2fcd9d1f2784fb95e9400d8eeaf6dd9584d8d35b8f0b5c231369a70aac5e5777'|" /opt/graylog2-web-interface/config/initializers/secret_token.rb

# Restart All Services
echo "Restarting All Services Required for Graylog2 to work"
sudo service elasticsearch restart
sudo service mongodb restart
sudo service graylog2-server restart
sudo service rsyslog restart
sudo service apache2 restart

# All Done
echo "Installation has completed!!"
echo "Browse to IP address of this Graylog2 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://$IPADDY"
echo "You Entered $SERVERNAME During Install"
echo "Browse to http://$SERVERNAME If Different"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
