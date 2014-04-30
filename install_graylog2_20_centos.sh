#!/bin/bash -x
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

#updated by Boardstretcher

EPEL_REPO="/etc/yum.repos.d/epel.repo"

echo "Creating $EPEL_REPO"
cat << 'EOF' > ${EPEL_REPO}
[epel]
name=Extra Packages for Enterprise Linux 6 - $basearch
#baseurl=http://download.fedoraproject.org/pub/epel/6/$basearch
mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=epel-6&arch=$basearch
failovermethod=priority
enabled=1
gpgcheck=0
EOF

# update system 
yum update -y 
  
# disable ip6 
echo "" >> /etc/sysctl.conf 
echo "# Disable IPV6" >> /etc/sysctl.conf 
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf 
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf 
chkconfig ip6tables off
chkconfig  iptables off
/etc/init.d/iptables stop
/etc/init.d/ip6tables stop
  
# disable selinux 
sed -i 's/\=enforcing/\=disabled/g' /etc/selinux/config 

# reboot

# Setup logging
exec 2> >(tee "./graylog2/install_graylog2.err")
exec > >(tee "./graylog2/install_graylog2.log")

# Apache Settings
IPADDY="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
SERVERNAME=$IPADDY
SERVERALIAS=$IPADDY

# Installing all pre-reqs
yum install -y gcc gcc-c++ gd gd-devel glibc glibc-common glibc-devel glibc-headers make automake wget tar vim nc libcurl-devel openssl-devel zlib-devel zlib patch readline readline-devel libffi-devel curl-devel libyaml-devel libtoolbisonlibxml2-devel libxslt-devel libtool bison pwgen nc

#install sun java (unless you like crashes, in that case use openjdk)
curl -L http://javadl.sun.com/webapps/download/AutoDL?BundleId=80804 -o java.rpm
rpm -ivh java.rpm

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
cd /opt
wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.90.10.noarch.rpm
wget https://github.com/Graylog2/graylog2-server/releases/download/0.20.1/graylog2-server-0.20.1.tgz
wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.20.1/graylog2-web-interface-0.20.1.tgz

# Extract files
echo "Extracting Graylog2-Server and Graylog2-Web-Interface to /opt"
  for f in *.*gz
do
tar zxf "$f"
done

# Create Symbolic Links
echo "Creating SymLink Graylog2-server"
ln -s graylog2-server-0.2*/ graylog2-server

# Install elasticsearch and start
echo "Installing elasticsearch"
rpm -ivh elasticsearch-0.90.10.noarch.rpm
sed -i -e 's|# cluster.name: elasticsearch|cluster.name: graylog2|' /etc/elasticsearch/elasticsearch.yml

# Restart elasticsearch
service elasticsearch restart

# Test elasticsearch
# curl -XGET 'http://localhost:9200/_cluster/health?pretty=true'

# Install mongodb
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

# Waiting for MongoDB to start accepting connections on tcp/27017
echo "!!!*** Waiting for MongoDB to start accepting connections ***!!!"
echo "This could take a while so connection timeouts below are normal!"
while ! nc -vz localhost 27017; do sleep 1; done

# Install graylog2-server
echo "Installing graylog2-server"
cd graylog2-server/
cp /opt/graylog2-server/graylog2.conf{.example,}
mv graylog2.conf /etc/
pass_secret=$(pwgen -s 96)
sed -i -e 's|password_secret =|password_secret = '$pass_secret'|' /etc/graylog2.conf
sed -i -e "s|root_password_sha2 =|root_password_sha2 = ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f|" /etc/graylog2.conf
sed -i -e 's|elasticsearch_shards = 4|elasticsearch_shards = 1|' /etc/graylog2.conf
sed -i -e 's|mongodb_useauth = true|mongodb_useauth = false|' /etc/graylog2.conf
sed -i -e 's|#elasticsearch_discovery_zen_ping_multicast_enabled = false|elasticsearch_discovery_zen_ping_multicast_enabled = false|' /etc/graylog2.conf
sed -i -e 's|#elasticsearch_discovery_zen_ping_unicast_hosts = 192.168.1.203:9300|elasticsearch_discovery_zen_ping_unicast_hosts = 127.0.0.1:9300|' /etc/graylog2.conf

# Setting new retention policy setting or Graylog2 Server will not start
sed -i 's|retention_strategy = delete|retention_strategy = close|' /etc/graylog2.conf

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
chkconfig --add graylog2-server
chkconfig graylog2-server on
service graylog2-server start

# Waiting for Graylog2-Server to start accepting requests on tcp/12900
echo "Waiting for Graylog2-Server to start!"
while ! nc -vz localhost 12900; do sleep 1; done

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.2*/ graylog2-web-interface

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

# Start graylog2-server on bootup
chkconfig --add graylog2-web-interface
chkconfig graylog2-web-interface on

# Now we need to modify some things to get rsyslog to forward to graylog. this is useful for ESXi syslog format to be correct.
echo "Updating graylog2.conf and rsyslog.conf"
sed -i -e 's|#$ModLoad imudp|$ModLoad imudp|' /etc/rsyslog.conf
sed -i -e 's|#$UDPServerRun 514|$UDPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|#$ModLoad imtcp|$ModLoad imtcp|' /etc/rsyslog.conf
sed -i -e 's|#$InputTCPServerRun 514|$InputTCPServerRun 514|' /etc/rsyslog.conf
sed -i -e 's|*.*;auth,authpriv.none|#*.*;auth,authpriv.none|' /etc/rsyslog.d/50-default.conf
echo '$template GRAYLOG2,"<%PRI%>1 %timegenerated:::date-rfc3339% %hostname% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | tee /etc/rsyslog.d/32-graylog2.conf
echo '$template GRAYLOGRFC5424,"<%pri%>%protocol-version% %timestamp:::date-rfc3339% %HOSTNAME% %app-name% %procid% %msg%\n" | tee /etc/rsyslog.d/32-graylog2.conf
echo '$PreserveFQDN on' | tee -a  /etc/rsyslog.d/32-graylog2.conf
echo '*.* @localhost:10514;GRAYLOG2' | tee -a  /etc/rsyslog.d/32-graylog2.conf
sed -i -e 's|graylog2-server.uris=""|graylog2-server.uris="http://127.0.0.1:12900/"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf
app_secret=$(pwgen -s 96)
sed -i -e 's|application.secret=""|application.secret="'$app_secret'"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf

# Fixing /opt/graylog2-web-interface Permissions
echo "Fixing Graylog2 Web Interface Permissions"
chown -R root:root /opt/graylog2*

# Cleaning up /opt
echo "Cleaning up"
rm /opt/graylog2-server*.*gz
rm /opt/graylog2-web-interface*.*gz
rm /opt/elasticsearch-0.90.10.noarch.rpm

# Restart rsyslog
service rsyslog restart

echo "Starting graylog2-web-interface"
service graylog2-web-interface start

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
