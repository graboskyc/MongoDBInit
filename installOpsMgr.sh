#!/bin/bash

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    This utility will install Ops Manager
# Deps:     Only supports Ubuntu 
# Refs:     https://docs.opsmanager.mongodb.com/current/tutorial/install-simple-test-deployment/
#           https://www.mongodb.com/download-center/enterprise/releases
#           https://github.com/graboskyc/MongoDBInit
######################################

echo -e "\nWARNING:\n\tThis setup is not suitable for a production deployment! \n"

# must run as root or sudo
if [ `id -u` -ne 0 ]
then
    echo "Please re-run this script using sudo."
    exit 1
fi

# Check if this is ubuntu
hash lsb_release 2>/dev/null || { echo >&2 "This script only supports Ubuntu with lsb_release"; exit 3; }

os=`lsb_release -a | grep Distributor | cut -d ":" -f 2 | sed -e 's/\t//g'`
release=`lsb_release -a | grep Release | cut -d ":" -f 2 | sed -e 's/\t//g'`

if [[ ! $os == "Ubuntu" ]]
then
    echo "This script only supports Ubuntu"
    exit 2
fi

function downloadAndInstall {
    echo "MongoDB is not installed."
    if [ ! -f ~/installEA.sh ]
    then
        echo "Downloading EA install script"
        wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/installEA.sh -O ~/installEA.sh
    fi
    chmod +x ~/installEA.sh
    ~/installEA.sh
}

# turn off firewall
ufw disable

# DB must be installed first
hash mongod 2>/dev/null || { downloadAndInstall; }

# make required dirs and start mongod
w=`whoami`
mkdir -p /data/appdb
chown -R ${w}:${w} /data
mkdir -p /data/backup
chown ${w}:${w} /data/backup
mongod --port 27017 --dbpath /data/appdb --logpath /data/appdb/mongodb.log --wiredTigerCacheSizeGB 1 --fork

# download and install ops mgr
wget https://downloads.mongodb.com/on-prem-mms/deb/mongodb-mms_4.0.1.50101.20180801T1119Z-1_x86_64.deb -O ~/mongodbmms.deb

dpkg -i ~/mongodbmms.deb
service mongodb-mms start

echo "MongoDB Ops Manager is now running on the default port of 8080"