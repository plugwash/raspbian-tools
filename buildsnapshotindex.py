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
parser.add_argument("--recover", help="add missing files to snapshot from hashpool if possible", action="store_true")
parser.add_argument("--internal", help="internal mode, various file path mangling for use in private repo on main server", action="store_true")
parser.add_argument("--internalrecover", help="when in internal mode recover missing extra sources from public repo to private repo", action="store_true")
parser.add_argument("--nohashpool", help="do not add files to hash pool", action="store_true")
parser.add_argument("--noscanpool", help="do not perform file search in pool directories, just include files from Debian metadata",action="store_true")
parser.add_argument("--addextrasources", help="add extra sources needed by outdated binaries and/or built-using fields", action="store_true")
parser.add_argument("--sssextrasources", help="download missing extra sources for main component using snapshotsecure")
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
	if args.noscanpool and (filenamesplit[1] == b'pool'):
		status = 'A'
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

if args.internal:
	dirlist = os.listdir('../repo')
	if 'raspbian' not in dirlist:
		dirlist.append('raspbian')
else:
	dirlist = os.listdir('.')

def isfilem(filepath):
	return os.path.isfile(manglefilepath(filepath))

def isdirm(filepath):
	return os.path.isdir(manglefilepath(filepath))

def islinkm(filepath):
	return os.path.islink(manglefilepath(filepath))

def listdirm(filepath):
	return os.listdir(manglefilepath(filepath))

def openm(filepath,mode):
	return open(manglefilepath(filepath),mode)

def readlinkm(filepath):
	return os.readlink(manglefilepath(filepath))

for toplevel in dirlist:
	if isdirm(toplevel+'/dists/'):
		dists = listdirm(toplevel+'/dists/')
		for dist in dists:
			if not islinkm(toplevel+'/dists/'+dist):
				distlocs.append((toplevel+'/dists/'+dist,toplevel.encode('ascii')))

knownfiles = SortedDict() #sorted for reproducibility and to hopefully get better locality on file accesses.

neededsources = defaultdict(list)

for distdir, toplevel in distlocs:
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
							if args.addextrasources and (packagefield is not None):
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
							if args.addextrasources and (builtusingfield is not None):
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
	print('in adddsc, prefix='+repr(prefix)+' filepath='+repr(filepath))
	f = openm(prefix + filepath, 'rb')
	data = f.read()
	f.close()
	sha256hash = hashlib.sha256(data)
	sha256hashed = sha256hash.hexdigest().encode('ascii')
	filesize = len(data)
	knownfiles[filepath] = [sha256hashed, filesize, 'R']
	f.close()
	f = openm(prefix + filepath, 'rb')
	insha256p = False
	filesfound = []
	for line in f:
		linesplit = line.split()
		if len(linesplit) == 0:
			pass
		elif ((line[0] == 32) and insha256p):
			filesfound.append(linesplit)
		elif (linesplit[0] == b'Checksums-Sha256:'):
			insha256p = True
		else:
			insha256p = False
		pf.close()
	for ls in filesfound:
		# print(repr(ls))
		componentfilepath = toplevel + b'/pool/' + testcomponent + b'/' + pooldir + b'/' + source + b'/' + ls[2]
		previouslyknown = componentfilepath in knownfiles
		addfilefromdebarchive(knownfiles, componentfilepath, ls[0], ls[1]);
		if not previouslyknown:
			knownfiles[componentfilepath][2] = 'R'
		if not isfilem(componentfilepath):
			if (prefix != b''):
				prefixlocal = prefix
			elif args.internalrecover:
				prefixlocal = b'../repo/'
			else:
				prefixlocal = b''
			if (prefixlocal != b'') and (prefixlocal + componentfilepath != manglefilepath(componentfilepath)):
				print('recovering ' + componentfilepath.decode('ascii') + ' from ' + prefixlocal.decode('ascii'))
				os.link(prefixlocal + componentfilepath, manglefilepath(componentfilepath))
			else:
				print('missing file while adding dsc for built using')
				sys.exit(1)
	if (prefix != b'') and not isfilem(filepath):
		if prefix + filepath != manglefilepath(filepath):
			print('recovering ' + filepath.decode('ascii') + ' from ' + repr(prefix))
			os.link(prefix + filepath, manglefilepath(filepath))
	f.close()


if args.addextrasources:
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

#print(knownfiles.items()[0])
#sys.exit(1)
symlinks = SortedList()

for filepath, meta in knownfiles.items():
	#print(repr(meta))
	(sha256,filesize,status) = meta
	if (filepath + b'.gz') in knownfiles:
		print('found file '+filepath.decode('ascii')+'  with .gz counterpart')
		f = gzip.open(manglefilepath(filepath)+b'.gz','rb')
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

