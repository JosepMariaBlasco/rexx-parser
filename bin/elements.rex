#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* elements.rex - Transform a file into a list of elements                    */
/* =======================================================                    */
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
/* 20241206    0.1  First public release                                      */
/* 20250103    0.1f Add TUTOR-flavored Unicode support                        */
/* 20250215    0.1g Rename to elements.rex                                    */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/*                  Binary directory is now "bin" instead of "cls"            */
/*                  Move "modules" directory inside "bin"                     */
/* 20250426    0.2b Fix compound count, simplify REQUIRES                     */
/* 20250606    0.2c Add --from and --to options                               */
/* 20250928    0.2e Fix crash when no args, add .rex to file when needed      */
/* 20251014         Add -lua, --lua options                                   */
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

--------------------------------------------------------------------------------
-- Main program                                                               --
--------------------------------------------------------------------------------

  unicode = 0
  lua     = 1
  opFrom  = 1
  opTo    = "*"

  Parse Arg file

  If file = "" Then Do
    Say .Resources[Help]~makeString~caselessChangeStr("myName", myName)
    Exit 1
  End

ProcessOptions:
  Parse Var file option file

  If option[1] == "-" Then Do
    Select Case Lower(option)
      When "-u", "--tutor", "--unicode" Then unicode = 1
      When "-lua", "--lua" Then lua = 1
      When "--help" Then Do
        Say .Resources[Help]~makeString~caselessChangeStr("myName", myName)
        Exit 1
      End
      When "--from" Then opFrom = Integer()
      When "--to"   Then opTo   = Integer()
      Otherwise
        Say "Invalid option '"option"'."
        Exit 1
    End
    Signal ProcessOptions
  End
  Else file = option file

  file = Strip(file)

  -- Filename may contain blanks
  c = file[1]
  If """'"~contains(c) Then Do
    If \file~endsWith(c) Then Signal BadArgument
    file = SubStr(file,2,Length(file)-2)
    If file~contains(c)  Then Signal BadArgument
  End

  fullPath = .context~package~findProgram(file)

  If fullPath == .Nil Then Do
    Say "File '"file"' does not exist."
    Exit 1
  End

  -- We need to compute the source separately to properly handle syntax errors
  source = CharIn(fullPath,1,Chars(fullPath))~makeArray
  Call CharOut fullPath

  -- Adjust "opTo" if necessary

  If opTo = "*"          Then opTo = source~items
  If opTo > source~items Then opTo = source~items

  -- Print a nice prolog
  Say myName".rex run on" Date() "at" Time()
  Say
  Say "Examining" Strip(Arg(1))"..."
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
  If Unicode Then Options~append(("UNICODE", 1))
  If Lua     Then Options~append(("LUA", 1))
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

Integer:
  Parse Var file n file
  If \DataType(n,"W") | n <= 0 Then Do
    Say "Positive whole number expected, found '"n"'."
    Exit 1
  End
  Return n

--------------------------------------------------------------------------------

BadArgument:
  Say "Incorrect file specification:" file
  Exit 1

--------------------------------------------------------------------------------

Print:
  class = element~category
  from = element~from
  to   = element~to
  Parse Var from fromLine fromCol
  Parse Var   to   toLine   toCol
  Call Chunk "["Extent(element)"]"
  Call Chunk (element~isImplicit)~?(" >","  ")
  Call Chunk (element~ignored == 1)~?("X"," ")
  Call Chunk (element~isAssigned)~?("A"," ")
  If class \== .EL.RESOURCE_DATA Then value = element~value
  Else value = "[... resource data ...]"
  Call Chunk " '"value"'"
  If class == .EL.TAKEN_CONSTANT Then Do
    Say " ("AorAN(ConstantName(element~subCategory))" taken_constant)"
  End
  Else Do
    Say " ( A" CategoryName(element~category)")"
    If element < .ALL.COMPOUND_VARIABLES Then Call Compound
  End
  If value == .Nil Then Do
    Say "Unexpected .Nil value for element condition."
    Exit 1
  End
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
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End

  additional = Condition("A")
  Say additional[1]":"
  line = Additional~lastItem~position
  Say Right(line,6) "*-*" source[line]
  Say Copies("-",80)
  Say co~stackFrames~makeArray
  additional = additional~lastItem

  Raise Syntax (additional~code) Additional (additional~additional)

  Exit

--------------------------------------------------------------------------------
-- Help text                                                                  --
--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "modules/print/print.cls"
::Resource Help end "::End"
Usage: myName [options] FILE

Transform FILE into a list of elements and list them.

Options:
     --from [LINE] Show elements starting at line LINE
     --help        Display this information
     --lua         Enable Lua support (also -lua)
     --to   [LINE] Stop showing elements after line LINE
     --tutor       Enable TUTOR-flavored Unicode
 -u, --unicode     Enable TUTOR-flavored Unicode

The 'myname' program is part of the Rexx Parser package, and is distributed
under the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024, 2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.
::End