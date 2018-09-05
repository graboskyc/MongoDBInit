#!/usr/bin/python

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    deploys a blueprint
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
import urllib
import time

# Create your blueprint. if not specified, this is what we deploy.
blueprint = []
blueprint.append({"name":'DB1', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'DB2', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'DB3', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'Ops Mgr', "os":"ubuntu", "size":"t2.large"})

# useful name to ami lookup table
ami = {}
ami['ubuntu'] = {"id" : "ami-04169656fea786776", "type" : "linux" }
ami["rhel"] = {"id" : "ami-6871a115", "type" : "linux" }
ami["win2016dc"] = {"id" : "ami-0b7b74ba8473ec232", "type" : "windows" }
ami["amazon"] = {"id" : "ami-0ff8a91507f77f867", "type" : "linux" }
ami["amazon2"] = {"id" : "ami-04681a1dbd79675a5", "type" : "linux" }

# parse cli arguments
parser = argparse.ArgumentParser(description='CLI Tool to esily deploy a blueprint to aws instances')
parser.add_argument('-b', action="store", dest="blueprint", help="path to the blueprint")
parser.add_argument("-s", "--sample", help="download a sample blueprint yaml", action="store_true")
parser.add_argument('-d', action="store", dest="days", help="how many days should we reserve this for before reaping")
arg = parser.parse_args()

# pull sample yaml file from github as reference
if arg.sample:
    print "Downloading file..."
    sfile = urllib.URLopener()
    sfile.retrieve("https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/sampleblueprint.yaml", os.path.expanduser('~') + "/sample.yaml")
    print "Check your home directory for sample.yaml"
    sys.exit(0)

# if they specifify a yaml, use that
# otherwise we will use the hard coded blueprint above
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

# always prepend a random 8 characters 
# makes it easier to find and be grouped later
# and track whether any failed deploys
uid = str(uuid.uuid4())[:8]
success=True
conf = {}
resdays = 7

# default to 7 day reservation, otherwise take args
if (arg.days != None):
    resdays = int(arg.days)

# do not change order!
# values get overridden below
t = []
t.append( {'Key':'Name', 'Value':'from the api'} )
t.append( {'Key':'owner', 'Value':'some.guy'} )
t.append( {'Key':'expire-on', 'Value':str(datetime.date.today()+ datetime.timedelta(days=resdays))} )
t.append( {'Key':'use-group', 'Value':uid} )

# parse the config files
if (os.path.isfile(os.path.expanduser('~') + "/.gskyaws.conf") and os.path.isfile(os.path.expanduser('~') + "/.aws/config")):
    # my custom config file parsing
    with open(os.path.expanduser('~') + "/.gskyaws.conf", 'r') as cf:
        for line in cf:
            temp = line.split("=")
            conf[temp[0]] = temp[1].replace('"',"").replace("\n","")
    
    # config files from aws cli utility
    cp = SafeConfigParser()
    cp.read(os.path.expanduser('~') + "/.aws/config")
    region = cp.get("default","region")

else:
    # configs were not present
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

# recusrsive function to check to make sure instances are up
def r_checkStatus(region, uid):
    up=True
    ec2 = boto3.client('ec2', region_name=region)
    reservations = ec2.describe_instances(Filters=[{"Name":"tag:use-group", "Values":[uid]}])
    for r in reservations["Reservations"]:
        for i in r["Instances"]:
            if i["State"]["Name"] != "running":
                up=False
    
    if(not up):
        time.sleep(10)
        print "."
        r_checkStatus(region, uid)

# where to deploy
# remember, you need ~/.aws/credentials set!
ec2 = boto3.resource('ec2', region_name=region)

# being deployment of each instance
for resource in blueprint:
    print "Trying to deploy " + resource["name"]
    try:
        # actually deploy
        inst = ec2.create_instances(ImageId=ami[resource["os"]]["id"], InstanceType=resource["size"], MinCount=1, MaxCount=1, SecurityGroupIds=[conf['sgID']], KeyName=conf['keypair'])
        
        # update tags for tracking and reaping
        t[0] = {'Key':'Name', 'Value':uid + "_" +resource["name"]} 
        t[1] = {'Key':'owner', 'Value': conf["name"]} 
        print "Created instance with instance ID: %s with Name: %s running: %s as a: %s" % (inst[0].id, uid + "_" +resource["name"], resource["os"], resource["size"])
        inst[0].create_tags(Tags=t)
    except:
        success=False
        print "!! Could not deploy instance with Name: %s running: %s as a: %s" % (resource["name"], resource["os"], resource["size"])

print
print "Waiting for everything to come up..."
print
r_checkStatus(region, uid)

# completed
print 
if success:
    print "Blueprint Successfully Deployed!"
else:
    print "The blueprint may not have been successfully deployed."
print