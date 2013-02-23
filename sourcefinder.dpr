program sourcefinder;
uses
  readtxt2,sysutils,util;

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
begin
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
            verifyroot := targetroot;
          end else begin
            writeln(filepath+' !!!failure!!! whilecopying');
            //no point in doing a verify if the copy failed
            verifyroot := '';
          end;          
        end else begin
          verifyroot := root;
          writeln(root+filepath);
        end;
        if verifyroot <> '' then begin
          flush(output); //flush standard output to preserve sane ordering
          executeresult := executeprocess('/usr/bin/dscverify','-u '+verifyroot+filepath);
          if executeresult <> 0 then writeln(filepath+' !!!failure!!!, source package failed to verify');
        end;
        found := true;
        break;
      end;
    end;
    if not found then writeln(filepath+' !!!failure!!!, could not find source package');
  until t.eof;
end.
