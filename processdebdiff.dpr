program procesdebdiff;
uses sysutils,readtxt2,classes,baseunix,unix,unixutil;
const
  //define our own versions of these constants to avoid stupid i18n in the fpc rtl;
  ShortDayNames : TWeekNameArray = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
  ShortMonthNames : TMonthNameArray = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
var
  tin : treadtxt;
  tout : file;
  line : string;
  inchunk : boolean;
  oldremain : integer;
  newremain : integer;
  i : integer;
  filename : string;
  inchangelog : boolean;
  changelog : tstringlist;
  currentchangelogentry : tstringlist;
  changelogline : string;
  lastnonemptyline : integer;
  datetime : string;
  tv : ttimeval;
  year,month,day,hour,minute,second : word;
  dow : string;
begin
  tin := treadtxt.createf(paramstr(1));
  tin.allowedeol := eoltype_lf;
  inchunk := false;
  inchangelog := false;
  oldremain := 0;
  newremain := 0;
  currentchangelogentry := tstringlist.create();
  changelog := tstringlist.create();
  changelog.add(paramstr(2)+' ('+paramstr(3)+') '+paramstr(4)+'; urgency=low');
  assignfile(tout,paramstr(1)+'.processed');
  rewrite(tout,1);
  repeat
    line := tin.readline;
    
    //code to track whether or not we are currently in a chunk (nessacery to unambiguously distinguish header lines from lines in chunks)
    if inchunk then begin
      case line[1] of
        ' ': begin
          oldremain := oldremain - 1;
          newremain := newremain - 1;
        end;
        '+': begin
          newremain := newremain - 1;
        end;
        '-': begin
          oldremain := oldremain - 1;
        end;
        else begin
          raise exception.create('broken chunk found (invalid line type)');
        end;
      end;
      if (oldremain < 0) or (newremain < 0) then raise exception.create('broken chunk found (too many lines)');
      if (oldremain = 0) and (newremain = 0) then inchunk := false;
    end else begin
      if (line[1] = '@') and (line[2] = '@') then begin
        writeln('1234567890123456789012345678901234567890');
        writeln(line);
        inchunk := true;
        i := 5;
        while (i < length(line)) and (line[i] in ['0'..'9']) do i := i + 1;
        if i = length(line) then raise exception.create('invalid chunk header (trap 1)');
        if line[i] = ',' then begin
          oldremain := 0;
          i := i+1;
          while (i < length(line)) and (line[i] in ['0'..'9']) do begin
            oldremain := (oldremain*10) + ord(line[i])-ord('0');
            i := i + 1;
          end;
        end else begin
          oldremain := 1;
        end;
        if i = length(line) then raise exception.create('invalid chunk header (trap 2)');
        if line[i] <> ' ' then raise exception.create('invalid chunk header (trap 3)');
        i := i + 1;
        if i = length(line) then raise exception.create('invalid chunk header (trap 4)');
        if line[i] <> '+' then raise exception.create('invalid chunk header (trap 5)');
        i := i + 1;
        while (i < length(line)) and (line[i] in ['0'..'9']) do i := i + 1;
        if i = length(line) then raise exception.create('invalid chunk header (trap 6)');
        if line[i] = ',' then begin
          writeln('starting extraction of new length at position',i);
          newremain := 0;
          i := i+1;
          while (i < length(line)) and (line[i] in ['0'..'9']) do begin
            newremain := (newremain*10) + ord(line[i])-ord('0');
            i := i + 1;
          end;
        end else begin
          writeln('character found at position ',i,' was not a comma, assuming new length is 1');
          newremain := 1;
        end;
        writeln('chunk found with ',oldremain,' old lines and ',newremain,' new lines');
        
      end;
    end;
    
    //if we aren't in a chunk then lookout for the --- line that signals a new file and extract the filename
    if (not inchunk) and (line[1] = '-') and (line[2] = '-') and (line[3] = '-') and (line[4] = ' ') then begin
      i := 5;
      filename := '';
      while (i < length(line)) and (line[i] <> #9) and (line[i] <> '/') do i := i + 1;
      i := i + 1;
      while (i < length(line)) and (line[i] <> #9) do begin
        filename := filename + line[i];
        i := i + 1;
      end;
      writeln('found file ',filename);
      inchangelog := (filename = 'debian/changelog');
    end;
    
    if inchangelog then begin
      if inchunk and (line[1] = '+') then begin
        changelogline := copy(line,2,maxlongint);
        if length(changelogline) < 2 then begin
          writeln('treat as a blank line');
          //keep blank lines in the midle of a changelog entry, discard ones
          //at the start of a changelog entry
          if currentchangelogentry.count <> 0 then currentchangelogentry.add('');
        end else if (changelogline[1] = ' ') and (changelogline[2] = ' ') then begin
          writeln('regular changelog line, add it to the current changelog entry');
          currentchangelogentry.add(changelogline);
        end else if changelogline[1] = ' ' then begin
          writeln('changelog trailer line');
          lastnonemptyline := -1;
          if currentchangelogentry.count > 0 then begin
            for i := currentchangelogentry.count -1 downto 0 do begin
              if currentchangelogentry[i] <> '' then begin
                lastnonemptyline := i;
                break;
              end;
            end;
          end;
          if lastnonemptyline >= 0 then begin
            changelog.add('');
            changelog.add('  ['+copy(changelogline,5,maxlongint)+']');
            for i := 0 to lastnonemptyline do begin
              changelog.add(currentchangelogentry[i]);
            end;
          end;
          currentchangelogentry.clear;
        end else begin
          //changelog header line (ignored)
        end;
        
      end;
    end else begin;
      line := line + #10;
      blockwrite(tout,line[1],length(line));
    end;
  until tin.eof;
  tin.free;
  
  changelog.add('');
  fpgettimeofday(@tv,nil);
  //HACK: subtract the timezone offset to nullify the addition of the timezone in epochtolocal
  tv.tv_sec := tv.tv_sec - TZSeconds;
  epochtolocal(tv.tv_sec,year,month,day,hour,minute,second);
  dow := shortdaynames[dayofweek(encodedate(year,month,day))];
  datetime := dow+', '+inttostr(day)+' '+shortmonthnames[month]+' '+inttostr(year)+' '+inttostr(hour)+':'+inttostr(minute)+':'+inttostr(second)+' +0000';
  changelog.add(' -- raspbian forward porter <forwardporter@raspbian.org>  '+datetime);
  changelog.add('');
  datetime := inttostr(year)+':'+inttostr(month)+':'+inttostr(day)+' '+inttostr(hour)+':'+inttostr(minute)+':'+inttostr(second)+' +0000';
  line := '--- a/debian/changelog'#9+datetime+#10;
  blockwrite(tout,line[1],length(line));
  line := '+++ b/debian/changelog'#9+datetime+#10;
  blockwrite(tout,line[1],length(line));
  line := '@@ -0,0 +1,'+inttostr(changelog.count)+' @@'+#10;
  blockwrite(tout,line[1],length(line));
  for i := 0 to changelog.count-1 do begin
    line := '+'+changelog[i]+#10;
    blockwrite(tout,line[1],length(line));
  end;
  closefile(tout);
  
end.