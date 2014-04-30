#!/bin/bash

# Provided by @mrlesmithjr
# EveryThingShouldBeVirtual.com

# This will install logstash as a shipper to output to Graylog2 GELF Input UDP/12201 on another server

set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/install_logstash_apache_ubuntu.err")
exec > >(tee "./graylog2/install_logstash_apache_ubuntu.log")

# Setting colors for output
red="$(tput setaf 1)"
yellow="$(tput bold ; tput setaf 3)"
NC="$(tput sgr0)"

# Capture your FQDN Domain Name and IP Address
echo "${yellow}Capturing your domain name${NC}"
yourdomainname=$(dnsdomainname)
echo "${yellow}Capturing your FQDN${NC}"
yourfqdn=$(hostname -f)
echo "${yellow}Detecting IP Address${NC}"
IPADDY="$(ifconfig | grep -A 1 'eth0' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1)"
echo "Your domain name is currently ${red}$yourdomainname${NC}"
echo "Your FQDN is currently ${red}$yourfqdn${NC}"
echo "Detected IP Address is ${red}$IPADDY${NC}"

# Disable CD Sources in /etc/apt/sources.list
echo "Disabling CD Sources and Updating Apt Packages and Installing Pre-Reqs"
sed -i -e 's|deb cdrom:|# deb cdrom:|' /etc/apt/sources.list
apt-get -qq update

# Install Pre-Reqs
apt-get install -y --force-yes openjdk-7-jre-headless libcurl4-openssl-dev git

# Install Logstash 
mkdir /opt/logstash
cd /opt/logstash
wget https://download.elasticsearch.org/logstash/logstash/logstash-1.3.3-flatjar.jar
mv logstash-*.jar logstash.jar

# Create Logstash Init Script
(
cat <<'EOF'
#! /bin/sh
 
### BEGIN INIT INFO
# Provides:          logstash
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO
 
. /lib/lsb/init-functions
 
name="logstash"
logstash_bin="/usr/bin/java -- -jar /opt/logstash/logstash.jar"
logstash_conf="/etc/logstash/apache_logstash.conf"
logstash_log="/var/log/logstash.log"
pid_file="/var/run/$name.pid"
patterns_path="/etc/logstash/patterns"
 
start () {
        command="${logstash_bin} agent -f $logstash_conf --log ${logstash_log}"
 
        log_daemon_msg "Starting $name" "$name"
        if start-stop-daemon --start --quiet --oknodo --pidfile "$pid_file" -b -m --exec $command; then
                log_end_msg 0
        else
                log_end_msg 1
        fi
}
 
stop () {
        log_daemon_msg "Stopping $name" "$name"
        start-stop-daemon --stop --quiet --oknodo --pidfile "$pid_file"
}
 
status () {
        status_of_proc -p "$pid_file" "$name"
}
 
case $1 in
        start)
                if status; then exit 0; fi
                start
                ;;
        stop)
                stop
                ;;
        reload)
                stop
                start
                ;;
        restart)
                stop
                start
                ;;
        status)
                status && exit 0 || exit $?
                ;;
        *)
                echo "Usage: $0 {start|stop|restart|reload|status}"
                exit 1
                ;;
esac
 
exit 0
EOF
) | tee /etc/init.d/logstash

# Make logstash executable
chmod +x /etc/init.d/logstash

# Enable logstash start on bootup
update-rc.d logstash defaults

echo "Enter your Graylog2 server name or IP: "
read graylog2server

# Create Logstash configuration file
mkdir /etc/logstash
tee -a /etc/logstash/apache_logstash.conf <<EOF
input {
  file {
    path => "/var/log/apache2/*access.log"
    type => "apache"
    sincedb_path => "/var/log/.sincedb"
  }
}
 
filter {
  if [type] == "apache" {
    grok {
      pattern => "%{COMBINEDAPACHELOG}"
    }
  }
}
 
output {
  gelf { host => "$graylog2server" }
}
EOF

# Create grok pattern folder
mkdir -p /etc/logstash/patterns
cd /tmp
git clone https://github.com/logstash/logstash
cp /tmp/logstash/patterns/* /etc/logstash/patterns/

# Restart logstash service
service logstash restart

# All Done
echo "Installation has completed!!"
echo "${yellow}EveryThingShouldBeVirtual.com${NC}"
echo "${yellow}@mrlesmithjr${NC}"
echo "${yellow}Enjoy!!!${NC}"
