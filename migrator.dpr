program migrator;
uses
  readtxt2,sysutils, contnrs, versions, classes, util;
const
  reporoot = '/home/repo/private/private/';
  architecture = 'armhf';
  
var
  codename: string;
  codenamestaging: string;
  

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
    halt;
  end;
  sourcepackage := sources.find(currentpackage);
  if sourcepackage = nil then begin
    sourcepackage := tsourcepackage.create();
    sourcepackage.name := currentpackage;
    sourcepackage.version := currentversion;
    sources.add(currentpackage, sourcepackage);
  end else begin
    writeln('multiple instances of source package '+currentpackage+' found, please use componentcleaner');
    halt;
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
    halt;
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
  maindistribution: tdistribution;
  stagingdistribution: tdistribution;
  resultingdistribution: tdistribution;
  
  mainbinaries,stagingbinaries,resultingbinaries : tfphashlist;
  i,j,k: integer;
  sourcepackagename: string;
  mainsourcepackage: tsourcepackage;
  stagingsourcepackage: tsourcepackage;
  resultingsourcepackage: tsourcepackage;
  binarypackage: tbinarypackage;
  binarypackagename: string;
  inconsistentcount: integer;
  proposedsourcemigrations: tfphashlist;
  proposedbinarymigrations: tfphashlist;
  dummysourcepackage: tsourcepackage;
  stagingbinarypackage: tbinarypackage;
  mainbinarypackage: tbinarypackage;
  resultingbinarypackage: tbinarypackage;
  removalsthisiteration: integer;
  dependedonpackage: string;
  satisfiableinmain,satisfiableinstaging,satisfiableinresulting,presentinmain : boolean;
  migrationindex : integer;
  t : textfile;
  b : boolean;
  removalsforthissource : boolean;
