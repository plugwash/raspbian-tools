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

parser = argparse.ArgumentParser(description="mirror raspbian repo.")
parser.add_argument("baseurl", help="base url for source repo")
parser.add_argument("--internal", help="base URL for private repo (internal use only)")
#parser.add_argument("timestamps", help="timestamp or range of timestamps to download, if a single timestamp is used then the current director is assumed to be the snapshot target directory, otherwise the current directory is assumed to be the directory above the snapshot target directory")
parser.add_argument("--sourcepool", help="specify a source pool to look for packages in before downloading them (useful if maintaining multiple mirrors)",action='append', nargs='*')

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
	#hashfn = b'../hashpool/' + sha256[:2] +b'/'+ sha256[:4] +b'/'+ sha256
	#if os.path.isfile(hashfn):
	#	if os.path.getsize(hashfn) != size:
	#		print('size mismatch on existing file in hash pool')
	#		sys.exit(1)
	#else:
	#	secondhashfn = None
	#	if args.secondpool is not None:
	#		secondhashfn = os.path.join(args.secondpool.encode('ascii'),sha256[:2] +b'/'+ sha256[:4] +b'/'+ sha256)
	#		#print(secondhashfn)
	#		if not os.path.isfile(secondhashfn):
	#			secondhashfn = None
	#	if secondhashfn is None:
	#	else:
	#		print('copying '+path.decode('ascii')+' with hash '+sha256.decode('ascii')+' from secondary pool')
	#		f = open(secondhashfn,'rb')
	#		data = f.read()
	#		f.close()
	#		ts = os.path.getmtime(secondhashfn)
	#	sha256hash = hashlib.sha256(data)
	#	sha256hashed = sha256hash.hexdigest().encode('ascii')
	#	if (sha256 != sha256hashed):
	#		#print(repr(filesize))
	#		#print(repr(sha256))
	#		#print(repr(sha256hashed))
	#		print('hash mismatch while downloading file '+path.decode('ascii')+' '+sha256.decode('ascii')+' '+sha256hashed.decode('ascii'));
	#		sys.exit(1)
	#	if len(data) != size:
	#		print('size mismatch while downloading file')
	#		sys.exit(1)
	#	hashdir = os.path.dirname(hashfn)
	#	os.makedirs(hashdir,exist_ok=True)
	#	f = open(hashfn,'wb')
	#	f.write(data)
	#	f.close()
	#	
	#	os.utime(hashfn,(ts,ts))
	if len(os.path.dirname(path)) > 0:
		os.makedirs(os.path.dirname(path),exist_ok=True)
	if os.path.isfile(path+b'.new'): # file with .new extension already exists
				#.new file already exists, lets check the hash
		f = open(path+b'.new','rb')
		data = f.read()
		f.close()
		sha256hash = hashlib.sha256(data)
		sha256hashed = sha256hash.hexdigest().encode('ascii')
		if (sha256 == sha256hashed) and (size == len(data)):
			print('existing file '+path.decode('ascii')+' matched by hash and size')
			fileupdates.add(path)
			return # no download needed but rename is
	elif path in oldknownfiles: 
		#shortcut exit if file is unchanged, we skip this if a .new file was detected because
		#that means some sort of update was going on to the file and may need to be finished/cleaned up.
		oldsha256,oldsize,oldstatus = oldknownfiles[path]
		if (oldsha256 == sha256) and (oldsize == size):
			return # no update needed
	if os.path.isfile(path): # file already exists
		if (size == os.path.getsize(path)): #no point reading the data and calculating a hash if the size does not match
			f = open(path,'rb')
			data = f.read()
			f.close()
			sha256hash = hashlib.sha256(data)
			sha256hashed = sha256hash.hexdigest().encode('ascii')
			if (sha256 == sha256hashed) and (size == len(data)):
				print('existing file '+path.decode('ascii')+' matched by hash and size')
				return # no update needed
				if os.path.isfile(path+b'.new'): 
					#if file is up to date but a .new file exists and is bad
					#(we wouldn't have got this far if it was good)
					#schedule the .new file for removal by adding it to "oldknownfiles"
					oldknownfiles[path+b'.new'] = 'stalenewfile'
	if os.path.isfile(path): # file already exists
		fileupdates.add(path)
		if os.path.isfile(path+b'.new'):
			os.remove(path+b'.new')
		outputpath = path+b'.new'
	else:
		outputpath = path
	pathsplit = path.split(b'/')
	if (args.internal is not None) and (pathsplit[0] == b'raspbian'):
		fileurl = args.internal.encode('ascii') +b'/private/' + b'/'.join(pathsplit[1:])
	else:
		fileurl = baseurl + b'/' + path
	data = None
	if args.sourcepool is not None:
		for sourcepool in args.sourcepool:
			if pathsplit[1] == b'pool':
				spp = os.path.join(sourcepool,b'/'.join(pathsplit[2:]))
				if os.path.isfile(spp)  and (size == os.path.getsize(spp)):
					print('trying file from sourcepool '+spp.decode('ascii'))
					ts = os.path.getmtime(spp)
					f = open(spp,'rb')
					data = f.read()
					f.close()
					sha256hash = hashlib.sha256(data)
					sha256hashed = sha256hash.hexdigest().encode('ascii')
					if (sha256 != sha256hashed):
						#print(repr(filesize))
						#print(repr(sha256))
						#print(repr(sha256hashed))
						print('hash mismatch while trying file from sourcepool, ignoring file');
						data = None
						continue
					try:
						os.link(spp,outputpath)
						print('successfully hardlinked file to source pool')
						return
					except:
						print('file in souce pool was good but hard linking failed, copying file instead')
	if data is None:
		if path+b'.gz' in knownfiles:
			if path+b'.gz' in fileupdates:
				gzfile = path+b'.gz.new'
			else:
				gzfile = path+b'.gz'
			print('uncompressing '+gzfile.decode('ascii')+' with hash '+sha256.decode('ascii')+' to '+outputpath.decode('ascii'))
			f = gzip.open(gzfile)
			data = f.read()
			f.close()
			ts = os.path.getmtime(gzfile)
		else:
			print('downloading '+fileurl.decode('ascii')+' with hash '+sha256.decode('ascii')+' to '+outputpath.decode('ascii'))
			(data,ts) = geturl(fileurl)
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
	f = open(outputpath,'wb')
	f.write(data)
	f.close()
	os.utime(outputpath,(ts,ts))
	

