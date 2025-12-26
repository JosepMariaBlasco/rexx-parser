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
/* 20251221         Add --itrace option, improve error messages               */
/* 20251226         Send error messages to .error, not .output                */
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
itrace    = 0

executor  = 0

Loop option Over args~makeArray(" ")
  Select Case option
    When "--help", "-h",         "-?" Then Signal Help
    When "--itrace",            "-it" Then itrace = 1
    When "--executor",         "-xtr" Then executor  = 1
    When "--noelements",        "-ne" Then elements  = 0
    When "--notree",            "-nt" Then tree      = 0
    Otherwise Do
     .Error~Say( "Invalid option '"option"'." )
      Exit 1
    End
  End
End

If Executor Then option = "-xtr"
Else             option = ""

cd = Directory()~changeStr("\","/")

extensions = "cls rex testgroup jrexx oodTestGroup rxj rxo testUnit rxu"

exception. = 0

-- Exceptions for .rex
----------------------

-- The following exceptions are tailored to the Executor tree.

-- expression=
exceptions = "executor-demo-array.rex executor-demo-extensions.rex"            -
  "executor-demo-text-compatibility-auto-conv.rex"                             -
  "executor-demo-text-compatibility.rex executor-demo-text-internal_checks.rex"-
  "executor-demo-text-unicode.rex executor-demo-text.rex"                      -
  "ooRexxShell-demo-interpreters.rex ooRexxShell-demo-queries.rex"             -
  "diary_examples.rex include_concatenation_infos.rex"                         -
  "include_concatenation_infos.rex include_conversion.rex"                     -
  "include_conversion_infos.rex"

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

extension = "REX"

Loop filename Over exceptions~makeArray(" ")
  exception.extension.filename = 1
End

-- Exceptions for .testgroup
----------------------

exceptions = "PARSE.testGroup"

extension = "TESTGROUP"

Loop filename Over exceptions~makeArray(" ")
  exception.extension.filename = 1
End

-- Exceptions for .rxj
----------------------

exceptions = "swing_buttons1.rxj swing_buttons2.rxj" -- Real error, invalid template

extension = "RXJ"

Loop filename Over exceptions~makeArray(" ")
  exception.extension.filename = 1
End

Loop extension Over extensions~makeArray(" ")
  extension = Upper(extension)
  Call SysFileTree "*."extension, "TREE", SysFileTreeOptions
  If extension == "RXU" Then options? = "-u" option
  Else options? = option
  options? = Strip(options?)
  If itrace Then options? = "-it" options?
  options? = Strip(options?)
  Loop i = 1 To tree.0
    name = FileSpec("N",tree.i)
    If exception.extension.name Then Iterate

    Say "Checking" tree.i"..."
    Say "--> Elements"
    Call ElIdent options? tree.i
    If result \== 0 Then Exit 1
    Say "--> Tree"
    Call TrIdent options? tree.i
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
  --help,          -h -? Display this help
  --executor,       -xtr Support Executor syntax
  --itrace,          -it Print internal traceback on error
  --noelements,      -ne Don't run the elident test
  --notree,          -nt Don't run the trident test
::End