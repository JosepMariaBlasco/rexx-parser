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

::Requires "ANSI.ErrorText.cls"
