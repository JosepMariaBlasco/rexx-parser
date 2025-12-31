#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* highlight.rex - Rexx highlighting example                                  */
/* =========================================                                  */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
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
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx.parser        */
/* 20250526    0.2b Add --css opt. & "-" to select .input (thanks, Rony!)     */
/* 20250529    0.2c Add support for detailed string and number highlighting   */
/* 20250706    0.2d Add support for detailed doc-comment highlighting         */
/* 20251029    0.2e Change .stdin to .input (thanks, Rony!)                   */
/* 20251114    0.3a Add support for Experimental features                     */
/* 20251125         Add support for Executor                                  */
/* 20251220    0.4a Disallow -xtr, etc when .md, .html, .htm                  */
/* 20251221         Add --itrace option, improve error messages               */
/* 20251226         Send error messages to .error, not .output                */
/* 20251226         Don't allow -s or --style for .md, improve error msgs     */
/* 20251227         Use .SysCArgs when available                              */
/* 20251228         Add support for --default                                 */
/* 20251230         Add support for --continue                                */
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

  package =  .context~package

  myName  =   package~name
  Parse Caseless Value FileSpec( "Name", myName ) With myName".rex"
  myHelp  = ChangeStr(                                         -
   "myName",                                                   -
   "https://rexx.epbcn.com/rexx-parser/doc/utilities/myName/", -
    myName)
  Parse Source . how .
  If how == "COMMAND", .SysCArgs \== .Nil
    Then args = .SysCArgs
    Else args = ArgArray(Arg(1))

  -- We will store our processed options in a stem
  options. = 0

  -- Set default mode to ANSI if called from the command line...
  If how == "COMMAND"
    Then options.mode = ANSI
    -- ...otherwise, assume HTML.
    Else options.mode = HTML

  options.default     = ""

  myPath              = FileSpec("Location",myself)
  sep                 = .File~separator
  patch               = .Nil
  styleSpecified      = 0

  Loop While args~size > 0, args[1][1] == "-"
    option = args[1]
    args~delete(1)

    Select Case Lower(option)
      When "-s", "--style"     Then Do
        If args~size == 0 Then
          Call Error "Missing style after '"option"' option."
        options.style = args[1]
        args~delete(1)
        styleSpecified = 1
      End
      When "--default"         Then Do
        If args~size == 0 Then
          Call Error "Missing attributes after '"option"' option."
        options.default = args[1]
        args~delete(1)
      End
      When "--doccomments"     Then Do
        If args~size == 0 Then
          Call Error "Missing value after '"option"' option."
        value = args[1]
        args~delete(1)
        If WordPos(value,"detailed block") == 0 Then
          Call Error "Invalid value for --doccomments: '"value"'."
        options.doccomments = value
      End
      When "--patch"           Then Do
        If args~size == 0 Then
          Call Error "Missing value after '"option"' option."
        patch = .StylePatch~of( args[1] )
        args~delete(1)
      End
      When "--patchfile"       Then Do
        If args~size == 0 Then
          Call Error "Missing value after '"option"' option."
        value = args[1]
        args~delete(1)
        file = Stream(value,"C", "Q Exists")
        If file == "" Then Call Error "File '"value"' not found."
        value = CharIn( file, 1, Chars(file) )~makeArray
        Call Stream file, "C", "Close"
        patch = .StylePatch~of( value )
        args~delete(1)
      End

      When "--startfrom"         Then options.startFrom    = Natural(value)
      When "-w", "--width"       Then options.width        = Natural(value)
      When "--pad"               Then options.pad          = Natural(value)

      When "-it", "--itrace"     Then options.itrace       =  1
      When "-h", "--html"        Then options.mode         =  HTML
      When "-l", "--latex"       Then options.mode         =  LaTeX
      When "-n", "--numberlines" Then options.numberlines  = .True
      When "-a", "--ansi"        Then options.mode         =  ANSI
      When "-xtr", "--executor"  Then options.executor     = 1
      When "--css"               Then options.css          = 1
      When "--tutor"             Then options.unicode      = 1
      When "-u", "--unicode"     Then options.unicode      = 1
      When "--noprolog"          Then options.prolog       = 0
      When "--prolog"            Then options.prolog       = 1
      When "--continue"          Then options.continue     = 1
      When "-e", "-exp", "--experimental" Then
                                      options.experimental = 1

      Otherwise Call Error "Invalid option '"option"'."
    End
  End

  If options.css, options.mode \== "HTML" Then
    Call Error "The --css option cannot be used in" options.mode "mode."

  If args~items == 0 Then Signal Help

  If args~items > 1 Then Call Error "Invalid argument '"args[2]"'."

  file = args[1]

  If file == "-" Then source = .Input~arrayIn
  Else Do
    fullPath = .context~package~findProgram(file)
    If fullPath == .Nil Then Call Error "File '"file"' does not exist."
    source = CharIn(fullPath,1,Chars(fullPath))~makeArray
    Call Stream fullPath,"c","close"
  End

  If Options.css == 0 Then Do
    Say ProcessSource()
    Exit
  End

  -- Pick selected style
  If Options.style == 0 Then mystyle = "dark"
  Else                       mystyle = Options.style

  -- A possible copy could reside in our rexx-parser installation
  cssPath = ChangeStr("\",mypath".."sep"css"sep"rexx-"mystyle".css","/")
  -- A possible copy could reside in the current directory
  local   = Stream(Directory()||sep"rexx-"mystyle".css","c","query exists")

  Do line Over .Resources[HTML]
    Select Case line
      When "[*CSS*]" Then Do
        Say  "    <link rel='stylesheet' href='https://rexx.epbcn.com/rexx-parser/css/rexx-"mystyle".css'></link>"
        Say  "    <link rel='stylesheet' href='file:///"cssPath"'></link>"
        If local \== "" Then Say  "    <link rel='stylesheet' href='rexx-"mystyle".css'></link>"
      End
      When "[*CONTENTS*]" Then Say ProcessSource()
      Otherwise Say line
    End
  End

  Exit

ProcessSource:
  -- Markdown? Process the fenced code blocks and display the result
  If file~caselessEndsWith(".md") Then Signal Fenced

  -- HTML? Process the fenced code blocks and display the result
  If file~caselessEndsWith(".html") | file~caselessEndsWith(".htm") Then
    Signal Fenced

  -- Assume it's Rexx
  hl =  .Highlighter~new(file, source, options.)
Return hl~parse( patch )

Fenced:
  If styleSpecified | options.executor | options.experimental | options.unicode Then Do
   .Error~Say( Copies("-",80) )
   .Error~Say( "None of -exp, -s, -u, -xtr, --executor, --experimental, --unicode, --style" )
   .Error~Say( "or --tutor can be specified for files with an extension of" FileSpec("E",file)"." )
   .Error~Say( "Please use the --default option, or specific attributes in your" )
   .Error~Say( "fenced code blocks instead." )
   .Error~Say( "See https://rexx.epbcn.com/rexx-parser/doc/highlighter/fencedcode/ for details" )
    Exit 1
  End

  Return FencedCode( file, source, , options. )

After:
  If args~size == 0 Then
    Call Error "Missing value after '"option"' option."
  Return args~delete(1)

Natural:
  If args~size == 0 Then
    Call Error "Missing number after '"option"' option."
  n = args[1]
  args~delete(1)
  If DataType(n,"W"), n > 0 Then Return n
  Call Error "Positive whole number expected after '"option"', found '"n"'."

Syntax:
  co         = condition("O")
  additional = Condition("A")
  extra = additional~lastitem
  line  = extra~position
  Parse Value co~code With major"."minor
 .Error~Say( Right(line,6) "*-*" extra~sourceline                            )
  -- Try to reconstruct the line number if we have enough information
  name = extra~name
  majorMessagePrinted = 0
  If Right(name,1) == "]" Then Do
    Parse Var name name1" [lines "start"-"end"]"
    If name == name1" [lines "start"-"end"]" Then Do
      majorMessagePrinted = 1
     .Error~Say( "Error" major "in" name1", line" (start+line)": " ErrorText(major) )
    End
  End
  If \majorMessagePrinted Then
   .Error~Say( "Error" major "in" extra~name", line" line": " ErrorText(major) )
 .Error~Say( "Error" co~code": " Ansi.ErrorText( co~code, additional )       )

  If options.itrace Then Do
   .Error~Say
   .Error~Say( "Trace follows:"         )
   .Error~Say( Copies("-",80)           )
   .Error~Say( co~stackFrames~makeArray )
  End

Exit -major

--------------------------------------------------------------------------------

Error:
 .Error~Say(Arg(1))
  Exit 1

--------------------------------------------------------------------------------

Help:
  Say .Resources[Help]~makeString        -
    ~caselessChangeStr("myName", myName) -
    ~caselessChangeStr("myHelp", myHelp)
  Exit 1

--------------------------------------------------------------------------------

::Requires "Highlighter.cls"
::Requires "FencedCode.cls"
::Requires "ANSI.ErrorText.cls"

::Resource Help
myname - Highlight a Rexx program, or a file containing Rexx programs

Usage: myname [OPTIONS] FILE

If FILE has a .md or .html extension, process all Rexx fenced code blocks
in FILE and highlight them. Otherwise, we assume that this is a Rexx file,
and we highlight it directly.

Options:
  -a,  --ansi               Select ANSI mode
       --continue           Continue when a fenced code block is in error
       --css                Include links to css files (HTML only)
       --default=attributes Select default attributes for code blocks
       --doccomments=detailed|block Select highlighting level for doc-comments
  -xtr,--executor           Enable support for Executor
  -e, -exp, --experimental  Enable Experimental features
  -h,  --html               Select HTML mode
  -it, --itrace             Printing internal traceback on error
  -l,  --latex              Select LaTeX mode
       --noprolog           Do not print a prolog (LaTeX only)
  -n,  --numberlines        Print line numbers
       --patch="PATCHES"    Apply semicolon-separated PATCHES
       --patchfile=FILE     Load patches from FILE
       --pad=N              Pad doc-comments and ::resources to N characters
       --prolog             Print a prolog (LaTeX only)
       --startFrom=N        Start line numbers at N
  -s,  --style=STYLE        Use "rexx-STYLE.css" (default is "dark")
       --tutor              Enable TUTOR-flavored Unicode
  -u,  --unicode            Enable TUTOR-flavored Unicode
  -w,  --width=N            Ensure that all lines have width >= N (ANSI only)

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::END

::Resource HTML
<!doctype html>
<html lang='en'>
  <head>
[*CSS*]
  </head>
  <body>
[*CONTENTS*]
  </body>
</html>
::END