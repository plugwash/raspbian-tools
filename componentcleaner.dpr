program componentcleaner;
uses
  readtxt2,sysutils, contnrs, versions, classes;
const
  reporoot = '/home/repo/repo/raspbian/';
  codename = 'wheezy';
  codenamestaging = 'wheezy-staging';
  architecture = 'armhf';
  

var
    t : treadtxt;
    currentpackage, currentversion, currentsourcepackage, currentsourceversion , currentdepends :string;

procedure reset;
begin
  currentpackage := '';
  currentversion := '';
  currentsourcepackage := '';
  currentsourceversion := '';
end;

procedure processpackage(list:tfphashlist);
var
  versionpchar : pchar;
begin
  if currentversion = '' then begin
    writeln('package without version');
    halt;
  end;
  getmem(versionpchar,length(currentversion)+1);
  move(currentversion[1],versionpchar^,length(currentversion)+1);
  list.add(currentpackage,versionpchar);
end;
function stringstartis(const s,start : string) : boolean;
var
  i : integer;
begin
  if length(s) < length(start) then begin
    result := false;
    exit;
  end;
  for i := 1 to length(start) do begin
    if s[i] <> start[i] then begin
      result := false;
      exit
    end;
  end;
  result := true;
end;

procedure readcontrolfile(filename :string;list : tfphashlist);
var
  p : integer;
  pass : byte;
  i : integer;
  line : string;
  t : treadtxt;
begin
  //writeln(compareversion('1','2'));
  //writeln(compareversion('1-1','1-2'));
  //writeln(compareversion('2','1'));
  //writeln(compareversion('1','1'));
  //halt;
  t := treadtxt.createf(filename);
  reset;
  repeat
    line := t.readline;
    if copy(line,1,8) = 'Package:' then begin
      currentpackage := trim(copy(line,9,255));
    end;
    if copy(line,1,8) = 'Version:' then begin
      currentversion := trim(copy(line,9,255));
    end;
    if line = '' then begin
      //end of block
      if currentpackage <> '' then processpackage(list);
      reset;
    end;
  until t.eof;
  if currentpackage <> '' then processpackage(list);
  
  t.free;
end;

const
  componentcount = 4;
type
  tcomponentnames = array[0..componentcount-1] of string;
const
  componentnames : tcomponentnames = ('main','contrib','non-free','rpi');
var
  components: array[0..componentcount-1] of tfphashlist;
  packagesinmultiple : tfphashlist;
procedure checkmultiple;
var
  i,j,k : integer;
  packagename : string;
begin
  for i := 0 to componentcount-2 do begin
    for j := i+1 to componentcount-1 do begin
      for k := 0 to components[i].count-1 do begin
        packagename := components[i].nameofindex(k);
        // writeln(i,' ',j,' ',componentnames[i],' ',packagename,' ',components[j].findindexof(packagename));

        if components[j].findindexof(packagename) >= 0 then begin
          //writeln(packagename);
          packagesinmultiple.add(packagename,pointer($deadbeef));
        end;
      end;
    end;
  end;
end;

var
  tout: textfile;

procedure calculateremovals(codename,architecture : string);
var
  i,j : integer;
  highestversion : string;
  versionpchar : pchar;
  versionstring : string;
  packagename : string;
begin
  for i := 0 to packagesinmultiple.count -1 do begin
    highestversion := '';
    packagename := packagesinmultiple.nameofindex(i);
    //writeln('foo');
    for j := 0 to componentcount-1 do begin
      versionpchar := components[j].find(packagename);
      if assigned(versionpchar) then begin
        if highestversion = '' then begin
          highestversion := versionpchar;
        end else begin
          if compareversion(versionpchar,highestversion) > 0 then highestversion := versionpchar;
        end;
      end;
    end;
    //writeln('bar');
    for j := 0 to componentcount-1 do begin
      versionpchar := components[j].find(packagename);
      if assigned(versionpchar) then begin
        versionstring := versionpchar;
        if versionstring = highestversion then begin
          writeln(packagename,' ',versionstring,' should be kept in ',componentnames[j]);
        end else begin
          writeln(packagename,' ',versionstring,' should be removed from ',componentnames[j]);
          writeln(tout,'reprepro -V --basedir . --morguedir +b/morgue --export=never --arch='+architecture+' --component='+componentnames[j]+' remove ',codename,' ',packagename);
        end;
      end;
    end;
    //writeln('baz');
  end;
end;

var
  i : integer;
begin
  assignfile(tout,'removals.sh');
  rewrite(tout);
  
  writeln('reading sources files for main distribution');
  for i := 0 to componentcount-1 do begin
    components[i] := tfphashlist.create();
    //components[i].add('foo',100);
    readcontrolfile(reporoot+'dists/'+codename+'/'+componentnames[i]+'/source/Sources',components[i]);
    writeln(components[i].findindexof('foo'));
    writeln(components[i].count);
  end;
  writeln('looking for source packages in multiple components');
  packagesinmultiple := tfphashlist.create;
  checkmultiple;
  writeln(packagesinmultiple.count);
  calculateremovals(codename,'source');
  writeln('reading packages files for main distribution');
  for i := 0 to componentcount-1 do begin
    components[i].clear;
    readcontrolfile(reporoot+'dists/'+codename+'/'+componentnames[i]+'/binary-'+architecture+'/Packages',components[i]);
    writeln(components[i].count);
  end;
  readcontrolfile(reporoot+'dists/'+codename+'/main/debian-installer/binary-'+architecture+'/Packages',components[0]);
  writeln('looking for binary packages in multiple components');
  packagesinmultiple.clear;
  checkmultiple;
  writeln(packagesinmultiple.count);
  calculateremovals(codename,architecture);
  //write export
  writeln(tout,'reprepro -V --basedir . --morguedir +b/morgue export ',codename);
  
  
  writeln('reading sources files for staging distribution');
  for i := 0 to componentcount-1 do begin
    components[i] := tfphashlist.create();
    //components[i].add('foo',100);
    readcontrolfile(reporoot+'dists/'+codenamestaging+'/'+componentnames[i]+'/source/Sources',components[i]);
    writeln(components[i].findindexof('foo'));
    writeln(components[i].count);
  end;
  writeln('looking for source packages in multiple components');
  packagesinmultiple := tfphashlist.create;
  checkmultiple;
  writeln(packagesinmultiple.count);
  calculateremovals(codenamestaging,'source');
  writeln('reading packages files for staging distribution');
  for i := 0 to componentcount-1 do begin
    components[i].clear;
    readcontrolfile(reporoot+'dists/'+codenamestaging+'/'+componentnames[i]+'/binary-'+architecture+'/Packages',components[i]);
    writeln(components[i].count);
  end;
  readcontrolfile(reporoot+'dists/'+codenamestaging+'/main/debian-installer/binary-'+architecture+'/Packages',components[0]);
  writeln('looking for binary packages in multiple components');
  packagesinmultiple.clear;
  checkmultiple;
  writeln(packagesinmultiple.count);
  calculateremovals(codenamestaging,architecture);
  
  
  //write export
  writeln(tout,'reprepro -V --basedir . --morguedir +b/morgue export ',codenamestaging);
  closefile(tout);
end.
