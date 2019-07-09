#!/bin/bash

# run on amazon2

sudo yum -y update
sudo yum -y install maven
java -version
mvn -version

wget https://github.com/johnlpage/POCDriver/archive/master.zip
unzip master.zip
cd POCDriver*
mvn clean package
cd bin
ls POCDriver.jar 
