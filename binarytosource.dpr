
program binarytosource;
uses
  readtxt2,sysutils, contnrs, versions, classes, util;

var
  t : treadtxt;
  line : string;
  currentpackage, currentversion, currentsourcepackage, currentsourceversion , currentdepends :string;
  packages : tfpstringhashtable;


procedure reset;
begin
  currentpackage := '';
  currentversion := '';
  currentsourcepackage := '';
  currentsourceversion := '';
end;

procedure processpackage;
var
  sourceversionfromsources : string;
  versioncomparison : integer;
  inbrackets : boolean;
  dependency : string;
  c : char;
  i : integer;
  rdeplist : tfphashlist;
begin
  if currentversion = '' then begin
    writeln('package without version!');
    halt;
  end;
  if currentsourcepackage = '' then currentsourcepackage := currentpackage;
  if currentsourceversion = '' then currentsourceversion := currentversion;
  packages.add(currentpackage,currentsourcepackage);
  
end;

var
  sourcelinecontent : string;
  p : integer;
  pass : byte;
  packagesfile : string;
  outputlist : tfphashlist;
  i : integer;
begin
  //writeln(compareversion('1','2'));
  //writeln(compareversion('1-1','1-2'));
  //writeln(compareversion('2','1'));
  //writeln(compareversion('1','1'));
  //halt;
  packages := tfpstringhashtable.create;
      //writeln('starting pass ',pass);
  packagesfile := paramstr(1);
  t := treadtxt.createf(packagesfile);
  reset;
  repeat
    line := t.readline;
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
    if stringstartis(line,'Depends:') then begin
      currentdepends := trim(copy(line,9,maxlongint));
    end;
    if line = '' then begin
      //writeln('end of block');
      if currentpackage <> '' then processpackage;
      reset;
      //writeln('end of block processing complete');
    end;
  until t.eof;
  if currentpackage <> '' then processpackage;
  t.free;
  outputlist := tfphashlist.create;
  repeat
    readln(currentpackage);
    currentsourcepackage := packages[currentpackage];
    if outputlist.findindexof(currentsourcepackage) < 0 then outputlist.add(currentsourcepackage,pointer($deadbeef));
  until eof(input);
  for i := 0 to outputlist.count-1 do begin
    writeln(outputlist.nameofindex(i));
  end;
  outputlist.free;
end.
