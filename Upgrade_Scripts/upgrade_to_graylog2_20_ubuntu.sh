#!/bin/bash
# Provided by @mrlesmithjr
# EveryThingShouldBeVirtual.com
#
# Ubuntu Graylog2 Preview/RC Upgrade to Final v0.20.0 Script
set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/upgrade_graylog2.err")
exec > >(tee "./graylog2/upgrade_graylog2.log")

service graylog2-web-interface stop
rm /etc/init.d/graylog2-web-interface
update-rc.d graylog2-web-interface remove
service graylog2-server stop
rm /etc/init.d/graylog2-server
update-rc.d graylog2-server remove
mv /etc/graylog2.conf /etc/graylog2.bak
rm -rf /opt/graylog2-*
# rm /etc/graylog2-server-node-id

echo "Detecting IP Address"
IPADDY="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo "Detected IP Address is $IPADDY"

SERVERNAME=$IPADDY
SERVERALIAS=$IPADDY

# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
cd /opt
wget https://github.com/Graylog2/graylog2-server/releases/download/0.20.3/graylog2-server-0.20.3.tgz
wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.20.3/graylog2-web-interface-0.20.3.tgz

# Extract files
echo "Extracting Graylog2-Server and Graylog2-Web-Interface to /opt"
  for f in *.*gz
do
tar zxf "$f"
done

# Reconfigure graylog2-server startup
update-rc.d -f graylog2-server remove
update-rc.d graylog2-server defaults 96 04

# Create Symbolic Links
echo "Creating SymLink Graylog2-server"
ln -s graylog2-server-0.2*/ graylog2-server

# Making changes to /etc/security/limits.conf to allow more open files for elasticsearch
mv /etc/security/limits.conf /etc/security/limits.bak
grep -Ev "# End of file" /etc/security/limits.bak > /etc/security/limits.conf
echo "elasticsearch soft nofile 32000" >> /etc/security/limits.conf
echo "elasticsearch hard nofile 32000" >> /etc/security/limits.conf
echo "# End of file" >> /etc/security/limits.conf

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

# Create graylog2-server startup script
echo "Creating /etc/init.d/graylog2-server startup script"
(
cat <<'EOF'
#!/bin/bash

### BEGIN INIT INFO
# Provides: graylog2-server
# Required-Start: $elasticsearch
# Required-Stop: $graylog2-web-interface
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start graylog2-server at boot time
# Description: Starts graylog2-server using start-stop-daemon
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
# sleep 2m
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

# Install graylog2 web interface
echo "Installing graylog2-web-interface"
cd /opt/
ln -s graylog2-web-interface-0.2*/ graylog2-web-interface

echo "Creating Graylog2-web-interface startup script"
(
cat <<'EOF'
#!/bin/sh

### BEGIN INIT INFO
# Provides: graylog2-web-interface
# Required-Start: $graylog2-server
# Required-Stop: $graylog2-server
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start graylog2-server at boot time
# Description: Starts graylog2-server using start-stop-daemon
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
echo "Updating graylog2.conf and rsyslog"
echo '$template GRAYLOG2,"<%PRI%>1 %timegenerated:::date-rfc3339% %hostname% %syslogtag% - %APP-NAME%: %msg:::drop-last-lf%\n"' | tee /etc/rsyslog.d/32-graylog2.conf
echo '$ActionForwardDefaultTemplate GRAYLOG2' | tee -a /etc/rsyslog.d/32-graylog2.conf
echo '$PreserveFQDN on' | tee -a /etc/rsyslog.d/32-graylog2.conf
echo '*.info @localhost:10514' | tee -a /etc/rsyslog.d/32-graylog2.conf
sed -i -e 's|graylog2-server.uris=""|graylog2-server.uris="http://127.0.0.1:12900/"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf
app_secret=$(pwgen -s 96)
sed -i -e 's|application.secret=""|application.secret="'$app_secret'"|' /opt/graylog2-web-interface/conf/graylog2-web-interface.conf

# Fixing /opt/graylog2-web-interface Permissions
echo "Fixing Graylog2 Web Interface Permissions"
chown -R root:root /opt/graylog2*
# chown -R www-data:www-data /opt/graylog2-web-interface*

# Cleaning up /opt
echo "Cleaning up"
rm /opt/graylog2-server*.*gz
rm /opt/graylog2-web-interface*.*gz

echo "Starting graylog2-web-interface"
service graylog2-web-interface start

# All Done
echo "Upgrade has completed!!"
echo "Browse to IP address of this Graylog2 Server Used for Installation"
echo "IP Address detected from system is $IPADDY"
echo "Browse to http://$IPADDY:9000"
echo "Login with username: admin"
echo "Login with password: password123"
echo "You Entered $SERVERNAME During Install"
echo "Browse to http://$SERVERNAME:9000 If Different"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
