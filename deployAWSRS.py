#!/usr/bin/python

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    
# Deps:     boto3 & ConfigParser pkgs installed. 
#           aws config file installed for user via aws cli tools `aws configure`
#           Config file in ~/.gskyaws
# Refs:     https://github.com/graboskyc/MongoDBInit
#           https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/updateAWSSG.sh
######################################

import boto3
import os
import sys
import datetime
import uuid
from ConfigParser import SafeConfigParser
import argparse
import yaml

######################################
# Create your blueprint. if not specified, this is what we deploy.
######################################
blueprint = []
blueprint.append({"name":'DB1', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'DB2', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'DB3', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'Ops Mgr', "os":"ubuntu", "size":"t2.large"})

######################################
# don't edit below unless you know what you are doing!
######################################
ami = {}
ami['ubuntu'] = "ami-04169656fea786776"
ami["rhel"] = "ami-6871a115"
ami["win2016dc"] = "ami-0b7b74ba8473ec232"
ami["amazon"] = "ami-0ff8a91507f77f867"
ami["amazon2"] = "ami-04681a1dbd79675a5"

parser = argparse.ArgumentParser(description='CLI Tool to esily deploy a blueprint to aws instances')
parser.add_argument('-b', action="store", dest="blueprint", help="path to the blueprint")
arg = parser.parse_args()

if (arg.blueprint != None):
    print "Using YAML file provided."
    with open(arg.blueprint,"r") as s:
        try:
            y = yaml.load(s.read())
        except:
            print "Error parsing YAML file!"
            sys.exit(2)
     
    blueprint = []
    blueprint = y["resources"]

uid = str(uuid.uuid4())[:8]
success=True
conf = {}

# do not change order!
t = []
t.append( {'Key':'Name', 'Value':'from the api'} )
t.append( {'Key':'owner', 'Value':'chris.grabosky'} )
t.append( {'Key':'expire-on', 'Value':str(datetime.date.today()+ datetime.timedelta(days=7))} )

# parse the config files
if (os.path.isfile(os.path.expanduser('~') + "/.gskyaws.conf") and os.path.isfile(os.path.expanduser('~') + "/.aws/config")):
    with open(os.path.expanduser('~') + "/.gskyaws.conf", 'r') as cf:
        for line in cf:
            temp = line.split("=")
            conf[temp[0]] = temp[1].replace('"',"").replace("\n","")

    cp = SafeConfigParser()
    cp.read(os.path.expanduser('~') + "/.aws/config")
    region = cp.get("default","region")

else:
    print
    print "You need your config in ~/.gskyaws.conf."
    print "See: https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/updateAWSSG.sh"
    print "Create ~/.gskyaws.conf with values:"
    print 'sgID="sg-yoursgidhere"'
    print 'keypair="yourawskeypairname"'
    print 'name="firstname.lastname"'
    print
    print "And you need to run `aws configure` to configure that as well"
    print
    sys.exit(1)

# where to deploy
# remember, you need ~/.aws/credentials set!
ec2 = boto3.resource('ec2', region_name=region)

for resource in blueprint:
    print "Trying to deploy " + resource["name"]
    try:
        i = ec2.create_instances(ImageId=ami[resource["os"]], InstanceType=resource["size"], MinCount=1, MaxCount=1, SecurityGroupIds=[conf['sgID']], KeyName=conf['keypair'])
        t[0] = {'Key':'Name', 'Value':uid + "_" +resource["name"]} 
        t[1] = {'Key':'owner', 'Value': conf["name"]} 
        print "Created instance with instance ID: %s with Name: %s running: %s as a: %s" % (i[0].id, uid + "_" +resource["name"], resource["os"], resource["size"])
        i[0].create_tags(Tags=t)
    except:
        success=False
        print "Could not deploy instance with Name: %s running: %s as a: %s" % (resource["name"], resource["os"], resource["size"])
        print sys.exc_info()[0]

print 
if success:
    print "Blueprint Successfully Deployed!"
else:
    print "The blueprint may not have been successfully deployed."
print