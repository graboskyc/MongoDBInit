# Guide for setting up TLS

## Prerequisites

* commands assume ubuntu but should work generally speaking
* openssl installed
* mongodb-enterprise installed (https://docs.mongodb.com/manual/tutorial/install-mongodb-enterprise-on-ubuntu/) 

# Set up CA and intermediate CA

## Make the CA CNF

Follow along https://docs.mongodb.com/manual/appendix/security/appendixA-openssl-ca/

There is a `openssl-test-ca.cnf` sample.

## Make the CA Key

`openssl genrsa -out mongodb-test-ca.key 4096`

## Make the CA Cert

`openssl req -new -x509 -days 1826 -key mongodb-test-ca.key -out mongodb-test-ca.crt -config openssl-test-ca.cnf`

And answer the prompts

## Make the private key

`openssl genrsa -out mongodb-test-ia.key 4096`

## Create the CSR for the intermediate

`openssl req -new -key mongodb-test-ia.key -out mongodb-test-ia.csr -config openssl-test-ca.cnf`

and follow the promtps

## create the intermediate cert

`openssl x509 -sha256 -req -days 730 -in mongodb-test-ia.csr -CA mongodb-test-ca.crt -CAkey mongodb-test-ca.key -set_serial 01 -out mongodb-test-ia.crt -extfile openssl-test-ca.cnf -extensions v3_ca`

## combine files to make the cert (PEM key)

`cat mongodb-test-ca.crt mongodb-test-ia.crt  > test-ca.pem`

# Set up server 

## Make the cnf file

Follow along https://docs.mongodb.com/manual/appendix/security/appendixB-openssl-server/

There is a `openssl-test-server.cnf` sample. Sub out IPs and hostnames. must match exactly!

## Generate the server PEM

`openssl genrsa -out mongodb-test-server1.key 4096`

## create the server CSR (certificate signing request)

`openssl req -new -key mongodb-test-server1.key -out mongodb-test-server1.csr -config openssl-test-server.cnf`

## create the cert

`openssl x509 -sha256 -req -days 365 -in mongodb-test-server1.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-server1.crt -extfile openssl-test-server.cnf -extensions v3_req`

## combine files into PEM key format

`cat mongodb-test-server1.crt mongodb-test-server1.key > test-server1.pem`

# Handle the client

## make openssl config file

Follow along https://docs.mongodb.com/manual/appendix/security/appendixC-openssl-client/

See `openssl-test-client.cnf` 

## generate client pem

`openssl genrsa -out mongodb-test-client.key 4096`

## make client CSR

`openssl req -new -key mongodb-test-client.key -out mongodb-test-client.csr -config openssl-test-client.cnf`

and answer prompts

## make client cert

`openssl x509 -sha256 -req -days 365 -in mongodb-test-client.csr -CA mongodb-test-ia.crt -CAkey mongodb-test-ia.key -CAcreateserial -out mongodb-test-client.crt -extfile openssl-test-client.cnf -extensions v3_req`

## combine files into PEM key format

`cat mongodb-test-client.crt mongodb-test-client.key > test-client.pem`

# Configure MongoDB

## make the directory for mongodb

`mkdir r0`

## make config file (r0.conf)

```
storage:
  dbPath: /home/ubuntu/r0
net:
  ssl:
    mode: requireSSL
    CAFile: /home/ubuntu/test-ca.pem
    PEMKeyFile: /home/ubuntu/test-server1.pem
  bindIp: 0.0.0.0
  port: 27017
systemLog:
  destination: file
  path: /home/ubuntu/r0/mongo.log
  logAppend: true
processManagement:
  fork: true
```
## start mongod

`mongod -f r0.conf`

## using localhost exception, create un/pw

 `mongo --tls --host <serverHost> --tlsCertificateKeyFile test-client.pem  --tlsCAFile test-ca.pem --eval "db = db.getSisterDB('admin');db.createUser({user:'root',pwd:'root123',roles:['root']});"`

# Test connection

## Copy over certs

copy `test-ca.pem` and `test-client.pem` to another machine

## mongo shell from remote machine

`mongo --tls --host mongodb://root:root123@<publichostname> --tlsCertificateKeyFile test-client.pem  --tlsCAFile test-ca.pem` 

Note that the host must match DNS exactly as you set up earlier in the config file! 

## Sample python code

Remember about the hostname as mentioned above! `tlsAllowInvalidCertificates` must be set as the CA is not in our trust chain so either set this to `True` or add it to chain of trus.

```
import pymongo
import time

client = pymongo.MongoClient('mongodb://root:root123@<publichostname>', tls=True, tlsCAFile='./cacert.pem', tlsCertificateKeyFile='./test-client.pem', tlsAllowInvalidCertificates=True)

db = client.isItWorking
i = 0
while True:
    print("Inserting record " + str(i))
    db.test.insert_one({"itIsWorking":True, "i":i})
    time.sleep(1)
    i=i+1
```

On this shell you should see an increasing counter. 

Log into the DB with mongo shell and see that a DB called `isItWorking` and collection `test` are created and it is inserting a document a second.
