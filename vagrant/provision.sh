#!/bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com

# Change to the password that you would like to use for logging into Graylog2
password="password123"

apt-get update
apt-get install -y git

# Pull down latest graylog2 install scripts
git clone https://github.com/mrlesmithjr/graylog2

# Change password123 below to a different password for graylog2 login
sed -i -e 's|#adminpass=|adminpass='$password'|' ./graylog2/install_graylog2_90_ubuntu.sh
sed -i -e 's|echo -n "Enter a password to use for the admin account to login to the Graylog2 webUI: "|#echo -n "Enter a password to use for the admin account to login to the Graylog2 webUI: "|' ./graylog2/install_graylog2_90_ubuntu.sh
sed -i -e 's|read adminpass|#read adminpass|' ./graylog2/install_graylog2_90_ubuntu.sh
sed -i -e 's|pause 'Press [Enter] key to continue...'|#pause 'Press [Enter] key to continue...'|' ./graylog2/install_graylog2_90_ubuntu.sh
chmod +x ./graylog2/install_graylog2_90_ubuntu.sh
./graylog2/install_graylog2_90_ubuntu.sh
rm -rf ./graylog2
