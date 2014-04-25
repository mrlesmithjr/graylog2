#!/bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

# Ubuntu Uninstall Script for Graylog2 v.0.12.0

set -e
# Setup logging
# Logs stderr and stdout to separate files.
exec 2> >(tee "./graylog2/uninstall_graylog2.err")
exec > >(tee "./graylog2/uninstall_graylog2.log")

# Stop All Services
echo "Stopping All Services Required for Graylog2 to work"
service elasticsearch stop
service mongodb stop
service graylog2-server stop
service rsyslog stop
service apache2 stop

# Disable virtualhost
echo "Disabling Apache VirtualHost Settings"
a2ensite 000-default
a2dissite graylog2
service apache2 reload
rm /etc/apache2/sites-available/graylog2

# Disable passenger modules
echo "Enabling Apache Passenger module"
a2dismod passenger
rm /etc/apache2/mods-available/passenger.conf
rm /etc/apache2/mods-available/passenger.load

# Uninstall all Ruby Gems
for i in `gem list --no-versions`; do gem uninstall -aIx $i; done

# Uninstall graylog2-server
rm /etc/init.d/graylog2-server
update-rc.d graylog2-server remove
rm /etc/graylog2.conf

# Remove /opt/graylog2*
rm /etc/graylog2-elasticsearch.yml
rm -rf /opt/graylog2*

# Uninstall elasticsearch
/opt/elasticsearch/bin/service/elasticsearch remove
rm -rf /opt/elasticsearch*

# Uninstall MongoDB
apt-get -y remove mongodb-10gen
apt-get -y purge mongodb-10gen

# Cleanup rsyslog
rm /etc/rsyslog.d/32-graylog2.conf
service rsyslog restart

# Remove old package dependencies
apt-get remove -y apache2 apache2-prefork-dev apache2-prefork-dev pkg-config python-software-properties software-properties-common

# All Done
echo "Uninstall has completed!!"
echo "EveryThingShouldBeVirtual.com"
echo "@mrlesmithjr"
