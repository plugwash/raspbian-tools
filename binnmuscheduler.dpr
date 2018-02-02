program binnmuscheduler;
uses
  readtxt2,sysutils, contnrs, versions, classes, util;
const
  architecture = 'armhf';
  

  

type
  tsourcepackage=class
    version : string;
    name : string;
    binaries : tfphashlist;
    constructor createcopy(sourcepackage:tsourcepackage);
  end;

  tbinarypackage=class
    version : string;
    source : tsourcepackage;
    sourceversion : string;

    //note: depends is sorted for easier comparisons
    depends : tfphashlist;
  end;

constructor tsourcepackage.createcopy(sourcepackage:tsourcepackage);
var
  i : integer;
  binarypackage : tbinarypackage;
  newbinarypackage : tbinarypackage;
  binarypackagename : string;
begin
  version := sourcepackage.version;
  name := sourcepackage.name;
  if assigned(sourcepackage.binaries) then begin
    binaries := tfphashlist.create;
    for i := 0 to sourcepackage.binaries.count-1 do begin
      binarypackage := sourcepackage.binaries[i];
      binarypackagename := sourcepackage.binaries.nameofindex(i);
      newbinarypackage := tbinarypackage.create;
      newbinarypackage.source := self;
      newbinarypackage.version := binarypackage.version;
      newbinarypackage.sourceversion := binarypackage.sourceversion;
      newbinarypackage.depends := binarypackage.depends;
      binaries.add(binarypackagename,newbinarypackage);
    end;
  end;
end;

type


  tdistribution=class
    t : treadtxt;
    currentpackage, currentversion, currentsourcepackage, currentsourceversion , currentdepends :string;
    sources : tfphashlist;
    //rdeps : tfpobjecthashtable;

    procedure reset;
    procedure processsource;
    //procedure processdependency(const sourcepackage:string; const dependency : string);
    procedure processpackage;
    //constructor create(sourcesfile : string ;packagesfile :string);
    procedure getbinaries(binaries:tfphashlist);

    procedure readsources(sourcesfile : string);
    procedure readpackages(packagesfile : string);

    //WARNING: copy is shallow, the tfphashlist is copied but it's contents is not.
    constructor createcopy(distribution : tdistribution);
  end;

procedure tdistribution.reset;
begin
  currentpackage := '';
  currentversion := '';
  currentsourcepackage := '';
  currentsourceversion := '';
  currentdepends := '';
end;

procedure tdistribution.processsource;
var
  sourcepackage : tsourcepackage;
begin
  if currentversion = '' then begin
    writeln('package without version!');
    halt(1);
  end;
  sourcepackage := sources.find(currentpackage);
  if sourcepackage = nil then begin
    sourcepackage := tsourcepackage.create();
    sourcepackage.name := currentpackage;
    sourcepackage.version := currentversion;
    sources.add(currentpackage, sourcepackage);
  end else begin
    writeln('multiple instances of source package '+currentpackage+' found, please use componentcleaner');
    halt(1);
  end;
end;

{procedure tdistribution.processdependency(const sourcepackage:string; const dependency : string);
var
  rdeplist : tfphashlist;
begin
  rdeplist := tfphashlist(rdeps[dependency]);
  if rdeplist = nil then begin
    rdeplist := tfphashlist.create;
    rdeps[dependency] := rdeplist;
  end;
  if rdeplist.findindexof(sourcepackage) < 0 then rdeplist.add(sourcepackage,0);
end;}

procedure tdistribution.processpackage;
var
  sourceversionfromsources : string;
  versioncomparison : integer;
  inbrackets : boolean;
  dependency : string;
  c : char;
  i : integer;
  rdeplist : tstringlist;
  sourcepackage : tsourcepackage;
  binarypackage : tbinarypackage;
  depends : tfphashlist;
begin
  if currentversion = '' then begin
    writeln('package without version!');
    halt(1);
  end;
  if currentsourcepackage = '' then currentsourcepackage := currentpackage;
  if currentsourceversion = '' then currentsourceversion := currentversion;

  depends := tfphashlist.create();
  dependency := '';
  inbrackets := false;
  for i := 1 to length(currentdepends) do begin
    c := currentdepends[i];
    if c = '(' then inbrackets := true;
    if c = ')' then inbrackets := false;
    if (not inbrackets) and (c in ['a'..'z','0'..'9','+','-','.']) then begin
      dependency := dependency + c;
    end else begin
      if dependency <> '' then depends.add(dependency,pointer($deadbeef));
      dependency := '';
    end;
  end;
  if dependency <> '' then depends.add(dependency,pointer($deadbeef));
  sourcepackage := tsourcepackage(sources.find(currentsourcepackage));
  if sourcepackage = nil then begin
    sourcepackage := tsourcepackage.create();
    sourcepackage.name := currentsourcepackage;
    sourcepackage.version := '__NOT_PRESENT_BUT_HAS_BINARIES__';
    sources.add(currentsourcepackage, sourcepackage);
  end;
  if sourcepackage.binaries = nil then begin
    sourcepackage.binaries := tfphashlist.create;
  end;
  binarypackage := tbinarypackage.create;
  binarypackage.version := currentversion;
  binarypackage.source := sourcepackage;
  binarypackage.sourceversion := currentsourceversion;
  binarypackage.depends := depends;
  sourcepackage.binaries.add(currentpackage,binarypackage);
