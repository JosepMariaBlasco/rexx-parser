/******************************************************************************/
/*                                                                            */
/* Clauses.cls -- Clone clauses (part of the identity compiler)               */
/* ============================================================               */
/*                                                                            */
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
/* 20251116    0.3a First version                                             */
/*                                                                            */
/******************************************************************************/

  Call "modules/Load.Parser.Module.rex"

  pkgLocal = .context~package~local

  -- Set to 1 to activate debug
  pkgLocal~DEBUG = 0

::Requires "modules/identity/compile.cls"

/******************************************************************************/
/* CLAUSES                                                                    */
/******************************************************************************/

::Method "Else.Clause::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause(element, stream, context)

  element = Clone( element, stream, context )

  Return element

::Method "End.Clause::compile"
  Use Strict Arg element, stream, context

  -- Look for END keyword
  element = PrepareClause(element, stream, context)

  -- Clone everything until EOC
  Do Until element < .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "If.Clause::compile"
  Use Strict Arg element, stream, context

  -- Look for IF keyword
  element = PrepareClause(element, stream, context)

  -- Clone IF keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile the expressions
  element = self~expressions~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

::Method "Otherwise.Clause::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause(element, stream, context)

  element = Clone( element, stream, context )

  Return element

::Method "Select.Clause::compile"
  Use Strict Arg element, stream, context

  -- Look for SELECT keyword
  element = PrepareClause(element, stream, context)

  If self~case \== .Nil Then Do
    -- Look for CASE keyword
    Loop Until element <.EL.SUBKEYWORD, element~value == "CASE"
      element = Clone( element, stream, context )
    End
    -- Skip it
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    element = self~case~compile( element, stream, context )
  End

  -- Clone everything until EOC
  Do While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "Then.Clause::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause(element, stream, context)

  element = Clone( element, stream, context )

  Return element

::Method "When.Clause::compile"
  Use Strict Arg element, stream, context

  -- Look for WHEN keyword
  element = PrepareClause(element, stream, context)

  -- Clone WHEN keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile the expressions
  element = self~expressions~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element