baseurl = args.baseurl.encode('ascii')
if args.internal is not None:
	fileurl = args.internal.encode('ascii') + b'/snapshotindex.txt'
else:
	fileurl = baseurl +b'/snapshotindex.txt'


symlinkupdates = list()
fileupdates = set()

def opengu(filepath):
	#print('in opengu')
	#print('filepath = '+repr(filepath))
	#print('fileupdates = '+repr(fileupdates))
	f = None
	if (filepath in fileupdates):
		print((b'opening '+filepath+b'.new for '+filepath).decode('ascii'))
		f = open(filepath+b'.new','rb')
	elif (filepath+b'.gz' in fileupdates):
		print((b'opening '+filepath+b'.gz.new for '+filepath).decode('ascii'))
		f = gzip.open(filepath+b'.gz.new','rb')
	elif os.path.exists(filepath):
		print((b'opening '+filepath+b' for '+filepath).decode('ascii'))
		f = open(filepath,'rb')
	elif os.path.exists(filepath+b'.gz'):
		print((b'opening '+filepath+b'.gz for '+filepath).decode('ascii'))
		f = gzip.open(filepath+b'.gz','rb')
	return f

oldsymlinks = set()
newsymlinks = set()

for stage in ("scanexisting","downloadnew"):
	if stage == "downloadnew":
		oldknownfiles = knownfiles
		(filedata,ts) = geturl(fileurl) 

		f = open(b'snapshotindex.txt.tmp','wb')
		f.write(filedata)
		f.close()
		os.utime(b'snapshotindex.txt.tmp',(ts,ts))

	knownfiles = OrderedDict()
	filequeue = deque()

	if stage == "scanexisting":
		if os.path.isfile(b'snapshotindex.txt'):
			f = open(b'snapshotindex.txt','rb')
		else:
			continue
	else:
		f = open(b'snapshotindex.txt.tmp','rb')
	for line in f:
		line = line.strip()
		filepath, sizeandsha = line.split(b' ')
		if sizeandsha[:2] == b'->':
			symlinktarget = sizeandsha[2:]
			ensuresafepath(filepath)
			ensuresafepath(symlinktarget)
			if len(os.path.dirname(filepath)) > 0:
				os.makedirs(os.path.dirname(filepath),exist_ok=True)
			if stage == "scanexisting":
				oldsymlinks.add(filepath)
			else:
				if os.path.islink(filepath):
					if os.readlink(filepath) != symlinktarget:
						symlinkupdates.append((filepath,symlinktarget))
				else:
					print('creating symlink '+filepath.decode('ascii')+' -> '+symlinktarget.decode('ascii'))
					os.symlink(symlinktarget,filepath)
				newsymlinks.add(filepath)
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


	while filequeue:
		filepath = filequeue.popleft()
		print('processing '+filepath.decode('ascii'))
		sha256,size,status = knownfiles[filepath]
		if (stage == "downloadnew") and ((filepath+b'.gz' not in knownfiles) or (status == 'R') or os.path.exists(filepath)):
			getfile(filepath,sha256,size)
		pathsplit = filepath.split(b'/')
		#print(pathsplit[-1])
		#if (pathsplit[-1] == b'Packages'):
		#	print(repr(pathsplit))
		if (pathsplit[-1] == b'Release') and (pathsplit[-3] == b'dists'):
			distdir = b'/'.join(pathsplit[:-1])
			f = opengu(filepath)
			if f is None:
				if stage == 'scanexisting':
					print('warning: cannot find '+filepath.decode('ascii')+' while scanning existing state')
					continue
				else:
					print('error: cannot find '+filepath.decode('ascii')+' or a gzipped substitute, aborting')
					sys.exit(1)
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
						pf = opengu(filepath)
						if pf is None:
							if stage == 'scanexisting':
								print('warning: cannot find '+filepath.decode('ascii')+' while scanning existing state')
								continue
							else:
								print('error: cannot find '+filepath.decode('ascii')+' or a gzipped substitute, aborting')
								sys.exit(1)

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
						pf = opengu(filepath)
						if pf is None:
							if stage == 'scanexisting':
								print('warning: cannot find '+filepath.decode('ascii')+' while scanning existing state')
								continue
							else:
								print('error: cannot find '+filepath.decode('ascii')+' or a gzipped substitute, aborting')
								sys.exit(1)
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

