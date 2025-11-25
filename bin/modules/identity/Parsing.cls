/******************************************************************************/
/*                                                                            */
/* Parsing.cls -- Parse-related instructions (part of the identity compiler)  */
/* =========================================================================  */
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
/* 20251119    0.3a First version                                             */
/*                                                                            */
/******************************************************************************/

  Call "modules/Load.Parser.Module.rex"

  pkgLocal = .context~package~local

  -- Set to 1 to activate debug
  pkgLocal~DEBUG = 0

::Requires "modules/identity/compile.cls"

/******************************************************************************/
/* ARG INSTRUCTIONS                                                           */
/******************************************************************************/

::Method "Arg.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for ARG keyword
  element = PrepareClause( element, stream, context )

  -- Skip ARG
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  -- Compile templates
  element = self~templates~compile( element, stream, context )

  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* PARSE INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Parse.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for PARSE keyword
  element = PrepareClause( element, stream, context )

  -- Skip PARSE
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  Loop While WordPos(element~value, "UPPER LOWER CASELESS") > 0
    -- Skip subkeyword
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
  End

  -- Skip variant subkeyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  If self~variant == "VAR" Then Do
    -- Compile varname
    element = self~varname~compile( element, stream, context )
    -- Skip ignorables
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
  End
  Else If self~variant == "VALUE" Then Do
    -- Compile expression
    element = self~expression~compile( element, stream, context )
    -- Skip ignorables
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    -- Skip WITH
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
  End

  -- Compile templates
  element = self~templates~compile( element, stream, context )

  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* ARG INSTRUCTIONS                                                           */
/******************************************************************************/

::Method "Pull.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for PULL keyword
  element = PrepareClause( element, stream, context )

  -- Skip PULL
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  -- Compile templates
  element = self~templates~compile( element, stream, context )

  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* TEMPLATE LIST                                                              */
/******************************************************************************/

::Method "Template.List::Compile"
  Use Arg element, stream, context

  nTemplates = self~items
  Loop Counter c template Over self
    -- Skip ignorables
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    If template \== .Nil Then Do
      element = template~compile( element, stream, context )
      -- Skip ignorables
      Loop While element~isIgnorable
        element = Clone( element, stream, context )
      End
    End
    If c < nTemplates Then Do
      -- Skip comma
      element = Clone( element, stream, context )
      -- Skip ignorables
      Loop While element~isIgnorable
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* TEMPLATE                                                                   */
/******************************************************************************/

::Method "Template::Compile"
  Use Arg element, stream, context

  nComponents = self~items
  Loop Counter c component Over self
    -- Skip ignorables
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    element = component~compile( element, stream, context )
  End

  Return element

/******************************************************************************/
/* PREFIXED TEMPLATE                                                          */
/******************************************************************************/

::Method "Prefixed.Template::Compile"
  Use Arg element, stream, context

  -- Skip ignorables until prefix
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  -- Clone prefix
  element = Clone( element, stream, context )

  -- Skip ignorables again
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  element = self~elementOrSubExpression~compile( element, stream, context )

  Return element
