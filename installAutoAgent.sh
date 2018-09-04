#!/bin/bash

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    This utility will add automation agent
# Deps:     Only supports Ubuntu 
# Refs:     https://docs.opsmanager.mongodb.com/current/tutorial/install-simple-test-deployment/
#           https://github.com/graboskyc/MongoDBInit
######################################

SERVER=""
APIKEY=""
GROUPID=""
CONFFILE="/etc/mongodb-mms/automation-agent.config"

function writeMsg {
    echo -e "\n====================="
    echo "| ${1}"
    echo "====================="
}

function downloadPreReqs {
    writeMsg "Installing wget"
    apt-get update
    apt-get install -Y wget
}

# Check if this is ubuntu
hash lsb_release 2>/dev/null || { echo >&2 "This script only supports Ubuntu with lsb_release"; exit 3; }

os=`lsb_release -a | grep Distributor | cut -d ":" -f 2 | sed -e 's/\t//g'`
release=`lsb_release -a | grep Release | cut -d ":" -f 2 | sed -e 's/\t//g'`

if [[ ! $os == "Ubuntu" ]]
then
    echo "This script only supports Ubuntu"
    exit 2
fi

# must run as root or sudo
if [ `id -u` -eq 0 ]
then

    while true; do
    read -p "What is the FQDN of the server?  Include http:// and :8080 " SERVER
        if [[ $SERVER == http* ]] && [[ $SERVER =~ .*:.* ]]
        then
            break
        fi
    done

    read -p "What is the MongoDB Ops Manager API Key used for this server? " APIKEY

    read -p "What is the Group ID (Project ID) for Ops Manager? " GROUPID

else
    echo "Please re-run this script using sudo."
    exit 1
fi

hash wget 2>/dev/null || { downloadPreReqs; }

writeMsg "Downloading and installing agent from server"
wget ${SERVER}/download/agent/automation/mongodb-mms-automation-agent-manager_5.4.9.5483-1_amd64.ubuntu1604.deb -O ~/autoagent.deb
dpkg -i ~/autoagent.deb

writeMsg "Modifying config"
sed -i "s/\(mmsGroupId *= *\).*/\1$GROUPID/" $CONFFILE
sed -i "s/\(mmsApiKey *= *\).*/\1$APIKEY/" $CONFFILE
sed -i "s|\(mmsBaseUrl *= *\).*|\1$SERVER|" $CONFFILE

echo 
grep -E 'mmsGroupId|mmsApiKey|mmsBaseUrl' $CONFFILE
echo

writeMsg "Creating users and data directories"
useradd mongodb
mkdir -p /data
chown mongodb:mongodb /data


writeMsg "Starting Automation Agent"
systemctl start mongodb-mms-automation-agent.service
systemctl | head -n 1
systemctl | grep mongodb-mms