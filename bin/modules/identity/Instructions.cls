/******************************************************************************/
/*                                                                            */
/* Instructions.cls -- Clone instructions (part of the identity compiler)     */
/* ======================================================================     */
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
/******************************************************************************/
/* INSTRUCTIONS                                                               */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/* ADDRESS INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Address.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for ADDRESS keyword
  element = PrepareClause( element, stream, context )

  -- Clone it
  element = Clone( element, stream, context )

  -- Clone ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  If self~environment \== .Nil Then Do
    element = self~environment~compile( element, stream, context )
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    If self~expression \== .Nil Then Do
      element = self~expression~compile( element, stream, context )
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
    End
  End

  If self~env_expression \== .Nil Then Do
    If element < .EL.SUBKEYWORD Then Do -- VALUE
      element = Clone( element, stream, context )
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
    End
    element = self~env_expression~compile( element, stream, context )
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  If element < .EL.END_OF_CLAUSE Then Return element

  -- WITH
  element = Clone( element, stream, context )
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  options. = self~options.

  Loop While element \< .EL.END_OF_CLAUSE
    -- INPUT, OUTPUT, ERROR
    redir = element~value
    element = Clone( element, stream, context )
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End

    If WordPos(element~value, "APPEND REPLACE") > 0 Then Do
      element = Clone( element, stream, context )
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
    End

    option = element~value
    element = Clone( element, stream, context )
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End

    If option \== "NORMAL" Then Do
      element = options.[redir"_"option]~compile( element, stream, context )
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
    End

  End

  Return element


/******************************************************************************/
/* ASSIGNMENT INSTRUCTIONS                                                    */
/******************************************************************************/

::Method "Assignment.Instruction::compile"
  Use Strict Arg element, stream, context

  element = PrepareClause( element, stream, context )

  -- Now element is the lhs variable

  element = self~symbol~compile( element, stream, context )

  expression = self~expression

  If expression~isEmpty Then Do -- When "x =;" is allowed
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
    Return element
  End

  begin = expression~begin
  Loop While element \== begin
    element = Clone( element, stream, context )
  End

  element = expression~compile( element, stream, context )

  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* CALL INSTRUCTIONS                                                          */
/******************************************************************************/

::Method "Call.Instruction::compile"

  Use Strict Arg element, stream, context

  -- Look for CALL keyword
  element = PrepareClause( element, stream, context )

  -- Clone it
  element = Clone( element, stream, context )

  -- Clone ignorables until function name
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone function name
  element = Clone( element, stream, context )

  -- Clone ignorables until expression list
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  If element \== .EL.END_OF_CLAUSE Then Do
    -- Compile arguments
    element = self~arguments~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* CALL VALUE INSTRUCTIONS                                                    */
/******************************************************************************/

::Method "Call.Value.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for CALL keyword
  element = PrepareClause( element, stream, context )

  -- Clone it
  element = Clone( element, stream, context )

  -- Clone ignorables until left parenthesis
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone the parenthesis
  element = Clone( element, stream, context )

  -- Clone ignorables until expression starts
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile the expression
  element = self~expression~compile( element, stream, context )

  -- Clone ignorables until right parenthesis
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone the parenthesis
  element = Clone( element, stream, context )

  -- Clone ignorables until arguments or EOC
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  If element \== .EL.END_OF_CLAUSE Then Do
    -- Compile arguments
    element = self~arguments~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* CALL OFF INSTRUCTIONS                                                      */
/******************************************************************************/

::Method "Call.Off.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for CALL keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* CALL ON INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Call.On.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for CALL keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* COMMAND INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Command.Instruction::compile"

  Use Strict Arg element, stream, context

  -- Skip to expression start
  element = PrepareClause( element, stream, context )

  expression = self~expression

  -- Compile expression
  element = expression~compile( element, stream, context )
  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* DO INSTRUCTIONS                                                            */
/******************************************************************************/

