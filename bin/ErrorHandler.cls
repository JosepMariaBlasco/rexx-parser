/******************************************************************************/
/*                                                                            */
/* ErrorHandler.cls -- Common error handler routine                           */
/* ================================================                           */
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
/* 20251221    0.4a  First public release                                     */
/* 20251226          Send error messages to .error, not .output               */
/* 20260313    0.5   Add ReportParseError for pipeline error handling         */
/*                                                                            */
/******************************************************************************/


/******************************************************************************/
/*                                                                            */
/* ErrorHandler(name, source, co, itrace) -- Standard error handler           */
/*                                                                            */
/* For use by standalone utilities (rxcheck, highlight, etc.).                */
/* Displays the error and exits with -major, following the ooRexx convention. */
/*                                                                            */
/* Usage: Exit ErrorHandler( ... )                                            */
/*                                                                            */
/******************************************************************************/

::Routine ErrorHandler Public
  Use Strict Arg name, source, co, itrace
  additional = co~additional
  section = additional~section(2)
  extra = Additional~lastItem
  line  = extra~position
  code  = extra~code
  Parse Var code major"."minor
 .Error~Say(  Right(line,6) "*-*" source[line]                         )
 .Error~Say( "Error" major "in" name", line" line": " ErrorText(major) )
 .Error~Say( "Error" code": " Ansi.ErrorText( code, section )          )

  If itrace Then Do
   .Error~Say
   .Error~Say( "Trace follows:"         )
   .Error~Say( Copies("-",80)           )
   .Error~Say( co~stackFrames~makeArray )
  End

  Exit - major


/******************************************************************************/
/*                                                                            */
/* IsAParseError(co, additional, itrace) -- Pipeline error handler            */
/*                                                                            */
/* For use by the RexxPub pipelines (CGI, md2pdf, md2html), where the         */
/* caller needs to retain control after the error (e.g. to continue in        */
/* batch mode).                                                               */
/*                                                                            */
/* Usage:                                                                     */
/*    If IsAParseError( ... ) Then Raise Propagate -- Application error       */
/*    -- Error already handled                                                */
/*                                                                            */
/* Unlike ErrorHandler, this routine is not designed to exit immediately      */
/* after calling it. It reports the error and returns 1 if the error was      */
/* handled, or 0 if the caller should propagate it (because the condition     */
/* object is not a FencedCode error).                                         */
/*                                                                            */
/******************************************************************************/

::Routine IsAParseError Public
  Use Strict Arg co, itrace

  additional = co~additional

  extra = additional~lastitem
  If \extra~hasMethod("position") Then Return 0

  line  = extra~position
  Parse Value co~code With major"."minor
 .Error~Say( Right(line,6) "*-*" extra~sourceline                            )
   -- Try to reconstruct the line number if we have enough information
  name = extra~name
  majorMessagePrinted = 0
  If Right(name,1) == "]" Then Do
    Parse Var name name1" [lines "start"-"end"]"
    If name == name1" [lines "start"-"end"]" Then Do
      majorMessagePrinted = 1
     .Error~Say( "Error" major "in" name1", line" (start+line)": " ErrorText(major) )
    End
  End
  If \majorMessagePrinted Then
   .Error~Say( "Error" major "in" extra~name", line" line": " ErrorText(major) )
 .Error~Say( "Error" co~code": " Ansi.ErrorText( co~code, additional )       )

  If itrace Then Do
   .Error~Say
   .Error~Say( "Trace follows:"         )
   .Error~Say( Copies("-",80)           )
   .Error~Say( co~stackFrames~makeArray )
  End

  Return 1

::Requires "ANSI.ErrorText.cls"
