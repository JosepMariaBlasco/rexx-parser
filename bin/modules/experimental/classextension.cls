/******************************************************************************/
/*                                                                            */
/* ClassExtension.cls -- Implement ::METHO EXTENDS and OVERRIDES              */
/* =============================================================              */
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
/* 20251112    0.3a First version                                             */
/*                                                                            */
/******************************************************************************/

  Call "modules/Load.Parser.Module.rex"

::Requires "modules/compile/compile.cls"

::Method "Method.Directive::Compile"

  Use Strict Arg element, stream, context

  -- No EXTENDS or OVERRIDES? Return the source, unaltered

  If self~extends == .Nil, self~overrides == .Nil Then Do
    element = PrepareClause( element, stream, context )
    Call CloneUntilElementIs .EL.END_OF_CLAUSE
    element = self~body~compile( element, stream, context )
    Return element
  End

  -- EXTENDS or OVERRIDES has been specified

  --
  -- We first compute the new method name as
  --
  --   methodName'<'sep'>'[nameSpace':']classname,
  --
  -- where sep is "+" for EXTENDS, and "*" for OVERRIDES
  --

  extends = self~extends \== .Nil

  If extends Then array = self~extends
  Else            array = self~overrides

  nameSpace = array[1]
  className = array[2]

  If extends Then separator = "<+>"
  Else            separator = "<*>"

  If nameSpace \== .Nil Then
    newName = self~name || separator || nameSpace~value":"className~value
  Else
    newName = self~name || separator || className~value

  newName = '"'ChangeStr('"',newName,'""')'"'

  -- We now carefully clone the directive, subtituting the
  -- method name, and commenting out the EXTENDS or OVERRIDES
  -- phrases.

  element = PrepareClause( element, stream, context )

  -- Look for a method name taken_constant and comment it out
  Call CloneUntilNameIsAndThenCommentOut .METHOD.NAME

  stream~charOut(newName)               -- Insert new name

  -- Clone everything until we find EXTENDS or OVERRIDES
  Loop
    Call CloneUntilElementIs .EL.DIRECTIVE_SUBKEYWORD
  If WordPos(element~value,"EXTENDS OVERRIDES") > 0 Then Leave
    element = Clone( element, stream, context )
  End

  Call CommentOut                       -- Comment out subkeyword

  If nameSpace \== .Nil Then Do
    -- Look for a namespace taken_constant and comment it out
    Call CloneUntilNameIsAndThenCommentOut .NAMESPACE.NAME
    -- Now look for a colon element and comment it out
    Call CloneUntilElementIsAndThenCommentOut .EL.COLON
  End

  -- Look for a class name taken_constant and comment it out
  Call CloneUntilNameIsAndThenCommentOut .CLASS.NAME

  Call CloneUntilElementIs .EL.END_OF_CLAUSE

  element = self~body~compile( element, stream, context )

  Return element

CloneUntilElementIs:
  Do While element \< Arg(1)
    element = Clone( element, stream, context )
  End
Return

CloneUntilElementIsAndThenCommentOut:
  -- Now look for a Arg(1) element...
  Do While element \< Arg(1)
    element = Clone( element, stream, context )
  End
  -- ...and comment it out
  Call CommentOut
Return

CloneUntilNameIsAndThenCommentOut:
  -- Look for an Arg(1) taken_constant...
  Do While element \<< Arg(1)
    element = Clone( element, stream, context )
  End
  -- ...and comment it out
  Call CommentOut
Return

CommentOut:
  stream~charOut("/*")
  element = Clone(element,stream,context)
  stream~charOut("*/")
Return
