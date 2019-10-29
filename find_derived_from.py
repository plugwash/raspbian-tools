#!/usr/bin/python

# Copyright 2011 Paul Wise 2013 Peter Green
# Released under the MIT/Expat license, see doc/COPYING


#Based on code taken from https://paste.debian.net/plain/78534
#The original code was produced by debian for checking up on 
#what derivatives were doing, this code is intended for use
#by the derivatives themselves.


import tempfile;
import os
import sys
import httplib
import urllib2
import hashlib
import shutil
import logging
import tempfile
import string
import socket
import signal
import subprocess
#import yaml
from debian import deb822, changelog
import apt_pkg
import psycopg2
try: import cjson as json
except ImportError: import json

# http://www.chiark.greenend.org.uk/ucgi/~cjwatson/blosxom/2009-07-02-python-sigpipe.html
def subprocess_setup():
	# Python installs a SIGPIPE handler by default. This is usually not what
	# non-Python subprocesses expect.
	signal.signal(signal.SIGPIPE, signal.SIG_DFL)

def rmtree(dir):
	try: shutil.rmtree(dir)
	except OSError: pass


def get_changelog_entries(tmp_dir, dsc_name):
	#print('getting changelog entries from %s', dsc_name)

	# Preparation
	extract_path = os.path.join(tmp_dir,'extracted')

	# Unpack the source tree
	#print('unpacking source package %s', dsc_name)
	cmdline = ['dpkg-source', '-x', dsc_name, 'extracted']
	process = subprocess.Popen(cmdline, cwd=tmp_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, preexec_fn=subprocess_setup)
	output = process.communicate()[0]
	if process.returncode:
		logging.warning('dpkg-source reported failure to extract %s:', dsc_name)
		logging.warning(output)
		cmdline = ['ls', '-lR', '--time-style=+']
		process = subprocess.Popen(cmdline, cwd=tmp_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, preexec_fn=subprocess_setup)
		output = process.communicate()[0]
		logging.warning(output)
		rmtree(extract_path)
		return None
	#print(os.listdir(tmp_dir))
	# Sanitise the debian dir and changelog file in case it is a symlink to outside
	debian_dir = os.path.join(extract_path, 'debian')
	changelog_filename = os.path.join(debian_dir,'changelog')
	if os.path.islink(debian_dir) or os.path.islink(changelog_filename):
		logging.warning('debian dir or changelog is a symbolic link %s', dsc_name)
		rmtree(extract_path)
		return None

	# Check if the changelog exists
	if not os.path.exists(changelog_filename):
		logging.warning('could not find changelog in %s', dsc_name)
		rmtree(extract_path)
		return None

	# Find out which source package is the most likely derivative
	#print('parsing changelog for %s', dsc_name)
	changelog_file = open(changelog_filename)
	changelog_obj = changelog.Changelog(changelog_file)
	try:
		changelog_entries = [(entry.package, str(entry._raw_version)) for entry in changelog_obj]
	except:
		logging.warning('could not read changelog from %s', dsc_name)
		rmtree(extract_path)
		return None
	del changelog_obj
	changelog_file.close()

	print('Debug: Clean up again '+extract_path);
	rmtree(extract_path)

	return changelog_entries


def find_derived_from(dsc_name,markerstrings):
	dsc_name = os.path.abspath(dsc_name)
	print('debug: finding base source package of ' + dsc_name +' marker string is '+markerstring)
	tmp_dir=tempfile.mkdtemp('','find_derived_from')
	#print('temporary directory is %s',tmp_dir)
	# Get a list of changelog entries
	#print(os.listdir(tmp_dir))
	changelog_entries = get_changelog_entries(tmp_dir, dsc_name)
	#if changelog_entries:
		#print('changelog entries are: %s', ' '.join(['%s %s' % (entry_name, entry_version) for entry_name, entry_version in changelog_entries]))
	rmtree(tmp_dir)
	# Match changelog versions against candidates
	if changelog_entries:
		#print('matching changelog entries against versions possibly derived from')
		for entry in changelog_entries:
			entry_name, entry_version = entry
			foundmarker = False
			for markerstring in markerstrings:
				if entry_version.find(markerstring) != -1:
					found = True
			if not found:
				return entry;
			#print(entry);
	return None
entry_name, entry_version =  find_derived_from(sys.argv[1],sys.argv[2].split('$')

print('name: '+entry_name)
print('version: '+entry_version)
