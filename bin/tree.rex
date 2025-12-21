#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* tree.rex - Display the parse tree of a program                             */
/* ==============================================                             */
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
/* 20251215    0.4a First public release                                      */
/*                                                                            */
/******************************************************************************/


  -- Errors returned by the parser require special handling
  Signal On Syntax

  -- Retrieve our own name
  package =  .context~package
  myName  =   package~name
  Parse Caseless Value FileSpec( "Name", myName ) With myName".rex"


  unicode      = 0
  experimental = 0
  executor     = 0
  itrace       = 0
  indent       = 2

  Parse Arg args

  args = Strip(args)

  Loop While args[1] == "-"
    Parse Var args option args
    Select Case Lower(option)
      When "-u", "--tutor", "--unicode" Then unicode = 1
      When "-e", "-exp", "--exp", "--experimental" Then experimental = 1
      When "-it", "--itrace"    Then itrace = 1
      When "-xtr", "--executor" Then executor = 1
      When "--help" Then Signal Help
      Otherwise Signal BadOption
    End
  End

  filename = args
  If filename == "" Then Signal Help

  fullPath = .context~package~findProgram(filename)

  If fullPath == .Nil Then Do
    Say "File '"filename"' does not exist."
    Exit 1
  End

  source = CharIn(fullPath, 1, Chars(fullPath))~makeArray
  Call Stream fullPath, 'c', 'close'

  -- Parse our program, and get the first element
  Options = .Array~new
  If Unicode      Then Options~append(("UNICODE", 1))
  If experimental Then Options~append(("EXPERIMENTAL", 1))
  If executor     Then Options~append(("EXECUTOR", 1))
  parser  = .Rexx.Parser~new(file, source, Options)
  package = parser~package

  Call Print package, 0, indent

  Exit

--------------------------------------------------------------------------------
-- Bad option                                                                 --
--------------------------------------------------------------------------------

BadOption:
  Say "Invalid option '"Upper(option)"'."
  Exit 1

--------------------------------------------------------------------------------
-- Display help and exit                                                      --
--------------------------------------------------------------------------------

Help:
  Say .Resources[Help]~makeString~caselessChangeStr("myName", myName)
  Exit 1

--------------------------------------------------------------------------------
-- Standard Rexx Parser error handler                                         --
--------------------------------------------------------------------------------

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End
  Exit ErrorHandler( fullPath, source, co, itrace)

--------------------------------------------------------------------------------
-- Print                                                                      --
--------------------------------------------------------------------------------

::Routine Print
  Use Strict Arg what, indent, step

  If what == .Nil Then Return

  class = what~class
  extra = Extra( class )
  If extra \== "" Then extra = " ---> ("extra")"
  Call CharOut , Copies(" ", indent)AorAN(class) NiceClassName( class ) "["
  If AnElement Then
    Call CharOut , element~from": "element~to
  Else
    Call CharOut , what~begin~from": "what~end~to
  Call CharOut , "]" extra
  If AnElement Then Do
     Call CharOut , ", a ".Parser.CategoryName[element~category]
  End
  Say

  If Processed Then Return

  Select
    When class == .Instruction.List Then Do
      Loop instruction Over what
        Call Print instruction, indent + step, step
      End
    End
    When what~isA(.NAry.Expression) Then Do
      Loop arg Over what~args
        Call Print arg, indent + step, step
      End
    End
    When what~isA(.Optional.Expression.Instruction) Then Do
      expression = what~expression
      If expression \== .Nil Then
        Call Print expression,  indent + step, step
    End
    Otherwise Do
      Loop message over what~tree~makeArray(" ")
        Call Print what~send(message), indent + step, step
      End
    End
  End
Return

Extra:
  AnElement = 1
  Processed = 1
  Select
    When class = .Literal.String.Term Then Do
      element = what~theString
      Return element~source
    End
    When class = .Symbol.Term Then Do
      element = what~symbol
      Return element~source
    End
    When class = .Operator.Character.Sequence Then Do
      element = what
      Return what~source
    End
    When class = .Inserted.Element Then Do
      element = what
      Return element~value
    End
    When class = .StringOrSymbol.Element Then Do
      element = what
      Return element~value
    End
    Otherwise Nop
  End
  AnElement = 0
  Select
    When class = .Implicit.Exit.Instruction Then Return ""
    Otherwise
      Processed = 0
      Return ""
  End

::Routine AorAN
  Use Strict Arg class
  If Pos(class~id[1], "AEIOUaeiou") > 0 Then Return "An"
  Return "A"

::Routine NiceClassName
  Use Strict Arg class

  id = class~id

  res = ""
  Loop Counter c word Over id~makeArray(".")
    If c > 1 Then res ||= "."
    res ||= word[1]~upper || SubStr(word,2)~lower
  End

  Return res

--------------------------------------------------------------------------------
-- Help text                                                                  --
--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "ErrorHandler.cls"
::Requires "modules/print/print.cls"    -- Helps in debugging

::Resource Help end "::End"
Usage: myName [options] FILE

Display the parse tree of FILE

Options:
-xtr,--executor     Enable support for Executor
-e,  --experimental Enable Experimental features (also -exp)
     --help         Display this information
-it, --itrace       Print internal traceback on error
     --tutor        Enable TUTOR-flavored Unicode
 -u, --unicode      Enable TUTOR-flavored Unicode

The 'myname' program is part of the Rexx Parser package, and is distributed
under the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.
::End