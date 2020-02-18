#!/bin/bash

# cd /tmp;wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/StageMyShit.sh -O StageMyShit.sh;chmod +x StageMyShit.sh

cd /tmp
wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/installOpsMgr.sh -O installOpsMgr.sh
wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/installEA.sh -O installEA.sh
wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/makeRSConfs.sh -O makeRSConfs.sh
wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/runRS.sh -O runRS.sh
wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/installAutoAgent.sh -O installAutoAgent.sh
wget https://raw.githubusercontent.com/graboskyc/MongoDBInit/master/installEAUbuntu.sh -O installEAUbuntu.sh
chmod +x ./*.sh