::Method "Do.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Do.Clause will call PrepareClause

  element = self~doClause~compile( element, stream, context )

  Loop instruction Over self~instructions
    element = instruction~compile( element, stream, context )
  End

  element = self~endClause~compile( element, stream, context )

  Return element

/******************************************************************************/
/* DROP INSTRUCTIONS                                                          */
/******************************************************************************/

::Method "Drop.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for DROP keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* EXIT INSTRUCTIONS                                                          */
/******************************************************************************/

::Method "Exit.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for EXIT keyword
  element = PrepareClause( element, stream, context )

  -- Skip EXIT
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  If expression \== .Nil Then Do
    -- Compile expression
    element = expression~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* EXPOSE INSTRUCTIONS                                                        */
/******************************************************************************/

::Method "Expose.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for EXPOSE keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* FORWARD INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Forward.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for FORWARD keyword
  element = PrepareClause( element, stream, context )

  -- Skip it
  element = Clone( element, stream, context )

  Do Until element \< .EL.SUBKEYWORD
    -- Skip ignorables
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
    If element < .EL.SUBKEYWORD Then Do
      last = element
      -- Skip ignorables
      Loop While element \< .EL.END_OF_CLAUSE
        element = Clone( element, stream, context )
      End
      Select Case Lower( last~value )
        When "continue"  Then Nop
        When "arguments" Then
          element = self~arguments~compile( element, stream, context )
        When "array" Then
          element = self~array    ~compile( element, stream, context )
        When "message" Then
          element = self~message  ~compile( element, stream, context )
        When "class" Then
          element = self~theClass ~compile( element, stream, context )
        When "to" Then
          element = self~to       ~compile( element, stream, context )
      End
      Iterate
    End
  End

  Return element

/******************************************************************************/
/* GUARD INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Guard.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for GUARD keyword
  element = PrepareClause( element, stream, context )

  -- Skip it
  element = Clone( element, stream, context )

  -- Skip ignorables until ON or OFF
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Skip ON or OFF
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- EOC? We are done
  If element < .EL.END_OF_CLAUSE Then Return element

  -- That's WHEN. Skip it
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Compile expression
  element = self~expression~compile( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element


/******************************************************************************/
/* IF INSTRUCTIONS                                                            */
/******************************************************************************/

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

/******************************************************************************/
/* IMPLICIT EXIT INSTRUCTIONS                                                 */
/******************************************************************************/

::Method "Implicit.Exit.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for implicit EXIT marker keyword
  element = PrepareClause( element, stream, context )

  -- Skip it
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "Interpret.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for INTERPRET keyword
  element = PrepareClause( element, stream, context )

  -- Skip INTERPRET
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  -- Compile expression
  element = expression~compile( element, stream, context )
  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "Iterate.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for ITERATE keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

::Method "Leave.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for LEAVE keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* LOOP INSTRUCTIONS                                                          */
/******************************************************************************/

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
/* MESSAGE ASSIGNMENT INSTRUCTIONS                                            */
/******************************************************************************/

::Method "Message.Assignment.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Skip until start of lhs
  element = PrepareClause( element, stream, context )

  -- Compile the lhs
  element = self~lhs~compile( element, stream, context )

  -- Clone everything until rgs begins
  rhs   = self~rhs
  begin = rhs~begin
  Loop While element \== begin
    element = Clone( element, stream, context )
  End

  -- Compile the rhs
  element = rhs~compile( element, stream, context )

  -- Skip to EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* MESSAGE INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Message.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Skip until start of expression
  element = PrepareClause( element, stream, context )

  -- Compile the expression
  element = self~expression~compile( element, stream, context )

  -- Skip to EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* NAMESPACE QUALIFIED CALL INSTRUCTIONS                                      */
/******************************************************************************/

