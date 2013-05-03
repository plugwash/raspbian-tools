program testversions;
uses sysutils,versions;
var
  epoch : integer;
  upstreamversion : string;
  debianrevision : string;
  result : string;
begin
 splitversion('12345',epoch,upstreamversion,debianrevision);
 if (epoch=0) and (upstreamversion='12345') and (debianrevision='0') then result := 'good' else result := 'bad';
 writeln(inttostr(epoch)+' '+upstreamversion+' '+debianrevision+' '+result);
 
 splitversion('1:12345',epoch,upstreamversion,debianrevision);
 if (epoch=1) and (upstreamversion='12345') and (debianrevision='0') then result := 'good' else result := 'bad';
 writeln(inttostr(epoch)+' '+upstreamversion+' '+debianrevision+' '+result);
 
 splitversion('1:12345-1+rpi1',epoch,upstreamversion,debianrevision);
 if (epoch=1) and (upstreamversion='12345') and (debianrevision='1+rpi1') then result := 'good' else result := 'bad';
 writeln(inttostr(epoch)+' '+upstreamversion+' '+debianrevision+' '+result);

 splitversion('12345-1+rpi1',epoch,upstreamversion,debianrevision);
 if (epoch=0) and (upstreamversion='12345') and (debianrevision='1+rpi1') then result := 'good' else result := 'bad';
 writeln(inttostr(epoch)+' '+upstreamversion+' '+debianrevision+' '+result);
 
 writeln(compareversion('12fuck','1234fuck'));
 
end.