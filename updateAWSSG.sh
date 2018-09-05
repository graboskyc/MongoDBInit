#!/bin/bash

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    This utility will update the security group for defined ports
# Deps:     SG must exist, have rules for authPorts already, and not have descriptions. AWS cli preinstalled
# Refs:     https://github.com/graboskyc/MongoDBInit
######################################

# what is my current public IP
pubIP=`wget -qO- ipinfo.io/ip`

# ports
authPorts=(22 8080)
sgID=""

hash aws 2>/dev/null || { echo >&2 "This script requires the AWS cli console. Install it first."; exit 3; }

# figure out what sg we use
if [[ -f ~/.gskyaws.conf ]]
then
    source ~/.gskyaws.conf
else
    if [ ! -z "$1" ]
    then
        sgID=$1
    else
        read -p "Which security group ID should we use? " sgID
        read -p "What is the name of your keypair? " kp
        read -p "What is your first.lastname? " n
    fi
    echo "sgID=\"${sgID}\"">~/.gskyaws.conf
    echo "keypair=\"${kp}\"">>~/.gskyaws.conf
    echo "name=\"${n}\"">>~/.gskyaws.conf
fi

# we need this in text mode so figure out what user is using so we can put it back later
origFormat=`cat ~/.aws/config | grep output | cut -d "=" -f 2 | sed -e 's/^[ ]*//'`

aws configure set output text

echo "We will now revoke existing SG rules for given ports, then apply them with your current public IP address."

for i in "${authPorts[@]}"
do
    echo "Handling port $i"
    # get our old IP
    oldIP=`aws ec2 describe-security-groups --group-ids sg-0e2814fcf49c0f92f | grep $i -C 1 | tail -n 1 | tr -d '[:space:]' | sed 's/IPRANGES//g'`
    # remove the existing rule
    aws ec2 revoke-security-group-ingress --group-id sg-0e2814fcf49c0f92f --protocol tcp --port $i --cidr $oldIP
    # add in new rule
    aws ec2 authorize-security-group-ingress --group-id sg-0e2814fcf49c0f92f --protocol tcp --port $i --cidr $pubIP/32
done

# put old config back
aws configure set output ${origFormat}

echo "Complete!"