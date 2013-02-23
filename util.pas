unit util;
interface

function stringstartis(const s,start : string) : boolean;
procedure makesourcepackagepath(sourcepackage,version: string; out dirname: string; out filepath: string);

implementation

function stringstartis(const s,start : string) : boolean;
var
  i : integer;
begin
  if length(s) < length(start) then begin
    result := false;
    exit;
  end;
  for i := 1 to length(start) do begin
    if s[i] <> start[i] then begin
      result := false;
      exit;
    end;
  end;
  result := true;
end;

procedure makesourcepackagepath(sourcepackage,version: string; out dirname: string; out filepath: string);
var
  p : integer;
  filename : string;
  versionnoepoch : string;
  
begin
  //writeln(sourcepackage);
  //writeln(version);
  p := pos(':',version);
    if p = 0 then begin
      versionnoepoch := version;
    end else begin
      versionnoepoch := copy(version,p+1,maxlongint);
    end;
    filename := sourcepackage+'_'+versionnoepoch+'.dsc';
    if stringstartis(sourcepackage,'lib') then begin
      dirname := 'lib' + sourcepackage[4];
    end else begin
      dirname := sourcepackage[1];
    end;
    dirname := dirname + '/' + sourcepackage;
    filepath := dirname + '/' + filename;
    
end;

end.
