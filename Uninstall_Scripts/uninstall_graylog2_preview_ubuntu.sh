#!/bin/bash
# Provided by @mrlesmithjr
# EveryThingShouldBeVirtual.com
#
# Ubuntu Graylog2 Preview/RC Uninstall Script
set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/uninstall_graylog2.err")
exec > >(tee "./graylog2/uninstall_graylog2.log")
#
service rsyslog stop
service mongodb stop
service elasticsearch stop
service graylog2-web-interface stop
rm /etc/init.d/graylog2-web-interface
update-rc.d graylog2-web-interface remove
service graylog2-server stop
rm /etc/init.d/graylog2-server
update-rc.d graylog2-server remove
rm /etc/graylog2.conf
apt-get -y remove mongodb-10gen
apt-get -y purge mongodb-10gen
dpkg -r elasticsearch
dpkg -P elasticsearch
rm -rf /opt/graylog2-*
rm /etc/graylog2-server-node-id
rm -rf /var/lib/mongodb
