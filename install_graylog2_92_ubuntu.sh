#!/bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

# Ubuntu Install Script

set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/install_graylog2.err")
exec > >(tee "./graylog2/install_graylog2.log")

#Setup Version
ELASTICSEARCH_VERSION="1.3.2"
GRAYLOG_SERVER_VERSION="0.92.0"
GRAYLOG_WEB_VERSION="0.92.0"

# Setup Pause function
function pause(){
   read -p "$*"
}

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
apt-get -y install git curl build-essential openjdk-7-jre pwgen wget

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
cd /opt
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ELASTICSEARCH_VERSION.deb
wget http://packages.graylog2.org/releases/graylog2-server/graylog2-server-$GRAYLOG_SERVER_VERSION.tgz
wget http://packages.graylog2.org/releases/graylog2-web-interface/graylog2-web-interface-$GRAYLOG_WEB_VERSION.tgz
# Extract files
echo "Extracting Graylog2-Server and Graylog2-Web-Interface to /opt"
  for f in *.*gz
do
tar zxf "$f"
done

# Create Symbolic Links
echo "Creating SymLink Graylog2-server"
ln -s graylog2-server-0.9*/ graylog2-server

# Install elasticsearch
echo "Installing elasticsearch"
dpkg -i elasticsearch-$ELASTICSEARCH_VERSION.deb
sed -i -e 's|#cluster.name: elasticsearch|cluster.name: graylog2|' /etc/elasticsearch/elasticsearch.yml

# Making elasticsearch start on boot
sudo update-rc.d elasticsearch defaults 95 10

# Restart elasticsearch
service elasticsearch restart

# Test elasticsearch
# curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

# Install mongodb
echo "Installing MongoDB"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | tee /etc/apt/sources.list.d/10gen.list
apt-get -qq update
apt-get -y install mongodb-10gen

# Waiting for MongoDB to start accepting connections on tcp/27017
echo "!!!*** Waiting for MongoDB to start accepting connections ***!!!"
echo "This could take a while so connection timeouts below are normal!"
while ! nc -vz localhost 27017; do sleep 1; done

# Making changes to /etc/security/limits.conf to allow more open files for elasticsearch
mv /etc/security/limits.conf /etc/security/limits.bak
grep -Ev "# End of file" /etc/security/limits.bak > /etc/security/limits.conf
echo "elasticsearch soft nofile 32000" >> /etc/security/limits.conf
echo "elasticsearch hard nofile 32000" >> /etc/security/limits.conf
echo "# End of file" >> /etc/security/limits.conf

# Install graylog2-server
echo "Installing graylog2-server"
echo -n "Enter a password to use for the admin account to login to the Graylog2 webUI: "
read adminpass
echo "You entered $adminpass (MAKE SURE TO NOT FORGET THIS PASSWORD!)"
pause 'Press [Enter] key to continue...'
cd graylog2-server/
cp /opt/graylog2-server/graylog2.conf{.example,}
mv graylog2.conf /etc/
#ln -s /opt/graylog2-server/graylog2.conf /etc/graylog2.conf
pass_secret=$(pwgen -s 96)
sed -i -e 's|password_secret =|password_secret = '$pass_secret'|' /etc/graylog2.conf
#root_pass_sha2=$(echo -n password123 | shasum -a 256)
admin_pass_hash=$(echo -n $adminpass|sha256sum|awk '{print $1}')
sed -i -e "s|root_password_sha2 =|root_password_sha2 = $admin_pass_hash|" /etc/graylog2.conf
sed -i -e 's|elasticsearch_shards = 4|elasticsearch_shards = 1|' /etc/graylog2.conf
sed -i -e 's|mongodb_useauth = true|mongodb_useauth = false|' /etc/graylog2.conf
sed -i -e 's|#elasticsearch_discovery_zen_ping_multicast_enabled = false|elasticsearch_discovery_zen_ping_multicast_enabled = false|' /etc/graylog2.conf
sed -i -e 's|#elasticsearch_discovery_zen_ping_unicast_hosts = 192.168.1.203:9300|elasticsearch_discovery_zen_ping_unicast_hosts = 127.0.0.1:9300|' /etc/graylog2.conf

