#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2026 Rexx Language Association. All rights reserved.         */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/

--------------------------------------------------------------------------------
--
-- Generate individual SVG railroad diagrams from an EBNF grammar
-- file.  Runs the Railroad Diagram Generator (rr.war) to produce
-- an XHTML file with embedded SVGs, then calls
-- extract_svg_from_rr_xhtml.rex to extract them.
--
-- Requirements:
--   - Java 11+ on the PATH
--   - rr.war in the same directory as this script (or use --rr)
--   - extract_svg_from_rr_xhtml.rex accessible via standard Rexx
--     search order
--
-- Usage:
--   rexx ebnf2svg.rex [--rr path/to/rr.war] <grammar>
--
-- The generated SVG files are placed in the same directory as
-- the EBNF file.
--
-- Changes:
--   - 20260317: first version
--
--------------------------------------------------------------------------------

  Signal On Syntax

  Parse Source . . myPath
  myName = FileSpec("name", myPath)
  myDir  = FileSpec("location", myPath)

  If myName~caselessEndsWith(".rex") Then
    myName = Left(myName,Length(myName)-4)

  Parse Arg args

  /* Parse options */
  rrWar = ""
  ebnfFile = ""
  Do While args \= ""
    Parse Var args word args
    Select Case word
      When "--rr" Then Do
        Parse Var args rrWar args
        If rrWar = "" Then Do
         .error~say(myName": --rr requires a path argument.")
          Exit 1
        End
      End
      When "--help", "-h" Then Signal Help
      Otherwise Do
        ebnfFile = word
        Leave
      End
    End
  End

  If ebnfFile = "" Then Signal Help

  ebnfFile = ebnfFile".ebnf"

/*-- Validate the EBNF file -----------------------------------------------*/

  ebnfFile = ebnfFile~strip
  If \SysFileExists(ebnfFile) Then Do
   .error~say(myName": EBNF file '"ebnfFile"' not found.")
    Exit 1
  End

  qualifiedEbnf = Qualify(ebnfFile)
  ebnfDir = FileSpec("location", qualifiedEbnf)

  Say myName": Processing '"qualifiedEbnf"'..."

/*-- Locate rr.war ---------------------------------------------------------*/

  If rrWar = "" Then
    rrWar = myDir"rr.war"

  If \SysFileExists(rrWar) Then Do
    .error~say(myName": rr.war not found: '"rrWar"'.")
    .error~say(myName": Use --rr to specify" -
      "the path, or place rr.war next to" myName || ".")
    Exit 1
  End

/*-- Check that Java is available ------------------------------------------*/

  discard = .array~new
  Address System "java -version" -
    With Output Using (discard) Error Using (discard)
  If rc \= 0 Then Do
    .error~say(myName": Java not found." -
      "Please install Java 11+ and add it to the PATH.")
    Exit 1
  End

/*-- Run rr.war to generate the XHTML with embedded SVGs -------------------*/

  /* Temporary XHTML filename in the EBNF directory */
  xhtmlFile = SysTempFilename(ebnfDir"ebnf2svg_temp_????.xhtml")
  If xhtmlFile == "" Then Do
   .error~say(myName": Could not create temporary filename in '"ebnfDir"'.")
    Exit 1
  End

  /* Fixed options:                                   */
  /*   -suppressebnf  No EBNF next to diagrams        */
  /*   -noinline      No inlining of single literals  */
  cmd = 'java -jar "'rrWar'"'                        -
        '-suppressebnf -noinline'                    -
        '-out:"'xhtmlFile'"'                         -
        '"'qualifiedEbnf'"'

  Say myName": Running Railroad Diagram Generator..."
  output = .array~new
  errors = .array~new
  Address System cmd With Output Using (output) Error Using (errors)

  If rc \= 0 Then Do
   .error~say(myName": rr.war returned RC ="rc)
    Do line Over errors
     .error~say("  " line)
    End
    Call Cleanup
    Exit 1
  End

  If \SysFileExists(xhtmlFile) Then Do
   .error~say(myName": rr.war did not produce utput file '"xhtmlFile"'.")
    Call Cleanup
    Exit 1
  End

  Say myName": Generated XHTML with embedded SVGs."

/*-- Run extract_svg_from_rr_xhtml.rex to extract the individual SVGs ------*/

  Say myName": Extracting individual SVG files..."
  Call extract_svg_from_rr_xhtml.rex xhtmlFile

/*-- Clean up and report ---------------------------------------------------*/

  Call Cleanup
  Say myName": Done. SVG files are in '"ebnfDir"'."
  Exit 0

/*-- Cleanup: remove the temporary XHTML file ------------------------------*/

Cleanup:
  If xhtmlFile \= "" Then
    Call SysFileDelete xhtmlFile
  Return

/*-- Help ------------------------------------------------------------------*/

Help:
  Say .resources~help~makeString~changeStr("myName", myName)
  Exit 0

/*-- Syntax error handler --------------------------------------------------*/

Syntax:
  co = Condition("O")
  code = co~code
  line = co~position
 .error~say(myName": SYNTAX error" code "at line" line":" co~errorText)
 .error~say(myName":" co~message)
  Exit - co~rc

/*--------------------------------------------------------------------------*/

::Resource help
myName - Generate railroad diagram SVGs from an EBNF grammar

Usage: [rexx] myName [--rr path/to/rr.war] <grammar>

An extension of .ebnf is automatically added to <grammar>.

Options:
  --rr <path>    Path to rr.war (default: same directory as myName)
  --help, -h     Show this help

Requirements:
  - Java 11+ on the PATH
  - rr.war (see https://www.bottlecaps.de/rr)
  - extract_svg_from_rr_xhtml.rex accessible via standard Rexx
    search order

Fixed rr.war options:
  -suppressebnf    Do not show EBNF next to diagrams
  -noinline        Do not inline single-literal productions

Output:
  SVG files are placed in the same directory as the EBNF file.
::END