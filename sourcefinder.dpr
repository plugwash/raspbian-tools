program sourcefinder;
uses
  readtxt2,sysutils,util;
type
  packageresults = (prfound,prcopied,prnotfound,prcopyfail,prverifyfail);
var
  t : treadtxt;
  line : string;
  sourcepackage : string;
  version : string;
  filepath : string;
  i : integer;
  root : string;
  found : boolean;
  start : integer;
  targetroot : string;
  executeresult : integer;
  docopy : boolean;
  verifyroot : string;
  dirname : string;
  p : integer;
  packageresult : packageresults;
  foundcount, copiedcount, notfoundcount, copyfailcount, verifyfailcount : integer;
begin
  foundcount := 0;
  copiedcount := 0;
  notfoundcount := 0;
  copyfailcount := 0;
  verifyfailcount := 0;
  t := treadtxt.createf(paramstr(1));
  docopy := (paramstr(2) = '--copy');
  repeat
    line := t.readline;
    p := pos(' ',line);
    sourcepackage := copy(line,1,p-1);
    version := copy(line,p+1,maxlongint);
    makesourcepackagepath(sourcepackage,version,dirname,filepath);
    found := false;
    start := 2;
    if docopy then start := start +1;
    for i := start to paramcount do begin
      root := paramstr(i);
      if root[length(root)] <> '/' then root := root + '/';  
      if fileexists(root+filepath) then begin
        if (i > start) and docopy then begin
          targetroot := paramstr(start);
          if targetroot[length(targetroot)] <> '/' then targetroot := targetroot + '/';
          writeln(root+filepath +' -> '+targetroot+filepath);
          forcedirectories(targetroot+dirname);
          flush(output); //flush standard output to preserve sane ordering
          executeresult := executeprocess('/usr/bin/dcmd','cp '+root+filepath+' '+targetroot+dirname);
          if executeresult = 0 then begin
            writeln(filepath+' successfully copied to target directory');
            packageresult := prcopied;
            verifyroot := targetroot;
          end else begin
            packageresult := prcopyfail;
            writeln(filepath+' !!!failure!!! whilecopying');
            //no point in doing a verify if the copy failed
            verifyroot := '';
          end;          
        end else begin
          packageresult := prfound;
          verifyroot := root;
          writeln(root+filepath);
        end;
        if verifyroot <> '' then begin
          flush(output); //flush standard output to preserve sane ordering
          executeresult := executeprocess('/usr/bin/dscverify','-u '+verifyroot+filepath);
          if executeresult <> 0 then begin
            writeln(filepath+' !!!failure!!!, source package failed to verify');
            packageresult := prverifyfail;
          end;
        end;
        found := true;
        break;
      end;
    end;
    if not found then begin 
      writeln(filepath+' !!!failure!!!, could not find source package');
      packageresult := prnotfound;
    end;
    case packageresult of
      prfound : foundcount := foundcount + 1;
      prcopied : copiedcount := copiedcount +1;
      prnotfound : notfoundcount := notfoundcount +1;
      prcopyfail : copyfailcount := copyfailcount +1;
      prverifyfail : verifyfailcount := verifyfailcount +1;
    end;
  until t.eof;
  if docopy then begin
    writeln(foundcount,' found already in the right place');
    writeln(copiedcount,' found and copied');
  end else begin
    writeln(foundcount,' found');
  end;
  writeln(notfoundcount,' not found');
  writeln(copyfailcount,' failed to copy');
  writeln(verifyfailcount,' failed to verify');
  if (notfoundcount > 0) or (copyfailcount > 0) or (verifyfailcount > 0) then begin
    writeln('exiting with error');
    halt(1);
  end;
end.
