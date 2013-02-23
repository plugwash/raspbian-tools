

{
  Automatically converted by H2Pas 1.0.0 from dpkg-db.h
  manually fixed by Peter Michael green to make it
  build successfully;
  The following command line parameters were used:
    -d
    -C
    -c
    -e
    dpkg-db.h
}

{
 * libdpkg - Debian packaging suite library routines
 * dpkg-db.h - declarations for in-core package database management
 *
 * Copyright © 1994,1995 Ian Jackson <ian@chiark.greenend.org.uk>
 * Copyright © 2000,2001 Wichert Akkerman
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
  }

unit dpkgdb;
interface

uses
  ctypes;

{$linklib dpkg}
{$linklib c}
{$linklib gcc}

{$PACKRECORDS C}
{$mode objfpc}
{$calling cdecl}

type
  dpkg_error = record
    errortype: cint;
    str: pchar;
  end;
  pdpkg_error = ^dpkg_error;

    type
       deptype =  Longint;
       Const
         dep_suggests = 0;
         dep_recommends = 1;
         dep_depends = 2;
         dep_predepends = 3;
         dep_breaks = 4;
         dep_conflicts = 5;
         dep_provides = 6;
         dep_replaces = 7;
         dep_enhances = 8;

    type
       depverrel =  Longint;
       Const
         dvrf_earlier = 0001;
         dvrf_later = 0002;
         dvrf_strict = 0010;
         dvrf_orequal = 0020;
         dvrf_builtup = 0100;
         dvr_none = 0200;
         dvr_earlierequal = (dvrf_builtup or dvrf_earlier) or dvrf_orequal;
         dvr_earlierstrict = (dvrf_builtup or dvrf_earlier) or dvrf_strict;
         dvr_laterequal = (dvrf_builtup or dvrf_later) or dvrf_orequal;
         dvr_laterstrict = (dvrf_builtup or dvrf_later) or dvrf_strict;
         dvr_exact = 0400;

Const
              want_unknown = 0;
              want_install = 1;
              want_hold = 2;
              want_deinstall = 3;
              want_purge = 4;
              want_sentinel = 5;
            Const
              eflag_ok = 0;
              eflag_reinstreq = 1;
            Const
              stat_notinstalled = 0;
              stat_configfiles = 1;
              stat_halfinstalled = 2;
              stat_unpacked = 3;
              stat_halfconfigured = 4;
              stat_triggersawaited = 5;
              stat_triggerspending = 6;
              stat_installed = 7;
            Const
              pri_required = 0;
              pri_important = 1;
              pri_standard = 2;
              pri_optional = 3;
              pri_extra = 4;
              pri_other = 5;
              pri_unknown = 6;
              pri_unset = -(1);


    Type
    Pdependency  = ^dependency;
    Pdeppossi  = ^deppossi;
    PFILE  = ^FILE;
    Ppkginfo  = ^pkginfo;
    Ppkginfoperfile  = ^pkginfoperfile;
    //Ppkgiterator  = ^pkgiterator;
    //Pvarbuf  = ^varbuf;
    Pversionrevision  = ^versionrevision;


{$ifndef LIBDPKG_DPKG_DB_H}
{$define LIBDPKG_DPKG_DB_H}
{ $include <sys/types.h>}
{ $include <stdbool.h>}
{ $include <stdio.h>}
{ $include <dpkg/macros.h>}
{ $include <dpkg/varbuf.h>}

      
      versionrevision = record
         epoch : culong;
         version : pchar;
         revision : pchar;
      end;

       dependency = record
            up : ppkginfo;
            next : pdependency;
            list : pdeppossi;
            _type : deptype;
         end;
       bool=cbool;
       deppossi = record
            up : ^dependency;
            ed : ppkginfo;
            next : pdeppossi;
            rev_next : pdeppossi;
            rev_prev : pdeppossi;
            version : versionrevision;
            verrel : depverrel;
            cyclebreak : bool;
         end;

(* Const before type ignored *)
(* Const before type ignored *)
       parbitraryfield = ^arbitraryfield;
       arbitraryfield = record
            next : parbitraryfield;
            name : ^cchar;
            value : ^cchar;
         end;

(* Const before type ignored *)
(* Const before type ignored *)
       pconffile = ^conffile;
       conffile = record
            next : pconffile;
            name : ^cchar;
            hash : ^cchar;
            obsolete : bool;
         end;

