#!/bin/bash

killall mongod 1>/dev/null 2>&1
sleep 1
mCt=`ps aux | grep -c mongod`
let "mCt = mCt - 1"
nodes=3

if [[ ! -z $2 ]]
then
    nodes=$2
fi

echo
echo "+=============================================+"
echo "| Running mongod count: ${mCt}"
echo "+=============================================+"
echo
echo "Starting mongod"
echo

i=0
while [ $i -lt ${nodes} ]
do
    let "i=i+1"
    echo "Starting using ${1}_${i}.conf"
    mongod -f ${1}_${i}.conf 
done

mCt=`ps aux | grep -c mongod`
let "mCt = mCt - 1"

echo
echo "+=============================================+"
echo "| Running mongod count: ${mCt}"
echo "+=============================================+"
echo