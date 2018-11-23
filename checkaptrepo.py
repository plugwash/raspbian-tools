#!/usr/bin/python3

# Copyright 2018 Peter Green
# Released under the MIT/Expat license, see doc/COPYING

import os
import sys
import hashlib
import gzip
from sortedcontainers import SortedDict

def addfiletoverify(filestoverify,filename,sha1,size):
	size = int(size)
	sha1andsize = (sha1,size)
	if filename in filestoverify:
		if (sha1andsize != filestoverify[filename]):
			print('error: same file with different hash/size old:'+repr(filestoverify[filename])+' new:'+repr(sha1andsize))
			sys.exit(1)
	else:
		filestoverify[filename] = sha1andsize

dists = os.listdir('dists/')
filestoverify = SortedDict() #sorted to hopefully get better locality on file accesses.
for dist in dists:
	f = open('dists/'+dist+'/Release','rb')
	insha1 = False;
	for line in f:
		#print(repr(line[0]))
		if (line == b'SHA1:\n'):
			insha1 = True
		elif ((line[0] == 32) and insha1):
			linesplit = line.split()
			filename = b'dists/'+dist.encode('ascii')+b'/'+linesplit[2]
			#if filename in filestoverify:
			#	if files
			addfiletoverify(filestoverify,filename,linesplit[0],linesplit[1]);
			if filename.endswith(b'Packages'):
				print('found packages file: '+filename.decode('ascii'))
				pf = open(filename,'rb')
				filename = None
				size = None
				sha1 = None
						
				for line in pf:
					linesplit = line.split()
					if (len(linesplit) == 0):
						if (filename != None):
							addfiletoverify(filestoverify,filename,sha1,size);
						filename = None
						size = None
						sha1 = None
					elif (linesplit[0] == b'Filename:'):
						filename = linesplit[1]
					elif (linesplit[0] == b'Size:'):
						size = linesplit[1]
					elif (linesplit[0] == b'SHA1:'):
						sha1 = linesplit[1]
				pf.close()
			elif filename.endswith(b'Sources'):
				print('found sources file: '+filename.decode('ascii'))
				pf = open(filename,'rb')
				filesfound = [];
				directory = None
				insha1p = False;
				for line in pf:
					linesplit = line.split()
					if (len(linesplit) == 0):
						for ls in filesfound:
							#print(repr(ls))
							addfiletoverify(filestoverify,directory+b'/'+ls[2],ls[0],ls[1]);
						filesfound = [];
						directory = None
						insha1p = False
					elif ((line[0] == 32) and insha1p):
						filesfound.append(linesplit)
					elif (linesplit[0] == b'Directory:'):
						insha1p = False
						directory = linesplit[1]
					elif (linesplit[0] == b'Checksums-Sha1:'):
						insha1p = True
					else:
						insha1p = False
				pf.close()
		else:
			insha1 = False
	f.close()

#print(repr(filestoverify))

#incomplete code to descend into dscs, seems this is
#not actually needed as files depended on by dscs
#are listed in the Sources file directly.
#filessofar = filestoverify.copy();
#for filename, sha1andsize in filessofar.items():
#	if filename.endswith(b'dsc'):
#	f = open(filename,'rb')
#	insha1 = False
#	for line in f:
#		if (line == b'Checksums-Sha1::\n'):
#			insha1 = True
#		elif ((line[0] == 32) and insha1):
#			
#		else:
#			insha1 = False
#	f.close()

for filename, sha1andsize in filestoverify.items():
	sha1,size = sha1andsize;
	print('verifying '+filename.decode('ascii'))
	if b'../' in filename:
		print('fucked up filename')
		sys.exit(1);
	if not os.path.isfile(filename):
		if not os.path.isfile(filename+b'.gz'):
			print('missing file '+ filename.decode('ascii'))
			sys.exit(1)
		else:
			#sometimes reprepro seems to create only a .gz file but includes the non-gzipped file in the index
			f = gzip.open(filename+b'.gz','rb')
	else:
		f = open(filename,'rb')
	data = f.read();
	
	f.close()
	sha1hash = hashlib.sha1(data)
	sha1hashed = sha1hash.hexdigest().encode('ascii')
	if (sha1 != sha1hashed):
		print('hash mismatch');
		sys.exit(1)
	filesize = len(data)
	if (size != filesize):
		print('size mismatch');
		sys.exit(1)


#print(repr(filestoverify))
