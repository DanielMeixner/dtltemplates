#!/bin/bash

sudo apt-get update
sudo apt-get install curl python-software-properties
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

sudo npm install -g http-server

mkdir wwwpub
cd wwwpub
echo "Hello from a simple webserver running on " > index.html
httpserver --port 8080 &