::Method "Namespace.Qualified.Call.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for CALL keyword
  element = PrepareClause( element, stream, context )

  -- Clone it
  element = Clone( element, stream, context )

  -- Clone ignorables until namespace
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone it
  element = Clone( element, stream, context )

  -- Clone ignorables until colon
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone it
  element = Clone( element, stream, context )

  -- Clone ignorables until function name
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Clone function name
  element = Clone( element, stream, context )

  -- Clone ignorables until argument list
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  If element \== .EL.END_OF_CLAUSE Then Do
    -- Compile arguments
    element = self~arguments~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* NOP INSTRUCTIONS                                                           */
/******************************************************************************/

::Method "Nop.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for NOP keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* NUMERIC INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Numeric.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for NUMERIC keyword
  element = PrepareClause( element, stream, context )

  Do Until element \< .EL.SUBKEYWORD
    -- Skip it
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  -- No EOC?
  If element \< .EL.END_OF_CLAUSE Then Do
    -- This must be an expression
    element = self~expression~compile( element, stream, context )
  End

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* OPTIONS INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Options.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for OPTIONS keyword
  element = PrepareClause( element, stream, context )

  -- Skip OPTIONS
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  -- Compile expression
  element = expression~compile( element, stream, context )
  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* PROCEDURE INSTRUCTIONS                                                     */
/******************************************************************************/

::Method "Procedure.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for PROCEDURE keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* PUSH INSTRUCTIONS                                                          */
/******************************************************************************/

::Method "Push.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for PUSH keyword
  element = PrepareClause( element, stream, context )

  -- Skip PUSH
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  If expression \== .Nil Then Do
    -- Compile expression
    element = expression~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* QUEUE INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Queue.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for QUEUE keyword
  element = PrepareClause( element, stream, context )

  -- Skip QUEUE
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  If expression \== .Nil Then Do
    -- Compile expression
    element = expression~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* RAISE INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Raise.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for RAISE keyword
  element = PrepareClause( element, stream, context )

  -- Skip RAISE
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Skip subkeyword (condition name or PROPAGATE)
  element = Clone( element, stream, context )

  If self~code \== .Nil Then Do
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    -- Compile code
    element = self~code~compile( element, stream, context )
  End
  Else If self~UserCondition \== .Nil Then Do
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    -- Skip usercondition
    element = Clone( element, stream, context )
  End

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  Loop While element \< .EL.END_OF_CLAUSE
    keyword = element
    -- Skip keyword
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    -- Process associated expression
    Select Case keyword~value
      When "ADDITIONAL" Then
        element = self~additional ~compile( element, stream, context )
      When "ARRAY" Then
        element = self~array      ~compile( element, stream, context )
      When "DESCRIPTION" Then
        element = self~description~compile( element, stream, context )
      When "EXIT" Then
        If self~exit \== "" Then
          element = self~exit     ~compile( element, stream, context )
      When "RETURN" Then
        If self~return \== "" Then
          element = self~return   ~compile( element, stream, context )
    End
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* REPLY INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Reply.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for REPLY keyword
  element = PrepareClause( element, stream, context )

  -- Skip REPLY
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  If expression \== .Nil Then Do
    -- Compile expression
    element = expression~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* RETURN INSTRUCTIONS                                                        */
/******************************************************************************/

::Method "Return.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for RETURN keyword
  element = PrepareClause( element, stream, context )

  -- Skip RETURN
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  If expression \== .Nil Then Do
    -- Compile expression
    element = expression~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* SAY INSTRUCTIONS                                                           */
/******************************************************************************/

::Method "Say.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for SAY keyword
  element = PrepareClause( element, stream, context )

  -- Skip SAY
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  expression = self~expression

  If expression \== .Nil Then Do
    -- Compile expression
    element = expression~compile( element, stream, context )
    -- Skip until EOC
    Loop While element \< .EL.END_OF_CLAUSE
      element = Clone( element, stream, context )
    End
  End

  Return element

/******************************************************************************/
/* SELECT INSTRUCTIONS                                                        */
/******************************************************************************/

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

