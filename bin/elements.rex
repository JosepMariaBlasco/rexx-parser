#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* elements.rex - Transform a file into a list of elements                    */
/* =======================================================                    */
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
/* 20241206    0.1  First public release                                      */
/* 20250103    0.1f Add TUTOR-flavored Unicode support                        */
/* 20250215    0.1g Rename to elements.rex                                    */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/*                  Binary directory is now "bin" instead of "cls"            */
/*                  Move "modules" directory inside "bin"                     */
/* 20250426    0.2b Fix compound count, simplify REQUIRES                     */
/* 20250606    0.2c Add --from and --to options                               */
/* 20250928    0.2e Fix crash when no args, add .rex to file when needed      */
/* 20251114    0.3a Add support for Experimental features                     */
/* 20251125         Add support for Executor                                  */
/* 20251221    0.4a Add --itrace option, improve error messages               */
/* 20251226         Send error messages to .error, not .output                */
/* 20251227         Use .SysCArgs when available                              */
/* 20260102         Standardize help options to -h and --help                 */
/* 20260228         Add --[no-]show-spaces options (suggestion by RGF)        */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- Introspect a little and load our dependencies                              --
--------------------------------------------------------------------------------

  -- Errors returned by the parser require special handling
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

--------------------------------------------------------------------------------
-- Main program                                                               --
--------------------------------------------------------------------------------

  unicode        = 0
  experimental   = 0
  executor       = 0
  opFrom         = 1
  itrace         = 0
  opTo           = "*"
  showSpaces = 1

ProcessOptions:
  If args~items == 0 Then Signal Help

  option = args[1]
  args~delete(1)

  If option[1] == "-" Then Do
    Select Case Lower(option)
      When "-h", "--help"        Then Signal Help
      When "-u", "--tutor", -
        "--unicode"              Then unicode = 1
      When "-e", "-exp", "--exp", -
        "--experimental"         Then experimental = 1
      When "-xtr", "--executor"  Then executor = 1
      When "-it", "--itrace"     Then itrace = 1
      When "--from"              Then opFrom = Integer()
      When "--to"                Then opTo   = Integer()
      When "--show-spaces"       Then showSpaces = 1
      When "--no-show-spaces"    Then showSpaces = 0
      Otherwise Call Error "Invalid option '"option"'."
    End
    Signal ProcessOptions
  End

  If args~items > 0 Then Call Error "Invalid argument '"args[1]"'."

  file = option

  fullPath = .context~package~findProgram(file)

  If fullPath == .Nil Then Call Error "File '"file"' does not exist."

  -- We need to compute the source separately to properly handle syntax errors
  source = CharIn(fullPath,1,Chars(fullPath))~makeArray
  Call CharOut fullPath

  -- Adjust "opTo" if necessary

  If opTo = "*"          Then opTo = source~items
  If opTo > source~items Then opTo = source~items

  -- Print a nice prolog
  Say myName".rex run on" Date() "at" Time()
  Say
  Say "Examining" fullPath"..."
  Say
  Say "Elements marked '>' are inserted by the parser."
  Say "Elements marked 'X' are ignorable."
  Say "Elements marked 'A' have isAssigned=1."
  Say "Compound symbol components are distinguished with a '->' mark."
  Say
  Say "[   from  :    to   ] >XA 'value' (class)"
  Say " --------- ---------  --- ---------------------------"

  -- Parse our program, and get the first element
  Options = .Array~new
  If Unicode      Then Options~append(("UNICODE", 1))
  If experimental Then Options~append(("EXPERIMENTAL", 1))
  If executor     Then Options~append(("EXECUTOR", 1))
  parser = .Rexx.Parser~new(file, source, Options)

  element  = parser~firstElement

  -- Iterate over all elements and print them
  elements = 0
  compound = 0
  Do Counter elements Until element == .Nil
    Parse Value element~from With line .
    If line >  opTo   Then Leave
    If line >= opFrom Then Call Print element
    element = element~next
  End
  Say "Total:" elements "elements and" compound "compound symbol elements examined."

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

