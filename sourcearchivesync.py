#!/usr/bin/python3

# Copyright 2018 Peter Green
# Released under the MIT/Expat license, see doc/COPYING

import os
import sys
import hashlib
import gzip
import urllib.request
import urllib.parse
import stat
#from sortedcontainers import SortedDict
#from sortedcontainers import SortedList
from collections import deque
from collections import OrderedDict
from datetime import datetime
from email.utils import parsedate_to_datetime
import argparse
import re

parser = argparse.ArgumentParser(description="sync source packages into pool-like structure")
parser.add_argument("baseurl", help="base url for snapshot source")

parser.add_argument("hashpool", help="specify location of hash pool")
parser.add_argument("--dsclist", help="specify file containing list of dscs rather than scanning source")

args = parser.parse_args()

hashpool = args.hashpool.encode('ascii')
if hashpool[-1:] != b'/':
	hashpool += b'/'

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

def makehashfn(sha256):
	return hashpool + sha256[:2] +b'/'+ sha256[:4] +b'/'+ sha256

def linkorcheck(path,sha256):
	hashfn = makehashfn(sha256)
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

def getfile(path,sha256,size):
	ensuresafepath(path)
	if not shaallowed.fullmatch(sha256):
		print('invalid character in sha256 hash')
		sys.exit(1)
	hashfn = makehashfn(sha256)
	if os.path.isfile(hashfn):
		if os.path.getsize(hashfn) != size:
			print('size mismatch on existing file in hash pool')
			sys.exit(1)
	else:
		print('downloading '+path.decode('ascii')+' with hash '+sha256.decode('ascii'))
		fileurl = baseurl + b'/' + path
		#fileurl = baseurl + hashfn[2:]
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
		hashdir = os.path.dirname(hashfn)
		os.makedirs(hashdir,exist_ok=True)
		f = open(hashfn,'wb')
		f.write(data)
		f.close()
		
		os.utime(hashfn,(ts,ts))
	linkorcheck(path,sha256)

baseurl = args.baseurl.encode('ascii')
if baseurl[-1] != b'/':
	baseurl += b'/'

def urldirlist(url, subdirsonly):
	print('downloading dir list for '+url.decode('ascii'))
	if url[:7] == b'file://':
		result = os.listdir(url[7:])
		if subdirsonly:
			oldresult = result
			result = []
			for filename in oldresult:
				if os.path.isdir(os.path.join(url[7:],filename)):
					result.append(filename)
	else:
			
		with urllib.request.urlopen(url.decode('ascii')) as response:
			dirdata = response.read()
			dirregex = re.compile(b'href="[a-z0-9A-Z\-_:\+~\.%]+/?"',re.ASCII)
			dirmatches = dirregex.findall(dirdata)
			result = []
			for match in dirmatches:
				match = match[6:-1]
				match = urllib.parse.unquote_to_bytes(match)
				if match[-1] == ord(b'/'):
					match = match[:-1]
				elif subdirsonly:
					continue
				if (match == b'.') or (match == b'..'):
					continue
				#print(match)
				result.append(match)
			#sys.exit(1)
	return result