/******************************************************************************/
/* SIGNAL INSTRUCTIONS                                                        */
/******************************************************************************/

::Method "Signal.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for SIGNAL keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* SIGNAL OFF INSTRUCTIONS                                                    */
/******************************************************************************/

::Method "Signal.Off.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for SIGNAL keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* SIGNAL ON INSTRUCTIONS                                                     */
/******************************************************************************/

::Method "Signal.On.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for SIGNAL keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* SIGNAL VALUE INSTRUCTIONS                                                  */
/******************************************************************************/

::Method "Signal.Value.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for SIGNAL keyword
  element = PrepareClause( element, stream, context )

  -- Skip it
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- VALUE?
  If element < .EL.SUBKEYWORD Then Do
    -- Skip it
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  element = self~expression~compile( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* TRACE INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Trace.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for TRACE keyword
  element = PrepareClause( element, stream, context )

  -- Skip it
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ ignorable
    element = Clone( element, stream, context )
  End

  Select
    When element < .ALL.NUMBERS Then
      element = self~number~compile( element, stream, context )
    When element < .ALL.SYMBOLS Then
      element = self~symbol~compile( element, stream, context )
    When element < .ALL.STRINGS Then
      element = self~theString~compile( element, stream, context )
    When element < .EL.SUBKEYWORD Then Do -- VALUE
      -- Skip "VALUE"
      element = Clone( element, stream, context )
      -- Skip ignorables
      Loop While element~ ignorable
        element = Clone( element, stream, context )
      End
      element = self~expression~compile( element, stream, context )
    End
    When self~expression == .Nil Then Nop
    Otherwise -- Expression
      element = self~expression~compile( element, stream, context )
  End

  -- Skip ignorables
  Loop While element~ ignorable
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* UPPER INSTRUCTIONS                                                         */
/******************************************************************************/

::Method "Upper.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for UPPER keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element

/******************************************************************************/
/* USE ARG INSTRUCTIONS                                                       */
/******************************************************************************/

::Method "Use.Arg.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for USE keyword
  element = PrepareClause( element, stream, context )

  -- Skip over it
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- Do we expect STRICT?
  If self~strict Then Do
    -- Skip over it
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  -- Do we expect AUTO?
  If self~auto Then Do
    -- Skip over it
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  -- Do we expect NAMED?
  If self~named Then Do
    -- Skip over it
    element = Clone( element, stream, context )
    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
  End

  -- Skip over ARG
  element = Clone( element, stream, context )

  -- Skip ignorables
  Loop While element~ignorable
    element = Clone( element, stream, context )
  End

  -- USE ARG; or (more frequent) USE STRICT ARG;
  If element < .EL.END_OF_CLAUSE Then Return element

  arguments  = self~arguments
  nArguments = arguments~items
  Do Counter c argument Over arguments

    -- Compile name
    name    = argument[1]
    element = name~compile( element, stream, context )

    If argument~items == 2 Then Do
      -- Skip ignorables until "="
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
      -- Skip "="
      element = Clone( element, stream, context )
      -- Skip ignorables until expr start
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
      -- Compile exp
      expr    = argument[2]
      element = expr~compile( element, stream, context )
   End

    -- Skip ignorables
    Loop While element~ignorable
      element = Clone( element, stream, context )
    End
    If c < nArguments Then Do
      -- Skip ","
      element = Clone( element, stream, context )
      -- Skip ignorables
      Loop While element~ignorable
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

/******************************************************************************/
/* USE LOCAL INSTRUCTIONS                                                     */
/******************************************************************************/

::Method "Use.Local.Instruction::compile"
  Use Strict Arg element, stream, context

  -- Look for USE keyword
  element = PrepareClause( element, stream, context )

  -- Skip until EOC
  Loop While element \< .EL.END_OF_CLAUSE
    element = Clone( element, stream, context )
  End

  Return element
