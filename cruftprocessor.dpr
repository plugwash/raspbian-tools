program cruftprocessor;
uses
  readtxt2,sysutils, contnrs, versions, classes, util;
const
  sourcesfile = '/home/repo/private/private/dists/jessie-staging/main/source/Sources';
  packagesfile = '/home/repo/private/private/dists/jessie-staging/main/binary-armhf/Packages';

var
  t : treadtxt;
  line : string;
  currentpackage, currentversion, currentsourcepackage, currentsourceversion , currentdepends,currentarch :string;
  sources : tfpstringhashtable;
  rdeps : tfpobjecthashtable;
  currentpackagestanza : tstringlist;
  packagescurrentarch, packagescurrentindep, removals : textfile;

procedure reset;
begin
  currentpackage := '';
  currentversion := '';
  currentsourcepackage := '';
  currentsourceversion := '';
  currentarch := '';
  if assigned(currentpackagestanza) then currentpackagestanza.clear else currentpackagestanza := tstringlist.create;
end;

procedure processsource;
var
  existingversion : string;
begin
  if currentversion = '' then begin
    writeln('package without version!');
    halt;
  end;
  existingversion := sources[currentpackage];
  if existingversion = '' then begin
    sources[currentpackage] := currentversion;
  end else begin
    writeln('multiple instances of the same source package cannot be handled yet');
    halt;
  end;
end;

procedure processdependency(const sourcepackage:string; const dependency : string);
var
  rdeplist : tfphashlist;
begin
  rdeplist := tfphashlist(rdeps[dependency]);
  if rdeplist = nil then begin
    rdeplist := tfphashlist.create;
    rdeps[dependency] := rdeplist;
  end;
  if rdeplist.findindexof(sourcepackage) < 0 then rdeplist.add(sourcepackage,0);
end;

var
  nsfcount     : integer = 0;
  oodcount     : integer = 0;
  futurecount  : integer = 0;
  currentcount : integer = 0;
procedure processpackage(pass: byte);
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
  
  if pass = 1 then begin
    dependency := '';
    inbrackets := false;
    for i := 1 to length(currentdepends) do begin
      c := currentdepends[i];
      if c = '(' then inbrackets := true;
      if c = '(' then inbrackets := false;
      if (not inbrackets) and (c in ['a'..'z','0'..'9','+','-','.']) then begin
        dependency := dependency + c;
      end else begin
        if dependency <> '' then processdependency(currentsourcepackage,dependency);
        dependency := '';
      end;
    end;
    if dependency <> '' then processdependency(currentsourcepackage,dependency);
  end else begin
    sourceversionfromsources := sources[currentsourcepackage];
    if sourceversionfromsources = '' then begin
      writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' nsf');
      nsfcount := nsfcount +1;
    end else begin
      //writeln('starting version comparison');
      versioncomparison := compareversion(currentsourceversion,sourceversionfromsources);
      //writeln('version comparison complete');
      if versioncomparison < 0 then begin
        writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' ood');
        oodcount := oodcount +1;
        rdeplist := tfphashlist(rdeps[currentpackage]);
        if rdeplist <> nil then for i := 0 to rdeplist.count -1 do begin
          writeln('  binnmu '+rdeplist.nameofindex(i)+'_'+sources[rdeplist.nameofindex(i)]+' 1 ''rebuild to eliminate dependency on '+currentpackage+'''');
        end else begin
          writeln(removals,'reprepro --arch=armhf --export=never remove jessie-staging '+currentpackage);
        end;
      end else if versioncomparison > 0 then begin
        writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' future');
        futurecount := futurecount +1;
      end else if versioncomparison = 0 then begin
        //writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' current');
        if currentarch = 'all' then begin
          for i := 0 to currentpackagestanza.count - 1 do begin
            writeln(packagescurrentindep,currentpackagestanza[i]);
          end;
          writeln(packagescurrentindep)
        end else begin
          for i := 0 to currentpackagestanza.count - 1 do begin
            writeln(packagescurrentarch,currentpackagestanza[i]);
          end;
          writeln(packagescurrentarch)
        end;
        currentcount := currentcount +1;
      end;
    end;
  end;
  
end;

var
  sourcelinecontent : string;
  p : integer;
  pass : byte;
begin
  //writeln(compareversion('1','2'));
  //writeln(compareversion('1-1','1-2'));
  //writeln(compareversion('2','1'));
  //writeln(compareversion('1','1'));
  //halt;
  assignfile(packagescurrentarch,'packagescurrentarch');
  rewrite(packagescurrentarch);
  assignfile(packagescurrentindep,'packagescurrentindep');
  rewrite(packagescurrentindep);
  assignfile(removals,'removals.sh');
  rewrite(removals);
  
  sources := tfpstringhashtable.create;
  t := treadtxt.createf(sourcesfile);
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
      if currentpackage <> '' then processsource;
      reset;
    end;
  until t.eof;
  if currentpackage <> '' then processsource;
  
  t.free;

  rdeps := tfpobjecthashtable.create();
  for pass := 1 to 2 do begin
    //writeln('starting pass ',pass);
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
      if stringstartis(line,'Architecture:') then begin
        currentarch := trim(copy(line,14,maxlongint));
      end;
      if line = '' then begin
        //writeln('end of block');
        if currentpackage <> '' then processpackage(pass);
        reset;
        //writeln('end of block processing complete');
      end else begin
        currentpackagestanza.add(line);
      end;
    until t.eof;
    if currentpackage <> '' then processpackage(pass);
    t.free;
  end;
  
  writeln('nsf:',nsfcount,' ood:',oodcount,' future:',futurecount,' current:',currentcount);
  closefile(packagescurrentarch);
  closefile(packagescurrentindep);
  writeln(removals,'reprepro -v export jessie-staging');
  closefile(removals);
end.
