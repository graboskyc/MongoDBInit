wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | sudo apt-key add -

echo "deb [ arch=amd64 ] http://repo.mongodb.com/apt/ubuntu bionic/mongodb-enterprise/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-enterprise.list

sudo apt-get update

sudo apt-get install -y mongodb-enterprise=4.0.15 mongodb-enterprise-server=4.0.15 mongodb-enterprise-shell=4.0.15 mongodb-enterprise-mongos=4.0.15 mongodb-enterprise-tools=4.0.15
