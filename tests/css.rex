/******************************************************************************/
/*                                                                            */
/* css.rex - Test the stylesheet routines                                     */
/* ======================================                                     */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
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
/* 20250626    0.2d First version                                             */
/*                                                                            */
/******************************************************************************/

Parse Source . . myself
sep = .File~separator
stylesheet = Left(myself, LastPos(sep,myself))"rexx-test.css"

Call Check "a1", "- - - ff0000ff:"

Say GetHighlight(stylesheet,"a1")
Say GetHighlight(stylesheet,"a2")
Exit 0

Check:
  If GetHighlight(stylesheet,Arg(1)) == Arg(2) Then Return
  got = GetHighlight(stylesheet,Arg(1))
  Say "Expecting GetHighlight('"Arg(1)"') = '"Arg(2)"', got '"got"'."
  Exit 100

::Requires "Rexx.Parser.cls"