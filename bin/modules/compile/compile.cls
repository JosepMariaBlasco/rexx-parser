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
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
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
/* CLAUSES                                                                    */
/******************************************************************************/

::Method "Rexx.Clause::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause(element, stream, context)

  -- We simply clone all elements until we find the next EOC marker

  Do Until element < .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  If .DEBUG Then Do Label Debug
    Select Case self~class
      When .Else.Clause, -
        .End.Clause, -
        .If.Clause, -
        .Otherwise.Clause, -
        .Select.Clause, -
        .Then.clause,-
        .When.Clause Then Nop
      Otherwise
        Say "Unexpected clause class" self~class
        Trace ?a
        Nop
    End
  End Debug

  Return element

::Method "Do.Clause::compile" -- Do.Clause and all its subclasses
  Use Strict Arg element, stream, context

  element = PrepareClause(element, stream, context)

  Do Until element < .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "Loop.Clause::compile" -- Loop.Clause and all its subclasses
  Use Strict Arg element, stream, context

  element = PrepareClause(element, stream, context)

  Do Until element < .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* INSTRUCTIONS                                                               */
/******************************************************************************/

::Method "Rexx.Instruction::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause( element, stream, context )

  if .DEBUG Then Do Label Debug
    Select Case self~class
      When .Say.Instruction, -
        .Arg.Instruction, -
        .Assignment.Instruction, -
        .Call.Instruction, -
        .Call.Off.Instruction, -
        .Call.On.Instruction, -
        .Call.Value.Instruction, -
        .Command.Instruction, -
        .Drop.Instruction, -
        .Exit.Instruction, -
        .Expose.Instruction, -
        .Implicit.Exit.Instruction, -
        .Interpret.Instruction, -
        .Iterate.Instruction, -
        .Leave.Instruction, -
        .Message.Assignment.Instruction, -
        .Message.Instruction, -
        .Nop.Instruction, -
        .Parse.Instruction, -
        .Procedure.Instruction, -
        .Raise.Instruction, -
        .Return.Instruction, -
        .Signal.Instruction, -
        .Signal.Off.Instruction, -
        .Signal.On.Instruction, -
        .Signal.Value.Instruction, -
        .Use.Arg.Instruction, -
        .Use.Local.Instruction -
        Then Nop
      Otherwise
        Say "Unexpected instruction class:" self~class
        Trace ?a
        Nop
    End
  End Debug

  Do Until element < .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "If.Instruction::compile"
  Use Strict Arg element, stream, context

  -- If.Clause will call PrepareClause

  element = self~ifClause         ~compile( element, stream, context )
  element = self~thenClause       ~compile( element, stream, context )
  element = self~thenInstruction  ~compile( element, stream, context )

  elseClause = self~elseClause
  If elseClause \== .Nil Then Do
    element = elseClause          ~compile( element, stream, context )
    element = self~elseInstruction~compile( element, stream, context )
  End

  Return element

::Method "Select.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Select.Clause will call PrepareClause

  element = self~selectClause~compile( element, stream, context )

  Do WhenThenInstruction Over self~whenThenInstructions
    whenClause      = WhenThenInstruction[1]
    thenClause      = WhenThenInstruction[2]
    thenInstruction = WhenThenInstruction[3]

    element         = whenClause~compile(      element, stream, context )
    element         = thenClause~compile(      element, stream, context )
    element         = thenInstruction~compile( element, stream, context )
  End

  otherwiseClause = self~otherwiseClause
  If otherwiseClause \== .Nil Then Do
    element = otherwiseClause~compile( element, stream, context )

    Do instruction Over self~otherwiseSequence
      element = instruction~compile(   element, stream, context )
    End
  End

  element = self~endClause~compile(    element, stream, context )

  Return element

::Method "Do.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Do.Clause will call PrepareClause

  element = self~doClause~compile( element, stream, context )

  Loop instruction Over self~instructions
    element = instruction~compile( element, stream, context )
  End

  element = self~endClause~compile( element, stream, context )

  Return element

::Method "Loop.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Loop.Clause will call PrepareClause

  element = self~loopClause~compile( element, stream, context )

  Loop instruction Over self~instructions
    element = instruction~compile( element, stream, context )
  End

  element = self~endClause~compile( element, stream, context )

  Return element

/******************************************************************************/
/* DIRECTIVES                                                                 */
/******************************************************************************/

::Method "Rexx.Directive::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause( element, stream, context )

  If .DEBUG Then Do Label Debug
    Select Case self~class
      When .Annotate.Directive, -
        .Attribute.Directive, -
        .Class.Directive, -
        .Constant.Directive, -
        .Method.Directive, -
        .Options.Directive, -
        .Requires.Directive, -
        .Routine.Directive -
        Then Nop
      Otherwise
        Say "Unexpeted directive class:" self~class
        Trace ?a
        Nop
    End
  End

  Do Until element < .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  element = self~body~compile( element, stream, context )

  Return element

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

