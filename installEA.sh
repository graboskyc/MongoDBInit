#!/bin/bash

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    This utility will install MongoDB Enterprise Edition
# Deps:     Only supports Ubuntu
# Refs:     https://docs.mongodb.com/v3.6/tutorial/install-mongodb-enterprise-on-ubuntu/
#           https://github.com/graboskyc/MongoDBInit
######################################
baseDir=`echo ~`

echo -e "\nWARNING:\n\tThis setup is not suitable for a production deployment! \n"

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
        echo -e "\nAdding MongoDB key for apt"
        apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
        echo -e "\nAdding Enterprise package list"
        if [[ $release == "14.04" ]]; then
            echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu trusty/mongodb-enterprise/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
            echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu trusty/mongodb-enterprise/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
            echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu trusty/mongodb-enterprise/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
        elif [[ $release == "16.04" ]]; then
            echo "deb [ arch=amd64,arm64,ppc64el,s390x ] http://repo.mongodb.com/apt/ubuntu xenial/mongodb-enterprise/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
            echo "deb [ arch=amd64,arm64,ppc64el,s390x ] http://repo.mongodb.com/apt/ubuntu xenial/mongodb-enterprise/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
            echo "deb [ arch=amd64,arm64,ppc64el,s390x ] http://repo.mongodb.com/apt/ubuntu xenial/mongodb-enterprise/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
        elif [[ $release == "18.04" ]]; then
            echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu bionic/mongodb-enterprise/4.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
            echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu bionic/mongodb-enterprise/3.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
            echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu bionic/mongodb-enterprise/3.6 multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
        else
            echo "This release of Ubuntu is not supported. You have: ${release}"
            echo "For more instructions, visit https://docs.mongodb.com/manual/tutorial/install-mongodb-enterprise-on-ubuntu/"
            exit 4
        fi

        echo -e "\nUpdating package cache"
        apt-get update

        if [ -z $1 ]
        then
            echo -e "\n=============\nInstalling Latest Version of MongoDB Enterprise\n=============\n"
            apt-get install -y --allow-unauthenticated mongodb-enterprise
        else
            echo -e "\n=============\nInstalling Version ${1} of MongoDB Enterprise\n=============\n"
            apt-get install -y --allow-unauthenticated mongodb-enterprise=${1} mongodb-enterprise-server=${1} mongodb-enterprise-shell=${1} mongodb-enterprise-mongos=${1} mongodb-enterprise-tools=${1}
        fi

        # prompt for base or to be managed
        while true; do
            read -p "Should I use a config file (c) to launch or just fork it as-is c/f?  " yn
            case $yn in
                c) 
                    useradd mongodb
                    if [ ! -f ${baseDir}/configs/makeRSConfs.sh ]
                    then
                            echo "Downloading latest runRS.sh file..."
                            wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/makeRSConfs.sh -O ${baseDir}/configs/runRS.sh
                    fi
                    chmod +x ${baseDir}/configs/makeRSConfs.sh
                    yes n | ${baseDir}/configs/makeRSConfs.sh 27017 NORS 1
                    chown -R mongodb:mongodb ${baseDir}/NORS
                    cp ${baseDir}/configs/NORS_1.conf /etc/mongod.conf
                    sudo -u mongodb mongod -f /etc/mongod.conf
                    break;;
                f) 
                    mkdir /data/db
                    w=`whoami`
                    chown -R ${w}:${w} /data
                    mongod --fork --logpath /data/db/log.log --bind_ip 0.0.0.0

                    echo -e "\n\nNOTE:\n\tIf using Ops Manager later, you will need to use a config file and start this database with user mongodb with appropriate persmissions on that db folder\n"
                    
                    break;;
                * ) 
                    echo "Please answer c or f.";;
            esac
        done

        echo -e "\nComplete! \n\n"
else
    echo "Please re-run this script using sudo."
    exit 1
fi