#!/usr/bin/python3

# Copyright 2018 Peter Green
# Released under the MIT/Expat license, see doc/COPYING

import os
import sys
import hashlib
import gzip
from sortedcontainers import SortedDict
from sortedcontainers import SortedList
import argparse
import re
from itertools import chain,product
from collections import defaultdict
import subprocess

parser = argparse.ArgumentParser(description="build a snapshot index file")
parser.add_argument("--internal", help="internal mode, various file path mangling for use in private repo on main server", action="store_true")
parser.add_argument("--internalrecover", help="when in internal mode recover missing extra sources from public repo to private repo", action="store_true")
parser.add_argument("--sssextrasources", help="download missing extra sources for main component using snapshotsecure")
parser.add_argument("toplevel", help="top level directory")
parser.add_argument("distribution", help="distribution to generate builtusingextra for")
args = parser.parse_args()

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
			print("file name "+repr(filename)+" contains unexpected characters")
			sys.exit(1)
		elif component[0] == '.':
			print("filenames starting with a dot are not allowed")
			sys.exit(1)


def addfilefromdebarchive(filestoverify,filename,sha256,size):
	ensuresafepath(filename)
	if not shaallowed.fullmatch(sha256):
		print('invalid character in sha256 hash')
		sys.exit(1)	
	size = int(size)
	status = 'M'
	filenamesplit = filename.split(b'/')
	sha256andsize = [sha256,size,status]
	if filename in filestoverify:
		if (sha256andsize[0:1] != filestoverify[filename][0:1]):
			print('error: same file with different hash/size old:'+repr(filestoverify[filename])+' new:'+repr(sha256andsize))
			sys.exit(1)
	else:
		filestoverify[filename] = sha256andsize

def manglefilepath(filepath):
	if args.internal:
		#file paths may be either strings or bytes,
		#convert to bytes for consistency during
		#mangle process, convert back at end.
		if isinstance(filepath,str):
			filepath = filepath.encode('ascii')
			asstr = True
		else:
			asstr = False
		filepath = filepath.split(b'/')
		if filepath[0] == b'raspbian':
			filepath[0] = b'private'
		else:
			filepath = [b'..',b'repo'] + filepath
		filepath = b'/'.join(filepath)
		if asstr:
			filepath = filepath.decode('ascii')
	return filepath

def openg(filepath):
	filepath = manglefilepath(filepath)
	if os.path.exists(filepath):
		f = open(filepath,'rb')
	else:
		f = gzip.open(filepath+b'.gz','rb')
	return f


distlocs = []

def isfilem(filepath):
	return os.path.isfile(manglefilepath(filepath))

def isdirm(filepath):
	return os.path.isdir(manglefilepath(filepath))

def islinkm(filepath):
	if os.path.islink(manglefilepath(filepath)):
		#treat absoloute symlinks as files/directories.
		#print(os.readlink(filepath)[0:1])
		return os.readlink(manglefilepath(filepath))[0:1] != b'/'
	else:
		return False

def listdirm(filepath):
	return os.listdir(manglefilepath(filepath))

def openm(filepath,mode):
	return open(manglefilepath(filepath),mode)

def readlinkm(filepath):
	return os.readlink(manglefilepath(filepath))

toplevel = args.toplevel

knownfiles = SortedDict() #sorted for reproducibility and to hopefully get better locality on file accesses.

neededsources = defaultdict(list)

distdir = toplevel+'/dists/'+args.distribution
toplevel = toplevel.encode('ascii')

