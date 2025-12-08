/******************************************************************************/
/*                                                                            */
/* Iterations.cls -- DO and LOOP instrs (part of the identity compiler)       */
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
/* 20251120    0.3a First version                                             */
/*                                                                            */
/******************************************************************************/

  Call "modules/Load.Parser.Module.rex"

  pkgLocal = .context~package~local

  -- Set to 1 to activate debug
  pkgLocal~DEBUG = 0

::Requires "modules/identity/compile.cls"

--------------------------------------------------------------------------------
-- Skip over DO/LOOP, and process COUNTER and LABEL phrases                   --
--------------------------------------------------------------------------------

::Routine InitBlock
  Use Strict Arg self, element, stream, context

  -- Skip until DO/LOOP
  element = PrepareClause(element, stream, context)

  -- Clone "DO"/"LOOP"
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Process LABEL and COUNTER phrases, if present
  Loop While element < .EL.SUBKEYWORD, -
    WordPos(element~value,"LABEL COUNTER") > 0
    If element~value == "LABEL" Then
      element = LabelPhrase( element, stream, context )
    Else
      element = CounterPhrase( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- BY PHRASE                                                                  --
--------------------------------------------------------------------------------

::Routine ByPhrase
  Use Strict Arg self, element, stream, context

  -- Clone the "BY" keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile exprb
  element = self~exprb~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- COUNTER PHRASE                                                             --
--------------------------------------------------------------------------------

::Routine CounterPhrase
  Use Strict Arg element, stream, context

  -- element is COUNTER. Clone it
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Now element is the counter
  element = element~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- FOR PHRASE                                                                 --
--------------------------------------------------------------------------------

::Routine ForPhrase
  Use Strict Arg self, element, stream, context

  -- No FOR phrase? Nothing to do
  If self~exprf == .Nil Then Return element

  -- Clone the "FOR" keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile exprf
  element = self~exprf~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- LABEL PHRASE                                                               --
--------------------------------------------------------------------------------

::Routine LabelPhrase
  Use Strict Arg element, stream, context

  -- element is LABEL. Clone it
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Now element is the label
  element = element~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- TO PHRASE                                                                  --
--------------------------------------------------------------------------------

::Routine ToPhrase
  Use Strict Arg self, element, stream, context

  -- Clone the "TO" keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile exprt
  element = self~exprt~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- UNTIL PHRASE                                                               --
--------------------------------------------------------------------------------

::Routine UntilPhrase
  Use Strict Arg self, element, stream, context

  -- No UNTIL phrase? Nothing to do
  If self~expru == .Nil Then Return element

  -- Clone the "UNTIL" keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile expru
  element = self~expru~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- WHILE PHRASE                                                               --
--------------------------------------------------------------------------------

::Routine WhilePhrase
  Use Strict Arg self, element, stream, context

  -- No WHILE phrase? Nothing to do
  If self~exprw == .Nil Then Return element

  -- Clone the "WHILE" keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile exprw
  element = self~exprw~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

--------------------------------------------------------------------------------
-- Controlled DO/LOOP -- Common routine                                       --
--------------------------------------------------------------------------------

::Routine DoLoop.Controlled
  Use Strict Arg self, element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile control variable
  element = element~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Equal sign
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile expri
  element = self~expri~compile( element, stream, context )

  Loop phrase Over self~order~makeArray(" ")
    Select Case phrase
      When "TO"  Then element =  ToPhrase( self, element, stream, context )
      When "BY"  Then element =  ByPhrase( self, element, stream, context )
      When "FOR" Then element = ForPhrase( self, element, stream, context )
    End
  End

  -- Compile WHILE or UNTIL phrases, if present
  element = WhilePhrase( self, element, stream, context )
  element = UntilPhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* CONTROLLED DO CLAUSE                                                       */
/******************************************************************************/

::Method "Do.Controlled.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.Controlled( self, element, stream, context )

  Return element

/******************************************************************************/
/* CONTROLLED LOOP CLAUSE                                                     */
/******************************************************************************/

::Method "Loop.Controlled.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.Controlled( self, element, stream, context )

  Return element

--------------------------------------------------------------------------------
-- DO/LOOP FOREVER -- Common routine                                          --
--------------------------------------------------------------------------------

::Routine DoLoop.Forever
  Use Strict Arg self, element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Skip FOREVER keyword
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile WHILE or UNTIL phrases, if present
  element = WhilePhrase( self, element, stream, context )
  element = UntilPhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* DO FOREVER CLAUSE                                                          */
/******************************************************************************/

::Method "Do.Forever.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.Forever( self, element, stream, context )

  Return element

/******************************************************************************/
/* LOOP FOREVER CLAUSE                                                        */
/******************************************************************************/

::Method "Loop.Forever.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.Forever( self, element, stream, context )

  Return element

--------------------------------------------------------------------------------
-- DO/LOOP OVER -- Common routine                                             --
--------------------------------------------------------------------------------

::Routine DoLoop.Over
  Use Strict Arg self, element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile control variable
  element = element~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone "OVER"
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile collection expression
  element = self~collection~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile FOR, WHILE and UNTIL phrases, if present
  element =   ForPhrase( self, element, stream, context )
  element = WhilePhrase( self, element, stream, context )
  element = UntilPhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* DO OVER CLAUSE                                                             */
/******************************************************************************/

::Method "Do.Over.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.Over( self, element, stream, context )

  Return element

/******************************************************************************/
/* LOOP OVER CLAUSE                                                           */
/******************************************************************************/

::Method "Loop.Over.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.Over( self, element, stream, context )

  Return element

/******************************************************************************/
/* SIMPLE DO CLAUSE                                                           */
/******************************************************************************/

::Method "Simple.Do.Clause::compile"
  Use Strict Arg element, stream, context

  element = InitBlock( self, element, stream, context )

  Return element

/******************************************************************************/
/* SIMPLE LOOP CLAUSE                                                         */
/******************************************************************************/

::Method "Simple.Loop.Clause::compile"
  Use Strict Arg element, stream, context

  element = InitBlock( self, element, stream, context )

  Return element

--------------------------------------------------------------------------------
-- DO/LOOP OVER -- Common routine                                             --
--------------------------------------------------------------------------------

::Routine Simple.Repetitive.DoLoop
  Use Strict Arg self, element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile exprr
  element = self~exprr~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile WHILE or UNTIL phrases, if present
  element = WhilePhrase( self, element, stream, context )
  element = UntilPhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* SIMPLE REPETITIVE DO CLAUSE                                                */
/******************************************************************************/

::Method "Simple.Repetitive.Do.Clause::compile"
  Use Strict Arg element, stream, context

  element = Simple.Repetitive.DoLoop( self, element, stream, context )

  Return element

/******************************************************************************/
/* SIMPLE REPETITIVE LOOP CLAUSE                                              */
/******************************************************************************/

::Method "Simple.Repetitive.Loop.Clause::compile"
  Use Strict Arg element, stream, context

  element = Simple.Repetitive.DoLoop( self, element, stream, context )

  Return element

/******************************************************************************/
/* DO UNTIL CLAUSE                                                            */
/******************************************************************************/

::Method "Do.Until.Clause::compile"
  Use Strict Arg element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile UNTIL phrase
  element = UntilPhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* LOOP UNTIL CLAUSE                                                          */
/******************************************************************************/

::Method "Loop.Until.Clause::compile"
  Use Strict Arg element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile UNTIL phrase
  element = UntilPhrase( self, element, stream, context )

  Return element

--------------------------------------------------------------------------------
-- DO/LOOP WITH -- Common routine                                             --
--------------------------------------------------------------------------------

::Routine DoLoop.With
  Use Strict Arg self, element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Clone WITH
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile ITEM and INDEX phrases
  Loop While element < .EL.SUBKEYWORD, -
    WordPos(element~value,"ITEM INDEX") > 0
    kValue = element~value
    -- Clone subkeyword
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    -- Compile ITEM or INDEX expressions
    If kValue == "ITEM" Then
      element = self~item ~compile( element, stream, context )
    Else
      element = self~index~compile( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  -- Clone OVER
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile supplier
  element = self~supplier~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile FOR phrase, if any
  element = ForPhrase( self, element, stream, context )

  -- Compile WHILE or UNTIL phrases, if present
  element = WhilePhrase( self, element, stream, context )
  element = UntilPhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* DO WITH CLAUSE                                                             */
/******************************************************************************/
::Method "Do.With.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.With( self, element, stream, context )

  Return element

/******************************************************************************/
/* LOOP WITH CLAUSE                                                           */
/******************************************************************************/
::Method "Loop.With.Clause::compile"
  Use Strict Arg element, stream, context

  element = DoLoop.With( self, element, stream, context )

  Return element

/******************************************************************************/
/* DO WHILE CLAUSE                                                            */
/******************************************************************************/

::Method "Do.While.Clause::compile"
  Use Strict Arg element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile WHILE phrase
  element = WhilePhrase( self, element, stream, context )

  Return element

/******************************************************************************/
/* LOOP WHILE CLAUSE                                                          */
/******************************************************************************/

::Method "Loop.While.Clause::compile"
  Use Strict Arg element, stream, context

  element = InitBlock( self, element, stream, context )

  -- Compile WHILE phrase
  element = WhilePhrase( self, element, stream, context )

  Return element
