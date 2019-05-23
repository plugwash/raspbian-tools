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
from datetime import datetime
from email.utils import parsedate_to_datetime
import argparse
import re

parser = argparse.ArgumentParser(description="download one or more raspbian snapshots")
parser.add_argument("baseurl", help="base url for snapshot source")
parser.add_argument("timestamps", help="timestamp or range of timestamps to download, if a single timestamp is used then the current director is assumed to be the snapshot target directory, otherwise the current directory is assumed to be the directory above the snapshot target directory, if this parameter is not specified then baseurl is assumed to point to an individual snapshot rather than a snapshot collection",nargs='?')

parser.add_argument("--secondpool", help="specify location of secondary hash pool")
parser.add_argument("--tlwhitelist", help="specify comma-seperated whitelist of top-level directories")

args = parser.parse_args()


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
	

def geturl(fileurl):
	with urllib.request.urlopen(fileurl.decode('ascii')) as response:
		data = response.read()
		#print(fileurl[:7])
		if fileurl[:7] == b'file://':
			ts = os.path.getmtime(fileurl[7:])
		else:
			dt = parsedate_to_datetime(response.getheader('Last-Modified'))
			if dt.tzinfo is None:
				dt = dt.replace(tzinfo=timezone.utc)
			ts = dt.timestamp()
	return (data,ts)

def getfile(path,sha256,size):
	ensuresafepath(path)
	if not shaallowed.fullmatch(sha256):
		print('invalid character in sha256 hash')
		sys.exit(1)
	hashfn = b'../hashpool/' + sha256[:2] +b'/'+ sha256[:4] +b'/'+ sha256
	if os.path.isfile(hashfn):
		if os.path.getsize(hashfn) != size:
			print('size mismatch on existing file in hash pool '+hashfn.decode('ascii'))
			sys.exit(1)
	else:
		secondhashfn = None
		if args.secondpool is not None:
			secondhashfn = os.path.join(args.secondpool.encode('ascii'),sha256[:2] +b'/'+ sha256[:4] +b'/'+ sha256)
			#print(secondhashfn)
			if not os.path.isfile(secondhashfn):
				secondhashfn = None
		if secondhashfn is None:
			print('downloading '+path.decode('ascii')+' with hash '+sha256.decode('ascii'))
			fileurl = snapshotbaseurl + b'/' + path
			#fileurl = baseurl + hashfn[2:]
			(data,ts) = geturl(fileurl)
		else:
			print('copying '+path.decode('ascii')+' with hash '+sha256.decode('ascii')+' from secondary pool')
			f = open(secondhashfn,'rb')
			data = f.read()
			f.close()
			ts = os.path.getmtime(secondhashfn)
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
		
		os.utime(hashfn,(ts,ts))
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

baseurl = args.baseurl.encode('ascii')

if args.timestamps is None:
	snapshottss = [None]
	changedirs = False
elif '-' in args.timestamps:
	with urllib.request.urlopen(baseurl.decode('ascii')) as response:
		dirdata = response.read()
	dirregex = re.compile(b'"[0-9]{12}/"',re.ASCII)
	dirmatches = dirregex.findall(dirdata)
	#print(repr(dirmatches))
	dirnames = [dirmatch[1:13] for dirmatch in dirmatches]	
	(start, end) = args.timestamps.split('-')
	if start != '':
		start = int(start)
	else:
		start = 0	
	if end != '':
		end = int(end)
	else:
		end = 999999999999
	snapshottss = []
	for dir in dirnames:
		if (int(dir) >= start) and (int(dir) <= end):
			snapshottss.append(dir)

	changedirs = True
else:
	snapshottss = [args.timestamps.encode('ascii')]
	changedirs = False

initialdir = os.getcwdb()

for snapshotts in snapshottss:
	if changedirs:
		snapshotdir = os.path.join(initialdir,snapshotts)
		os.makedirs(snapshotdir,exist_ok=True)
		os.chdir(snapshotdir)
		if os.path.isfile('snapshotindex.txt'):
			continue #we already have this snapshot.
	if snapshotts is None:
		snapshotbaseurl = baseurl
	else:
		snapshotbaseurl = baseurl + b'/' + snapshotts
	fileurl = snapshotbaseurl +b'/snapshotindex.txt'

	(filedata,ts) = geturl(fileurl)

	f = open(b'snapshotindex.txt.tmp','wb')
	f.write(filedata)
	f.close()
	os.utime(b'snapshotindex.txt.tmp',(ts,ts))

	knownfiles = OrderedDict()
	filequeue = deque()

	if args.tlwhitelist is not None:
		ffilter = open('snapshotindex.txt.filter','wb')
		tlwhitelist = set(args.tlwhitelist.encode('ascii').split(b','))

	f = open(b'snapshotindex.txt.tmp','rb')
	for line in f:
		line = line.strip()
		filepath, sizeandsha = line.split(b' ')
		if args.tlwhitelist is not None:
			filepathsplit = filepath.split(b'/')
			if filepathsplit[0] not in tlwhitelist:
				#print(repr(tlwhitelist))
				#print(repr(filepathsplit[0]))
				continue
			ffilter.write(line+b'\n')
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
	f.close()
	if args.tlwhitelist is not None:
		ffilter.close()
		os.remove('snapshotindex.txt.tmp')
		os.rename('snapshotindex.txt.filter','snapshotindex.txt')
	else:
		os.rename('snapshotindex.txt.tmp','snapshotindex.txt')
			