# Setting new retention policy setting or Graylog2 Server will not start
sed -i 's|retention_strategy = delete|retention_strategy = close|' /etc/graylog2.conf

# This setting is required as of v0.20.2 in /etc/graylog2.conf
sed -i -e 's|#rest_transport_uri = http://192.168.1.1:12900/|rest_transport_uri = http://127.0.0.1:12900/|' /etc/graylog2.conf

# Create graylog2-server startup script
echo "Creating /etc/init.d/graylog2-server startup script"
(
cat <<'EOF'
#!/bin/bash

### BEGIN INIT INFO
# Provides:          graylog2-server
# Required-Start:    $elasticsearch
# Required-Stop:     $graylog2-web-interface
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start graylog2-server at boot time
# Description:       Starts graylog2-server using start-stop-daemon
### END INIT INFO

CMD=$1
NOHUP=`which nohup`

GRAYLOG2CTL_DIR="/opt/graylog2-server/bin"
GRAYLOG2_SERVER_JAR=graylog2-server.jar
GRAYLOG2_CONF=/etc/graylog2.conf
GRAYLOG2_PID=/tmp/graylog2.pid
LOG_FILE=log/graylog2-server.log

start() {
    echo "Starting graylog2-server ..."
    cd "$GRAYLOG2CTL_DIR/.."
#    sleep 2m
    $NOHUP java -jar ${GRAYLOG2_SERVER_JAR} -f ${GRAYLOG2_CONF} -p ${GRAYLOG2_PID} >> ${LOG_FILE} &
}

stop() {
    PID=`cat ${GRAYLOG2_PID}`
    echo "Stopping graylog2-server ($PID) ..."
    if kill $PID; then
        rm ${GRAYLOG2_PID}
    fi
}

restart() {
    echo "Restarting graylog2-server ..."
    stop
    start
}

status() {
    pid=$(get_pid)
    if [ ! -z $pid ]; then
        if pid_running $pid; then
            echo "graylog2-server running as pid $pid"
            return 0
        else
            echo "Stale pid file with $pid - removing..."
            rm ${GRAYLOG2_PID}
        fi
    fi

    echo "graylog2-server not running"
}

get_pid() {
    cat ${GRAYLOG2_PID} 2> /dev/null
}

pid_running() {
    kill -0 $1 2> /dev/null
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
    status)
        status
        ;;
    *)
        echo "Usage $0 {start|stop|restart|status}"
        RETVAL=1
esac
EOF
) | tee /etc/init.d/graylog2-server

# Make graylog2-server executable
chmod +x /etc/init.d/graylog2-server

# Start graylog2-server on bootup
echo "Making graylog2-server startup on boot"
update-rc.d graylog2-server defaults

echo "Starting graylog2-server"
service graylog2-server start

# Waiting for Graylog2-Server to start accepting requests on tcp/12900
echo "Waiting for Graylog2-Server to start!"
while ! nc -vz localhost 12900; do sleep 1; done

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.9*/ graylog2-web-interface

