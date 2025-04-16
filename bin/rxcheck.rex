/******************************************************************************/
/*                                                                            */
/* rxcheck.rex - Run the parser with all the early check activated            */
/* ===============================================================            */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
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
/* 20250416    0.2a First release                                             */
/*                                                                            */
/******************************************************************************/

  Parse Arg file

  If file = "" Then Signal Help

  signal = 1
  guard  = 1
  bifs   = 1
  Do While "+-"~contains(Left(file,1))
    Parse Var file option file
    Select Case Lower(option)
      When "-?", "-help", "--help" Then Signal Help
      When "-all" Then Do
        signal = 0
        guard  = 0
        bifs   = 0
      End
      When "+all" Then Do
        signal = 1
        guard  = 1
        bifs   = 1
      End
      When "-signal" Then signal = 0
      When "+signal" Then signal = 1
      When "-guard"  Then guard  = 0
      When "+guard"  Then guard  = 0
      When "-bifs"   Then bifs   = 0
      When "+bifs"   Then bifs   = 1
      Otherwise
        Say "Invalid option '"option"'."
        Exit 1
    End
  End

  file = Strip(file)

  fullPath = Stream(file, 'c', 'query exists')

  If fullPath == "" Then Do
    Say "File '"file"' does not exist."
    Exit 1
  End

  source = CharIn(fullPath, 1, Chars(fullPath))~makeArray
  Call Stream fillPath, 'c', 'close'

  check = .Array~new
  If signal Then check~append("SIGNAL")
  If guard  Then check~append("GUARD")
  If bifs   Then check~append("BIFS")
  Options = .Array~of( (earlyCheck, check ) )

  Signal On Syntax

 .environment~Parser.check = 1

  package = .Rexx.Parser~new(file,source,options)~package

  Say "No errors found."

  Exit

Syntax:

  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End

  additional = Condition("A")
  Say additional[1]":"
  line = Additional~lastItem~position
  Say Right(line,6) "*-*" source[line]
  Say Copies("-",80)
  Say "Internal traceback follows"
  Say Copies("-",80)
  Say co~stackFrames~makeArray~makeString("L",.endOfLine)
  additional = additional~lastItem

  Raise Syntax (additional~code) Additional (additional~additional)

  Exit

Help:
  Say .Resources~Help
  Exit 1

::Requires "Rexx.Parser.cls"
::Resource help

Usage: rxcheck [OPTIONS] FILE

Perform a series of early checks on a Rexx program, without needing to
run it first. Checks are performed syntactically, and therefore they
reach dead branches, uncalled procedures and routines, etc.

Options:
  -?, -help, -- help Display this help file
  +all         Activate all toggles. This is the default
  -all         Deactivate all toggles.
  [+|-]signal  Toggle detecting SIGNAL to inexistent labels
  [+|-]guard   Toggle checking that GUARD is in a method body
  [+|-]bifs    Check BIF arguments

All toggles are active by default
::END