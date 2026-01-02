#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* erexx.rex - Run an Experimental REXX program                               */
/* ============================================                               */
/*                                                                            */
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
/* 20251113    0.3a First version                                             */
/* 20251127         Add support for Executor                                  */
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

  list     = 0
  executor = 0
  itrace   = 0

ProcessOptions:
  If args~items == 0 Then Signal Help

  option = args[1]
  args~delete(1)

  If option[1] == "-" Then Do
    Select Case lower(option)
      When "-l"                 Then list     = 1
      When "-h", "--help"       Then Signal Help
      When "-it", "--itrace"    Then itrace = 1
      When "-xtr", "--executor" Then executor = 1
      Otherwise Call Error "Invalid option '"option"'."
    End
    Call ProcessOptions
  End

  filename = option

  moreArgs = args~makeString("L"," ")

  fullPath = .context~package~findProgram(filename)

  If fullPath == .Nil Then
    fullPath = .context~package~findProgram(filename".erx")

  If fullPath == .Nil Then Do
   .Error~Say( "Error 3:  Failure during initialization." )
   .Error~Say( "Error 3.901:  Failure during initialization: Program "filename" was not found." )
    Exit -3
  End

  -- We need to compute the source separately to properly handle syntax errors
  chunk = CharIn(fullPath,1,Chars(fullPath))
  source = chunk~makeArray
  -- Makearray has a funny definition that ignores a possible
  -- last empty line.
  If Right(chunk,1) == "0a"X Then source~append("")
  Call Stream fullPath, "C", "Close"

  options = .Array~of((Experimental,1))
  If executor Then options~append(("EXECUTOR",1))

  -- Parse our program
  parser = .Rexx.Parser~new(fullPath, source, options)

  package = parser~package

  element = parser~firstElement

  output = .Array.OutputStream~new

  -- Compile the program
  package~compile(element, output, .StringTable~new)

  -- Add a call to the enabler for experimental features
  If output[1][1] == "#" Then insertAt = 2 -- A shebang
  Else                        insertAt = 1
  output[insertAt] = "Call EnableExperimentalFeatures .Methods; "output[insertAt]

  If list Then Do
    Say output
    Exit 0
  End

  -- Run the program we just compiled
 .routine~new(fullPath, output)~call(moreArgs)

  -- We are done
  Exit result

Help:
  Say .Resources[Help]~makeString        -
    ~caselessChangeStr("myName", myName) -
    ~caselessChangeStr("myHelp", myHelp)
  Exit 1

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
  Exit ErrorHandler( fullpath, source, co, itrace)

--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"                      -- The Parser
::Requires "BaseClassesAndRoutines.cls"           -- For ArgArray et al
::Requires "ErrorHandler.cls"                     -- Standard error handling
::Requires "modules/print/print.cls"              -- Helps in debug
::Requires "modules/identity/compile.cls"         -- The Identity compiler
::Requires "modules/identity/Clauses.cls"
::Requires "modules/identity/Directives.cls"
::Requires "modules/identity/Expressions.cls"
::Requires "modules/identity/Instructions.cls"
::Requires "modules/identity/Iterations.cls"
::Requires "modules/identity/Parsing.cls"

-- Load experimental modules

::Requires "modules/experimental/classextensions.cls"
::Requires "modules/experimental/initializers.cls"

--------------------------------------------------------------------------------

::Class Array.OutputStream Public SubClass Array Inherit OutputStream

::Method Init
  Expose written
  written = 0

::Method Say
  Expose written

  Use Strict Arg string = ""

  If written == 0 Then self~append( string )
  Else                 self[self~last] ||= string

  written = 0

  Return 0

::Method CharOut
  Expose written

  Use Strict Arg string -- We don't implement start

  If written == 0 Then self~append( string )
  Else                 self[self~last] ||= string

  written = 1

--------------------------------------------------------------------------------

::Resource Help
myname -- Run a Rexx program with Experimental features

Usage:
  myname [OPTIONS] [FILE]

Runs the Rexx Parser against FILE, compiles the Experimental features,
and runs the resulting program.

If the only option is -h or --help, or if no arguments are present,
then display this help and exit.

Options:

  -l                Print the translated program and exit
  -it, --itrace     Print internal trace on error
  -xtr, --executor  Activate Executor support


The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::END