echo "Creating Graylog2-web-interface startup script"
(
cat <<'EOF'
#!/bin/sh

### BEGIN INIT INFO
# Provides:          graylog2-web-interface
# Required-Start:    $graylog2-server
# Required-Stop:     $graylog2-server
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start graylog2-server at boot time
# Description:       Starts graylog2-server using start-stop-daemon
### END INIT INFO

CMD=$1
NOHUP=`which nohup`
JAVA_CMD=/usr/bin/java
GRAYLOG2_WEB_INTERFACE_HOME=/opt/graylog2-web-interface

GRAYLOG2_WEB_INTERFACE_PID=/opt/graylog2-web-interface/RUNNING_PID

start() {
echo "Starting graylog2-web-interface ..."
#sleep 3m
$NOHUP /opt/graylog2-web-interface/bin/graylog2-web-interface &
}

stop() {
echo "Stopping graylog2-web-interface ($PID) ..."
PID=`cat ${GRAYLOG2_WEB_INTERFACE_PID}`
if kill $PID; then
        rm ${GRAYLOG2_WEB_INTERFACE_PID}
fi
}

restart() {
echo "Restarting graylog2-web-interface ..."
stop
start
}

status() {
    pid=$(get_pid)
    if [ ! -z $pid ]; then
        if pid_running $pid; then
            echo "graylog2-web-interface running as pid $pid"
            return 0
        else
            echo "Stale pid file with $pid - removing..."
            rm ${GRAYLOG2_WEB_INTERFACE_PID}
        fi
    fi

    echo "graylog2-web-interface not running"
}

get_pid() {
    cat ${GRAYLOG2_WEB_INTERFACE_PID} 2> /dev/null
}

pid_running() {
    kill -0 $1 2> /dev/null
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
        status)
                status
                ;;
*)
echo "Usage $0 {start|stop|restart|status}"
RETVAL=1
esac
EOF
) | tee /etc/init.d/graylog2-web-interface

# Make graylog2-web-interface executable
chmod +x /etc/init.d/graylog2-web-interface

# Start graylog2-web-interface on bootup
echo "Making graylog2-web-interface startup on boot"
update-rc.d graylog2-web-interface defaults

# Now we need to modify some things to get rsyslog to forward to graylog. this is useful for ESXi syslog format to be correct.
echo "Updating graylog2.conf and rsyslog.conf"
#sed -i -e 's|syslog_listen_port = 514|syslog_listen_port = 10514|' /etc/graylog2.conf
#sed -i -e 's|#$ModLoad immark|$ModLoad immark|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imudp|$ModLoad imudp|' /etc/rsyslog.conf
sed -i -e 's|#$UDPServerRun 514|$UDPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imtcp|$ModLoad imtcp|' /etc/rsyslog.conf
sed -i -e 's|#$InputTCPServerRun 514|$InputTCPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|*.*;auth,authpriv.none|#*.*;auth,authpriv.none|' /etc/rsyslog.d/50-default.conf
echo '$template GRAYLOG2-1,"<%PRI%>1 %timegenerated:::date-rfc3339% %hostname% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | tee /etc/rsyslog.d/32-graylog2.conf
echo '$template GRAYLOG2-2,"<%pri%>1 %timegenerated:::date-rfc3339% %fromhost% %app-name% %procid% %msg%\n"'  | tee -a /etc/rsyslog.d/32-graylog2.conf
echo '$template GRAYLOGRFC5424,"<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msg%\n"' | tee -a /etc/rsyslog.d/32-graylog2.conf
echo '$PreserveFQDN on' | tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '*.* @localhost:10514;GRAYLOG2-2' | tee -a  /etc/rsyslog.d/32-graylog2.conf
sed -i -e 's|graylog2-server.uris=""|graylog2-server.uris="http://127.0.0.1:12900/"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf
app_secret=$(pwgen -s 96)
sed -i -e 's|application.secret=""|application.secret="'$app_secret'"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf

# Fixing /opt/graylog2-web-interface Permissions
echo "Fixing Graylog2 Web Interface Permissions"
chown -R root:root /opt/graylog2*
#chown -R www-data:www-data /opt/graylog2-web-interface*

# Cleaning up /opt
echo "Cleaning up"
rm -f /opt/graylog2-server*.*gz
rm -f /opt/graylog2-web-interface*.*gz
rm -f /opt/elasticsearch-$ELASTICSEARCH_VERSION.deb

# Restart All Services
echo "Restarting All Services Required for Graylog2 to work"
# service elasticsearch restart
# service mongodb restart
service rsyslog restart

echo "Starting graylog2-web-interface"
service graylog2-web-interface start

# All Done
echo "Installation has completed!!"
echo "Browse to IP address of this Graylog2 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://$IPADDY:9000"
echo "Login with username: admin"
echo "Login with password: $adminpass"
echo "You Entered $SERVERNAME During Install"
echo "Browse to http://$SERVERNAME:9000 If Different"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
