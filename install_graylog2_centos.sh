#! /bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

#updated by Boardstretcher

#initial centos config
# update system 
yum update -y 
  
# disable ip6 
echo "" >> /etc/sysctl.conf 
echo "# Disable IPV6" >> /etc/sysctl.conf 
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf 
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf 
chkconfig ip6tables off 
chkconfig  iptables off 
  
# disable selinux 
sed -i 's/\=enforcing/\=disabled/g' /etc/selinux/config 

# reboot

# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/install_graylog2.err")
exec > >(tee "./graylog2/install_graylog2.log")

#
# Apache Settings
# Change x.x.x.x to whatever your ip address is of the server you are installing on or let the script auto detect your IP
# which is the default
#SERVERNAME="x.x.x.x"
#SERVERALIAS="x.x.x.x"
#

echo "Detecting IP Address"
IPADDY="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo "Detected IP Address is $IPADDY"

SERVERNAME=$IPADDY
SERVERALIAS=$IPADDY

# Adding EL6 Extra Packages
yum install -y elrepo-release 

# Installing all pre-reqs
yum install -y gcc gcc-c++ gd gd-devel glibc glibc-common glibc-devel glibc-headers make automake httpd httpd-devel wget tar vim nc libcurl-devel openssl-devel zlib-devel zlib patch readline readline-devel libffi-devel curl-devel libyaml-devel libtoolbisonlibxml2-devel libxslt-devel libtool bison

#install sun java (unless you like crashes, in that case use openjdk)
curl -L http://javadl.sun.com/webapps/download/AutoDL?BundleId=80804 -o java.rpm
rpm -ivh java.rpm

echo "Downloading Elasticsearch"
git clone https://github.com/elasticsearch/elasticsearch-servicewrapper.git
cd /opt
git clone https://github.com/elasticsearch/elasticsearch-servicewrapper.git

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.6.tar.gz
wget http://download.graylog2.org/graylog2-server/graylog2-server-0.11.0.tar.gz
wget http://download.graylog2.org/graylog2-web-interface/graylog2-web-interface-0.11.0.tar.gz

# Extract files
echo "Extracting Elasticsearch, Graylog2-Server and Graylog2-Web-Interface to /opt"

for f in *.tar.gz
do
tar zxf "$f"
done

# Create Symbolic Links
echo "Creating SymLinks for elasticsearch and graylog2-server"
ln -s elasticsearch-0.20.6/ elasticsearch
ln -s graylog2-server-0.11.0/ graylog2-server

# Install elasticsearch and start
echo "Installing elasticsearch"
mv *servicewrapper*/service elasticsearch/bin/
rm -Rf *servicewrapper*
/opt/elasticsearch/bin/service/elasticsearch install
ln -s `readlink -f elasticsearch/bin/service/elasticsearch` /usr/bin/elasticsearch_ctl
sed -i -e 's|# cluster.name: elasticsearch|cluster.name: graylog2|' /opt/elasticsearch/config/elasticsearch.yml
/etc/init.d/elasticsearch start

# Test elasticsearch
# curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

# Install mongodb
echo "Installing MongoDB"
(
cat <<'EOF'
[10gen]
name=10gen Repository
baseurl=http://downloads-distro.mongodb.org/repo/redhat/os/x86_64
gpgcheck=0
enabled=1
EOF
) | tee /etc/yum.repos.d/10gen.repo

yum install -y mongo-10gen-server && /etc/init.d/mongod start

#Install graylog2-server
echo "Installing graylog2-server"
cd graylog2-server-0.11.0/
cp /opt/graylog2-server/elasticsearch.yml{.example,}
ln -s /opt/graylog2-server/elasticsearch.yml /etc/graylog2-elasticsearch.yml
cp /opt/graylog2-server/graylog2.conf{.example,}
ln -s /opt/graylog2-server/graylog2.conf /etc/graylog2.conf
sed -i -e 's|mongodb_useauth = true|mongodb_useauth = false|' /opt/graylog2-server/graylog2.conf

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
chkconfig --add graylog2-server
chkconfig graylog2-server on
/etc/init.d/graylog2-server start

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.11.0 graylog2-web-interface

