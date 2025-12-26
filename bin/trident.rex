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
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

  Parse Arg args

  args = Strip(args)

  If args == "" Then Signal Help

  executor = 0
  unicode  = 0
  itrace   = 0

  Loop While args[1] == "-"
    Parse Var args option args
    Select Case Lower(option)
      When "--help", "-?"               Then Signal Help
      When "--itrace", "-it"            Then itrace = 1
      When "--executor", "-xtr"         Then executor = 1
      When "-u", "--tutor", "--unicode" Then unicode = 1
      Otherwise Signal InvalidOption
    End
  End

  If args = "" Then Signal Help

  fullPath = .context~package~findProgram(args)

  If fullPath == .Nil Then Do
   .Error~Say( "File '"args"' does not exist." )
    Exit 1
  End

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

InvalidOption:
 .Error~Say( "Invalid option '"option"'." )
  Exit 1

Help:
  Say .Resources["HELP"]
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

::Resource HELP
elident -- Verify if the identity compiler returns a perfect copy of a program.

Usage: trident [OPTION]... [FILE]

If the only option is --help or -?, or if no arguments are present,
then display this help and exit.

Options:

--executor, -xtr  Activate support for Executor language extensions
--itrace, -it     Print internal trace on error
::END

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
