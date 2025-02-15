#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* highlight.rex - Rexx highlighting example                                  */
/* =========================================                                  */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx.parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241228    0.1d First public release                                      */
/* 20241229    0.1e Add support for ANSI highlighing                          */
/* 20241231         Add support for LaTeX highlighing                         */
/* 20250102    0.1f Add --prolog and --noprolog options                       */
/* 20250103         Add -u --tutor and --unicode options                      */
/* 20250105         Add --patch="patch specs" and --patchfile=file            */
/* 20250107         Change -t and --term for -a and --ansi                    */
/* 20250108         Add --pad= option                                         */
/*                                                                            */
/******************************************************************************/

Parse Arg fn

-- ::REQUIRES does not work well with "../" paths
package   = .context~package
local     =  package~local
mypath    =  FileSpec( "Path", package~name )
local ~ . = .File~new( mypath"../" )~absolutePath      -- Creates ".."

Call Requires .."/cls/Highlighter.cls"
Call Requires .."/cls/FencedCode.cls"

-- Remember how we were called
Parse Source . how .

-- We will store our processed options in a stem
options. = 0

-- Set default mode to ANSI if called from the command line...
If how == Command Then options.mode = ANSI
-- ...otherwise, assume HTML.
Else                   options.mode = HTML

-- Process user options, if any

patch = .Nil

Loop
  Parse var fn op value rest
If op[1] \== "-" Then Leave
  If op~contains("=") Then Do
    fn = value rest
    Parse Var op op"="value
    Select Case Lower(op)
      When "--startfrom"       Then options.startFrom   = Natural(value)
      When "--style"           Then options.style       = value
      When "--width"           Then options.width       = Natural(value)
      When "--pad"             Then options.pad         = Natural(value)
      When "--patch"           Then Do
        Call AllowQuotes
        If value = "" Then patch = .Nil
        Else patch = .StylePatch~of( value )
      End
      When "--patchfile"       Then Do
        Call AllowQuotes
        If value = "" Then Do
          Say "Invalid option '"op"'."
          Exit 1
        End
        file = Stream(value,"C", "Q Exists")
        If file == "" Then Do
          Say "File '"value"' not found."
          Exit 1
        End
        value = CharIn( file, 1, Chars(file) )~makeArray
        Call Stream file, "C", "Close"
        patch = .StylePatch~of( value )
      End
      Otherwise Do
        Say "Invalid option '"op"'."
        Exit 1
      End
    End
    Iterate
  End
  gotAValue = 1
  Select Case Lower(op)
    When "-s"                  Then options.style       = value
    When "-w"                  Then options.width       = Natural(value)
    Otherwise gotAValue = 0
  End
  If gotAValue Then Do
    fn = rest
    Iterate
  End
  Select Case Lower(op)
    When "-h", "--html"        Then options.mode        =  HTML
    When "-l", "--latex"       Then options.mode        =  LaTeX
    When "-n", "--numberlines" Then options.numberlines = .True
    When "-a", "--ansi"        Then options.mode        =  ANSI
    When "--tutor"             Then options.unicode     = 1
    When "-u", "--unicode"     Then options.unicode     = 1
    When "--noprolog"          Then options.prolog      = 0
    When "--prolog"            Then options.prolog      = 1
    Otherwise Do
      Say "Invalid option '"op"'."
      Exit 1
    End
  End
  fn = value rest
End

-- We need an argument
If fn = "" Then Do
  Say .Resources[Help]
  Exit 1
End

-- Process filenames containing blanks
fn = Strip(fn)
c  = fn[1]
If """'"~contains( c ) Then Do
  Parse Var fn (c)fn2(c)extra
  If extra \== "" Then Do
    Say "Invalid filename '"fn"'."
    Exit 1
  End
  fn = fn2
End

-- Check that the file exists
file = Stream(fn, 'c', 'q exists')
If file == "" Then Do
  Say "File '"fn"' not found."
  Exit 1
End

-- Load the whole file in the "source" array
source = CharIn(file,1,Chars(file))~makeArray
Call Stream file,"c","close"

-- Markdown or html? Process the fenced code blocks and display the result
If file~caselessEndsWith(".md") | file~caselessEndsWith(".html") Then Do
  Say FencedCode( fn, source )
End
-- Assume it's Rexx
Else Do
  hl =  .Highlighter~new(fn, source, options.)
  Do line Over hl~parse( patch )
    Say line
  End
End

Exit

AllowQuotes:
  q = value[1]
  If """'"~contains( q ) Then Do
    fn = value fn
    Parse Var fn (q)value(q)fn
  End
  Return

Natural:
  If DataType(Arg(1),"W"), Arg(1) >= 0 Then Return Arg(1)
  Say "Invalid value" Arg(1)"."
  Exit 1

Requires:
  package~addPackage( .Package~new( Arg(1) ) )
  Return

--------------------------------------------------------------------------------

::Resource Help
Usage: highlight [OPTIONS] FILE
If FILE has a .md or .html extension, process all Rexx fenced code blocks
in FILE and highlight them. Otherwise, we assume that this is a Rexx file,
and we highlight it directly.

Options:
  -a, --ansi             Select ANSI mode
  -h, --html             Select HTML mode
  -l, --latex            Select LaTeX mode
      --noprolog         Do not print a prolog (LaTeX only)
  -n, --numberlines      Print line numbers
      --patch="PATCHES"  Apply semicolon-separated PATCHES
      --patchfile=FILE   Load patches from FILE
      --pad=N            Pad doc-comments and ::resources to N characters
      --prolog           Print a prolog (LaTeX only)
      --startFrom=N      Start line numbers at N
  -s, --style=STYLE      Use "rexx-STYLE.css" (default is "dark")
      --tutor            Enable TUTOR-flavored Unicode
  -u, --unicode          Enable TUTOR-flavored Unicode
  -w, --width=N          Ensure that all lines have width >= N (ANSI only)

The 'highlight' program is part of the Rexx Parser package, and is distributed
under the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024, 2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.
::END