#!/usr/bin/python3

# Copyright 2018 Peter Green
# Released under the MIT/Expat license, see doc/COPYING

import os
import sys
import hashlib
import gzip
import urllib.request
import stat
#from sortedcontainers import SortedDict
#from sortedcontainers import SortedList
from collections import deque
from collections import OrderedDict
import re

def addfilefromdebarchive(filestoverify,filequeue,filename,sha256,size):
	size = int(size)
	sha256andsize = [sha256,size,'M']
	if filename in filestoverify:
		if (sha256andsize != filestoverify[filename]):
			print('error: same file with different hash/size old:'+repr(filestoverify[filename])+' new:'+repr(sha256andsize))
			sys.exit(1)
	else:
		filestoverify[filename] = sha256andsize
		if filename.endswith(b'.gz'):
			# process gz files with high priority so they can be used as substitutes for their uncompressed counterparts
			filequeue.appendleft(filename)
		else:
			filequeue.append(filename)

baseurl = sys.argv[1].encode('ascii')
snapshotts = sys.argv[2].encode('ascii')

#regex used for filename sanity checks
pfnallowed = re.compile(b'[a-z0-9A-Z\-_:\+~\.]+',re.ASCII)
shaallowed = re.compile(b'[a-z0-9]+',re.ASCII)

def ensuresafepath(path):
	pathsplit = path.split(b'/')
	if path[0] == '/':
		print("path must be relative")
		sys.exit(1)
	for component in pathsplit:
		if not pfnallowed.fullmatch(component):
			print("file name contains unexpected characters")
			sys.exit(1)
		elif component[0] == '.':
			print("filenames starting with a dot are not allowed")
			sys.exit(1)
	if not shaallowed.fullmatch(sha256):
		print('invalid character in sha256 hash')
	

def getfile(path,sha256,size):
	ensuresafepath(path)
	hashfn = b'../hashpool/' + sha256[:2] +b'/'+ sha256[:4] +b'/'+ sha256
	if os.path.isfile(hashfn):
		if os.path.getsize(hashfn) != size:
			print('size mismatch on existing file in hash pool')
			sys.exit(1)
	else:
		print('downloading '+path.decode('ascii')+' with hash '+sha256.decode('ascii'))
		fileurl = baseurl + hashfn[2:]
		with urllib.request.urlopen(fileurl.decode('ascii')) as response:
			data = response.read()
		sha256hash = hashlib.sha256(data)
		sha256hashed = sha256hash.hexdigest().encode('ascii')
		if (sha256 != sha256hashed):
			#print(repr(filesize))
			#print(repr(sha256))
			#print(repr(sha256hashed))
			print('hash mismatch while downloading file '+path.decode('ascii')+' '+sha256.decode('ascii')+' '+sha256hashed.decode('ascii'));
			sys.exit(1)
		if len(data) != size:
			print('size mismatch while downloading file')
			sys.exit(1)
		hashdir = os.path.dirname(hashfn)
		os.makedirs(hashdir,exist_ok=True)
		f = open(hashfn,'wb')
		f.write(data)
		f.close()
	os.makedirs(os.path.dirname(path),exist_ok=True)
	if os.path.isfile(path): # file already exists
		sh = os.stat(hashfn)
		sp = os.stat(path)
		if (sh[stat.ST_INO], sh[stat.ST_DEV]) == (sp[stat.ST_INO], sp[stat.ST_DEV]):
			pass #file is already hardlinked to the hash pool
		else:
			#file is not linked to the hash pool, lets verify it.
			f = open(path,'rb')
			data = f.read()
			f.close()
			sha256hash = hashlib.sha256(data)
			sha256hashed = sha256hash.hexdigest().encode('ascii')
			if (sha256 != sha256hashed):
				print('hash mismatch on existing file in tree')
				sys.exit(1)
	else:
		os.link(hashfn,path)

fileurl = baseurl + b'/' + snapshotts +b'/snapshotindex.txt'

with urllib.request.urlopen(fileurl.decode('ascii')) as response:
	filedata = response.read()

f = open(b'snapshotindex.txt','wb')
f.write(filedata)
f.close()

knownfiles = OrderedDict()
filequeue = deque()

