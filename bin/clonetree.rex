#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* clonetree.rex - Clone a program using the Tree API                         */
/* ==================================================                         */
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
/* 20250707    0.2d First version                                             */
/*                                                                            */
/******************************************************************************/

  Parse Arg filename

  filename = Strip(filename)

  -- Check that our file exists
  If Stream(filename,'c','q exists') == "" Then Do
    Say "File '"filename"' not found."
    Exit 1
  End

  -- We need to compute the source separately to properly handle syntax errors
  source = CharIn(filename,1,Chars(filename))~makeArray
  Call CharOut filename

  -- Parse our program
  parser = .Rexx.Parser~new(filename, source)

  package = parser~package

  element = parser~firstElement
  package~process(element, .Output, .StringTable~new)

  -- We are done
  Exit 0

--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "modules/print/print.cls"  -- Helps in debug
::Requires "modules/clonetree/clonetree.cls"
