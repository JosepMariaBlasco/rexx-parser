#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* xtrtest.rex - Test all cls and rex programs in the Executor tree           */
/* ================================================================           */
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
/*                                                                            */
/******************************************************************************/

-- xtrtest
--
-- Usage: cd to a directory in the Executor tree and run it
--
-- The script will stop when an error is encountered
--
-- See the list of exceptions below
--

Call SysFileTree "*.cls",cls, so

Exception. = 0

-- Add exceptions here

Loop i = 1 To cls.0
  name = FileSpec("N",cls.i)
  If exception.name Then Iterate

  Say "Checking" cls.i"..."
  Say "--> Elements"
  Call ElIdent "-xtr" cls.i
  If result \== 0 Then Exit 1
  Say "--> Tree"
  Call TrIdent "-xtr" cls.i
  If result \== 0 Then Exit 1
End

Call SysFileTree "*.rex",rex, so

Exception. = 0

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

Loop word Over exceptions~makeArray(" ")
  exception.word = 1
End

Loop i = 1 To rex.0
  name = FileSpec("N",rex.i)
  If exception.name Then Iterate

  Say "Checking" rex.i"..."
  Say "--> Elements"
  Call ElIdent "-xtr" rex.i
  If result \== 0 Then Exit 1
  Say "--> Tree"
  Call TrIdent "-xtr" rex.i
  If result \== 0 Then Exit 1
End