#! /bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

# Ubuntu Install Script

set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/install_graylog2.err")
exec > >(tee "./graylog2/install_graylog2.log")

# Checking if running as root (10/16/2013 - No longer an issue - Should be ran as root or with sudo)
# Do not run as root
# if [[ $EUID -eq 0 ]];then
# echo "$(tput setaf 1)DO NOT RUN AS ROOT or use SUDO"
# echo "Now exiting...Hit Return"
# echo "$(tput setaf 3)Run script as normal non-root user and without sudo$(tput sgr0)"
# exit 1
# fi

echo "Detecting IP Address"
IPADDY="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo "Detected IP Address is $IPADDY"

SERVERNAME=$IPADDY
SERVERALIAS=$IPADDY

# Disable CD Sources in /etc/apt/sources.list
echo "Disabling CD Sources and Updating Apt Packages and Installing Pre-Reqs"
sed -i -e 's|deb cdrom:|# deb cdrom:|' /etc/apt/sources.list
apt-get -qq update

# Install Pre-Reqs
# apt-get -y install git curl libcurl4-openssl-dev libapr1-dev libcurl4-openssl-dev libapr1-dev build-essential openssl libreadline6 libreadline6-dev curl git-core zlib1g zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 libxml2-dev libxslt-dev autoconf libc6-dev ncurses-dev automake libtool bison subversion pkg-config python-software-properties software-properties-common openjdk-7-jre pwgen
apt-get -y install git curl build-essential openjdk-7-jre pwgen

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
cd /opt
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.7.deb
#wget https://github.com/Graylog2/graylog2-server/releases/download/0.20.0-preview.6/graylog2-server-0.20.0-preview.6.tgz
#wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.20.0-preview.6/graylog2-web-interface-0.20.0-preview.6.tgz
#wget https://github.com/Graylog2/graylog2-server/releases/download/0.20.0-preview.7/graylog2-server-0.20.0-preview.7.tgz
wget https://github.com/Graylog2/graylog2-server/releases/download/0.20.0-preview.8/graylog2-server-0.20.0-preview.8.tgz
#wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.20.0-preview.7/graylog2-web-interface-0.20.0-preview.7.tgz
wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.20.0-preview.8/graylog2-web-interface-0.20.0-preview.8.tgz

# Extract files
echo "Extracting Graylog2-Server and Graylog2-Web-Interface to /opt"
  for f in *.*gz
do
tar zxf "$f"
done

# Create Symbolic Links
echo "Creating SymLink Graylog2-server"
ln -s graylog2-server-0.2*/ graylog2-server

# Install elasticsearch
echo "Installing elasticsearch"
dpkg -i elasticsearch-0.90.7.deb
sed -i -e 's|# cluster.name: elasticsearch|cluster.name: graylog2|' /etc/elasticsearch/elasticsearch.yml
sed -i -e 's|# discovery\.zen\.ping\.multicast\.enabled: false|discovery\.zen\.ping\.multicast\.enabled: false|' /etc/elasticsearch/elasticsearch.yml
sed -i -e 's|# discovery\.zen\.ping\.unicast\.hosts: \[[^]]\+\]|discovery\.zen\.ping\.unicast\.hosts: \["192.168.1.203:9300"\]|' /etc/elasticsearch/elasticsearch.yml

# Test elasticsearch
# curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

# Install mongodb
echo "Installing MongoDB"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | tee /etc/apt/sources.list.d/10gen.list
apt-get -qq update
apt-get -y install mongodb-10gen

# Install graylog2-server
echo "Installing graylog2-server"
cd graylog2-server/
cp /opt/graylog2-server/graylog2.conf{.example,}
mv graylog2.conf /etc/
#ln -s /opt/graylog2-server/graylog2.conf /etc/graylog2.conf
pass_secret=$(pwgen -s 96)
sed -i -e 's|password_secret =|password_secret = '$pass_secret'|' /etc/graylog2.conf
#root_pass_sha2=$(echo -n password123 | shasum -a 256)
sed -i -e "s|root_password_sha2 =|root_password_sha2 = ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f|" /etc/graylog2.conf
sed -i -e 's|elasticsearch_shards = 4|elasticsearch_shards = 1|' /etc/graylog2.conf
sed -i -e 's|mongodb_useauth = true|mongodb_useauth = false|' /etc/graylog2.conf
sed -i -e 's|#elasticsearch_discovery_zen_ping_multicast_enabled = false|elasticsearch_discovery_zen_ping_multicast_enabled = false|' /etc/graylog2.conf
sed -i -e 's|#elasticsearch_discovery_zen_ping_unicast_hosts = 192.168.1.203:9300|elasticsearch_discovery_zen_ping_unicast_hosts = 127.0.0.1:9300|' /etc/graylog2.conf
# Setting new retention policy setting or Graylog2 Server will not start
sed -i 's|retention_strategy = delete|retention_strategy = close|' /etc/graylog2.conf

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.2*/ graylog2-web-interface

# Now we need to modify some things to get rsyslog to forward to graylog. this is useful for ESXi syslog format to be correct.
echo "Updating graylog2.conf and rsyslog.conf"
#sed -i -e 's|syslog_listen_port = 514|syslog_listen_port = 10514|' /etc/graylog2.conf
sed -i -e 's|#$ModLoad immark|$ModLoad immark|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imudp|$ModLoad imudp|' /etc/rsyslog.conf
sed -i -e 's|#$UDPServerRun 514|$UDPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imtcp|$ModLoad imtcp|' /etc/rsyslog.conf
sed -i -e 's|#$InputTCPServerRun 514|$InputTCPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|*.*;auth,authpriv.none|#*.*;auth,authpriv.none|' /etc/rsyslog.d/50-default.conf
echo '$template GRAYLOG2,"<%PRI%>1 %timegenerated:::date-rfc3339% %FROMHOST% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | tee /etc/rsyslog.d/32-graylog2.conf
echo '$ActionForwardDefaultTemplate GRAYLOG2' | tee -a  /etc/rsyslog.d/32-graylog2.conf
# echo '$PreserveFQDN on' | tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '*.info @localhost:10514' | tee -a  /etc/rsyslog.d/32-graylog2.conf
sed -i -e 's|graylog2-server.uris=""|graylog2-server.uris="http://127.0.0.1:12900/"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf
app_secret=$(pwgen -s 96)
sed -i -e 's|application.secret=""|application.secret="'$app_secret'"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf



# Fixing /opt/graylog2-web-interface Permissions
echo "Fixing Graylog2 Web Interface Permissions"
chown -R root:root /opt/graylog2*
#chown -R www-data:www-data /opt/graylog2-web-interface*

# Cleaning up /opt
echo "Cleaning up"
rm /opt/graylog2-server*.*gz
rm /opt/graylog2-web-interface*.*gz
rm /opt/elasticsearch-0.90.7.deb

# Restart All Services
echo "Restarting All Services Required for Graylog2 to work"
service elasticsearch restart
service mongodb restart
service rsyslog restart

# Starting Graylog2 Server
/opt/graylog2-server/bin/graylog2ctl start

# Starting Graylog2 Web Interface
echo "Waiting 2 Minutes for Graylog2 Server to start before starting web interface"
sleep 2m
nohup /opt/graylog2-web-interface/bin/graylog2-web-interface &

# All Done
echo "Installation has completed!!"
echo "Browse to IP address of this Graylog2 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://$IPADDY:9000"
echo "Login with username: admin"
echo "Login with password: password123"
echo "You Entered $SERVERNAME During Install"
echo "Browse to http://$SERVERNAME:9000 If Different"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
