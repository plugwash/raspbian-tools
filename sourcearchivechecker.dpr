program sourcearchivechecker;
uses
  readtxt2,sysutils, contnrs, classes, process, util, regexpr,unix;

var
  line : string;
  currentpackage, currentversion, currentsourcepackage, currentsourceversion, currentstatus, currentbuiltusing :string;
  sourcesandversions : tfphashlist;
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
  baseversion : string;
  regexobj : tregexpr;
  strippattern : string;
  i : integer;
  baseversionnoepoch : string;
  debdiffsdir : string;
  versionnoepoch : string;
  debdiffbase : string;
begin
  
  sl := tstringlist.create;
  sl.Delimiter := '$';
  sl.DelimitedText := paramstr(1);
  
  if paramcount >= 2 then begin
    debdiffsdir := paramstr(2);
    if debdiffsdir[length(debdiffsdir)] <> '/' then debdiffsdir := debdiffsdir + '/';
  end;
  writeln('debdiffsdir = '+debdiffsdir);
  strippattern := '(';
  for i := 0 to sl.count -1 do begin
    if strippattern <> '(' then begin
      strippattern := strippattern + '|';
    end;
    strippattern := strippattern + QuoteRegExprMetaChars(sl[i]);
  end;
  strippattern := strippattern + ')[0-9]*';

  writeln(strippattern);
                  

  regexobj := tregexpr.create;
  regexobj.expression := strippattern;

  writeln(regexobj.replace('foo+rpi1','',false));

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
                sourcepackage := '';
                version := '';
                t := treadtxt.createf(''+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name);
                line :=t.readline;
                while trim(line) <> 'Files:' do begin
                  
                  if copy(line,1,8) = 'Source: ' then sourcepackage := copy(line,9,maxlongint);
                  if copy(line,1,9) = 'Version: ' then version := copy(line,10,maxlongint);
                  
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
                //p := pos('+rpi',version);
                //if p > 0 then writeln(sourcepackage+' '+version);
                baseversion := regexobj.replace(version,'',false);
                if baseversion <> version then begin
                  p := pos(':',baseversion);
                  if p > 0 then begin
                    baseversionnoepoch := copy(baseversion,p+1,maxlongint);
                  end else begin
                    baseversionnoepoch := baseversion;
                  end;
                  p := pos(':',version);
                  if p > 0 then begin
                    versionnoepoch := copy(version,p+1,maxlongint);
                  end else begin
                    versionnoepoch := version;
                  end;
                    
                  debdiffbase := '';
                  if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+baseversionnoepoch+'.dsc') then begin
                    debdiffbase := baseversionnoepoch;
                  end else if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa1.dsc') then begin
                    //for mate themes
                    debdiffbase := copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa1';
                  end else if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa2.dsc') then begin
                    //for mate themes
                    debdiffbase := copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa2';
                  end else if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa3.dsc') then begin
                    //for mate themes
                    debdiffbase := copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa3';
                  end else if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa1+nmu1.dsc') then begin
                    //for mate themes
                    debdiffbase := copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa1+nmu1';
                  end else if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa2+nmu1.dsc') then begin
                    //for mate themes
                    debdiffbase := copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.natty.ppa2+nmu1';
                  end else if fileexists(s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.lucid.ppa1+nmu1.dsc') then begin
                    //for mate themes
                    debdiffbase := copy(baseversionnoepoch,1,length(baseversionnoepoch)-5)+'.lucid.ppa1+nmu1';
                  end else if (debdiffsdir = '') or not fileexists(debdiffsdir+s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+versionnoepoch+'.debdiff') then begin
                    writeln('source package for base version not found '+sourcepackage+' '+baseversion+' '+version);
                  end;
                  if debdiffbase <> '' then begin
                    if (debdiffsdir <> '') and not fileexists(debdiffsdir+s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+versionnoepoch+'.debdiff') then begin
                      writeln('generating debdiff '+sourcepackage+' '+baseversion+' '+version);
                      forcedirectories(debdiffsdir+s1.name+'/'+s2.name+'/'+s3.name);
                      fpsystem('debdiff '+s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+debdiffbase+'.dsc'+' '+s1.name+'/'+s2.name+'/'+s3.name+'/'+s4.name+' > '+debdiffsdir+s1.name+'/'+s2.name+'/'+s3.name+'/'+sourcepackage+'_'+versionnoepoch+'.debdiff');
                    end;
                  end else
                end;
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
