#! /bin/bash
#Provided by @mrlesmithjr
#EveryThingShouldBeVirtual.com
#
#
# Ubuntu Install Script
#


# Download Elasticsearch, Graylog2-Server and Graylog2-Web-Interface
echo "Downloading Elastic Search, Graylog2-Server and Graylog2-Web-Interface to /opt"
cd /opt
#wget https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-0.20.6.tar.gz
# wget https://github.com/Graylog2/graylog2-server/releases/download/0.12.0/graylog2-server-0.12.0.tar.gz
wget https://github.com/Graylog2/graylog2-server/archive/0.20.0-rc.1-1.tar.gz
# wget https://github.com/Graylog2/graylog2-web-interface/releases/download/0.12.0/graylog2-web-interface-0.12.0.tar.gz
wget https://github.com/Graylog2/graylog2-web-interface/archive/0.20.0-rc.1-1.tar.gz

# Extract files
echo "Extracting Elasticsearch, Graylog2-Server and Graylog2-Web-Interface to /opt"
for f in *.tar.gz
do
tar zxf "$f"
done