Integer:
  n = ""
  If args~items > 0 Then Do
    n = args[1]
    args~delete(1)
  End
  If DataType(n,"W"), n > 0 Then Return n
  Call Error "Positive whole number expected, found '"n"'."

--------------------------------------------------------------------------------

BadArgument:
  Call Error "Incorrect file specification:" file

--------------------------------------------------------------------------------

Print:
  class = element~category
  from = element~from
  to   = element~to
  Parse Var from fromLine fromCol
  Parse Var   to   toLine   toCol
  Call Chunk "["Extent(element)"]"
  Call Chunk (element~isInserted)~?(" >","  ")
  Call Chunk (element~ignorable)~?("X"," ")
  Call Chunk (element~isAssigned)~?("A"," ")
  If class \== .EL.RESOURCE_DATA Then Do
    value = element~value
    If showSpaces Then
      value = ChangeStr(" ",value,"␣")
  End
  Else value = "[... resource data ...]"
  Call Chunk " '"value"'"
  If class == .EL.TAKEN_CONSTANT Then Do
    Say " ("AorAN(ConstantName(element~subCategory))" taken_constant)"
  End
  Else Do
    Say " ( A" CategoryName(element~category)")"
    If element < .ALL.COMPOUND_VARIABLES Then Call Compound
  End
  If value == .Nil Then
    Call Error "Unexpected .Nil value for element condition."
Return

--------------------------------------------------------------------------------

Extent: Procedure
  Use Arg element
  from = element~from
  to   = element~to
  Parse Var from fromLine fromCol
  Parse Var   to   toLine   toCol
Return Right(fromLine,5) Right(fromCol,3)":"Right(toLine,5) Right(toCol,3)

--------------------------------------------------------------------------------

Compound:
  compound += 1
  Do part Over element~parts
    Say " "Extent(part)"     -> '"part~value"' ("||,
      AorAN(.Parser.CategoryName[part~category])")"
  End
Return

--------------------------------------------------------------------------------

AorAN:
  If "AEIOU"~contains(Arg(1)[1]) Then Return "an" Arg(1)
  Return "a" Arg(1)

--------------------------------------------------------------------------------

Chunk:
  Call CharOut , Arg(1)
Return

--------------------------------------------------------------------------------
-- Standard Rexx Parser error handler                                         --
--------------------------------------------------------------------------------

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
   .Error~Say( "Error" co~code "in" co~program", line" co~position":" )
    Raise Propagate
  End
  additional = Condition("A")
  section = additional~section(2)
  extra = Additional~lastItem
  line  = extra~position
  code  = extra~code
  Parse Var code major"."minor
 .Error~Say( Right(line,6) "*-*" source[line] )
 .Error~Say( "Error" major "in" fullpath", line" line": " ErrorText(major) )
 .Error~Say( "Error" code": " Ansi.ErrorText( code, section ) )

  If itrace Then Do
   .Error~Say
   .Error~Say( "Trace follows:" )
   .Error~Say( Copies("-",80) )
   .Error~Say( co~stackFrames~makeArray )
  End

  Exit -major

--------------------------------------------------------------------------------
-- Help text                                                                  --
--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "ANSI.ErrorText.cls"
::Requires "BaseClassesAndRoutines.cls"
::Requires "modules/print/print.cls"
::Resource Help end "::End"
myname - Transform a file into its constituent elements and list them

Usage: myName [options] FILE

Options:
-xtr,--executor     Enable support for Executor
-e,  --experimental Enable Experimental features (also -exp)
     --from [LINE]  Show elements starting at line LINE
     --help         Display this information
-it, --itrace       Print internal traceback on error
     --to   [LINE]  Stop showing elements after line LINE
     --tutor        Enable TUTOR-flavored Unicode
-u,  --unicode      Enable TUTOR-flavored Unicode
--show-spaces       Display spaces as "␣" (requires UTF8)
--no-show-spaces    Display spaces as spaces

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::End