class Table:
	sizes = []
	names = []
	rows = []

	def Return(self):
		retStr = ""
		retStr += self.__DrawHeader()
		for row in self.rows:
			retStr += self.__DrawRow(row)
		retStr += self.__DrawSeperator()
		return retStr

	def Draw(self):
		print self.Return()

	def AddHeader(self, names):
		self.names = names
		i = 0
		if len(self.sizes) < len(names):
			o = 0
			for n in names:
				self.sizes.append(0)
				o += 1
				
		for s,n in zip(self.sizes, names):
			if len(str(n)) > s:
				self.sizes[i] = len(str(n))
			i+=1
	def AddRow(self, names):
		self.rows.append(names)
		i = 0
		if len(self.sizes) < len(names):
			o = 0
			for n in names:
				self.sizes.append(0)
				o += 1

		for s,n in zip(self.sizes, names):
			if len(str(n)) > s:
				self.sizes[i] = len(str(n))
			i+=1

	def Clear(self):
		self.sizes = []
		self.names = []
		self.rows = []
		
	def __DrawSeperator(self):
		headerString = "+"
		for i in self.sizes:
			headerString += "-"
			while i > 0:
				headerString += "-"
				i -= 1
			headerString += "-+"
		return headerString

	def __DrawHeader(self):
		retStr = ""
		retStr += self.__DrawSeperator() +"\n"
		retStr += self.__DrawRow(self.names)
		retStr += self.__DrawSeperator() +"\n"
		return retStr
		
	def __DrawRow(self, names):
		lineString = "| "
		i = 0
		for name in names:
			strName = str(name)
			lineString += strName.ljust(self.sizes[i])
			lineString += " | "
			i += 1
		return lineString  +"\n"