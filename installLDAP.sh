#!/bin/bash

# https://github.com/10gen/pov-proof-exercises/blob/master/proofs/23/SetupLDAP.md
sudo apt-get -y update
sudo apt-get -y upgrade
sudo apt -y install slapd ldap-utils ldapscripts