end;

procedure tdistribution.readsources(sourcesfile :string);
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
  if sources = nil then sources := tfphashlist.create;
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

procedure tdistribution.readpackages(packagesfile : string);
var
  line : string;
  t : treadtxt;
  sourcelinecontent : string;
  p : integer;
begin
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
      //end of block
      if currentpackage <> '' then processpackage;
      reset;
    end;
  until t.eof;
  if currentpackage <> '' then processpackage;
  t.free;
end;

procedure tdistribution.getbinaries(binaries : tfphashlist);
var
  i,j : integer;
  sourcepackage : tsourcepackage;
  binarypackagename : string;
  binarypackage : tbinarypackage;
begin
  binaries.clear;
  for i := 0 to sources.count-1 do begin
    sourcepackage := tsourcepackage(sources[i]);
    if sourcepackage.binaries <> nil then for j := 0 to sourcepackage.binaries.count -1 do begin
      binarypackage := tbinarypackage(sourcepackage.binaries[j]);
      binarypackagename := sourcepackage.binaries.nameofindex(j);
      binaries.add(binarypackagename,binarypackage);
    end;
  end;
 
end;

constructor tdistribution.createcopy(distribution: tdistribution);
var
  i : integer;
begin
  sources := tfphashlist.create;
  for i := 0 to distribution.sources.count -1 do begin
    sources.add(distribution.sources.nameofindex(i),distribution.sources[i]);
  end;
end;

var
  stagingdistribution: tdistribution;
  i,j,k: integer;
  stagingsourcepackage: tsourcepackage;
  binarypackage: tbinarypackage;
  binarypackagename: string;
  t : textfile;
  b : boolean;
  sourcepackagename : string;
  binnmunumber : integer;
  newbinnmunumber : integer;
  binaryversion : string;
  reporoot : string;
  codenamestaging : string;
  outputfilename : string;
  outputfile : textfile;
begin
  reporoot := paramstr(1);
  if reporoot[length(reporoot)] <> '/' then reporoot := reporoot + '/';
  codenamestaging := paramstr(2);
  outputfilename := paramstr(3);
  
  writeln('reading packages and sources files for staging distribution');
  stagingdistribution := tdistribution.create;
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/main/source/Sources');
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/contrib/source/Sources');
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/non-free/source/Sources');
  
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/main/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/contrib/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/non-free/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/main/debian-installer/binary-'+architecture+'/Packages');

  assignfile(outputfile,outputfilename);
  rewrite(outputfile);

  repeat
    readln(sourcepackagename);
    stagingsourcepackage := tsourcepackage(stagingdistribution.sources.find(sourcepackagename));
    if assigned(stagingsourcepackage) then begin
      //writeln(sourcepackagename+'_'+stagingsourcepackage.version);
      binnmunumber := 1;
      for i := 0 to stagingsourcepackage.binaries.count-1 do begin
        binaryversion := tbinarypackage(stagingsourcepackage.binaries[i]).version;
        j := length(binaryversion);
        if (j >= 4) and (binaryversion[j] in ['0'..'9']) then begin
          while (j >= 4) and (binaryversion[j] in ['0'..'9']) do j := j -1;
          if (binaryversion[j] = 'b') and (binaryversion[j-1] = '+') then begin
            //we have a binnmu version.
            newbinnmunumber := 0;
            while j < length(binaryversion) do begin
              j := j +1;
              newbinnmunumber := (newbinnmunumber * 10)+ord(binaryversion[j])-ord('0');
            end;
            newbinnmunumber := newbinnmunumber + 1;
            if newbinnmunumber > binnmunumber then binnmunumber := newbinnmunumber;
          end;
        end;
        
      end;
      writeln(outputfile,'wanna-build -A armhf -d '+codenamestaging+' -m "rebuild due to debcheck failure" --binNMU '+inttostr(binnmunumber)+' '+sourcepackagename+'_'+stagingsourcepackage.version);

    end else begin
      writeln(outputfile,'echo can\''t find information needed to generate binnmu for '+sourcepackagename);
    end;
  until eof(input);
  closefile(outputfile);
end.