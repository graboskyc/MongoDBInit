class AWS:
    def getAMI(self, name):
        ami = {}
        ami['ubuntu'] = {"id" : "ami-04169656fea786776", "type" : "linux", "user":"ubuntu" }
        ami["rhel"] = {"id" : "ami-6871a115", "type" : "linux" }
        ami["win2016dc"] = {"id" : "ami-0b7b74ba8473ec232", "type" : "windows" }
        ami["amazon"] = {"id" : "ami-0ff8a91507f77f867", "type" : "linux" }
        ami["amazon2"] = {"id" : "ami-04681a1dbd79675a5", "type" : "linux" }

        if name in ami:
            return ami[name]
        else:
            raise "KeyNotFound"