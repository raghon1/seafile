#!/bin/python
#

import SoftLayer
import re
import sys

with open("/root/.softlayer", "r") as ins:
    array = []
    for line in ins:
        l=line.split('=',1)
	if (l[0].strip() == 'username'):
		username=l[1].strip()
	if (l[0].strip() == 'api_key'):
		api_key=l[1].strip()


client = SoftLayer.Client(username=username, api_key=api_key)

ff=client['Account'].getObject()

manager = SoftLayer.DNSManager(client)
ext='biz'

dns = SoftLayer.DNSManager(client)
zones=dns.list_zones();
zoneid=[]
for z in zones :
    if z['name'] == "cloudwalker.biz" :
        print z['name']
        zoneid=z['id']
        break

if zoneid:
	print "finnes"
else:
	manager.create_zone('cloudwalker.'+ext)


sys.argv.pop(0)
for host in sys.argv:
	hostname=host.strip()
	ff=client['Dns_Domain'].getObject(hostname, id=zoneid)

	cname=dns.get_records(zoneid, ttl=None, data=None, host=hostname, record_type='CNAME')
	if cname:
		print "finnes "+str(cname[0]['id'])
		dns.delete_record(cname[0]['id'])
	else:
		print "lager dns record"
		new_record = client['Dns_Domain'].createCNAMERecord(hostname, 'demo01.cloudwalker.biz.', 900, id=zoneid)

