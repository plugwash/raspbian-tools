#!/usr/bin/php
<?php
//code to grab sourcecode from snapshot.debian.org
//first parameter is s for source package name and version or b for 
//binary package name and version
//second parameter is name
//third parameter is version

//print($argv[1]."\n");
//print($argv[2]."\n");
//print($argv[3]."\n");

$type = $argv[1];
$name = $argv[2];
$version = $argv[3];
if ($type=='b') {
  print("looking up binary package $name $version\n");
  //translate binary package name and version to source package name and version
  $json = file_get_contents('http://snapshot.debian.org/mr/binary/'.$name.'/');
  $jsontree = json_decode($json,true);
  //var_dump($jsontree);
  $srcname = '';
  $srcversion = '';
  foreach($jsontree['result'] as $entry) {
    if ($entry['binary_version']==$version) {
      $srcname = $entry['source'];
      $srcversion = $entry['version'];
    }
  }
  if (($srcname == '') || ($srcversion == '')) {
    print("could not find source package\n");
    die;
  }
  $name = $srcname;
  $version = $srcversion;
  print("translated to source package $name $version\n");
} else if ($type=='s') {
  //we already have a source package name and version;
} else {
  print("unrecognised package type\n");
  die;
}

$json = file_get_contents('http://snapshot.debian.org/mr/package/'.$name.'/'.$version.'/srcfiles');
$jsontree = json_decode($json,true);
//var_dump($jsontree);
$sourcefiles = $jsontree['result'];
foreach($sourcefiles as $entry) {
  $hash = $entry['hash'];
  print($hash."\n");
  $json = file_get_contents('http://snapshot.debian.org/mr/file/'.$hash.'/info');
  $jsontree = json_decode($json,true);
  $result = $jsontree['result'][0];
  //var_dump($result);
  $filename = $result['name'];
  $fileurl = 'http://snapshot.debian.org/archive/'.$result['archive_name'].'/'.$result['first_seen'].$result['path'].'/'.$filename;
  if (file_exists($filename)) {
    $filecontents = file_get_contents($filename);
    if ($hash != sha1($filecontents)) {
      print('hash sum mismatch while validating existing file '.$filename.'\n');
      die;
    }
    print("used existing file $filename\n");
  } else {
    $filecontents = file_get_contents($fileurl);
    if ($hash != sha1($filecontents)) {
      print('hash sum mismatch while retreiving '.$fileurl.'\n');
      die;
    }
    file_put_contents($filename,$filecontents);
    print("$fileurl saved as $filename\n");
  }
}

?>