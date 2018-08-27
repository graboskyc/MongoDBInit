#!/bin/bash

## make sure we stop all running mongod and count that none are left
# ignoring the grep
killall mongod 1>/dev/null 2>&1
sleep 1
mCt=`ps aux | grep -c mongod`
let "mCt = mCt - 1"

# override default 3 node rs to user-entered data
nodes=3
if [[ ! -z $2 ]]
then
    nodes=$2
fi

# replica set name is name of config file. if not provided, quit
if [ -z "$1" ]
then
    "You must provide the name of the replica set"
    exit 2
fi

echo
echo "+=============================================+"
echo "| Running mongod count: ${mCt}"
echo "+=============================================+"
echo
echo "Starting mongod"
echo

# start the mongod processes
i=0
while [ $i -lt ${nodes} ]
do
    let "i=i+1"
    echo "Starting using ${1}_${i}.conf"
    mongod -f ${1}_${i}.conf 
done

# count how many mongod are running, ignoring the grep
mCt=`ps aux | grep -c mongod`
let "mCt = mCt - 1"

echo
echo "+=============================================+"
echo "| Running mongod count: ${mCt}"
echo "+=============================================+"
echo