f = openm(distdir+'/Release','rb')
insha256 = False;
for line in f:
	#print(repr(line[0]))
	if (line == b'SHA256:\n'):
		insha256 = True
	elif ((line[0] == 32) and insha256):
		linesplit = line.split()
		filename = distdir.encode('ascii')+b'/'+linesplit[2]
		component = (linesplit[2].split(b'/'))[0]
		#if filename in knownfiles:
		#	if files
		addfilefromdebarchive(knownfiles,filename,linesplit[0],linesplit[1]);
		if filename.endswith(b'Packages'):
			print('found packages file: '+filename.decode('ascii'))
			pf = openg(filename)
			filename = None
			size = None
			sha256 = None
			packagefield = None
			sourcefield = None
			versionfield = None
			builtusingfield = None
					
			for line in pf:
				linesplit = line.split()
				if (len(linesplit) == 0):
					if (filename != None):
						addfilefromdebarchive(knownfiles,filename,sha256,size);
					if packagefield is not None:
						#print(packagefield)
						#print(sourcefield)
						if sourcefield is None:
							sourcepackage = packagefield
							sourceversion = versionfield
						elif len(sourcefield) == 1:
							sourcepackage = sourcefield[0]
							sourceversion = versionfield
						elif (sourcefield[1][0] == ord(b'(')) and (sourcefield[1][-1] == ord(b')')):
							sourcepackage = sourcefield[0]
							sourceversion = sourcefield[1][1:-1]
						else:
							#print(len(sourcefield))
							#print(sourcefield[1][0])
							#print(sourcefield[1][-1])
							print('error: cannot decode source package and version')
							sys.exit(1)
						sourcedetails = (toplevel,component,sourcepackage,sourceversion)
						neededsources[sourcedetails].append((packagefield,versionfield))
					if builtusingfield is not None:
						builtusingfield = b' '.join(builtusingfield).split(b',')
						for builtusingitem in builtusingfield:
							builtusingitem = builtusingitem.strip()
							(sourcepackage,sourceversion) = builtusingitem.split(b' ',1)
							if (sourceversion[0:2] != b'(=') or (sourceversion[-1] != ord(b')')):
								print("can't parse built-using")
								sys.exit(1)
							sourceversion = sourceversion[2:-1].strip()
							sourcedetails = (toplevel,component,sourcepackage,sourceversion)
							neededsources[sourcedetails].append((packagefield,versionfield))
					filename = None
					size = None
					sha256 = None
					packagefield = None
					sourcefield = None
					versionfield = None
					builtusingfield = None
				elif (linesplit[0] == b'Filename:'):
					filename = toplevel+b'/'+linesplit[1]
				elif (linesplit[0] == b'Size:'):
					size = linesplit[1]
				elif (linesplit[0] == b'SHA256:'):
					sha256 = linesplit[1]
				elif (linesplit[0] == b'Package:'):
					packagefield = linesplit[1]
				elif (linesplit[0] == b'Source:'):
					sourcefield = linesplit[1:]
				elif (linesplit[0] == b'Version:'):
					versionfield = linesplit[1]
				elif (linesplit[0] == b'Built-Using:'):
					builtusingfield = linesplit[1:]
			pf.close()
		elif filename.endswith(b'Sources'):
			print('found sources file: '+filename.decode('ascii'))
			pf = openg(filename)
			filesfound = [];
			directory = None
			insha256p = False;
			for line in pf:
				linesplit = line.split()
				if (len(linesplit) == 0):
					for ls in filesfound:
						#print(repr(ls))
						addfilefromdebarchive(knownfiles,toplevel+b'/'+directory+b'/'+ls[2],ls[0],ls[1]);
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


