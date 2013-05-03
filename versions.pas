unit versions;

interface

function compareversion(versiona,versionb: string) : longint;
procedure splitversion(version : string; var epoch: integer; var upstreamversion,debianrevision: string);

implementation

uses sysutils;

//return -1 if versiona is less than versionb
//reutrn 0 if versiona is equal to versionb
//reutrn 1 if versiona is greater than versionb

procedure splitversion(version : string; var epoch: integer; var upstreamversion,debianrevision: string);
var
  epochdelim, debiandelim, i : integer;
begin
  epochdelim := 0;
  debiandelim := length(version)+1;
  for i := 1 to length(version) do begin;
    if (version[i] = ':') and (epochdelim = 0) then epochdelim := i;
    if (version[i] = '-') then debiandelim := i;
  end;
  if epochdelim = 0 then begin
    epoch := 0;
  end else begin
    epoch := strtoint(copy(version,1,epochdelim-1));
  end;
  if debiandelim = length(version)+1 then begin
    debianrevision := '0';
  end else begin
    debianrevision := copy(version,debiandelim+1,maxlongint);
  end;
  upstreamversion := copy(version,epochdelim+1,debiandelim-epochdelim-1);
end;

//return -1 if versionparta is less than versionpartb
//reutrn 0 if versionparta is equal to versionpartb
//reutrn 1 if versionparta is greater than versionpartb

function compareversionpart(versionparta,versionpartb : string) : longint;
var 
  countera, counterb ,lengtha,lengthb : integer;
  chara, charb : char;
  numbera, numberb : integer;
begin
  countera := 1;
  counterb := 1;
  result := 0;
  lengtha := length(versionparta);
  lengthb := length(versionpartb);
  while (countera<=lengtha) or (counterb <=lengthb) do begin
    //writeln('process nondigit part');
    while true do begin
      if countera <= lengtha then chara := versionparta[countera] else chara := #1;
      if counterb <= lengthb then charb := versionparta[counterb] else charb := #1;
      if chara = '~' then chara := #0;
      if charb = '~' then charb := #0;
      if chara in ['0'..'9'] then chara := #1;
      if charb in ['0'..'9'] then charb := #1;
      if chara in ['.','+','-',':'] then chara := chr(ord(chara)+128);
      if charb in ['.','+','-',':'] then charb := chr(ord(charb)+128);
      if chara < charb then begin
        result := -1;
        exit;
      end else if chara > charb then begin
        result := 1;
        exit;
      end;
      if chara = #1 then break; //we have reached the end of the nondigit sequence
      countera := countera + 1;
      counterb := counterb + 1;
    end;
    
    //writeln('if we have reached the end of both version numbers then break out here.');
    if (countera >lengtha) and (counterb >lengthb) then break;
    
    //writeln('process digit part');
    numbera := 0;
    while (countera <= lengtha) and (versionparta[countera] in ['0'..'9']) do begin
      //writeln('countera = ',countera,' versionparta[countera]= ',versionparta[countera]);
      numbera := numbera * 10;
      numbera := numbera + ord(versionparta[countera]) - ord('0');
      countera := countera +1;
    end;
    numberb := 0;
    while (counterb <= lengthb) and (versionpartb[counterb] in ['0'..'9']) do begin
      numberb := numberb * 10;
      numberb := numberb + ord(versionpartb[counterb]) - ord('0');
      counterb := counterb +1;
    end;
    //writeln('digit parts read as ',numbera,' ',numberb);
    if numbera < numberb then begin
      result := -1;
      exit;
    end else if numbera > numberb then begin
      result := 1;
      exit;
    end;
  end;
  result := 0;
end;

//return -1 if versiona is less than versionb
//reutrn 0 if versiona is equal to versionb
//reutrn 1 if versiona is greater than versionb

function compareversion(versiona,versionb: string) : longint;
var
  //rversiona:versionrevision;
  //rversionb:versionrevision;
  //error : dpkg_error;
  epocha, epochb : integer;
  upstreamversiona,upstreamversionb,debianrevisiona,debianrevisionb : string;
begin
  splitversion(versiona,epocha,upstreamversiona,debianrevisiona);
  splitversion(versionb,epochb,upstreamversionb,debianrevisionb);
  result := 0;
  if (epocha < epochb) then result := -1;
  if (epocha > epochb) then result := 1;
  if result = 0 then begin
    //writeln('comparing upstream versions '+upstreamversiona+' '+upstreamversionb);
    result := compareversionpart(upstreamversiona,upstreamversionb);
  end;
  if result = 0 then begin
    //writeln('comparing debian revisions '+debianrevisiona+' '+debianrevisionb);
    result := compareversionpart(debianrevisiona,debianrevisionb);
  end;
  
  
  { old code based on libdpkg eliminated to avoid unstable interface
  //writeln(versiona,' ',versionb);
  uniquestring(versiona);
  uniquestring(versionb);
  if parseversion(@rversiona,pchar(versiona),@error) <> 0 then begin
    writeln('error parsing version '+versiona);
    halt;
  end;
  //writeln('rversiona.version ',rversiona.version);
  //writeln('rversiona.revision ',rversiona.revision);
  if parseversion(@rversionb,pchar(versionb),@error) <> 0 then begin
    writeln('error parsing version '+versionb);
    halt;
  end;
  //writeln('rversionb.version ',rversionb.version);
  //writeln('rversionb.revision ',rversionb.revision);
  
  result := versioncompare(@rversiona,@rversionb);
  }
end;


end.
