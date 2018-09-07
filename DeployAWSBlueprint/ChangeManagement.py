import urllib
import os
import sys
from subprocess import Popen, PIPE
import paramiko
import subprocess
import time
from paramiko.ssh_exception import BadHostKeyException, AuthenticationException, SSHException
import socket

class ChangeManagement:
    # see if ssh is up
    def _r_waitSSHUp(self, hostname, user, keypath, attempts=0):
        if attempts > 5:
            return False
        else:
            try:
                ssh = paramiko.SSHClient()
                ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
                ssh.connect(hostname, username=user, key_filename=keypath)
                return True
            except (SSHException, socket.error):
                time.sleep(10)
                attempts=attempts+1
                self._r_waitSSHUp(hostname, user, keypath, attempts)
    # function to run a playbook
    def runPlaybook(self, url, hostname, uid, i, keypath, user):
        pfilename = "/tmp/gskyplaybook_"+uid+"_"+str(i)+".yaml"
        ifilename = "/tmp/gskyinv_"+uid+"_"+str(i)+".yaml"
        # first, download the file to temp
        u = urllib.URLopener()
        u.retrieve(url, pfilename)
        # next make the inventory file
        with open(ifilename, "w") as f:
            f.write("all:\n")
            f.write("\thosts:\n")
            f.write("\t\t"+hostname)
        # build command to run an run it
        cmd = "ansible-playbook "+pfilename+" --inventory-file "+ifilename+" --key-file " + keypath + " --user " + user
        o = subprocess.Popen(cmd.split(" "), stdout = subprocess.PIPE).communicate()[0]
        return o
    # function to push bash script and run playbook
    def runBashScript(self, url, hostname, uid, i, keypath, user):
        sfilename = "/tmp/gskyscript_"+uid+"_"+str(i)+".sh"
        # first download the file to temp
        u = urllib.URLopener()
        u.retrieve(url, sfilename)
        # wait for host up
        self._r_waitSSHUp(hostname, user, keypath)
        # next we scp the script to the server
        # then we ssh in and run the script
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(hostname, username=user, key_filename=keypath)
        sftp = ssh.open_sftp()
        sftp.put(sfilename, sfilename)
        sftp.close()
        # make it executable
        stdin,stdout,stderr = ssh.exec_command("chmod +x " + sfilename)
        stdout.channel.recv_exit_status()
        lines = stdout.readlines()
        # now run the script
        stdin,stdout,stderr = ssh.exec_command(sfilename)
        stdout.channel.recv_exit_status()
        lines = stdout.readlines()
        return "".join(lines)