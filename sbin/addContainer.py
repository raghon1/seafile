#!/usr/bin/python
#

import object_storage
import re
import sys
import getopt



class storage:
	def __init__(self):
		with open("/root/.cloudwalker/secret", "r") as ins:
			for line in ins:
				line=line.replace("\"","")
				l=line.split('=',1)
				if (l[0].strip() == 'S3QL_API_USER'):
					username=l[1].strip()

				if (l[0].strip() == 'S3QL_API_PASSWD'):
					api_key=l[1].strip()

				if (l[0].strip() == 'S3QL_STORAGE'):
					dc=l[1].strip()

		self.auth = object_storage.get_client(username, api_key, auth_url='https://'+dc+'/auth/v1.0/')


	def addCustomer(self, customer) :
		storage=self.auth
		container = storage.container(customer)
		if container.exists() == False :
			container.create()
			container.set_metadata({'seafile' : 'true'})
			readme = container.storage_object('README.txt')
			if readme.exists() == False :
				readme.create()
				readme.send('Object storage opprettet for '+customer+' som benyttes til seafile')
		else :
			sys.exit(1)

	def delCustomer(self, customer, force) :
		storage=self.auth
		container = storage.container(customer)
		if container.exists() == True :
			if (force == True) :
				warning="delete"
			else :
				warning=raw_input("Type \"delete\" to verify that you want to delete "+container.name+": ")

			if warning == "delete" : 
				container.delete_all_objects()
				container.delete()
			else :
				print ("not deleting "+container.name)
		else :
			print (customer+' finnes ikke')

	def listCustomers(self) :
		storage=self.auth
		for c in storage.containers():
			print (c)

def usage():
	print ("Usage: "+sys.argv[0]+" {-ad} customer")
	print ("\t-a Add container for customer")
	print ("\t-a Delete customer container")
	
	sys.exit(2)


def main():
	# finn container for kunde a 
	kunde='raghon-consulting'
	if len(sys.argv) > 1 :
		kunde=sys.argv[1]
	try:
		opts, args = getopt.getopt(sys.argv[1:], "a:d:fhl", ["help", "add=", "delete=", "list", "force"])
	except getopt.GetoptError as err:
		# print help information and exit:
		print(err) 
		usage()
		sys.exit(2)
	output = None
	verbose = False
	force = False
	for o, a in opts:
		if o in ("-h", "--help"):
		    usage()
		    sys.exit()
		elif o in ("-a", "--add"):
		    customer=a
		    action='add'
		elif o in ("-d", "--delete"):
		    customer=a
		    action='delete'
		elif o in ("-l", "--list"):
		    action='list'
		elif o in ("-f", "--force"):
		    force=True
		else:
		    assert False, "unhandled option"
		# ...
	
	slo=storage()
	if force == True :
		print ("Forching delete")

	if action == 'add' :
		slo.addCustomer(customer)
	elif action == 'delete' :
		slo.delCustomer(customer, force)
	elif action == 'list' :
		slo.listCustomers()

if __name__ == "__main__":
    main()