f = open(b'snapshotindex.txt','rb')
for line in f:
	line = line.strip()
	filepath, sizeandsha = line.split(b' ')
	if sizeandsha[:2] == b'->':
		symlinktarget = sizeandsha[2:]
		ensuresafepath(filepath)
		ensuresafepath(symlinktarget)
		os.makedirs(os.path.dirname(filepath),exist_ok=True)
		if os.path.islink(filepath):
			if os.readlink(filepath) != symlinktarget:
				print('symlink already exists with wrong target')
				sys.exit(1)
		else:
			os.symlink(symlinktarget,filepath)
	else:
		size,sha256 = sizeandsha.split(b':')
		size = int(size)
		knownfiles[filepath] = [sha256,size,'R']
		if filepath.endswith(b'.gz'):
			# process gz files with high priority so they can be used as substitutes for their uncompressed counterparts
			filequeue.appendleft(filepath)
		else:
			filequeue.append(filepath)

f.close()

def openg(filepath):
	if os.path.exists(filepath):
		f = open(filepath,'rb')
	else:
		f = gzip.open(filepath+b'.gz','rb')
	return f

while filequeue:
	filepath = filequeue.popleft()
	print('processing '+filepath.decode('ascii'))
	sha256,size,status = knownfiles[filepath]
	if (filepath+b'.gz' not in knownfiles) or (status == 'R'):
		
		getfile(filepath,sha256,size)
	pathsplit = filepath.split(b'/')
	#print(pathsplit[-1])
	#if (pathsplit[-1] == b'Packages'):
	#	print(repr(pathsplit))
	if (pathsplit[-1] == b'Release') and (pathsplit[-3] == b'dists'):
		distdir = b'/'.join(pathsplit[:-1])
		f = open(filepath,'rb')
		insha256 = False;
		for line in f:
			#print(repr(line[0]))
			if (line == b'SHA256:\n'):
				insha256 = True
			elif ((line[0] == 32) and insha256):
				linesplit = line.split()
				filename = distdir+b'/'+linesplit[2]
				#if filename in knownfiles:
				#	if files
				print(filename)
				addfilefromdebarchive(knownfiles,filequeue,filename,linesplit[0],linesplit[1]);
			else:
				insha256 = False
		f.close()
	elif (pathsplit[-1] == b'Packages') and ((pathsplit[-5] == b'dists') or ((pathsplit[-3] == b'debian-installer') and (pathsplit[-6] == b'dists'))):
					if pathsplit[-5] == b'dists':
						toplevel = b'/'.join(pathsplit[:-5])
					else:
						toplevel = b'/'.join(pathsplit[:-6])
					print('found packages file: '+filepath.decode('ascii'))
					pf = openg(filepath)
					filename = None
					size = None
					sha256 = None
							
					for line in pf:
						linesplit = line.split()
						if (len(linesplit) == 0):
							if (filename != None):
								addfilefromdebarchive(knownfiles,filequeue,filename,sha256,size);
							filename = None
							size = None
							sha256 = None
						elif (linesplit[0] == b'Filename:'):
							filename = toplevel+b'/'+linesplit[1]
						elif (linesplit[0] == b'Size:'):
							size = linesplit[1]
						elif (linesplit[0] == b'SHA256:'):
							sha256 = linesplit[1]
					pf.close()
	elif (pathsplit[-1] == b'Sources') and (pathsplit[-5] == b'dists'):
					print('found sources file: '+filepath.decode('ascii'))
					toplevel = b'/'.join(pathsplit[:-5])
					pf = openg(filepath)
					filesfound = [];
					directory = None
					insha256p = False;
					for line in pf:
						linesplit = line.split()
						if (len(linesplit) == 0):
							for ls in filesfound:
								#print(repr(ls))
								addfilefromdebarchive(knownfiles,filequeue,toplevel+b'/'+directory+b'/'+ls[2],ls[0],ls[1]);
							filesfound = [];
							directory = None
							insha256p = False
						elif ((line[0] == 32) and insha256p):
							filesfound.append(linesplit)
						elif (linesplit[0] == b'Directory:'):
							insha256p = False
							directory = linesplit[1]
						elif (linesplit[0] == b'Checksums-Sha256:'):
							insha256p = True
						else:
							insha256p = False
					pf.close()
			

