#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* identtest.rex - Test Rexx programs in a file tree                          */
/* =================================================                          */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
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
/* 20251211    0.3a First public release                                      */
/* 20251215    0.4a Add toggles for Executor support, .TestGroup files        */
/*                  Change name to identtest (thanks, JLF!)                   */
/*                                                                            */
/******************************************************************************/

-- identtest
--
-- Usage: cd to a directory run it.
--
-- By default, the script will recursively examine the whole directory
-- tree and run the elident and trident tests against all .rex and .cls
-- files. The script will stop when all files have been processed, or when
-- an error is encountered.
--
-- Run "indentest -?" to show a list of the available options.
--
-- See also the list of exceptions below
--

Parse Lower Arg args
args = Space(Strip(args))

SysFileTreeOptions = "FSO"

elements  = 1
tree      = 1

executor  = 0
rexx      = 1
cls       = 1
testGroup = 0

Loop option Over args~makeArray(" ")
  Select Case option
    When "--help", "-h",         "-?" Then Signal Help
    When "--executor",         "-xtr" Then executor  = 1
    When "--testgroup",         "-tg" Then testGroup = 1
    When "--noelements",        "-ne" Then elements  = 0
    When "--notree",            "-nt" Then tree      = 0
    When "--norexx", "--norex", "-nr" Then rexx      = 0
    When "--nocls",             "-nc" Then cls       = 0
    Otherwise
      Say "Invalid option '"option"'."
      Exit 1
  End
End

If Executor Then option = "-xtr"
Else             option = ""

If cls Then Do
  Call SysFileTree "*.cls", "cls", SysFileTreeOptions

  Exception. = 0

  -- Add exceptions here

  Loop i = 1 To cls.0
    name = FileSpec("N",cls.i)
    If exception.name Then Iterate

    Say "Checking" cls.i"..."
    Say "--> Elements"
    Call ElIdent option cls.i
    If result \== 0 Then Exit 1
    Say "--> Tree"
    Call TrIdent option cls.i
    If result \== 0 Then Exit 1
  End
End

If rexx Then Do
  Call SysFileTree "*.rex", "rex", SysFileTreeOptions

  Exception. = 0

  -- These exceptions are tailored to the Executor tree.

  -- expression=
  exceptions = "executor-demo-array.rex executor-demo-extensions.rex executor-demo-text-compatibility-auto-conv.rex" -
    "executor-demo-text-compatibility.rex executor-demo-text-internal_checks.rex executor-demo-text-unicode.rex"     -
    "executor-demo-text.rex ooRexxShell-demo-interpreters.rex ooRexxShell-demo-queries.rex"                          -
    "diary_examples.rex include_concatenation_infos.rex include_concatenation_infos.rex"                             -
    "include_conversion.rex include_conversion_infos.rex"

  -- Real error
  exceptions ||= " classic_rexx.rex ooRexxTry.rex"

  -- malformed expression

  exceptions ||= " include_conversion_to_unicode.rex include_conversion_to_unicode16.rex include_conversion_to_unicode32.rex" -
    "include_conversion_to_unicode8.rex include_conversion_to_utf16be.rex include_conversion_to_utf16le.rex"                 -
    "include_conversion_to_utf32be.rex include_conversion_to_utf32le.rex include_conversion_to_utf8.rex"                     -
    "include_conversion_to_wtf16be.rex include_conversion_to_wtf16le.rex include_conversion_to_wtf8.rex"                     -
    "main_concatenation.rex main_conversion.rex"

  -- test/trunk (SVN)
  exceptions ||=  " tmpTest_ExternalCode_Compiled.rex tmpTest_ExternalCode_CompiledAndEncoded.rex"

  -- samples/ (ooRexx installations)
  exceptions ||=  " MSInternetExplorer_search.rex"

  -- Experimental features of the Rexx Parser
  exceptions ||=  " extends.rex tables.rex"

  Loop word Over exceptions~makeArray(" ")
    exception.word = 1
  End

  Loop i = 1 To rex.0
    name = FileSpec("N",rex.i)
    If exception.name Then Iterate

    Say "Checking" rex.i"..."
    Say "--> Elements"
    Call ElIdent option rex.i
    If result \== 0 Then Exit 1
    Say "--> Tree"
    Call TrIdent option rex.i
    If result \== 0 Then Exit 1
  End
End

If testGroup Then Do
  Call SysFileTree "*.testgroup", "testgroup", SysFileTreeOptions

  Exception. = 0

  exceptions = "PARSE.testGroup" -- test/trunk

  -- expression=
  exceptions = ""

  Loop word Over exceptions~makeArray(" ")
    exception.word = 1
  End

  Loop i = 1 To testgroup.0
    name = FileSpec("N",testgroup.i)
    If exception.name Then Iterate

    Say "Checking" testgroup.i"..."
    Say "--> Elements"
    Call ElIdent option testgroup.i
    If result \== 0 Then Exit 1
    Say "--> Tree"
    Call TrIdent option testgroup.i
    If result \== 0 Then Exit 1
  End
End

Exit 0

Help:
  Say .Resources[help]
  Exit 1

::Resource Help End "::End"
identtest -- Run identity tests against a collection of files

Usage:
  [rexx] identtest [OPTIONS...]

Options:
  --help         -h -? Display this help
  --executor      -xtr Support Executor syntax
  --testgroup      -tg Analyze .testgroup files
  --noelements     -ne Don't run the elident test
  --notree         -nt Don't run the trident test
  --norexx --norex -nr Don't analyze .rex files
  --nocls          -nc Don't analyze .cls files
::End