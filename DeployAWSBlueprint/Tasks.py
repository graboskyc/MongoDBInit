# from https://stackoverflow.com/questions/8749542/creating-a-defaultlist-in-python
class defaultlist(list):
    def __init__(self, fx):
        self._fx = fx
    def _fill(self, index):
        while len(self) <= index:
            self.append(self._fx())
    def __setitem__(self, index, value):
        self._fill(index)
        list.__setitem__(self, index, value)
    def __getitem__(self, index):
        self._fill(index)
        return list.__getitem__(self, index)
        
# ugly, primitive, and error-prone
class Tasks:
    # tasks will be a list
    # if you set the index of an item to a number grater than elements, it will pad None
    tasks = defaultlist(lambda:None)
    def addTaskGroup(self, parentorder, tasklist):
        # if list is basically empty, just put it in place
        # in this case, pretend parentorder is 10 and list size is 0 (first item)
        if len(self.tasks) < parentorder:
            self.tasks[parentorder] = tasklist
        # if the prev already fired and filled Nones 
        # so continuing example, we had a previous task at 10, now parentorder is 5
        elif self.tasks[parentorder] == None:
            self.tasks[parentorder] = tasklist
        # ok now if we have another 10 after having a 10
        # and 10 (11 as zero index) is last item, append
        elif ((parentorder+1) == len(self.tasks)):
            self.tasks.append(tasklist)
        ## now imagine we have items at 10, 11, and 15 and Nones filling all gaps
        ## we get another 10. this should be now at spot 12 (index 13)
        else:
            # get from wanted index to end
            sublist = self.tasks[parentorder:]
            i=0
            newIndex=-1
            for item in sublist:
                if item == None:
                    newIndex = i
                    break
                i=i+1
            # if we never found it, append it
            if newIndex == -1:
                self.tasks.insert((len(self.tasks)-1),tasklist)
            else:
                newIndex=newIndex+parentorder
                self.tasks[newIndex]=tasklist
    def getTasks(self):
        tList = []
        for t in self.tasks:
            if t != None:
                tList.append(t)
        return tList
