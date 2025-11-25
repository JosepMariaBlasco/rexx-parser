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
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

  nArgs = .SysCArgs~items
  If nArgs == 0 Then Call ShowHelp

  list = 0

  Loop Counter n i = 1 By 1 While i <= nArgs, .SysCArgs[i][1] == "-"
    Select Case lower(.SysCArgs[i])
      When "-l" Then list = 1
      Otherwise Call ShowHelp
    End
  End

  n = n + 1
  If n > nArgs Then Call ShowHelp
  filename = .SysCArgs[n]

  moreArgs = .SysCArgs~section(n+1)~makeString("L"," ")

  filename = Strip(filename)

  fullPath = .context~package~findProgram(filename)

  If fullPath == .Nil Then
    fullPath = .context~package~findProgram(filename".erx")

  If fullPath == .Nil Then Do
    Say "Error 3:  Failure during initialization."
    Say "Error 3.901:  Failure during initialization: Program "filename" was not found."
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

Syntax:

  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End

  additional = Condition("A")
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

ShowHelp:
  Say .Resources~help
  Exit 1

--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"                      -- The Parser
::Requires "ANSI.ErrorText.cls"                   -- Rexx error messages
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
erexx -- Run a Rexx program with Experimental features

Usage:
  erexx [OPTIONS] [FILE]

Runs the Rexx Parser against FILE, compiles
the Experimental features, and runs the resulting
program.

Options:

  -l      Print the translated program and exit
::END