(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
       pfiledetails = ^filedetails;
       filedetails = record
            next : pfiledetails;
            name : ^cchar;
            msdosname : ^cchar;
            size : ^cchar;
            md5sum : ^cchar;
         end;

    { pif  }
    { The ‘essential’ flag, true = yes, false = no (absent).  }
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
       pkginfoperfile = record
            depends : ^dependency;
            depended : ^deppossi;
            essential : bool;
            description : ^cchar;
            maintainer : ^cchar;
            source : ^cchar;
            architecture : ^cchar;
            installedsize : ^cchar;
            origin : ^cchar;
            bugs : ^cchar;
            version : versionrevision;
            conffiles : ^conffile;
            arbs : ^arbitraryfield;
         end;

    { Node indicates that parent's Triggers-Pending mentions name.  }
    { NB that these nodes do double duty: after they're removed from
       * a package's trigpend list, references may be preserved by the
       * trigger cycle checker (see trigproc.c).
        }
(* Const before type ignored *)
       ptrigpend = ^trigpend;
       trigpend = record
            next : ptrigpend;
            name : ^cchar;
         end;

    { Node indicates that aw's Triggers-Awaited mentions pend.  }
       ptrigaw = ^trigaw;
       trigaw = record
            aw : ppkginfo;
            pend : ppkginfo;
            samepend_next : ptrigaw;
            sameaw : record
                 next : ptrigaw;
                 prev : ptrigaw;
              end;
         end;

       perpackagestate = record
           {undefined structure}
         end;

    { dselect and dpkg have different versions of this  }
    { pig  }
(* Const before type ignored *)
    { Not allowed except as special sentinel value
                         in some places  }
    { Bitmask.  }
(* Const before type ignored *)
(* Const before type ignored *)
    { ->aw == this  }
    { ->pend == this, non-NULL for us when Triggers-Pending.  }



       pkginfo = record
            next : ppkginfo;
            name : ^cchar;
            want :  Longint;
            
            eflag :  Longint;
            status :  Longint;
            priority :  Longint;

            otherpriority : ^cchar;
            section : ^cchar;
            configversion : versionrevision;
            files : ^filedetails;
            installed : pkginfoperfile;
            available : pkginfoperfile;
            clientdata : ^perpackagestate;
            trigaw : record
                 head : ^trigaw;
                 tail : ^trigaw;
              end;
            othertrigaw_head : ^trigaw;
            trigpend_head : ^trigpend;
         end;
    {** from dbmodify.c ** }
    { Those marked with \*s*\ are possible returns from modstatdb_init.  }
    {s }(* error 
  msdbrw_readonly/*s*/, msdbrw_needsuperuserlockonly/*s*/,
    {s }    {s }    { Now some optional flags:  }
    { flags start at 0100  }
 in enum_list *)
       modstatdb_rw =  Longint;

function modstatdb_is_locked(admindir:pchar):bool;cdecl;external;
(* Const before type ignored *)
procedure modstatdb_lock(admindir:pchar);cdecl;external;
procedure modstatdb_unlock;cdecl;external;
(* error 
enum modstatdb_rw modstatdb_init(const char *admindir, enum modstatdb_rw reqrwflags);
in declaration at line 205 *)
procedure modstatdb_note(pkg:Ppkginfo);cdecl;external;
procedure modstatdb_note_ifwrite(pkg:Ppkginfo);cdecl;external;
procedure modstatdb_checkpoint;cdecl;external;
procedure modstatdb_shutdown;cdecl;external;
(* Const before type ignored *)
function pkgadmindir:pchar;cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
function pkgadminfile(pkg:Ppkginfo; whichfile:pchar):pchar;cdecl;external;
    {** from database.c ** }
(* error 
struct pkginfo *findpackage(const char *name);
in declaration at line 216 *)
procedure blankpackage(pp:Ppkginfo);cdecl;external;
procedure blankpackageperfile(pifp:Ppkginfoperfile);cdecl;external;
procedure blankversion(_para1:Pversionrevision);cdecl;external;
function informative(pkg:Ppkginfo; info:Ppkginfoperfile):bool;cdecl;external;
function countpackages:cint;cdecl;external;
procedure resetpackages;cdecl;external;
(* error 
struct pkgiterator *iterpkgstart(void);
in declaration at line 224 *)
(* error 
struct pkginfo *iterpkgnext(struct pkgiterator
in declaration at line 225 *)
//procedure iterpkgend(_para1:Ppkgiterator);cdecl;external;
procedure hashreport(_para1:PFILE);cdecl;external;
    {** from parse.c ** }
    { Store in `available' in-core structures, not `status'  }
    { Throw up an error if `Status' encountered              }
    { Ignore priority/section info if we already have any    }
    { Ignore files info if we already have them              }
    { Ignore packages with older versions already read.  }
    { Perform laxer parsing, used to transition to stricter parsing.  }
    type
       parsedbflags =  Longint;
       Const
         pdb_recordavailable = 001;
         pdb_rejectstatus = 002;
         pdb_weakclassification = 004;
         pdb_ignorefiles = 010;
         pdb_ignoreolder = 020;
         pdb_lax_parser = 040;

(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
type
  ppchar = ^pchar;
function illegal_packagename(p:pchar; ep:Ppchar):pchar;cdecl;external;
(* Const before type ignored *)
//function parsedb(filename:pchar; _para2:parsedbflags; donep:PPpkginfo; warnto:PFILE; warncount:pcint):cint;cdecl;external;
//procedure copy_dependency_links(pkg:Ppkginfo; updateme:PPdependency; newdepends:Pdependency; available:bool);cdecl;external;
    {** from parsehelp.c ** }
(* Const before type ignored *)
    type
       namevalue = record
            name : pchar;
            value : cint;
            length : cint;
         end;

(* Const before type ignored *)
//      var
//         booleaninfos : array of namevalue;cvar;external;
(* Const before type ignored *)
//         priorityinfos : array of namevalue;cvar;external;
(* Const before type ignored *)
//         statusinfos : array of namevalue;cvar;external;
(* Const before type ignored *)
//         eflaginfos : array of namevalue;cvar;external;
(* Const before type ignored *)
//         wantinfos : array of namevalue;cvar;external;
(* Const before type ignored *)

function informativeversion(version:Pversionrevision):bool;cdecl;external;
    type
       versiondisplayepochwhen =  Longint;
       Const
         vdew_never = 0;
         vdew_nonambig = 1;
         vdew_always = 2;

(* Const before type ignored *)
//procedure varbufversion(_para1:Pvarbuf; _para2:Pversionrevision; _para3:versiondisplayepochwhen);cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
function parseversion(rversion:Pversionrevision; _para2:pchar;err:pdpkg_error):cint;cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
function versiondescribe(_para1:Pversionrevision; _para2:versiondisplayepochwhen):pchar;cdecl;external;
    {** from dump.c ** }
(* Const before type ignored *)
(* Const before type ignored *)
(* Const before type ignored *)
procedure writerecord(_para1:PFILE; _para2:pchar; _para3:Ppkginfo; _para4:Ppkginfoperfile);cdecl;external;
(* Const before type ignored *)
procedure writedb(filename:pchar; available:bool; mustsync:bool);cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
//procedure varbufrecord(_para1:Pvarbuf; _para2:Ppkginfo; _para3:Ppkginfoperfile);cdecl;external;
//procedure varbufdependency(vb:Pvarbuf; dep:Pdependency);cdecl;external;
    { NB THE VARBUF MUST HAVE BEEN INITIALISED AND WILL NOT BE NULL-TERMINATED  }
    {** from vercmp.c ** }
function versionsatisfied(it:Ppkginfoperfile; against:Pdeppossi):bool;cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
function versionsatisfied3(it:Pversionrevision; ref:Pversionrevision; verrel:depverrel):bool;cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
function versioncompare(version:Pversionrevision; refversion:Pversionrevision):cint;cdecl;external;
(* Const before type ignored *)
(* Const before type ignored *)
function epochsdiffer(a:Pversionrevision; b:Pversionrevision):bool;cdecl;external;
    {** from nfmalloc.c ** }
type
  size_t = csize_t;
function nfmalloc(_para1:size_t):pointer;cdecl;external;
(* Const before type ignored *)
function nfstrsave(_para1:pchar):pchar;cdecl;external;
(* Const before type ignored *)
function nfstrnsave(_para1:pchar; _para2:size_t):pchar;cdecl;external;
procedure nffreeall;cdecl;external;
{$endif}
    { LIBDPKG_DPKG_DB_H  }
(* error 
#endif /* LIBDPKG_DPKG_DB_H */ *)

implementation


end.
