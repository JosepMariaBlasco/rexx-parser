#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* elident.rex - Check that a program is equal to its Element API parsing     */
/* ======================================================================     */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241206    0.1  First public release                                      */
/* 20241208    0.1a c/CLASSIC_COMMENT/STANDARD_COMMENT/                       */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20251110    0.3a Change the name to elident.rex                            */
/* 20252111         Add Executor support, move to /bin                        */
/* 20252118         Add TUTOR support                                         */
/* 20251221    0.4a Add --itrace option, improve error messages               */
/* 20251226         Send error messages to .error, not .output                */
/* 20251227         Use .SysCArgs when available                              */
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

  executor = 0
  unicode  = 0
  itrace   = 0

ProcessOptions:
  If args~items == 0 Then Signal Help

  option = args[1]
  args~delete(1)

  If option[1] == "-" Then Do
    Select Case Lower(option)
      When "-h", "--help"               Then Signal Help
      When "--executor", "-xtr"         Then executor = 1
      When "-it", "--itrace"            Then itrace = 1
      When "-u", "--tutor", "--unicode" Then unicode = 1
      Otherwise Call Error "Invalid option '"option"'."
    End
    Call ProcessOptions
  End

  If args~items > 0 Then Call Error "Invalid argument '"args[1]"'."

  file = option

  fullPath = .context~package~findProgram(file)

  If fullPath == .Nil Then Call Error "File '"file"' does not exist."

  -- Read the whole file into an array
  chunk = CharIn(fullPath,1,Chars(fullPath))
  Call Stream fullPath,"c","close"
  source = chunk~makeArray
  -- Makearray has a funny definition that ignores a possible
  -- last empty line.
  If Right(chunk,1) = "0a"X Then source~append("")

  options = .Array~new
  If executor Then options~append(("EXECUTOR", 1))
  If unicode  Then options~append(("UNICODE", 1))

  parser = .Rexx.Parser~new( file, source, options )

  currentLineNo = 1
  currentLine   = ""

  element = parser~firstElement -- Same as parser~package~prolog~body~begin
  Do Counter elements Until element == .Nil
    If element~from \== element~to Then Do
      category = element~category
      elementLine  = element~from~word(1)
      If      elementLine > currentLineNo          Then Call ChangeLine
      If      category == .EL.STANDARD_COMMENT     Then Call StandardComment
      Else If category == .EL.DOC_COMMENT          Then Call StandardComment
      Else If category == .EL.DOC_COMMENT_MARKDOWN Then Call StandardComment
      Else If category == .EL.RESOURCE_DATA        Then Call ResourceData
      Else    currentLine ||= element~source
    End
    element = element~next
  End

  Exit 0

Help:
  Say .Resources[Help]~makeString        -
    ~caselessChangeStr("myName", myName) -
    ~caselessChangeStr("myHelp", myHelp)
  Exit 1

StandardComment:
  lastLine = element~to~word(1)
  start = element~from~word(2)
  end   = element~  to~word(2)
  If elementLine == lastLine Then Do
    currentLine ||= source[currentLineNo][ start, end-start ]
    Return
  End
  elementLine += 1
  currentLine ||= SubStr( source[currentLineNo], start )
  Call ChangeLine
  currentLineNo = lastLine
  currentLine   = source[currentLineNo][1, end - 1]
Return

ResourceData:
  lastLine = element~to~word(1)
  currentLineNo = lastLine + 1
  currentLine   = ""
Return

ChangeLine:
  Do While elementLine > currentLineNo
    If source[currentLineNo] \== currentLine Then Do
      Say( "Difference found in line number" currentLineNo":" )
      Say "Source line is '"source[currentLineNo]"',"
      Say "Parsed line is '"currentLine"'."
      Exit 1
    End
    currentLineNo += 1
    currentLine    = ""
  End
Return

--------------------------------------------------------------------------------

Error:
 .Error~Say(Arg(1))
  Exit 1

--------------------------------------------------------------------------------
-- Standard Rexx Parser error handler                                         --
--------------------------------------------------------------------------------

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
   .Error~Say( "Error" co~code "in" co~program", line" co~position":" )
    Raise Propagate
  End
  Exit ErrorHandler( file, source, co, itrace)

::Resource HELP
myname -- Checks that the Parser' stream of elements is identical to a FILE.

Usage: myname [OPTION]... [FILE]

If the only option is -h or --help, or if no arguments are present,
then display this help and exit.

Options:

-it, --itrace           Print internal trace on error
-u, --tutor, --unicode  Enable TUTOR-flavored Unicode
-xtr, --executor        Activate support for Executor language extensions

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myHelp for details.
::END

::Requires "Rexx.Parser.cls"
::Requires "BaseClassesAndRoutines.cls"
::Requires "ErrorHandler.cls"