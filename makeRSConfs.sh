#!/bin/bash

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    This utility will bring up a replica set based on user input. See help function.
# Deps:     Assumes mongod is installed
# Refs:     https://github.com/graboskyc/MongoDBInit
######################################

echo -e "\nWARNING:\n\tThis setup is not suitable for a production deployment! \n"

# user inputs
port=$1
dbPath=$2
ssl=$3

# global vars
baseDir=`echo ~`
keyFile="${baseDir}/keyfile"
baseFile="BASE.conf"
i=0
caFile=""
pemFile=""
nodes=3
startPort=$port

# function to print out usage help
function help {
        echo 
        echo "usage: ${0} <port> <rsname> <size> [--ssl]"
        echo
        echo "CLI tool to generate basic MongoDB config files and launch the instances. More advanced needs should use mtools mlaunch or manually editing the resulting configs."
        echo
        echo "Required Args:"
        echo -e "\t<port> - the number of the starting instance to use"
        echo -e "\t<name> - the name of the config and will be used by the replicaset"
        echo
        echo "Optional Args:"
        echo -e "\t<size> - number of nodes in replica set. if omitted, will use 3"
        echo -e "\t--ssl - Use an SSL config"
        echo
}

# if user requested help, run it and quit
if [[ $1 == "--help" ]]
then
        help
        exit 0
fi

# openssl is required to generate keyfiles
# so make sure its installed
hash openssl 2>/dev/null || { echo >&2 "openssl is not installed. try running apt-get install openssl or your equiv."; exit 3; }


# user must provide a port number and replica set name (dbpath)
# if not provided, exit with error
if [ -z "$port" ]
then
	echo "You must provide a port"
        help
	exit 2
fi

if [ -z "$dbPath" ]
then
        echo "You must provide a name"
        help
        exit 2
fi

# see if the files and directory structures this script needs
# are here. if not, pull latest from github
if [[ ! -d ${baseDir}/configs ]]
then
	echo "Making configs directory..."
        mkdir ${baseDir}/configs
fi

if [ ! -f ${baseDir}/configs/BASE.conf ]
then
	echo "Downloading latest BASE.conf file..."
	wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/BASE.conf -O ${baseDir}/configs/BASE.conf
fi

if [ ! -f ${baseDir}/configs/BASESSL.conf ]
then
	echo "Downloading latest BASESSL.conf file..."
	wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/BASESSL.conf -O ${baseDir}/configs/BASESSL.conf
fi

if [ ! -f ${baseDir}/configs/BASENOREPL.conf ]
then
	echo "Downloading latest BASENOREPL.conf file..."
	wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/BASENOREPL.conf -O ${baseDir}/configs/BASESSL.conf
fi

if [ ! -f ${baseDir}/configs/runRS.sh ]
then
        echo "Downloading latest runRS.sh file..."
        wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/runRS.sh -O ${baseDir}/configs/runRS.sh
fi

# don't want to do a whole optparse thing yet
# so if there is a third cli input, check to see if it is a number
# in that case, override the default replica set node count
# if the third cli arg is --ssl, prompt for ssl pem files
# and if the third cli arg was a number, check to see if there is a 4th
# arg and that is the --ssl flag to get pem files
if [ ! -z "$ssl" ]
then
        re='^[0-9]+$'
        if [[ $ssl =~ $re ]]
        then
                nodes=$ssl
                if [ ! -z $4 ]
                then
                        echo "Looks like you want ssl..."
                        read -p "What is the full path to the CA File?  " caFile
                        read -p "What is the full path to the PEM file?  " pemFile
                        baseFile="BASESSL.conf"
                fi
        else
                echo "Looks like you want ssl..."
                read -p "What is the full path to the CA File?  " caFile
                read -p "What is the full path to the PEM file?  " pemFile
                baseFile="BASESSL.conf" 
        fi
fi

if [ ${nodes} -eq 1 ]
then
        baseFile="BASENOREPL.conf"
fi

# create the config files from 0 to number of nodes provided
while [ $i -lt ${nodes} ]
do
	dbp=${baseDir}/${dbPath}/r$i
	mkdir -p ${baseDir}/${dbPath}/r$i
	let "i=i+1"
	cp ${baseDir}/configs/${baseFile} ${baseDir}/configs/${dbPath}_${i}.conf
	sed -i "s|##DBPATH##|$dbp|g" ${baseDir}/configs/${dbPath}_${i}.conf
	sed -i "s/##PORT##/$port/g" ${baseDir}/configs/${dbPath}_${i}.conf
	sed -i "s|##KEYFILE##|$keyFile|g" ${baseDir}/configs/${dbPath}_${i}.conf
	sed -i "s|##CAPATH##|$caFile|g" ${baseDir}/configs/${dbPath}_${i}.conf
	sed -i "s|##PEMPATH##|$pemFile|g" ${baseDir}/configs/${dbPath}_${i}.conf
        sed -i "s/##REPL##/$dbPath/g" ${baseDir}/configs/${dbPath}_${i}.conf
	echo "Created config ${baseDir}/configs/${dbPath}_${i}.conf to run on port ${port}"
	let "port=port+1"
done

# config files use keyfile so make one if it doesn't exist
if [ ! -f $keyFile ]
then
	echo "Making keyfile"
	openssl rand -base64 741 > $keyFile
fi

echo
echo

# prompt the user what we should do now
while true; do
    read -p "Should I start the RS? y/n?  " yn
    case $yn in
        y) 
		${baseDir}/configs/runRS.sh $dbPath ${nodes};
		break;;
        n) 
		exit;;
        * ) 
		echo "Please answer yes or no.";;
    esac
done


echo 
echo

while true; do
    read -p "Should I initiate the RS? y/n?  " yn
    case $yn in
        y)
		sleep 3
 		mongo --port $startPort --eval "rs.initiate();"
		break;;
        n)
                exit;;
        * )
                echo "Please answer yes or no.";;
    esac
done

echo
echo

while true; do
    read -p "Should I create a root user? y/n?  " yn
    case $yn in
        y)
                sleep 1
                mongo --port $startPort --eval "db = db.getSisterDB('admin');db.createUser({user:'root',pwd:'root123',roles:['root']});"
		echo "Created root user with un root and pw root123"
                break;;
        n)
                exit;;
        * )
                echo "Please answer yes or no.";;
    esac
done

echo
echo

while true; do
    read -p "Should I add other nodes to RS? y/n?  " yn
    case $yn in
        y)
                sleep 1
                i=0
                eval=""
                while [ $i -lt ${nodes} ]
                do
                        h=`hostname`:`let "p1=startPort+$i";echo $p1`
                        eval="${eval}rs.add('$h');"
                        let "i=i+1"
                done
                mongo --port $startPort --authenticationDatabase admin -u root -p root123 --eval "$eval"
                sleep 5
		mongo --port $startPort --authenticationDatabase admin -u root -p root123 --eval "rs.status();"
                break;;
        n)
                exit;;
        * )
                echo "Please answer yes or no.";;
    esac
done

echo
echo

while true; do
    read -p "Should I start the shell? y/n?  " yn
    case $yn in
        y)
                sleep 1
                mongo --port $startPort --authenticationDatabase "admin" -u root -p root123
                break;;
        n)
                exit;;
        * )
                echo "Please answer yes or no.";;
    esac
done