for filepath in fileupdates:
	print((b'renaming '+filepath+b'.new to '+filepath).decode('ascii'))
	os.replace(filepath+b'.new',filepath)

for (filepath,symlinktarget) in symlinkupdates:
	print('updating symlink '+filepath.decode('ascii')+' -> '+symlinktarget.decode('ascii'))
	os.remove(filepath)
	os.symlink(symlinktarget,filepath)


removedfiles = (set(oldknownfiles.keys()) | oldsymlinks) - (set(knownfiles.keys()) | newsymlinks)

def isemptydir(dirpath):
	#scandir would be significantly more efficient, but needs python 3.6 or above
	#which is not reasonable to expect at this time.
	#return os.path.isdir(dirpath) and ((next(os.scandir(dirpath), None)) is None)
	return os.path.isdir(dirpath) and (len(os.listdir(dirpath)) == 0)

for filepath in removedfiles:
	#file may not actually exist, either due to earlier updates gone-wrong
	#or due to the file being a non-realised uncompressed version of
	#a gzipped file.
	if os.path.exists(filepath): 
		print('removing '+filepath.decode('ascii'))
		os.remove(filepath)
		#clean up empty directories.
		dirpath = os.path.dirname(filepath)
		while (len(dirpath) != 0) and isemptydir(dirpath):
			print('removing empty dir '+dirpath.decode('ascii'))
			os.rmdir(dirpath)
			dirpath = os.path.dirname(dirpath)

os.rename('snapshotindex.txt.tmp','snapshotindex.txt')

