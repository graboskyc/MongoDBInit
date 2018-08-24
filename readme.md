# Background
This is a basic initiation script for a 3 node MongoDB replica set. It is meant for internal testing, and more specifically, MongoDB University courses.

While you could use `mongod` command line flags or mtools to start the replica set, keeping the configs around is useful, especially for MongoDB University coursework.

# Use
* Download this repo to your home directory (in this case, `/home/vagrant`)
* create a directory called `configs` there and put these 2 shell scripts and `BASE.conf` inside
* Run `makeRSConfs.sh` to make your configs
* Alternately, if you already have the configs made in the format of `name_1.conf` through `name_3.conf` you can just run `./runRS.sh name`
* If you want to run with an ssl config, use `makeRsConfs.sh 27100 test -ssl` and it will prompt you for where your `.pem` keys are located
* After creating the configs, it will ask you whether you want to start the mongo instances of the replica set, initiate the replica set (based on `hostname`), create a root user, add other nodes to the replica set, then if you want to enter the mongo shell. Enter `y` or `n` when prompted.

```
vagrant@database:~/configs$ ./makeRSConfs.sh 27100 test
Created config /home/vagrant/configs/test_1.conf to run on port 27100
Created config /home/vagrant/configs/test_2.conf to run on port 27101
Created config /home/vagrant/configs/test_3.conf to run on port 27102


Should I start the RS? y/n?  y

+=============================================+
| Running mongod count: 0
+=============================================+

Starting mongod

Starting using test_1.conf
about to fork child process, waiting until server is ready for connections.
forked process: 28340
child process started successfully, parent exiting
Starting using test_2.conf
about to fork child process, waiting until server is ready for connections.
forked process: 28357
child process started successfully, parent exiting
Starting using test_3.conf
about to fork child process, waiting until server is ready for connections.
forked process: 28394
child process started successfully, parent exiting

+=============================================+
| Running mongod count: 3
+=============================================+


Should I initiate the RS? y/n?  y
MongoDB shell version: 3.2.20
connecting to: 127.0.0.1:27100/test
{
	"info2" : "no configuration specified. Using a default configuration for the set",
	"me" : "database:27100",
	"ok" : 1
}


Should I create a root user? y/n?  y
MongoDB shell version: 3.2.20
connecting to: 127.0.0.1:27100/test
Successfully added user: { "user" : "root", "roles" : [ "root" ] }
Created root user with un root and pw root123


Should I start the shell? y/n?  y
MongoDB shell version: 3.2.20
connecting to: 127.0.0.1:27100/test
MongoDB Enterprise m310:PRIMARY> 
```