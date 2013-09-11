program cruftprocessor;
uses
  readtxt2,sysutils, contnrs, versions, classes, util;
const
  reporoot = '/home/repo/private/private/'; //must have a trailing /
  suite = 'jessie-staging';
  componentcount = 5;
  components : array[1..componentcount] of string  = ('main','contrib','non-free','rpi','firmware');
  
var
  t : treadtxt;
  line : string;
  currentpackage, currentversion, currentsourcepackage, currentsourceversion , currentdepends,currentarch :string;
  sourcestosourceversions : tfpstringhashtable;
  sourcestoarchbinarysourceversions : tfpstringhashtable;
  rdeps : tfpobjecthashtable;
  currentpackagestanza : tstringlist;
  packagescurrentarch, packagescurrentindep, packagesoodbutnotcruft, removals : textfile;

procedure reset;
begin
  currentpackage := '';
  currentversion := '';
  currentsourcepackage := '';
  currentsourceversion := '';
  currentarch := '';
  currentdepends := '';
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
  existingversion := sourcestosourceversions[currentpackage];
  if existingversion = '' then begin
    sourcestosourceversions[currentpackage] := currentversion;
  end else begin
    writeln('multiple instances of the same source package cannot be handled yet');
    halt;
  end;
end;

procedure processdependency(const sourcepackage:string; const binarypackage:string; const dependency : string);
var
  rdeplist : tfphashlist;
  binarylist : tfphashlist;
begin
  rdeplist := tfphashlist(rdeps[dependency]);
  if rdeplist = nil then begin
    rdeplist := tfphashlist.create;
    rdeps[dependency] := rdeplist;
  end;
  binarylist := rdeplist.find(sourcepackage);
  if binarylist = nil then begin
    binarylist := tfphashlist.create;
    rdeplist.add(sourcepackage,binarylist);
    binarylist.add(binarypackage,pointer($deadbeef));
  end else begin
    if binarylist.findindexof(binarypackage) < 0 then binarylist.add(binarypackage,pointer($deadbeef));
  end;
  //if sourcepackage = 'guile-1.6' then writeln('fuck '+dependency);
end;

var
  nsfcount     : integer = 0;
  oodcount     : integer = 0;
  cruftcount   : integer = 0;
  futurecount  : integer = 0;
  currentcount : integer = 0;
procedure processpackage(pass: byte);
var
  sourceversionfromsources : string;
  versioncomparison : integer;
  inbrackets : boolean;
  dependency : string;
  c : char;
  i,j : integer;
  rdeplist : tfphashlist;
  oldsourceversion : string;
  latestarchbinarysourceversion : string;
  binarylist: tfphashlist;
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
    //if currentsourcepackage = 'guile-1.6' then writeln('shit '+currentdepends);
    for i := 1 to length(currentdepends) do begin
      c := currentdepends[i];
      if c = '(' then inbrackets := true;
      if c = ')' then inbrackets := false;
      if (not inbrackets) and (c in ['a'..'z','0'..'9','+','-','.']) then begin
        dependency := dependency + c;
      end else begin
        if dependency <> '' then processdependency(currentsourcepackage,currentpackage,dependency);
        dependency := '';
      end;
    end;
    if dependency <> '' then processdependency(currentsourcepackage,currentpackage,dependency);
    if currentarch <> 'all' then begin
      oldsourceversion := sourcestoarchbinarysourceversions[currentsourcepackage];
      if oldsourceversion = '' then begin
        sourcestoarchbinarysourceversions[currentsourcepackage] := currentsourceversion;
      end else begin
        versioncomparison := compareversion(currentsourceversion,oldsourceversion);
        if versioncomparison > 0 then begin
          sourcestoarchbinarysourceversions[currentsourcepackage] := currentsourceversion;
        end;
      end;      
    end;
  end else begin
    sourceversionfromsources := sourcestosourceversions[currentsourcepackage];
    if sourceversionfromsources = '' then begin
      writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' nsf');
      nsfcount := nsfcount +1;
    end else begin
      //writeln('starting version comparison');
      versioncomparison := compareversion(currentsourceversion,sourceversionfromsources);
      //writeln('version comparison complete');
      if versioncomparison < 0 then begin
        latestarchbinarysourceversion := sourcestoarchbinarysourceversions[currentsourcepackage];
        versioncomparison := compareversion(currentsourceversion,latestarchbinarysourceversion);
        if (currentarch = 'all') or (versioncomparison < 0) then begin
          writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' cruft');
          cruftcount := cruftcount +1;
          rdeplist := tfphashlist(rdeps[currentpackage]);
          if rdeplist <> nil then for i := 0 to rdeplist.count -1 do begin
            //writeln('  binnmu '+rdeplist.nameofindex(i)+'_'+sourcestosourceversions[rdeplist.nameofindex(i)]+' 1 ''rebuild to eliminate dependency on '+currentpackage+'''');
            write('  '+rdeplist.nameofindex(i)+':');
            binarylist := tfphashlist(rdeplist.items[i]);
            for j := 0 to binarylist.count -1 do begin
              write(' '+binarylist.nameofindex(j));
            end;
            writeln;
          end else begin
            writeln(removals,'reprepro --arch=armhf --export=never remove jessie-staging '+currentpackage);
          end;
        end else begin
          writeln(currentpackage+' '+currentversion+' '+currentsourcepackage+' '+currentsourceversion+' ood');
          oodcount := oodcount +1;
          for i := 0 to currentpackagestanza.count - 1 do begin
            writeln(packagesoodbutnotcruft,currentpackagestanza[i]);
          end;
          writeln(packagesoodbutnotcruft);
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
  ms : tmemorystream;
  fs : tfilestream;
  sourcesfile,packagesfile,dipackagesfile : string;
  i : integer;
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
  assignfile(packagesoodbutnotcruft,'packagesoodbutnotcruft');
  rewrite(packagesoodbutnotcruft); 
  assignfile(removals,'removals.sh');
  rewrite(removals);
  
  
  sourcestosourceversions := tfpstringhashtable.create;
  sourcestoarchbinarysourceversions := tfpstringhashtable.create;
  
  for i := 1 to componentcount do begin
    sourcesfile := reporoot+'dists/'+suite+'/'+components[i]+'/source/Sources';
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
  end;
  rdeps := tfpobjecthashtable.create();
  
  ms := tmemorystream.create;
  for i := 1 to componentcount do begin
    packagesfile := reporoot+'dists/'+suite+'/'+components[i]+'/binary-armhf/Packages';
    fs := tfilestream.create(packagesfile,fmOpenRead or fmShareDenyWrite);
    ms.copyfrom(fs,fs.size);
    fs.free;
  end;
  dipackagesfile := reporoot+'dists/'+suite+'/main/debian-installer/binary-armhf/Packages';
  fs := tfilestream.create(dipackagesfile,fmOpenRead or fmShareDenyWrite);
  ms.copyfrom(fs,fs.size);
  fs.free;
    
  
  for pass := 1 to 2 do begin
    //writeln('starting pass ',pass);
    ms.seek(0,soFromBeginning);
    t := treadtxt.create(ms,false);
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
  ms.free;
  
  writeln('nsf:',nsfcount,' ood:',oodcount,' cruft:',cruftcount,' future:',futurecount,' current:',currentcount);
  closefile(packagescurrentarch);
  closefile(packagescurrentindep);
  closefile(packagesoodbutnotcruft);
  writeln(removals,'reprepro -v export jessie-staging');
  closefile(removals);
end.
