#!/bin/bash

port=$1
dbPath=$2
ssl=$3
baseDir=`echo ~`
keyFile="${baseDir}/keyfile"
baseFile="BASE.conf"
i=0
caFile=""
pemFile=""

startPort=$port

if [ -z "$port" ]
then
	echo "You must provide a port"
	exit 2
fi

if [ -z "$dbPath" ]
then
        echo "You must provide a name"
        exit 2
fi

if [ ! -d ${baseDir}/configs ]
then
	echo "Making configs directory..."
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

if [ ! -z "$ssl" ]
then
        echo "Looks like you want ssl..."
	read -p "What is the full path to the CA File?  " caFile
	read -p "What is the full path to the PEM file?  " pemFile
	baseFile="BASESSL.conf"
fi

while [ $i -le 2 ]
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
	echo "Created config ${baseDir}/configs/${dbPath}_${i}.conf to run on port ${port}"
	let "port=port+1"
done

if [ ! -f $keyFile ]
then
	echo "Making keyfile"
	openssl rand -base64 741 > $keyFile
fi

echo
echo

while true; do
    read -p "Should I start the RS? y/n?  " yn
    case $yn in
        y) 
		${baseDir}/configs/runRS.sh $dbPath;
		break
		;;
        n) 
		exit
		;;
        * ) 
		echo "Please answer yes or no."
		;;
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
		break               
                ;;
        n)
                exit
                ;;
        * )
                echo "Please answer yes or no."
                ;;
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
                break
                ;;
        n)
                exit
                ;;
        * )
                echo "Please answer yes or no."
                ;;
    esac
done

echo
echo

while true; do
    read -p "Should I add other nodes to RS? y/n?  " yn
    case $yn in
        y)
                sleep 1
		h1=`hostname`:`let "p1=startPort+1";echo $p1`
		h2=`hostname`:`let "p2=startPort+2";echo $p2`
		mongo --port $startPort --authenticationDatabase admin -u root -p root123 --eval "rs.add('$h1');rs.add('$h2');"
		mongo --port $startPort --authenticationDatabase admin -u root -p root123 --eval "rs.status();"
                break
                ;;
        n)
                exit
                ;;
        * )
                echo "Please answer yes or no."
                ;;
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
                break
                ;;
        n)
                exit
                ;;
        * )
                echo "Please answer yes or no."
                ;;
    esac
done
