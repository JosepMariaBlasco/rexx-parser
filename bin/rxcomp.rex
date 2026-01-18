/******************************************************************************/
/*                                                                            */
/* rxcomp.rex - Compare two rexx files element-wise                           */
/* ================================================                           */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2026-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260117    0.4a First release                                             */
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

  If args~items == 0 Then Signal Help

  unicode      = 0
  experimental = 0
  executor     = 0
  itrace       = 0

ProcessOptions:
  If args~items == 0 Then Signal Help

  option = args[1]
  args~delete(1)

  If option[1] == "-" Then Do
    Select Case Lower(option)
      When "-h", "--help"       Then Signal Help
      When "-u", "--tutor", -
        "--unicode"             Then unicode = 1
      When "-e", "-exp", "--exp", -
        "--experimental"        Then experimental = 1
      When "-xtr", "--executor" Then executor = 1
      When "-it", "--itrace"    Then itrace = 1
      Otherwise Call Error "Invalid option '"option"'."
    End
    Signal ProcessOptions
  End

  sfile1 = option -- Remember file1 as written

  file1 = .context~package~findProgram(option)

  If file1 == .Nil Then Call Error "File '"option"' does not exist."

  If args~items == 0 Then Call Error "Missing filename after '"option"'."

  option = args[1]
  args~delete(1)

  sfile2 = option -- Remember file2 as written

  file2 = .context~package~findProgram(option)

  If file2 == .Nil Then Call Error "File '"option"' does not exist."

  If args~items > 0 Then Call Error "Invalid parameter '"args[1]"'."

  Options = .Array~new
  If Unicode      Then Options~append(("UNICODE", 1))
  If experimental Then Options~append(("EXPERIMENTAL", 1))
  If executor     Then Options~append(("EXECUTOR", 1))

  source   = CharIn(file1,1,Chars(file1))~makeArray
  Call CharOut file1
  fullpath = file1
  parser1  = .Rexx.Parser~new(file1, source, Options)
  element1 = parser1~firstElement

  source   = CharIn(file2,1,Chars(file2))~makeArray
  Call CharOut file2
  fullpath = file2
  parser2  = .Rexx.Parser~new(file2, source, Options)
  element2 = parser2~firstElement

  Loop While element1 \< .EL.END_OF_SOURCE, element2 \< .EL.END_OF_SOURCE
    Call Next
    from1 = element1~from
    from2 = element2~from
    to1   = element1~to
    to2   = element2~to
    cat1  = element1~category
    cat2  = element2~category
    src1  = element1~source
    src2  = element2~source
    If cat1 \== cat2 Then Call CategoriesDiffer
    If element1 < .ALL.SYMBOLS_AND_KEYWORDS Then Call CaselessCompare
    Else If element1 < .EL.TAKEN_CONSTANT, Pos(src1[1], "'""") == 0 Then Call CaselessCompare
    Else Call Compare
  End

  If element1 \< .EL.END_OF_SOURCE Then Do
    Say file2 "exhausted but" file1 "continues at ["from1"-"to1"]: '"src1"'."
    Exit 1
  End

  If element2 \< .EL.END_OF_SOURCE Then Do
    Say file1 "exhausted but" file2 "continues at ["from2"-"to2"]: '"src2"'."
    Exit 1
  End

  Exit

CategoriesDiffer:
  Say sfile1 "@" from1"-"to1 "is '"src1"' (a" .Parser.CategoryName[cat1]"), but" .EndOfLine || -
    sfile2 "@" from2"-"to2 "is '"src2"' (a" .Parser.CategoryName[cat2]")."
  Exit 1

CaselessCompare:
  val1  = element1~value
  val2  = element2~value
  If val1 == val2 Then Return
  Say "Elements '"val1"' ["from1"-"to1"] and '"val2"' ["from2"-"to2"] differ."
  Exit 1

Compare:
  If src1 == src2 Then Return
  Say "Elements '"src1"' ["from1"-"to1"] (a" .Parser.CategoryName[cat1]") and '"src2"' ["from2"-"to2"] (a" .Parser.CategoryName[cat2]") differ."
  Exit 1

Next:
  Call Next1
  Call Next2
  Return

Next1:
  element1 = element1~next
  If element1 < .EL.END_OF_SOURCE Then Return
  If element1~ignorable           Then Signal Next1
  If element1~from == element1~to Then Signal Next1
  Return

Next2:
  element2 = element2~next
  If element2 < .EL.END_OF_SOURCE Then Return
  If element2~ignorable           Then Signal Next2
  If element2~from == element2~to Then Signal Next2
  Return


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

::Requires "Rexx.Parser.cls"
::Requires "ANSI.ErrorText.cls"
::Requires "BaseClassesAndRoutines.cls"
::Requires "modules/print/print.cls"

--------------------------------------------------------------------------------

::Resource Help end "::End"
myname - Compare two Rexx files element-wise

Usage: myName [options] FILE1 FILE2

Options:
-xtr,--executor     Enable support for Executor
-e,  --experimental Enable Experimental features (also -exp)
     --help         Display this information
-it, --itrace       Print internal traceback on error
     --tutor        Enable TUTOR-flavored Unicode
 -u, --unicode      Enable TUTOR-flavored Unicode

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::End