begin
  codename := paramstr(1);
  codenamestaging := codename + '-staging';
  writeln('reading packages and sources files for main distribution');
  maindistribution := tdistribution.create;
  maindistribution.readsources(reporoot+'dists/'+codename+'/main/source/Sources');
  maindistribution.readsources(reporoot+'dists/'+codename+'/contrib/source/Sources');
  maindistribution.readsources(reporoot+'dists/'+codename+'/non-free/source/Sources');
  maindistribution.readsources(reporoot+'dists/'+codename+'/rpi/source/Sources');
  maindistribution.readsources(reporoot+'dists/'+codename+'/firmware/source/Sources');
  
  maindistribution.readpackages(reporoot+'dists/'+codename+'/main/binary-'+architecture+'/Packages');
  maindistribution.readpackages(reporoot+'dists/'+codename+'/contrib/binary-'+architecture+'/Packages');
  maindistribution.readpackages(reporoot+'dists/'+codename+'/non-free/binary-'+architecture+'/Packages');
  maindistribution.readpackages(reporoot+'dists/'+codename+'/rpi/binary-'+architecture+'/Packages');
  maindistribution.readpackages(reporoot+'dists/'+codename+'/firmware/binary-'+architecture+'/Packages');
  maindistribution.readpackages(reporoot+'dists/'+codename+'/main/debian-installer/binary-'+architecture+'/Packages');

  
  //sourcesfilestaging = '/home/repo/repo/raspbian/dists/wheezy-staging/main/source/Sources';
  //packagesfilestaging = '/home/repo/repo/raspbian/dists/wheezy-staging/main/binary-armhf/Packages';

  
  mainbinaries := tfphashlist.create;
  maindistribution.getbinaries(mainbinaries);
  writeln('reading packages and sources files for staging distribution');
  stagingdistribution := tdistribution.create;
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/main/source/Sources');
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/contrib/source/Sources');
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/non-free/source/Sources');
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/rpi/source/Sources');
  stagingdistribution.readsources(reporoot+'dists/'+codenamestaging+'/firmware/source/Sources');
  
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/main/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/contrib/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/non-free/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/rpi/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/firmware/binary-'+architecture+'/Packages');
  stagingdistribution.readpackages(reporoot+'dists/'+codenamestaging+'/main/debian-installer/binary-'+architecture+'/Packages');

  stagingbinaries := tfphashlist.create;
  stagingdistribution.getbinaries(stagingbinaries);

  resultingbinaries := tfphashlist.create;

  writeln('scanning for source migration canditates');
  
  dummysourcepackage := tsourcepackage.create;
  dummysourcepackage.version := '__NOT_PRESENT__';
  
  proposedsourcemigrations := tfphashlist.create;
  for i := 0 to stagingdistribution.sources.count-1 do begin
    sourcepackagename := stagingdistribution.sources.nameofindex(i);
    stagingsourcepackage := tsourcepackage(stagingdistribution.sources[i]);
    mainsourcepackage := tsourcepackage(maindistribution.sources.find(sourcepackagename));
    if mainsourcepackage = nil then begin
      mainsourcepackage := dummysourcepackage;
      
    end;
    if mainsourcepackage.version = stagingsourcepackage.version then continue;
    writeln(sourcepackagename,' ',mainsourcepackage.version,' ',stagingsourcepackage.version);
    //if stagingsourcepackage.binaries <> nil then writeln(stagingsourcepackage.binaries.count) else writeln('no binaries found');
    inconsistentcount := 0;
    if stagingsourcepackage.binaries <> nil then for j := 0 to stagingsourcepackage.binaries.count -1 do begin
      binarypackage := tbinarypackage(stagingsourcepackage.binaries[j]);
      binarypackagename := stagingsourcepackage.binaries.nameofindex(j);
      if binarypackage.sourceversion = stagingsourcepackage.version then begin
        writeln('  ',binarypackagename,' consistent');
      end else begin
        writeln('  ',binarypackagename,' inconsistent');
        inconsistentcount := inconsistentcount + 1;
      end;
    end;
    if inconsistentcount <> 0 then begin
      writeln('  rejecting migration of '+sourcepackagename+' due to inconsistent binaries');
      writeln;
      continue;
    end;
    writeln('  accepting '+sourcepackagename+' onto list of proposed source migrations');
    proposedsourcemigrations.add(sourcepackagename,stagingsourcepackage);
    writeln;
  end;
  
  writeln('scanning for binary migration canditates');
  proposedbinarymigrations := tfphashlist.create;
  for i := 0 to stagingdistribution.sources.count-1 do begin
    sourcepackagename := stagingdistribution.sources.nameofindex(i);
    stagingsourcepackage := tsourcepackage(stagingdistribution.sources[i]);
    mainsourcepackage := tsourcepackage(maindistribution.sources.find(sourcepackagename));
    if mainsourcepackage = nil then begin
      mainsourcepackage := dummysourcepackage;
    end;
    if mainsourcepackage.version <> stagingsourcepackage.version then continue;
    if stagingsourcepackage.binaries <> nil then for j := 0 to stagingsourcepackage.binaries.count -1 do begin
      stagingbinarypackage := tbinarypackage(stagingsourcepackage.binaries[j]);
      binarypackagename := stagingsourcepackage.binaries.nameofindex(j);
      if assigned(mainsourcepackage.binaries) then begin
        mainbinarypackage := tbinarypackage(mainsourcepackage.binaries.find(binarypackagename));
      end else begin
        mainbinarypackage := nil;
      end;
      if assigned(mainbinarypackage) then begin
        b := stagingbinarypackage.version <> mainbinarypackage.version
      end else begin
        b := true;
      end;
      if b then begin
        if stagingbinarypackage.sourceversion = stagingsourcepackage.version then begin
          proposedbinarymigrations.add(binarypackagename,stagingbinarypackage);
          writeln(binarypackagename,' accepted as candidate for binary migration');
        end else begin
          writeln(binarypackagename,' from source '+sourcepackagename+' rejected for binary migration due to inconsistent source version ',stagingbinarypackage.sourceversion,' expected ',stagingsourcepackage.version);
        end;
      end;
    end;
  end;

  writeln('stage 1 complete, there are ',proposedsourcemigrations.count,' proposed source migrations and ',proposedbinarymigrations.count,' proposed binary migrations');
  writeln('starting candidate test and removal loop');
  repeat
    writeln('copying distribution structure and applying changes');
    //writeln(ptruint(resultingbinaries));
    //writeln('resultingbinaries.findindexof(''libcitadel2'')=',resultingbinaries.findindexof('libcitadel2'));
    removalsthisiteration := 0;
    resultingdistribution := tdistribution.createcopy(maindistribution);
    
    for i := 0 to proposedsourcemigrations.count-1 do begin
      sourcepackagename := proposedsourcemigrations.nameofindex(i);
      stagingsourcepackage := proposedsourcemigrations[i];
      writeln('applying source migration '+sourcepackagename+' '+stagingsourcepackage.version);
      j := resultingdistribution.sources.findindexof(sourcepackagename);
      if j >= 0 then begin
        resultingdistribution.sources[j] := stagingsourcepackage;
      end else begin
        resultingdistribution.sources.add(sourcepackagename,stagingsourcepackage);
      end;
      //writeln(ptruint(resultingbinaries));
    end;
    writeln('finished applying source migrations, about to apply binary ones');
    for i := 0 to proposedbinarymigrations.count-1 do begin
      binarypackagename := proposedbinarymigrations.nameofindex(i);
      stagingbinarypackage := proposedbinarymigrations[i];
      writeln('applying binary migration '+binarypackagename+' '+stagingbinarypackage.version);
      sourcepackagename := stagingbinarypackage.source.name;
      //writeln('a');
      j := resultingdistribution.sources.findindexof(sourcepackagename);
      //writeln('b');
      resultingsourcepackage := tsourcepackage.createcopy(resultingdistribution.sources[j]);
      //writeln('c');
      resultingbinarypackage := tbinarypackage.create;
      resultingbinarypackage.source := resultingsourcepackage;
      resultingbinarypackage.version := stagingbinarypackage.version;
      resultingbinarypackage.sourceversion := stagingbinarypackage.sourceversion;
      //writeln(binarypackagename);
      //writeln(ptruint(stagingbinarypackage.depends));
      resultingbinarypackage.depends := stagingbinarypackage.depends;
      if resultingsourcepackage.binaries = nil then resultingsourcepackage.binaries := tfphashlist.create;
      //writeln('d');
      k := resultingsourcepackage.binaries.findindexof(binarypackagename);
      if k >= 0 then begin
        resultingsourcepackage.binaries[k] := resultingbinarypackage;
      end else begin
        resultingsourcepackage.binaries.add(binarypackagename,resultingbinarypackage);
      end;
      //writeln('e');
      resultingdistribution.sources[j] := resultingsourcepackage;
      //writeln('f');
    end;
    
    writeln('scanning depedencies');
    resultingdistribution.getbinaries(resultingbinaries);
    for i := 0 to resultingbinaries.count -1 do begin
      binarypackagename := resultingbinaries.nameofindex(i);
      resultingbinarypackage := tbinarypackage(resultingbinaries[i]);
      mainbinarypackage := tbinarypackage(mainbinaries.find(binarypackagename));

      //writeln('scanning dependencies for binary package '+binarypackagename);

      //we don't care if new binaries migrate before their dependencies are satisfiable.
      if mainbinarypackage = nil then begin
        //writeln('not checking dependencies because it''s a new binary');
        continue;
      end;
      //writeln(ptruint(resultingbinarypackage));
      //writeln(ptruint(resultingbinarypackage.depends));

      for j := 0 to resultingbinarypackage.depends.count -1 do begin
        //writeln(resultingbinarypackage.depends.nameofindex(j));
        dependedonpackage := resultingbinarypackage.depends.nameofindex(j);

        //find out whether the dependency is present in main
        //writeln(ptruint(mainbinarypackage));
        //writeln(ptruint(mainbinarypackage.depends));
        presentinmain := mainbinarypackage.depends.findindexof(dependedonpackage) >= 0;
        //if presentinmain then begin
        //  writeln('dependency:',dependedonpackage,' IS present in main');
        //end else begin
          //writeln(mainbinarypackage.depends.count);
        //  writeln('dependency:',dependedonpackage,' NOT present in main');
        //end;
        //find out where the dependency is "satisfiable";
        satisfiableinmain := mainbinaries.findindexof(dependedonpackage) >= 0;
        satisfiableinstaging := stagingbinaries.findindexof(dependedonpackage) >= 0;
        satisfiableinresulting := resultingbinaries.findindexof(dependedonpackage) >= 0;
        //writeln('dependency:',dependedonpackage,' satisfiable in main:',satisfiableinmain,' staging:',satisfiableinstaging,' resulting:',satisfiableinresulting);

        if satisfiableinresulting then begin //is the dependency satisfiable in resulting, if so great
        end else if presentinmain and not satisfiableinmain then begin //if the dependency is present in main and not satisdiable there  we aren't making things worse
          //writeln('the dependency is present in main and not satisdiable there so we aren''t making things worse');
        end else if not (satisfiableinmain or satisfiableinstaging or satisfiableinresulting) then begin //if the dependency is not satisdiable in any distribution it's probablly a virtual package, ignore it
          //writeln('the dependency is not satisfiable in any distribution it''s probablly a virtual package, ignore it');
        end else if presentinmain and  satisfiableinmain then begin
          //writeln('the dependency was made unsatisfiable in resulting by an update to another package, remove that update from the candidate list');
          mainsourcepackage := tbinarypackage(mainbinaries.find(dependedonpackage)).source;
          sourcepackagename := mainsourcepackage.name;
          migrationindex := proposedsourcemigrations.findindexof(sourcepackagename);
          writeln('migrationindex=',migrationindex);
          if migrationindex >= 0 then begin //if this is -1 it most likely means the migration has already been removed from the list
            writeln('removing source package ',sourcepackagename,' from migration list because migrating it would break dependency of ',binarypackagename,' on ',dependedonpackage);
            proposedsourcemigrations.delete(migrationindex);
            removalsthisiteration := removalsthisiteration + 1;
          end;
        end else begin
          //writeln('we are going to break a dependency and it''s most likely a real one remove the migration');
          sourcepackagename := resultingbinarypackage.source.name;
          migrationindex := proposedsourcemigrations.findindexof(sourcepackagename);
          //writeln('looking up source migration for '+sourcepackagename+' source migrations migrationindex=',migrationindex);
          if migrationindex >= 0 then begin
            writeln('removing source package ',sourcepackagename,' from migration list because of dependency on ',dependedonpackage);
            proposedsourcemigrations.delete(migrationindex);
            removalsthisiteration := removalsthisiteration + 1;
          end;

          migrationindex := proposedbinarymigrations.findindexof(binarypackagename);
          //writeln('checking binary migrations migrationindex=',migrationindex);
          if migrationindex >= 0 then begin
            writeln('removing binary package ',sourcepackagename,' from migration list because of dependency on ',dependedonpackage);
            proposedbinarymigrations.delete(migrationindex);
            removalsthisiteration := removalsthisiteration + 1;
          end;
        end;
      end;
    end;
    writeln('removed ',removalsthisiteration,' from the migration lists this iteration');
  until removalsthisiteration = 0;
  writeln('stage 2 complete, there are ',proposedsourcemigrations.count,' proposed source migrations and ',proposedbinarymigrations.count,' proposed binary migrations');
  assignfile(t,'migrations.sh');
  rewrite(t);
  for i := 0 to proposedsourcemigrations.count-1 do begin
    sourcepackagename := proposedsourcemigrations.nameofindex(i);
    stagingsourcepackage := proposedsourcemigrations[i];
    mainsourcepackage := maindistribution.sources.find(sourcepackagename);
    //write removals
    removalsforthissource := false;
    if assigned(mainsourcepackage) then if assigned(mainsourcepackage.binaries) then for j := 0 to mainsourcepackage.binaries.count -1 do begin
      binarypackagename := mainsourcepackage.binaries.nameofindex(j);
      //writeln;
      //writeln(sizeint(stagingsourcepackage));
      //writeln(sizeint(stagingsourcepackage.binaries));
      //writeln(binarypackagename);
      //writeln(stagingsourcepackage.binaries.findindexof(binarypackagename));
      if (stagingsourcepackage.binaries = nil) or (stagingsourcepackage.binaries.findindexof(binarypackagename) < 0) then begin
        if not removalsforthissource then begin
          writeln('outputing removals for source migration '+sourcepackagename+' '+stagingsourcepackage.version);
          writeln(t,'#removals for source migration '+sourcepackagename+' '+stagingsourcepackage.version);
          removalsforthissource := true;
        end;
        writeln(t,'reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=armhf remove ',codename,' ',binarypackagename);
      end;
    end;
    if removalsforthissource then writeln(t);
  end;
  for i := 0 to proposedsourcemigrations.count-1 do begin
    sourcepackagename := proposedsourcemigrations.nameofindex(i);
    stagingsourcepackage := proposedsourcemigrations[i];
    mainsourcepackage := maindistribution.sources.find(sourcepackagename);

    writeln('outputing source migration '+sourcepackagename+' '+stagingsourcepackage.version);
    writeln(t,'#source migration '+sourcepackagename+' '+stagingsourcepackage.version);
    //write source migration
    writeln(t,'reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=source copy ',codename,' ',codenamestaging,' ',sourcepackagename);
    //write binary migration
    if assigned(stagingsourcepackage.binaries) then for j := 0 to stagingsourcepackage.binaries.count -1 do begin
      binarypackagename := stagingsourcepackage.binaries.nameofindex(j);
      writeln(t,'reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=armhf copy ',codename,' ',codenamestaging,' ',binarypackagename);
    end;
    
    writeln(t);
  end;
  
  for i := 0 to proposedbinarymigrations.count-1 do begin
    binarypackagename := proposedbinarymigrations.nameofindex(i);
    stagingbinarypackage := proposedbinarymigrations[i];
    //mainsourcepackage := maindistribution.sources.find(sourcepackagename);

    writeln('outputing binary migration '+binarypackagename+' '+stagingbinarypackage.version);
    writeln(t,'#binary migration '+binarypackagename+' '+stagingbinarypackage.version);
    //write migration
    writeln(t,'reprepro -V --basedir . --morguedir +b/morgue --export=never --arch=armhf copy ',codename,' ',codenamestaging,' ',binarypackagename);
    
    writeln(t);
  end;
  
  //write export
  writeln(t,'reprepro -V --basedir . --morguedir +b/morgue export '+codename);
  closefile(t);
end.
