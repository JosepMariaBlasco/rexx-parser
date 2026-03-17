/******************************************************************************/
/*                                                                            */
/* ParserTestCase.cls - ooTestCase subclass for parser agreement tests        */
/* ==================================================================         */
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
/* 20260316    0.5  First version                                             */
/*                                                                            */
/******************************************************************************/

::Requires "ooTest.frm"
::Requires "Rexx.Parser.cls"
::Requires "ANSI.ErrorText.cls"

::Class ParserTestCase Subclass ooTestCase Public

/******************************************************************************/
/* parserError: verify that source produces a specific SYNTAX error, and      */
/* that the ooRexx interpreter and the Rexx Parser agree on error code        */
/* and message.                                                               */
/******************************************************************************/

::Method parserError
  Use Strict Arg code, source

  Parse Var code major"."minor
  major = major + 0
  minor = minor + 0
  If source~isA(.Array) Then
    label = code":" source[1]~substr(1, min(50, source[1]~length))~strip
  Else
    label = code":" source~substr(1, min(50, source~length))~strip

  options = .Array~of( (earlyCheck, (BIFs, SIGNAL, GUARD, LEAVE, ITERATE)) )

  -- Step 1: Check the ooRexx interpreter
  Signal On Syntax Name InterpreterTrapped
  .Package~new("Compiled", source)

  -- Interpreter did NOT trap — fail
  self~assertTrue(.False, label "— Expected SYNTAX" code "from interpreter")
  Return

InterpreterTrapped:
  co                    = Condition("O")
  interpreterCode       = co~code
  interpreterMessage    = co~message
  interpreterAdditional = co~additional

  -- Step 2: Check the Rexx Parser
  Signal On Syntax Name ParserTrapped
  .Rexx.Parser~new("", source, options)~package

  -- Parser did NOT trap — fail
  self~assertTrue(.False, label "— Expected SYNTAX" code "from parser")
  Return

ParserTrapped:
  co = Condition("O")

  If co~code \== 98.900 Then Do
    self~assertTrue(.False, -
      label "— Parser raised unexpected error" co~code":" co~errorText)
    Return
  End

  parserCode       = co~additional~lastItem~code
  parserAdditional = co~additional~lastItem~additional

  -- Check that both agree on the error code
  If interpreterCode \== parserCode Then Do
    self~assertTrue(.False, -
      label "— Codes differ: interpreter=" interpreterCode "parser=" parserCode)
    Return
  End

  -- Check that the code matches what was expected
  If parserCode \== major"."minor Then Do
    self~assertTrue(.False, -
      label "— Expected" major"."minor "got" parserCode)
    Return
  End

  -- Check that additional information matches
  If parserAdditional~items \== interpreterAdditional~items Then Do
    self~assertTrue(.False, -
      label "— Additional arrays differ:" -
      "interpreter=" interpreterAdditional~items -
      "parser=" parserAdditional~items)
    Return
  End

  -- Reconstruct parser message and compare
  message = ANSI.ErrorText(major"."minor, parserAdditional)
  If message \== interpreterMessage Then Do
    self~assertTrue(.False, -
      label "— Messages differ: interpreter='" || interpreterMessage || -
      "' parser='" || message || "'")
    Return
  End

  -- All checks passed
  self~assertTrue(.True, label)

/******************************************************************************/
/* parserOK: verify that source compiles without error on both interpreter    */
/* and parser.                                                                */
/******************************************************************************/

::Method parserOK
  Use Strict Arg source, label = .Nil

  If label == .Nil Then Do
    If source~isA(.Array) Then
      label = "OK:" source[1]~substr(1, min(50, source[1]~length))~strip
    Else
      label = "OK:" source~substr(1, min(50, source~length))~strip
  End

  options = .Array~of( (earlyCheck, (BIFs, SIGNAL, GUARD, LEAVE, ITERATE)) )

  -- Step 1: Check the ooRexx interpreter
  Signal On Syntax Name InterpreterFailed
  .Package~new("Compiled", source)
  Signal ParserCheck

InterpreterFailed:
  co = Condition("O")
  self~assertTrue(.False, -
    label "— Interpreter raised SYNTAX" co~code":" co~message)
  Return

ParserCheck:
  -- Step 2: Check the Rexx Parser
  Signal On Syntax Name ParserFailed
  .Rexx.Parser~new("", source, options)~package

  -- Both OK
  self~assertTrue(.True, label)
  Return

ParserFailed:
  co = Condition("O")
  If co~code == 98.900 Then Do
    additional = co~additional~lastItem
    self~assertTrue(.False, -
      label "— Parser raised SYNTAX" additional~code":" -
      ANSI.ErrorText(additional~code, additional~additional))
  End
  Else
    self~assertTrue(.False, -
      label "— Parser raised unexpected error" co~code":" co~errorText)

/******************************************************************************/
/* parserOnly: verify that source parses without error (parser only, no       */
/* interpreter check). Use for regression tests where the code cannot be      */
/* executed (e.g., references to uninitialized variables, infinite loops,     */
/* interactive trace).                                                        */
/******************************************************************************/

::Method parserOnly
  Use Strict Arg source, label = .Nil

  If label == .Nil Then Do
    If source~isA(.Array) Then
      label = "OK:" source[1]~substr(1, min(50, source[1]~length))~strip
    Else
      label = "OK:" source~substr(1, min(50, source~length))~strip
  End

  options = .Array~of( (earlyCheck, (BIFs, SIGNAL, GUARD, LEAVE, ITERATE)) )

  Signal On Syntax Name ParserFailed
  .Rexx.Parser~new("", source, options)~package

  self~assertTrue(.True, label)
  Return

ParserFailed:
  co = Condition("O")
  If co~code == 98.900 Then Do
    additional = co~additional~lastItem
    self~assertTrue(.False, -
      label "— Parser raised SYNTAX" additional~code":" -
      ANSI.ErrorText(additional~code, additional~additional))
  End
  Else
    self~assertTrue(.False, -
      label "— Parser raised unexpected error" co~code":" co~errorText)