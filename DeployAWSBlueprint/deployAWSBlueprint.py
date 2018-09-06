#!/usr/bin/python

######################################
# Author:   Chris Grabosky
# Email:    chris.grabosky@mongodb.com
# GitHub:   graboskyc
# About:    deploys a blueprint
# Deps:     boto3, ConfigParser, paramiko, scp pkgs installed. 
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
from subprocess import Popen, PIPE
from paramiko import SSHClient
from scp import SCPClient
from Table import Table
from PostInstall import PostInstall
from AWS import AWS

# Create your blueprint. if not specified, this is what we deploy.
blueprint = []
blueprint.append({"name":'DB1', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'DB2', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'DB3', "os":"ubuntu", "size":"t2.micro"})
blueprint.append({"name":'Ops Mgr', "os":"ubuntu", "size":"t2.large"})

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
    sfile.retrieve("https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/DeployAWSBlueprint/sampleblueprint.yaml", os.path.expanduser('~') + "/sample.yaml")
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

# figure out the ami
aws = AWS()

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
        sys.stdout.write(".")
        sys.stdout.flush()
        r_checkStatus(region, uid)

# where to deploy
# remember, you need ~/.aws/credentials set!
ec2 = boto3.resource('ec2', region_name=region)

# being deployment of each instance
print "Deploying Instances..."
tbl = Table()
tbl.AddHeader(["Instance ID", "Name", "Op System", "Size", "Succ/Fail"])

for resource in blueprint:
    print "Trying to deploy " + resource["name"]
    try:
        # actually deploy
        inst = ec2.create_instances(ImageId=aws.getAMI(resource["os"])["id"], InstanceType=resource["size"], MinCount=1, MaxCount=1, SecurityGroupIds=[conf['sgID']], KeyName=conf['keypair'])
        tbl.AddRow([inst[0].id, uid + "_" +resource["name"], resource["os"], resource["size"], "Success"])
        # update tags for tracking and reaping
        t[0] = {'Key':'Name', 'Value':uid + "_" +resource["name"]} 
        t[1] = {'Key':'owner', 'Value': conf["name"]} 
        inst[0].create_tags(Tags=t)
    except:
        success=False
        tbl.AddRow([inst[0].id, uid + "_" +resource["name"], resource["os"], resource["size"], "Fail"])

print
print "Results:"
print

tbl.Draw()

print
sys.stdout.write("Waiting for successfully deployed instances to come up...")
sys.stdout.flush()
r_checkStatus(region, uid)
print
print "Instances are running..."
print "Building Post-Configuration Plan..."

tbl.Clear()
tbl.AddHeader(["Name", "Type", "Machine Order", "Task Order", "Description"])
for resource in blueprint:
    i=0
    if "tasks" in resource:
        for task in resource["tasks"]:
            tbl.AddRow([resource["name"], task["type"], str(resource["postinstallorder"]), str(i), task["description"]])
            i=i+1

tbl.Draw()

# completed
print 
if success:
    print "Blueprint Successfully Deployed!"
else:
    print "The blueprint may not have been successfully deployed."
print