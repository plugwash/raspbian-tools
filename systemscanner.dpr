program systemscanner;
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
      writeln('!'+sourceandversion);
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
var
  t: treadtxt;
  i: integer;
  s : tsearchrec;
  findresult : longint;
  param : string;
  process : tprocess;
begin
  sourcesandversions := tfphashlist.create;
  for i := 1 to paramcount do begin
    param := paramstr(i);
    writeln(erroutput,'scanning '+param);
    if param[length(param)] = '/' then begin
      findresult := findfirst(param+'*.deb',faReadOnly or fahidden or fasysfile or faarchive,s);
      while findresult = 0 do begin
        writeln(erroutput,' reading info from '+s.name);
        process := tprocess.create(nil);
        process.options := [poUsePipes];
        process.commandline := 'dpkg-deb --info '+param+s.name;
        process.execute;
        t := treadtxt.create(process.output,false);
        processtext(t,true);
        t.free;
        process.free;
        findresult := findnext(s);
      end;
      findclose(s);
    end else begin
      t := treadtxt.createf(param);
      processtext(t,true);
      t.free;
    end;
  end;
  for i := 0 to sourcesandversions.count - 1 do begin
    writeln(sourcesandversions.nameofindex(i));
  end;
end.
