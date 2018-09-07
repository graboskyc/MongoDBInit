import os
import sys
import datetime

class Logger:
    filename = ""

    def __init__(self, uid):
        self.filename = os.path.expanduser('~')+"/executionlog_"+uid+".txt"
        with open(self.filename, "w") as f:
            f.write(self._heading("Start of execution for " + uid))

    def write(self, text):
        with open(self.filename, "a") as f:
            f.write(text)
            f.write("\n")

    def writeTimestamp(self, text):
        with open(self.filename, "a") as f:
            f.write("!!"+str(datetime.datetime.now())+"\n")
            f.write(text)
            f.write("\n\n")

    def writeSection(self, section, text):
        with open(self.filename, "a") as f:
            f.write(self._heading(section))
            f.write(text)
            f.write("\n\n")

    def _heading(self, text):
        retStr = "\n\n"
        retStr += "+=========================================\n"
        retStr += "| " + text + "\n"
        retStr += "|" + str(datetime.datetime.now()) + "\n"
        retStr += "+=========================================\n"
        return retStr