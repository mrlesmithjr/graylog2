#!/bin/bash -x

# Install MondoDB

sudo apt-get install mongodb-server

# Install Elastic Search
wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
sudo apt-get update && sudo apt-get install elasticsearch
sudo update-rc.d elasticsearch defaults 95 10

# Installing Graylog 2 Components

wget https://packages.graylog2.org/repo/packages/graylog-1.3-repository-ubuntu14.04_latest.deb
sudo dpkg -i graylog-1.3-repository-ubuntu14.04_latest.deb
sudo apt-get install apt-transport-https
sudo apt-get update
sudo apt-get install graylog-server graylog-web
