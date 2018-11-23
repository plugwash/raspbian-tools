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

sys.exit(1)

def addfilefromdebarchive(filestoverify,filequeue,filename,sha256,size):
	size = int(size)
	sha256andsize = [sha256,size,'M']
	if filename in filestoverify:
		if (sha256andsize != filestoverify[filename]):
			print('error: same file with different hash/size old:'+repr(filestoverify[filename])+' new:'+repr(sha256andsize))
			sys.exit(1)
	else:
		filestoverify[filename] = sha256andsize
		filequeue.append(filename)

baseurl = sys.argv[1].encode('ascii')
snapshotts = sys.argv[2].encode('ascii')

#regex used for filename sanity checks
pfnallowed = re.compile(b'[a-z0-9A-Z\-_:\+~\.]+',re.ASCII)
shaallowed = re.compile(b'[a-z0-9]+',re.ASCII)

def getfile(path,sha256,size):
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
		print('FIXME: symlinks are not yet supported')
	else:
		size,sha256 = sizeandsha.split(b':')
		size = int(size)
		knownfiles[filepath] = [sha256,size,'R']
		filequeue.append(filepath)

while filequeue:
	filepath = filequeue.popleft()
	sha256,size,status = knownfiles[filepath]
	getfile(filepath,sha256,size)

f.close()
sys.exit(1)

distlocs = []




for toplevel in os.listdir('.'):
	if os.path.isdir(toplevel+'/dists/'):
		dists = os.listdir(toplevel+'/dists/')
		for dist in dists:
			if not os.path.islink(toplevel+'/dists/'+dist):
				distlocs.append((toplevel+'/dists/'+dist,toplevel.encode('ascii')))

knownfiles = SortedDict()
for distdir, toplevel in distlocs:
		f = open(distdir+'/Release','rb')
		insha256 = False;
		for line in f:
			#print(repr(line[0]))
			if (line == b'SHA256:\n'):
				insha256 = True
			elif ((line[0] == 32) and insha256):
				linesplit = line.split()
				filename = distdir.encode('ascii')+b'/'+linesplit[2]
				#if filename in knownfiles:
				#	if files
				addfilefromdebarchive(knownfiles,filequeue,filename,linesplit[0],linesplit[1]);
				if filename.endswith(b'Packages'):
					print('found packages file: '+filename.decode('ascii'))
					pf = open(filename,'rb')
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
				elif filename.endswith(b'Sources'):
					print('found sources file: '+filename.decode('ascii'))
					pf = open(filename,'rb')
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
			else:
				insha256 = False
		f.close()

def throwerror(error):
	raise error

#print(knownfiles.items()[0])
#sys.exit(1)
symlinks = SortedList()

for filepath, meta in knownfiles.items():
	#print(repr(meta))
	(sha256,filesize,status) = meta
	if (filepath + b'.gz') in knownfiles:
		print('found file '+filepath.decode('ascii')+'  with .gz counterpart')
		f = gzip.open(filepath+b'.gz','rb')
		data = f.read();
		f.close()
		sha256hash = hashlib.sha256(data)
		sha256hashed = sha256hash.hexdigest().encode('ascii')
		if (sha256 != sha256hashed):
			#print(repr(filesize))
			#print(repr(sha256))
			#print(repr(sha256hashed))
			print('hash mismatch while matching file '+filepath.decode('ascii')+' to gzipped counterpart '+sha256.decode('ascii')+' '+sha256hashed.decode('ascii'));
			sys.exit(1)
		knownfiles[filepath][2] = 'U'


for (dirpath,dirnames,filenames) in os.walk('.',True,throwerror,False):
	#if dirpath == './raspbian/dists':
	#	print(dirpath)
	#	print(dirnames)
	#	print(filenames)
	#print(dirpath)
	for filename in (filenames+dirnames): #os.walk seems to regard symlinks to directories as directories.
		filepath = os.path.join(dirpath,filename)[2:].encode('ascii') # [2:] is to strip the ./ prefix
		#print(filepath)
		if os.path.islink(filepath):
			symlinks.append(filepath)
	for filename in filenames:
		filepath = os.path.join(dirpath,filename)[2:].encode('ascii') # [2:] is to strip the ./ prefix
		if not os.path.islink(filepath) and filepath != b'snapshotindex.txt':
			if filepath in knownfiles:
				if knownfiles[filepath][2] == 'M':
					knownfiles[filepath][2] = 'N'
				elif knownfiles[filepath][2] == 'U':
					pass
				else:
					print('status should only be M or U at this point, wtf')
					sys.exit(1)
			else:
				#print(filepath)
				f = open(filepath,'rb')
				data = f.read();
				f.close()
				sha256hash = hashlib.sha256(data)
				sha256hashed = sha256hash.hexdigest().encode('ascii')
				filesize = len(data)
				if filesize is None:
					print('wtf filesize is none')
					sys.exit(1)
				knownfiles[filepath] = [sha256hashed,filesize,'R']