if args.internal:
	if args.noscanpool:
		towalk = chain(os.walk('../repo',True,throwerror,False),os.walk('private/dists',True,throwerror,False))
	else:
		towalk = chain(os.walk('../repo',True,throwerror,False),os.walk('private/dists',True,throwerror,False),os.walk('private/pool',True,throwerror,False))
else:
	towalk = os.walk('.',True,throwerror,False)

for (dirpath,dirnames,filenames) in towalk:
	#if dirpath == './raspbian/dists':
	#	print(dirpath)
	#	print(dirnames)
	#	print(filenames)
	#print(dirpath)
	physicaldirpath = dirpath
	if args.internal:
		if dirpath == '../repo':
			i = 0
			while i < len(dirnames):
				if dirnames[i] == 'raspbian':
					del dirnames[i]
				else:
					i += 1
		dirpath = dirpath.split('/')
		if dirpath[0] == '..' and dirpath[1] == 'repo':
			dirpath = ['.'] + dirpath[2:]
		elif dirpath[0] == 'private':
			dirpath = ['.','raspbian'] + dirpath[1:]
		else:
			print("can't demangle dir path")
			sys.exit(1)
		dirpath = '/'.join(dirpath)
		print('scanning logical path '+dirpath+' physical path '+physicaldirpath)
	else:
		print('scanning '+dirpath)
	if args.noscanpool:
		dirpathsplit = dirpath.split('/')
		if len(dirpathsplit) == 2:
			i = 0
			while i < len(dirnames):
				if dirnames[i] == 'pool':
					del dirnames[i]
				else:
					i += 1
					
	for filename in (filenames+dirnames): #os.walk seems to regard symlinks to directories as directories.
		filepath = os.path.join(dirpath,filename)[2:].encode('ascii') # [2:] is to strip the ./ prefix
		#print(filepath)
		if islinkm(filepath):
			symlinks.add(filepath)
	for filename in filenames:
		filepath = os.path.join(dirpath,filename)[2:].encode('ascii') # [2:] is to strip the ./ prefix
		if not islinkm(filepath) and not filepath.startswith(b'snapshotindex.txt'):
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
				f = openm(filepath,'rb')
				filesize = 0
				sha256hash = hashlib.sha256()
				while True:
					data = f.read(65536);
					if not data:
						break
					filesize += len(data)
					sha256hash.update(data)
				f.close()
	
				sha256hashed = sha256hash.hexdigest().encode('ascii')
				knownfiles[filepath] = [sha256hashed,filesize,'R']

normalcount = 0
rootcount = 0
missingcount = 0
uncompressedcount = 0
assumedcount = 0

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
	elif status == 'A':
		assumedcount +=1
	else:
		print('unknown status')
		sys.exit(1)

print('normal count:'+str(normalcount))
print('root count: '+str(rootcount))
print('uncompressed count: '+str(uncompressedcount))
if args.noscanpool:
	print('assumed count: '+str(assumedcount))
print('missing count: '+str(missingcount))

if missingcount > 0:
	if args.recover:
		for filepath, (sha256hashed,filesize,status) in knownfiles.items():
			if status == 'M':
				print('recovering missing file '+filepath.decode('ascii'))
				os.makedirs(os.path.dirname(filepath),exist_ok=True)
				hashdir = b'../hashpool/'+sha256hashed[:2]+b'/'+sha256hashed[:4]
				hashfn = hashdir + b'/' + sha256hashed
				os.link(hashfn,filepath)
	else:
		print('missing files, aborting')
		sys.exit(1)

if not args.nohashpool:
	for filepath, (sha256,filesize,status) in knownfiles.items():
		if status == 'U':
			continue #we don't bother storing uncompressed versions of compressed files.
		hashdir = b'../hashpool/'+sha256[:2]+b'/'+sha256[:4]
		hashfn = hashdir + b'/' + sha256
		if os.path.isfile(hashfn):
			continue #we already have this in the hash pool
		print('adding '+filepath.decode('ascii')+' with hash '+sha256.decode('ascii')+' to hash pool')
		f = openm(filepath,'rb')
		sha256hash = hashlib.sha256()
		while True:
			data = f.read(65536);
			if not data:
				break
			sha256hash.update(data)
		f.close()
	
		sha256hashed = sha256hash.hexdigest().encode('ascii')
		if (sha256 != sha256hashed):
			print('hash mismatch');
			sys.exit(1)
		os.makedirs(hashdir,exist_ok=True)
		os.link(manglefilepath(filepath),hashfn)

f = open('snapshotindex.txt','wb')
for filepath, (sha256,filesize,status) in knownfiles.items():
#	print(repr(filepath))
#	print(repr(filesize))
#	print(repr(sha256))
#	print(repr(status))
	if status == 'R':
		f.write(filepath+b' '+str(filesize).encode('ascii')+b':'+sha256+b'\n')

for filepath in symlinks:
		f.write(filepath+b' ->'+readlinkm(filepath)+b'\n')

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

