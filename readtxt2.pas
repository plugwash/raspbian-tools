{ Copyright (C) 2009 Bas Steendijk and Peter Green
  For conditions of distribution and use, see copyright notice in zlib_license.txt
  which is included in the package
  ----------------------------------------------------------------------------- }

unit readtxt2;

interface

{
readtxt, version 2
by beware

this can be used to read a text file exposed as a tstream line by line.
automatic handling of CR, LF, and CRLF line endings, and readout of detected line ending type.
fast: 1.5-2 times faster than textfile readln in tests.
}

uses
  classes,sysutils;

const
  bufsize=4096;
  eoltype_none=0;
  eoltype_any=0;
  eoltype_cr=1;
  eoltype_lf=2;
  eoltype_crlf=3;

type
  treadtxt=class(tobject)
  private
    buf:array[0..bufsize-1] of byte;
    numread:integer;
    bufpointer:integer;
    currenteol,preveol:integer;
    fileeof,reachedeof:boolean;
    fdetectedeol:integer;
    procedure checkandread;
  public
    sourcestream:tstream;
    destroysourcestream:boolean;
    allowedeol:integer;
    constructor create(asourcestream: tstream; adestroysourcestream:boolean);
    constructor createf(filename : string);

    function readline:ansistring;
    function eof:boolean;
    destructor destroy; override;
    property detectedeol : integer read fdetectedeol;
  end;
  
implementation

constructor treadtxt.create(asourcestream: tstream; adestroysourcestream:boolean);
begin
  inherited create;
  sourcestream := asourcestream;
  destroysourcestream := adestroysourcestream;

  //if sourcestream.Position >= sourcestream.size then fileeof := true;
  bufpointer := bufsize;
end;

constructor treadtxt.createf(filename: string);
begin
  create(tfilestream.create(filename,fmOpenRead or fmShareDenyWrite),true);
end;


procedure treadtxt.checkandread;
begin
  if bufpointer >= numread then begin
    numread := sourcestream.read(buf,bufsize);
    bufpointer := 0;
    if numread = 0 then fileeof := true;
      
  end;
end;

function treadtxt.readline;
var
  a,b,c,d:integer;
  prevchar : integer;
  trimchar : boolean;
begin
  prevchar := 0;
  result := '';
  repeat
    checkandread;
    b := numread-1;
    trimchar := false;
    {core search loop begin}
    d := -1;
    for a := bufpointer to b do begin
      c := buf[a];
      //check if the character can possiblly be a line ending before getting
      //into the more complex checks that depend on eol type
      if (c = 10) or (c = 13) then case allowedeol of
        eoltype_any: begin
          d := a;
          break;
        end;
        eoltype_cr: begin
          if (c = 13) then begin
            d := a;
            break;
          end;
        end;
        eoltype_lf: begin
          if (c = 10) then begin
            d := a;
            break;
          end;
        end;
        eoltype_crlf: begin
          if (c = 10) and (prevchar= 13) then begin
            d := a;
            trimchar := true;
            break;
          end;
          prevchar := c;
        end;
        else begin
          raise exception.create('undefined eol type set');
        end;
      end;
      prevchar := c;
    end;
    {core search loop end}
    
    c := length(result);
    if (d = -1) then begin
      {ran out of buffer before end of line}
      b := numread-bufpointer;
      setlength(result,c+b);
      move(buf[bufpointer],result[c+1],b);
      bufpointer := numread;
      if fileeof then begin
        {we reached the end of the file, return what we have}
        reachedeof := true;
        exit;
      end;
    end else begin

      preveol := currenteol;
      currenteol := buf[d];

      {end of line before end of buffer}
      if (currenteol = 10) and (preveol = 13) and (bufpointer = d) then begin
        {it's the second EOL char of a DOS line ending, don't cause a line}
        bufpointer := d+1;
        fdetectedeol := eoltype_crlf;
      end else begin
        if fdetectedeol = eoltype_none then begin
          if (currenteol = 10) then fdetectedeol := eoltype_lf else fdetectedeol := eoltype_cr;
        end;  
        b := d-bufpointer;
        if trimchar then begin
          setlength(result,c+b-1);
          move(buf[bufpointer],result[c+1],b-1);
          bufpointer := d+1;
        end else begin
          setlength(result,c+b);
          move(buf[bufpointer],result[c+1],b);
          bufpointer := d+1;
        end;

        {EOF check}
        if fileeof then begin
          if (bufpointer >= numread) then reachedeof := true;
          if (currenteol = 13) and (bufpointer = numread-1) then if (buf[bufpointer] = 10) then reachedeof := true;
        end;  

        exit;
      end;
    end;
  until false;
end;

function treadtxt.eof:boolean;
begin
  checkandread;
  result := ((bufpointer >= numread) and fileeof) or reachedeof;
end;

destructor treadtxt.destroy;
begin
  if destroysourcestream then if assigned(sourcestream) then sourcestream.destroy;
  inherited destroy;
end;

end.
