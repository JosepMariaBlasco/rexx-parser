/******************************************************************************/
/*                                                                            */
/* compile.cls -- Clone a program using the Tree API                          */
/* =================================================                          */
/*                                                                            */
/* This class implements a skeleton identity compiler. It compiles a ooRexx   */
/* program to a perfect copy of itself.                                       */
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
/* 20250707    0.2d First version                                             */
/* 20251102    0.2e Rename to "compile.cls" (was "clonetree")                 */
/*                                                                            */
/******************************************************************************/

  Call "modules/Load.Parser.Module.rex"

  pkgLocal = .context~package~local

  -- Set to 1 to activate debug
  pkgLocal~DEBUG = 0

  -- Elements to skip to get to the beginning of a clause
  pkgLocal~SKIP.BEFORE.CLAUSE =    -
   .EL.END_OF_CLAUSE    ||         -    -- ends Of clauses (implied or not )
   .ALL.WHITESPACE_LIKE ||         -    -- Including continuations
   .ALL.COMMENTS        ||         -    -- Including doc-comments
   .EL.TAKEN_CONSTANT   ||         -    -- Labels
   .EL.COLON                            -- Label colons

/******************************************************************************/
/* CLONE -- Clone a single element                                            */
/******************************************************************************/

::Routine Clone Public
  Use Strict Arg element, stream, context

  -- Inserted elements are zero-length and do not need to be cloned
  If \element~isInserted Then Do
    If element < .ALL.COMMENTS, -- Special case: multi-line block comments
      element~from~word(1) \== element~to~word(1) Then Do
      a = element~source~makeArray
      n = a~items
      Loop Counter c l Over a
        If c < n Then stream~Say(l)
        Else          stream~charOut(l)
      End
    End
    Else stream~charOut( element~source )
  End

  -- Get next element
  next = element~next

  -- Take care of newlines
  If element~to~word(1) \== next~from~word(1) Then stream~Say

  -- Return next element
  Return next

/******************************************************************************/
/* PREPARECLAUSE -- Skip whitespace, end-of-clause, comments and labels       */
/******************************************************************************/

::Routine PrepareClause Public
  Use Strict Arg element, stream, context

  -- Clone initial end-of-clauses, whitespace, comments,
  -- doc-comments and labels
  Do While element < .SKIP.BEFORE.CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* CODE BODIES                                                                */
/******************************************************************************/

::Method "Code.Body::compile"
  Use Strict Arg element, stream, context

  Do instruction Over self~instructions
    element = instruction~compile( element, stream, context )
  End

  Return element

/******************************************************************************/
/* PACKAGES                                                                   */
/******************************************************************************/

::Method "Rexx.Package::compile"
  Use Strict Arg element, stream, context

  element = self~prolog~body~compile( element, stream, context )

  Loop directive Over self~directives
    element = directive~compile( element, stream, context )
  End

  Return element~next

