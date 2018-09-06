class PostInstall:
    # function to run a playbook
    def runPlaybook(url, hostname, uid, i):
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
        cmd = "ansible-playbook "+pfilename+" -i "+ifilename
        o = subprocess.Popen(cmd.split(" "), stdout = subprocess.PIPE).communicate()[0]
        return o

    # function to push bash script and run playbook
    def runBashScript(url, hostname, uid, i, keypath):
        sfilename = "/tm/gskyscript_"+uid+"_"+i+".sh"
        # first download the file to temp
        u = urllib.URLopener()
        u.retrieve(url, sfilename)
        # next we scp the script to the server
        # then we ssh in and run the script