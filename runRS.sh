#!/bin/bash

killall mongod 1>/dev/null 2>&1
sleep 1
mCt=`ps aux | grep -c mongod`
let "mCt = mCt - 1"

echo
echo "+=============================================+"
echo "| Running mongod count: ${mCt}"
echo "+=============================================+"
echo
echo "Starting mongod"
echo

echo "Starting using ${1}_1.conf"
mongod -f ${1}_1.conf 
echo "Starting using ${1}_2.conf"
mongod -f ${1}_2.conf 
echo "Starting using ${1}_3.conf"
mongod -f ${1}_3.conf

mCt=`ps aux | grep -c mongod`
let "mCt = mCt - 1"

echo
echo "+=============================================+"
echo "| Running mongod count: ${mCt}"
echo "+=============================================+"
echo