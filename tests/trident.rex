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
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20250707    0.2d First version                                             */
/* 20251110    0.2e Rename to "trident.rex" (was "clonetree")                 */
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

  Parse Arg filename

  filename = Strip(filename)

  fullPath = .context~package~findProgram(filename)

  If fullPath == .Nil Then Do
    Say "File '"filename"' does not exist."
    Exit 1
  End

  -- We need to compute the source separately to properly handle syntax errors
  chunk = CharIn(fullPath,1,Chars(fullPath))
  source = chunk~makeArray
  -- Makearray has a funny definition that ignores a possible
  -- last empty line.
  If Right(chunk,1) == "0a"X Then source~append("")
  Call Stream fullPath, "C", "Close"

  -- Parse our program
  parser = .Rexx.Parser~new(fullPath, source)

  package = parser~package

  element = parser~firstElement

  output = .Array.OutputStream~new
 .output~destination( output )

    package~compile(element, .Output, .StringTable~new)

 .output~destination -- Restore

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

Syntax:

  If .Array.Output~isA(.Array) Then .output~destination

  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End

  additional = Condition("A")
  Say additional[1]":"
  additional = additional~lastItem
  line = additional~position
  code = additional~code
  additional~additional
  Parse Var code major"."minor
  minor = 0 + minor
  Say Right(line,6) "*-*" source[line]
  Say "Error" major "running" fullPath "line" line": " ErrorText(major)
  minor = 0 + minor
  Say "Error" major"."minor": " ANSI.ErrorText(code, additional~additional)

  Exit -major

--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "ANSI.ErrorText.cls"
::Requires "modules/print/print.cls"  -- Helps in debug
::Requires "modules/compile/compile.cls"

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
