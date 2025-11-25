/******************************************************************************/
/*                                                                            */
/* Expressions.cls -- Clone expressions (part of the identity compiler)       */
/* ====================================================================       */
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
/* ADDITION EXPRESSIONS                                                       */
/******************************************************************************/

::Method "Addition.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is an addition operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* AND EXPRESSIONS                                                            */
/******************************************************************************/

::Method "And.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is an and operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* ARRAY TERMS                                                                */
/******************************************************************************/

::Method "Array.Term::Compile"
  Use Strict Arg element, stream, context

  Return self~expression_list~compile( element, stream, context )

/******************************************************************************/
/* COMPOUND VARIABLE TERMS                                                    */
/******************************************************************************/

::Method "Compound.Variable.Term::Compile"
  Use Strict Arg element, stream, context

  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* COMPARISON EXPRESSIONS                                                     */
/******************************************************************************/

::Method "Comparison.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is a comparison operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* CONCATENATION EXPRESSIONS                                                  */
/******************************************************************************/

::Method "Concatenation.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is a concatenation operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* EXPRESSION LISTS                                                           */
/******************************************************************************/

::Method "Expression.List::Compile"
  Use Strict Arg element, stream, context

  If self~isEmpty Then Return element

  Loop arg Over self~args
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    If arg~isA( .Special.Character.Sequence ) Then
      element = Clone( element, stream, context )
    Else element = arg~compile( element, stream, context )
  End

  Return element

/******************************************************************************/
/* FUNCTION CALL TERMS                                                        */
/******************************************************************************/

::Method "Function.Call.Term::Compile"
  Use Strict Arg element, stream, context

  name         = self~name
  argumentList = self~argumentList

  -- Name
  element = name~compile( element, stream, context )
  -- "("
  element = Clone( element, stream, context )
  -- Ignorable stuff
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End
  -- Argument list
  element = argumentList~compile( element, stream, context )
  -- More ignorable stuff
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End
  -- ")"
  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* INDEXED OR INVOKED TERMS                                                   */
/******************************************************************************/

::Method "Indexed.Or.Invoked.Term::Compile"
  Use Strict Arg element, stream, context

  term      = self~term
  bracket   = self~bracket
  arguments = self~arguments

  -- term
  element = term~compile( element, stream, context )
  -- Left bracket
  element = Clone( element, stream, context )
  -- Arguments
  element = arguments~compile( element, stream, context )
  -- Right bracket
  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* LITERAL STRING TERMS                                                       */
/******************************************************************************/

::Method "Literal.String.Term::Compile"
  Use Strict Arg element, stream, context

  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* MESSAGE TERMS                                                              */
/******************************************************************************/

::Method "Message.Term::Compile"
  Use Strict Arg element, stream, context

  term        = self~term
  messageName = self~messageName
  scope       = self~scope
  arguments   = self~arguments

  element = term~compile( element, stream, context )

  Loop While element \== messageName
    element = Clone( element, stream, context )
  End

  element = messageName~compile( element, stream, context )

  If scope \== .Nil Then Do
    Loop While element \< .EL.COLON
      element = Clone( element, stream, context )
    End
    element = Clone( element, stream, context )
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    element = scope~compile( element, stream, context )
  End

  If element < .EL.LEFT_PARENTHESIS Then Do
    element = Clone( element, stream, context )
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    element = arguments~compile( element, stream, context )
    Loop While element~isIgnorable
      element = Clone( element, stream, context )
    End
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* MULTIPLICATION EXPRESSIONS                                                 */
/******************************************************************************/

::Method "Multiplication.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is a multiplication operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* OR EXPRESSIONS                                                             */
/******************************************************************************/

::Method "Or.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is a or operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* POWER EXPRESSIONS                                                          */
/******************************************************************************/

::Method "Power.Expression::Compile"
  Use Strict Arg element, stream, context

  args  = self~args
  nArgs = args~items

  Loop i = 1 By 2 To nArgs
    -- Compile args[i]
    element = args[i]~compile( element, stream, context )
    -- Now if i < nArgs, args[i+1] is a power operator
    If i < nArgs Then Do
      -- Clone everything until the start of the next argument
      begin = args[i+2]~begin
      Loop While element \== begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* PREFIX EXPRESSIONS                                                         */
/******************************************************************************/

::Method "Prefix.Expression::Compile"
  Use Strict Arg element, stream, context

  term  = self~term
  begin = term~begin

  -- Skip over prefixes
  Loop While element \== begin
    element = Clone( element, stream, context )
  End

  element = term~compile( element, stream, context )

  Return element

/******************************************************************************/
/* STEM VARIABLE TERMS                                                        */
/******************************************************************************/

::Method "Stem.Variable.Term::Compile"
  Use Strict Arg element, stream, context

  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* STRING OR SYMBOL ELEMENTS                                                  */
/******************************************************************************/

::Method "StringOrSymbol.Element::Compile"
  Use Strict Arg element, stream, context

  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* SUBEXPRESSIONS                                                             */
/******************************************************************************/

::Method "SubExpression::Compile"
  Use Strict Arg element, stream, context

  subExpression = self~subExpression

  -- "("
  element = Clone( element, stream, context )

  -- Skip until the subexpression proper begins
  begin = subExpression~begin
  Loop While element \== begin
    element = Clone( element, stream, context )
  End

  -- Compile the subexpression
  element = subExpression~compile( element, stream, context )

  -- Skip until ")"
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  -- ")"
  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* SYMBOL TERMS                                                               */
/******************************************************************************/

::Method "Symbol.Term::Compile"
  Use Strict Arg element, stream, context

  element = Clone( element, stream, context )

  Return element

/******************************************************************************/
/* VARIABLE REFERENCE TERMS                                                   */
/******************************************************************************/

::Method "Variable.Reference.Term::Compile"
  Use Strict Arg element, stream, context

  -- Clone the operator
  element = Clone( element, stream, context )

  -- Skip all ignorables until we find the variable
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End

  -- Clone the variable
  element = Clone( element, stream, context )

  Return element