def adddsc(prefix, filepath):
	#print('in adddsc, prefix='+repr(prefix)+' filepath='+repr(filepath))
	f = openm(prefix + filepath, 'rb')
	data = f.read()
	f.close()
	sha256hash = hashlib.sha256(data)
	sha256hashed = sha256hash.hexdigest().encode('ascii')
	filesize = len(data)
	knownfiles[filepath] = [sha256hashed, filesize, 'R']
	f.close()
	f = openm(prefix + filepath, 'rb')
	section = None
	filesfound = {}
	hashsections = [b'Files:',b'Checksums-Sha1:',b'Checksums-Sha256:']
	for line in f:
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
	f.close()
	for componentfilename, meta in filesfound.items():
		# print(repr(ls))
		componentfilepath = toplevel + b'/pool/' + testcomponent + b'/' + pooldir + b'/' + source + b'/' + componentfilename
		previouslyknown = componentfilepath in knownfiles
		if meta[3] is None:
			print(repr(meta))
			print('dsc without sha256 cannot currently be handled')
			sys.exit(1)
		addfilefromdebarchive(knownfiles, componentfilepath, meta[3], meta[0]);
		if not previouslyknown:
			knownfiles[componentfilepath][2] = 'R'
		if not isfilem(componentfilepath):
			if (prefix != b''):
				prefixlocal = prefix
			elif args.internalrecover:
				prefixlocal = b'../repo/'
			else:
				prefixlocal = b''
			if (prefixlocal != b'') and (prefixlocal + componentfilepath != manglefilepath(componentfilepath)) and (os.path.isfile(prefixlocal + componentfilepath)):
				print('recovering ' + componentfilepath.decode('ascii') + ' from ' + prefixlocal.decode('ascii'))
				os.link(prefixlocal + componentfilepath, manglefilepath(componentfilepath))
			elif args.sssextrasources is not None:
				print('grabbing missing file '+componentfilepath.decode('ascii')+'  needed by '+filepath.decode('ascii')+' from snapshot.debian.org')
				import urllib.request # import this at local scope because we rarely need it.
				fileurl='http://snapshot.debian.org/file/'+meta[2].decode('ascii')
				with urllib.request.urlopen(fileurl) as response:
					filedata = response.read()
				sha256hash = hashlib.sha256(filedata)
				sha256hashed = sha256hash.hexdigest().encode('ascii')
				if sha256hashed != meta[3]:
					print('hash mismatch while grabbing missing file for dsc from snapshot.debian.org')
					sys.exit(1)
				f = openm(componentfilepath,'wb')
				f.write(filedata)
				f.close()
			else:
				print('missing file while adding dsc for built using')
				sys.exit(1)
	if (prefix != b'') and not isfilem(filepath):
		if prefix + filepath != manglefilepath(filepath):
			print('recovering ' + filepath.decode('ascii') + ' from ' + repr(prefix))
			os.link(prefix + filepath, manglefilepath(filepath))


missingsources = False
for ((toplevel,component,source,version),binaries) in neededsources.items():
	versionsplit = version.split(b':',1)
	versionnoepoch = versionsplit[-1]
	if source[0:3] == b'lib':
		pooldir = source[0:4]
	else:
		pooldir = source[0:1]
	filepath = toplevel+b'/pool/'+component+b'/'+pooldir+b'/'+source+b'/'+source+b'_'+versionnoepoch+b'.dsc'
	components = [component]
	
	if component == b'non-free':
		components.append(b'contrib')
	if component != b'main':
		components.append(b'main')
	found = False
	prefixes = [b'']
	if args.internalrecover:
		prefixes.append(b'../repo/')
	for (prefix,testcomponent) in product(prefixes,components):
		#print('checking '+filepath.decode('ascii'))
		filepath = toplevel+b'/pool/'+testcomponent+b'/'+pooldir+b'/'+source+b'/'+source+b'_'+versionnoepoch+b'.dsc'
		if filepath in knownfiles:
			found = True
			break
		if not pfnallowed.fullmatch(source+b'_'+versionnoepoch+b'.dsc'):
			print("file name contains "+repr(source+b'_'+versionnoepoch+b'.dsc')+" unexpected characters")
			sys.exit(1)
		if isfilem(prefix+filepath):
			adddsc(prefix,filepath)
			found = True
	if (not found) and (args.sssextrasources is not None):
		filepath = toplevel+b'/pool/'+testcomponent+b'/'+pooldir+b'/'+source+b'/'+source+b'_'+versionnoepoch+b'.dsc'
		filepathm = manglefilepath(filepath)
		command = [args.sssextrasources,source,version]
		print(command, flush=True)
		if (subprocess.call(command,cwd=os.path.dirname(filepathm)) != 0): exit(1)
		if isfilem(filepath):
			adddsc(b'',filepath)
			found = True
	if not found:
		filepath = toplevel+b'/pool/'+component+b'/'+pooldir+b'/'+source+b'/'+source+b'_'+versionnoepoch+b'.dsc'
		missingsources = True
		print((toplevel,component,source,version,filepath))
		for binary in binaries:
			print(binary)
		
if missingsources:
	print('aborting due to missing sources')
	sys.exit(1)

f = openm(distdir+'/extrasources','wb')
for filepath, (sha256,filesize,status) in knownfiles.items():
#	print(repr(filepath))
#	print(repr(filesize))
#	print(repr(sha256))
#	print(repr(status))
	if status == 'R':
		f.write(filepath+b' '+str(filesize).encode('ascii')+b':'+sha256+b'\n')

f.close()

