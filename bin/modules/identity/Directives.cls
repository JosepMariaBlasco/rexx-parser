/******************************************************************************/
/*                                                                            */
/* Directives.cls -- Clone directives (part of the identity compiler)         */
/* ==================================================================         */
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
/* 20251212         (Executor) Implement the ::EXTENSION directive            */
/*                                                                            */
/******************************************************************************/

  Call "modules/Load.Parser.Module.rex"

  pkgLocal = .context~package~local

  -- Set to 1 to activate debug
  pkgLocal~DEBUG = 0

::Requires "modules/identity/compile.cls"

/******************************************************************************/
/******************************************************************************/
/* DIRECTIVES                                                                 */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/* ANNOTATE DIRECTIVE                                                         */
/******************************************************************************/

::Method "Annotate.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile empty code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* ATTRIBUTE DIRECTIVE                                                        */
/******************************************************************************/

::Method "Attribute.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile possibly empty code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* CLASS DIRECTIVE                                                            */
/******************************************************************************/

::Method "Class.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile empty code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* COACTIVITY DIRECTIVE                                                       */
/******************************************************************************/

::Method "Coactivity.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- No body for ::co

  Return element

/******************************************************************************/
/* CONSTANT DIRECTIVE                                                         */
/******************************************************************************/

::Method "Constant.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End
  element = Clone( element, stream, context )

  -- Clone ignorables
  Do while element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone CONSTANT
  element = Clone( element, stream, context )

  -- Clone ignorables
  Do while element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone constant name
  element = Clone( element, stream, context )

  -- Clone ignorables
  Do while element~ignorable
    element = Clone( element, stream, context )
  End

  Select
    When element < .EL.END_OF_CLAUSE Then Nop
    When element < .ALL.OPS.ADDITIVE Then Do
      -- Clone sign
      element = Clone( element, stream, context )
      -- Clone ignorables
      Do while element~ignorable
        element = Clone( element, stream, context )
      End
      -- Clone integer
      element = Clone( element, stream, context )
      -- Clone ignorables
      Do while element~ignorable
        element = Clone( element, stream, context )
      End
    End
    When element < .EL.LEFT_PARENTHESIS Then Do
      -- Compile (expression)
      element = self~value~compile( element, stream, context )
    End
    Otherwise
      element = Clone( element, stream, context )
  End

  -- Clone ignorables
  Do while element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile empty code body
  element = self~body~compile( element, stream, context )

  Return element


/******************************************************************************/
/* EXTENSION DIRECTIVE                                                        */
/******************************************************************************/

::Method "Extension.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile empty code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* METHOD DIRECTIVE                                                           */
/******************************************************************************/

::Method "Method.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* OPTIONS DIRECTIVE                                                          */
/******************************************************************************/

::Method "Options.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile empty code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* REQUIRES DIRECTIVE                                                         */
/******************************************************************************/

::Method "Requires.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile empty code body
  element = self~body~compile( element, stream, context )

  Return element

/******************************************************************************/
/* RESOURCE DIRECTIVE                                                         */
/******************************************************************************/

::Method "Resource.Directive::compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Now clone until the resource data starts
  Do While element \< .EL.RESOURCE_DATA
    element = Clone( element, stream, context )
  End

  -- Clone the resource data itself
  element = element~compile( element, stream, context )

  -- Now clone the end marker
  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  -- Ignorable stuff until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- An empty code body
  element = self~body~compile( element, stream, context )

  Return element

::Method "Resource.Data::compile"
  Use Strict Arg element, stream, context

  Parse Value self~from With line1 .
  Parse Value self~to   With line2 .
  source = self~source

  Do line = line1 To line2
    stream~Say( source[line] )
  End

  Return element~next

/******************************************************************************/
/* R DIRECTIVE                                                                */
/******************************************************************************/

::Method "R.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Clone everything until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- No body for ::r

  Return element

/******************************************************************************/
/* ROUTINE DIRECTIVE                                                          */
/******************************************************************************/

::Method "Routine.Directive::Compile"
  Use Strict Arg element, stream, context

  -- Clone up to "::"
  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  -- Ignorable stuff until EOC
  Do while element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  -- Compile code body
  element = self~body~compile( element, stream, context )

  Return element
