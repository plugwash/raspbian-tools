program sourcearchivechecker;
uses
  readtxt2,sysutils, contnrs, classes, process, util;

var
  line : string;
  currentpackage, currentversion, currentsourcepackage, currentsourceversion, currentstatus, currentbuiltusing :string;
  sourcesandversions : tfphashlist;
  
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
  writeln('phase3: checking source packages are complete');
  findresult := findfirst('*',faDirectory,s1);
  while findresult = 0 do begin
    if ((s1.attr and fadirectory) > 0) and (s1.name <> '.') and  (s1.name <> '..') then begin
      findresult := findfirst(''+s1.name+'/*',faDirectory,s2);
      while findresult = 0 do begin
        if ((s2.attr and fadirectory) > 0) and (s2.name <> '.') and  (s2.name <> '..') then begin
          findresult := findfirst(''+s1.name+'/'+s2.name+'/*',faDirectory,s3);
          while findresult = 0 do begin
            if ((s3.attr and fadirectory) > 0) and (s3.name <> '.') and  (s3.name <> '..') then begin
              findresult := findfirst(''+s1.name+'/'+s2.name+'/'+s3.name+'/*.dsc',faanyfile,s4);
              while findresult = 0 do begin
                //writeln(''+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name);
                t := treadtxt.createf(''+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name);
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
                  if not fileexists(''+s1.name+'/'+s2.name+'/'+s3.name+'/'+sl[2]) then begin
                    writeln(''+s1.name+'/'+s2.name+'/'+s3.name+'/'+sl[2]+' needed by '+''+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name+' not found');
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