normalcount = 0
rootcount = 0
missingcount = 0
uncompressedcount = 0

for filepath, (sha256hashed,filesize,status) in knownfiles.items():
	if status == 'N':
		normalcount += 1
	elif status == 'R':
		rootcount += 1
	elif status == 'M':
		missingcount += 1
		print('missing file: '+filepath.decode('ascii'))
	elif status == 'U':
		uncompressedcount +=1
	else:
		print('unknown status')
		sys.exit(1)

print('normal count:'+str(normalcount))
print('root count: '+str(rootcount))
print('uncompressed count: '+str(uncompressedcount))
print('missing count: '+str(missingcount))

if missingcount > 0:
	print('missing files, aborting')
	sys.exit(1)

for filepath, (sha256,filesize,status) in knownfiles.items():
	if status == 'U':
		continue #we don't bother storing uncompressed versions of compressed files.
	hashdir = b'../'+sha256[:2]+b'/'+sha256[:4]
	hashfn = hashdir + b'/' + sha256
	if os.path.isfile(hashfn):
		continue #we already have this in the hash pool
	print('adding '+filepath.decode('ascii')+' with hash '+sha256.decode('ascii')+' to hash pool')
	f = open(filepath,'rb')
	data = f.read();
	f.close()
	sha256hash = hashlib.sha256(data)
	sha256hashed = sha256hash.hexdigest().encode('ascii')
	if (sha256 != sha256hashed):
		print('hash mismatch');
		sys.exit(1)
	os.makedirs(hashdir,exist_ok=True)
	os.link(filepath,hashfn)

f = open('snapshotindex.txt','wb')
for filepath, (sha256,filesize,status) in knownfiles.items():
#	print(repr(filepath))
#	print(repr(filesize))
#	print(repr(sha256))
#	print(repr(status))
	if status == 'R':
		f.write(filepath+b' '+str(filesize).encode('ascii')+b':'+sha256+b'\n')

for filepath in symlinks:
		f.write(filepath+b' ->'+os.readlink(filepath)+b'\n')

f.close()

#print(repr(knownfiles))

#incomplete code to descend into dscs, seems this is
#not actually needed as files depended on by dscs
#are listed in the Sources file directly.
#filessofar = knownfiles.copy();
#for filename, sha256andsize in filessofar.items():
#	if filename.endswith(b'dsc'):
#	f = open(filename,'rb')
#	insha256 = False
#	for line in f:
#		if (line == b'Checksums-Sha1::\n'):
#			insha256 = True
#		elif ((line[0] == 32) and insha256):
#			
#		else:
#			insha256 = False
#	f.close()

#for filename, sha256andsize in knownfiles.items():
#	sha256,size = sha256andsize;
#	print('verifying '+filename.decode('ascii'))
#	if b'../' in filename:
#		print('fucked up filename')
#		sys.exit(1);
#	if not os.path.isfile(filename):
#		if not os.path.isfile(filename+b'.gz'):
#			print('missing file '+ filename.decode('ascii'))
#			sys.exit(1)
#		else:
#			#sometimes reprepro seems to create only a .gz file but includes the non-gzipped file in the index
#			f = gzip.open(filename+b'.gz','rb')
#	else:
#		f = open(filename,'rb')
#	data = f.read();
#	
#	f.close()
#	sha256hash = hashlib.sha256(data)
#	sha256hashed = sha256hash.hexdigest().encode('ascii')
#	if (sha256 != sha256hashed):
#		print('hash mismatch');
#		sys.exit(1)
#	filesize = len(data)
#	if (size != filesize):
#		print('size mismatch');
#		sys.exit(1)
#

#print(repr(knownfiles))