def handledsc(baseurl,component,prefix,package,filename):
				if filename[-4:] != b'.dsc':
					return
				if not pfnallowed.fullmatch(filename):
					print('disallowed characters in filename')
					sys.exit(1)
				packagef, version = filename[:-4].split(b'_')
				if packagef[:3] == b'lib':
					prefixf = packagef[:4]
				else:
					prefixf = packagef[:1]
				if (packagef != package) or (prefixf != prefix):
					print('package in wrong directory')
					sys.exit(1)
				dscpath = component+b'/'+prefix+b'/'+package+b'/'+filename
				if os.path.exists(dscpath):
					return
				dscurl = baseurl + dscpath
				print("downloading "+dscurl.decode('ascii'))
				data,ts = geturl(dscurl)

				section = None
				filesfound = {}
				hashsections = [b'Files:',b'Checksums-Sha1:',b'Checksums-Sha256:']
				for line in data.split(b'\n'):
					linesplit = line.split()
					if len(linesplit) == 0:
						pass
					elif (line[0] == 32):
						if (section in hashsections):
							componentfilename = linesplit[2]
							filesizestr = linesplit[1]
							if componentfilename in filesfound:
								meta = filesfound[componentfilename]
								if meta[0] != filesizestr:
									print('inconsistent dsc')
									sys.exit(1)
								if filesizestr != str(int(filesizestr)).encode('ascii'):
									print('bogus size string')
									sys.exit(1)
							else:
								meta = [filesizestr]+([None]*len(hashsections))
								filesfound[componentfilename] = meta
							if not shaallowed.fullmatch(linesplit[0]):
								print('bogus character found in hash')
								sys.exit(1)
							meta[hashsections.index(section)+1] = linesplit[0]
					else:
						section = linesplit[0]
				#print(filesfound)
				for componentfilename, meta in filesfound.items():
					componentfilepath = component+b'/'+prefix+b'/'+package+b'/'+componentfilename
					if meta[3] is None:
						#print(repr(meta))
						#print('dsc without sha256 cannot currently be handled while processing '+componentfilename.decode('ascii')+' in '+dscpath.decode('ascii'))
						#sys.exit(1)
						#we don't have the sha256 so we can't use the hashpool at this point
						if os.path.exists(componentfilepath):
							f = open(componentfilepath,'rb')
							componentdata = f.read()
							f.close()
						else:
							componentdata,componentts = geturl(baseurl+componentfilepath)
						md5hash = hashlib.md5(componentdata)
						md5hashed = md5hash.hexdigest().encode('ascii')
						if md5hashed != meta[1]:
							print('md5 mismatch')
							sys.exit(1)
						
						if meta[2] is not None:
							sha1hash = hashlib.sha1(componentdata)
							sha1hashed = sha1hash.hexdigest().encode('ascii')
							if sha1hashed != meta[2]:
								print('sha1 mismatch')
								sys.exit(1)
						sha256hash = hashlib.sha256(componentdata)
						sha256hashed = sha256hash.hexdigest().encode('ascii')
						hashfn = makehashfn(sha256hashed)
						if not os.path.exists(hashfn):
							hashdir = os.path.dirname(hashfn)
							os.makedirs(hashdir,exist_ok=True)
							f = open(hashfn,'wb')
							f.write(componentdata)
							f.close()
							os.utime(hashfn,(componentts,componentts))
						linkorcheck(componentfilepath,sha256hashed)

					else:
						#we have the sha256 so we can use the standard getfile which will only download stuff we don't already
                        #have in either the tree or the hashpool.
						getfile(componentfilepath,meta[3],int(meta[0]))	


				sha256hash = hashlib.sha256(data)
				sha256hashed = sha256hash.hexdigest().encode('ascii')
				hashfn = makehashfn(sha256hashed)
				if not os.path.exists(hashfn):
					hashdir = os.path.dirname(hashfn)
					os.makedirs(hashdir,exist_ok=True)
					f = open(hashfn,'wb')
					f.write(data)
					f.close()
					os.utime(hashfn,(ts,ts))
				linkorcheck(dscpath,sha256hashed)

if args.dsclist is not None:
	f = open(args.dsclist,'rb')
	for line in f:
		component,prefix,package,filename = line.strip().split(b'/')
		handledsc(baseurl,component,prefix,package,filename)
	f.close()
else:
	for component in urldirlist(baseurl,True):
		for prefix in urldirlist(baseurl+component+b'/',True):
			for package in urldirlist(baseurl+component+b'/'+prefix+b'/',True):
				for filename in urldirlist(baseurl+component+b'/'+prefix+b'/'+package+b'/',False):
					handledsc(baseurl,component,prefix,package,filename)
