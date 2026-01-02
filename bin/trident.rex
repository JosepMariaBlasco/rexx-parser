#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* trident.rex - Check that a program is equal to its Tree API parsing        */
/* ===================================================================        */
/*                                                                            */
/* This program compiles a ooRexx source program and produces an identical    */
/* program using the Tree API. You can build over it to produce other         */
/* language processors that do things more interesting than simply cloning    */
/* the source.                                                                */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
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
/* 20250707    0.2d First version                                             */
/* 20251110    0.2e Rename to "trident.rex" (was "clonetree")                 */
/* 20251211    0.3a Implement Executor support                                */
/* 20252118         Add TUTOR support                                         */
/* 20251221    0.4a Add --itrace option, improve error messages               */
/* 20251226         Send error messages to .error, not .output                */
/* 20251227         Use .SysCArgs when available                              */
/* 20260102         Standardize help options to -h and --help                 */
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
      When "--itrace", "-it"            Then itrace = 1
      When "--executor", "-xtr"         Then executor = 1
      When "-u", "--tutor", "--unicode" Then unicode = 1
      Otherwise Call Error "Invalid option '"option"'."
    End
    Signal ProcessOptions
  End

  file = option

  If args~items > 0 Then Call Error "Unexpected argument '"args[1]"'."

  fullPath = .context~package~findProgram(file)

  If fullPath == .Nil Then
    Call Error "File '"file"' does not exist."

  -- We need to compute the source separately to properly handle syntax errors
  chunk = CharIn(fullPath,1,Chars(fullPath))
  source = chunk~makeArray
  -- Makearray has a funny definition that ignores a possible
  -- last empty line.
  If Right(chunk,1) == "0a"X Then source~append("")
  Call Stream fullPath, "C", "Close"

  options = .Array~new
  If executor Then options~append(("EXECUTOR", 1))
  If unicode  Then options~append(("UNICODE",  1))

  -- Parse our program
  parser = .Rexx.Parser~new(fullPath, source, options)

  package = parser~package

  element = parser~firstElement

  output = .Array.OutputStream~new

  package~compile(element, output, .StringTable~new)

  Do i = 1 To Min(source~items, output~items)
    If source[i] \== output[i] Then Do
      Say "Difference found in line number" i":"
      Say "Source line is '"source[i]"',"
      Say "Parsed line is '"output[i]"'."
      Exit 1
    End
  End

  If source~items == output~items +1, source~lastItem == "" Then Exit 0

  If source~items \== output~items Then Do
    Say "No. of source lines and parsed lines are different:"
    Say "Source:" source~items
    Say "Parsed:" output~items
    Exit 1
  End

  -- We are done
  Exit 0

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
-- Standard Rexx Parser error handler                                         --
--------------------------------------------------------------------------------

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
   .Error~Say( "Error" co~code "in" co~program", line" co~position":" )
    Raise Propagate
  End
  Exit ErrorHandler( fullpath, source, co, itrace)

--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "ErrorHandler.cls"
::Requires "modules/print/print.cls"    -- Helps in debug

::Requires "modules/identity/compile.cls"         -- The Identity compiler
::Requires "modules/identity/Clauses.cls"
::Requires "modules/identity/Directives.cls"
::Requires "modules/identity/Expressions.cls"
::Requires "modules/identity/Instructions.cls"
::Requires "modules/identity/iterations.cls"
::Requires "modules/identity/Parsing.cls"

--------------------------------------------------------------------------------

::Class Array.OutputStream Public SubClass Array Inherit OutputStream

::Method Init
  Expose written
  written = 0

::Method Say
  Expose written

  Use Strict Arg string = ""

  If written == 0 Then self~append( string )
  Else                self[self~last] ||= string

  written = 0

  Return 0

::Method CharOut
  Expose written

  Use Strict Arg string -- We don't implement start

  If written == 0 Then self~append( string )
  Else                 self[self~last] ||= string

  written = 1

--------------------------------------------------------------------------------

::Resource HELP
myname -- Verify if the identity compiler returns a perfect copy of a program.

Usage: myname [OPTION]... [FILE]

If the only option is -h or --help, or if no arguments are present,
then display this help and exit.

Options:

--executor, -xtr  Activate support for Executor language extensions
--itrace, -it     Print internal trace on error

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::END
