program repochecker;
uses
  readtxt2,sysutils, contnrs, classes, process, util;

var
  line : string;
  currentpackage, currentversion, currentsourcepackage, currentsourceversion, currentstatus, currentbuiltusing :string;
  sourcesandversions : tfphashlist;
  

procedure reset;
begin
  currentpackage := '';
  currentversion := '';
  currentsourcepackage := '';
  currentsourceversion := '';
  currentstatus := '';
  currentbuiltusing := '';
  
end;

procedure processpackage;
var
  inbrackets : boolean;
  dependency : string;
  sourceandversion : string;
  builtusingstringlist : tstringlist;
  i : integer;
begin
  if currentversion = '' then begin
    writeln(erroutput,'package without version!');
    halt;
  end;
  if currentsourcepackage = '' then currentsourcepackage := currentpackage;
  if currentsourceversion = '' then currentsourceversion := currentversion;
  sourceandversion := currentsourcepackage + ' ' +currentsourceversion;
  //writeln(erroutput,sourceandversion);
  if sourcesandversions.findindexof(sourceandversion) < 0 then sourcesandversions.add(sourceandversion,pointer($deadbeef));
  if currentbuiltusing <> '' then begin
    builtusingstringlist := tstringlist.create;
    extractstrings([','],[' '],pchar(currentbuiltusing),builtusingstringlist);
    for i := 0 to builtusingstringlist.count-1 do begin
      sourceandversion := stringreplace(builtusingstringlist[i],' (= ',' ',[]);
      setlength(sourceandversion,length(sourceandversion)-1);
      //writeln('!'+sourceandversion);
      if sourcesandversions.findindexof(sourceandversion) < 0 then sourcesandversions.add(sourceandversion,pointer($deadbeef));
    end;
    builtusingstringlist.free;
  end;
  
end;

procedure processtext(t : treadtxt; stripinitialspace : boolean);
var
  p : integer;
  sourcelinecontent : string;
begin
  
  reset;
  repeat
    line := t.readline;
    if stripinitialspace and (length(line) > 0) then begin
      if line[1] = ' ' then line := copy(line,2,maxlongint); 
    end;
    //writeln(erroutput,line);
    if stringstartis(line,'Package:') then begin
      currentpackage := trim(copy(line,9,maxlongint));
    end;
    if stringstartis(line,'Version:') then begin
      currentversion := trim(copy(line,9,maxlongint));
    end;
    if stringstartis(line,'Source:') then begin
      sourcelinecontent := trim(copy(line,8,maxlongint));
      p := pos('(',sourcelinecontent);
      if p = 0 then begin
        currentsourcepackage := sourcelinecontent;
      end else begin
        currentsourcepackage := trim(copy(sourcelinecontent,1,p-1));
        currentsourceversion := copy(sourcelinecontent,p+1,255);
        p := pos(')',currentsourceversion);
        currentsourceversion := trim(copy(currentsourceversion,1,p-1));
      end;
    end;
    if stringstartis(line,'Built-Using:') then begin
      currentbuiltusing := trim(copy(line,13,maxlongint));
    end;
    if stringstartis(line,'Status:') then begin
      currentstatus := trim(copy(line,8,maxlongint));
    end;
    if line = '' then begin
      //end of block
      if currentpackage <> '' then processpackage;
      reset;
    end;
  until t.eof;
  if currentpackage <> '' then processpackage;
end;

procedure processfile(filename:string);
var
  t: treadtxt;

begin 
  //writeln(filename);
  t := treadtxt.createf(filename);
  processtext(t,true);
  t.free;
end;


var
  i: integer;
  s1,s2,s3,s4 : tsearchrec;
  findresult : longint;
  param : string;
  process : tprocess;
  sourcepackage,version,dirname,filepath : string;
  p : integer;
  found : boolean;
  exitstatus : integer;
  t:treadtxt;
  sl : tstringlist;