# Install Ruby
echo "Installing Ruby"
curl -L https://get.rvm.io | bash -s stable --ruby
source /usr/local/rvm/scripts/rvm

# Install Ruby Gems
echo "Installing Ruby Gems"
cd /opt/graylog2-web-interface
gem install bundle
gem update

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
echo "Creating MongoDB Users and Passwords"
mongo admin --eval "db.addUser('admin', 'password123')"
mongo admin --eval "db.auth('admin', 'password123')"
mongo graylog2 --eval "db.addUser('grayloguser', 'password123')"
mongo graylog2 --eval "db.auth('grayloguser', 'password123')"

useradd graylog2 -d /opt/graylog2-web-interface -G rvm
chown -R graylog2:graylog2 /opt/graylog2-web-interface
usermod -g rvm root
source /etc/profile.d/rvm.sh
bundle install

# Test Install
# cd /opt/graylog2-web-interface
# RAILS_ENV=production script/rails server

# Install Apache-passenger
echo "Installing Apache-Passenger Modules"
yum -y install curl-devel
gem install passenger
gem install file-tail
passenger-install-apache2-module --auto

# Add passenger modules for Apache2
echo "Adding Apache Passenger modules to /etc/httpd/conf.d/passenger.conf"
echo "LoadModule passenger_module /usr/local/rvm/gems/ruby-2.0.0-p247/gems/passenger-4.0.20/buildout/apache2/mod_passenger.so" | tee -a /etc/httpd/conf.d/passenger.conf
echo "PassengerRoot /usr/local/rvm/gems/ruby-2.0.0-p247/gems/passenger-4.0.20" | tee -a /etc/httpd/conf.d/passenger.conf
echo "PassengerDefaultRuby /usr/local/rvm/wrappers/ruby-2.0.0-p247/ruby" | tee -a /etc/httpd/conf.d/passenger.conf

# Assign permissions for Apache startup
chown -R apache:apache /opt/graylog2-web-interface
chkconfig httpd on

# Restart Apache2
echo "Restarting Apache2"
/etc/init.d/httpd restart

#If apache fails and complains about unable to load mod_passenger.so check and verify that your passengerroot version matches

# Configure virtualhost
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
</VirtualHost>" | tee -a /etc/httpd/conf/httpd.conf

# Enable virtualhost
echo "Enabling Apache VirtualHost Settings"

# Restart apache
echo "Restarting Apache2"
/etc/init.d/httpd restart

# Now we need to modify some things to get rsyslog to forward to graylog. this is useful for ESXi syslog format to be correct.
echo "Updating graylog2.conf, rsyslog.conf"
sed -i -e 's|syslog_listen_port = 514|syslog_listen_port = 10514|' /etc/graylog2.conf
sed -i -e 's|mongodb_password = 123|mongodb_password = password123|' /etc/graylog2.conf
sed -i -e 's|#$ModLoad immark|$ModLoad immark|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imudp|$ModLoad imudp|' /etc/rsyslog.conf
sed -i -e 's|#$UDPServerRun 514|$UDPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imtcp|$ModLoad imtcp|' /etc/rsyslog.conf
sed -i -e 's|#$InputTCPServerRun 514|$InputTCPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|*.*;auth,authpriv.none|#*.*;auth,authpriv.none|' /etc/rsyslog.conf
echo '$template GRAYLOG2,"<%PRI%>%HOSTNAME% %TIMESTAMP% %syslogtag% %APP-NAME% %msg%\n"' | tee /etc/rsyslog.d/32-graylog2.conf
echo '$ActionForwardDefaultTemplate GRAYLOG2' | tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '$PreserveFQDN on' | tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '*.* @localhost:10514' | tee -a  /etc/rsyslog.d/32-graylog2.conf

# Restart All Services
echo "Restarting All Services Required for Graylog2 to work"
service elasticsearch restart
service mongodb restart
service graylog2-server restart
service rsyslog restart
service apache2 restart

# All Done
echo "Installation has completed!!"
echo "Browse to IP address of this Graylog2 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://$IPADDY"
echo "You Entered $SERVERNAME During Install"
echo "Browse to http://$SERVERNAME If Different"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