begin
  writeln('checking that required sources are available');
  writeln('phase 1: reading package lists');
  sourcesandversions := tfphashlist.create;
  findresult := findfirst('dists/*',faDirectory,s1);
  while findresult = 0 do begin
    if ((s1.attr and fadirectory) > 0) and (s1.name <> '.') and  (s1.name <> '..') then begin
      findresult := findfirst('dists/'+s1.name+'/*',faDirectory,s2);
      while findresult = 0 do begin
        if ((s2.attr and fadirectory) > 0) and (s2.name <> '.') and  (s2.name <> '..') then begin
          findresult := findfirst('dists/'+s1.name+'/'+s2.name+'/binary-*',faDirectory,s3);
          while findresult = 0 do begin
            if ((s3.attr and fadirectory) > 0) and (s3.name <> '.') and  (s3.name <> '..') then begin
              processfile('dists/'+s1.name+'/'+s2.name+'/'+s3.name+'/Packages');
            end;
            findresult := findnext(s3);
          end;
          findclose(s3);
          findresult := findfirst('dists/'+s1.name+'/'+s2.name+'/debian-installer/binary-*',faDirectory,s3);
          while findresult = 0 do begin
            if ((s3.attr and fadirectory) > 0) and (s3.name <> '.') and  (s3.name <> '..') then begin
              processfile('dists/'+s1.name+'/'+s2.name+'/debian-installer/'+s3.name+'/Packages');
            end;
            findresult := findnext(s3);
          end;
          findclose(s3);
        end;
        findresult := findnext(s2);
      end;
      findclose(s2);
    end;
    findresult := findnext(s1);
  end;
  findclose(s1);

  writeln('phase2: checking required source packages are in the pool');
  exitstatus := 0;
  for i := 0 to sourcesandversions.count - 1 do begin
    line := sourcesandversions.nameofindex(i);
    p := pos(' ',line);
    sourcepackage := copy(line,1,p-1);
    version := copy(line,p+1,maxlongint);
    makesourcepackagepath(sourcepackage,version,dirname,filepath);
    found := false;
    findresult := findfirst('pool/*',faDirectory,s1);
    while findresult = 0 do begin
      if ((s1.attr and fadirectory) > 0) and (s1.name <> '.') and  (s1.name <> '..') then begin
        if fileexists('pool/'+s1.name+'/'+filepath) then found := true;
      end;
      findresult := findnext(s1);
    end;
    findclose(s1);
    if not found then begin
      writeln('failed to find ',filepath);
      exitstatus := 1;
    end;
  end;
  if exitstatus > 0 then begin
    writeln('exiting with error due to sources not found');
    halt(exitstatus);
  end;
  sl := tstringlist.create;
  writeln('phase3: checking source packages are complete');
  findresult := findfirst('pool/*',faDirectory,s1);
  while findresult = 0 do begin
    if ((s1.attr and fadirectory) > 0) and (s1.name <> '.') and  (s1.name <> '..') then begin
      findresult := findfirst('pool/'+s1.name+'/*',faDirectory,s2);
      while findresult = 0 do begin
        if ((s2.attr and fadirectory) > 0) and (s2.name <> '.') and  (s2.name <> '..') then begin
          findresult := findfirst('pool/'+s1.name+'/'+s2.name+'/*',faDirectory,s3);
          while findresult = 0 do begin
            if ((s3.attr and fadirectory) > 0) and (s3.name <> '.') and  (s3.name <> '..') then begin
              findresult := findfirst('pool/'+s1.name+'/'+s2.name+'/'+s3.name+'/*.dsc',faanyfile,s4);
              while findresult = 0 do begin
                //writeln('pool/'+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name);
                t := treadtxt.createf('pool/'+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name);
                line :=t.readline;
                while trim(line) <> 'Files:' do begin
                  if t.eof then begin
                    writeln('broken dsc found, no files section');
                    halt(99);
                  end;
                  Line := t.readline;
                end;
                while not t.eof do begin
                  line := t.readline;
                  if length(line) =0 then break;
                  if line[1] <> ' ' then break;
                  //writeln(line);
                  sl.clear;
                  extractstrings([' '],[],pchar(line),sl);
                  //for i := 0 to sl.count-1 do begin
                    //writeln(sl[i]);
                  //end;
                  if not fileexists('pool/'+s1.name+'/'+s2.name+'/'+s3.name+'/'+sl[2]) then begin
                    writeln('pool/'+s1.name+'/'+s2.name+'/'+s3.name+'/'+sl[2]+' needed by '+'pool/'+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name+' not found');
                    exitstatus := 2;
                  end;
                end;
                t.free;
                //halt;
                findresult := findnext(s4);
              end;
              findclose(s4);
            end;
            findresult := findnext(s3);
          end;
          findclose(s3);
          
        end;
        findresult := findnext(s2);
      end;
      findclose(s2);
    end;
    findresult := findnext(s1);
  end;
  findclose(s1);

  if exitstatus > 0 then begin
    writeln('exiting with error due to incomplete source package in pool');
    halt(exitstatus);
  end;
  
end.
