/******************************************************************************/
/*                                                                            */
/* cloneTree.cls -- Clone a program using the Tree API                        */
/* ===================================================                        */
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
/*                                                                            */
/******************************************************************************/

Call "modules/Load.Parser.Module.rex" "BaseClassesAndRoutines"

::Method "Addition.Expression::process"
  Use Strict Arg element, stream, context

  element = ProcessNAryExpression( self~args, element, stream, context )

  Return element

::Method "And.Expression::process"
  Use Strict Arg element, stream, context

  element = ProcessNAryExpression( self~args, element, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element

::Method "Arg.Instruction::process"
  Use Strict Arg element, stream, context

  ARG = PrepareInstruction( element, stream, context )
  element = Clone( ARG, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Assignment.Instruction::process"
  Use Strict Arg element, stream, context

  element = PrepareInstruction( element, stream, context )

  -- Clone the lhs symbol
  element = element~process( element, stream, context )

  element = SkipIgnorable( element, stream, context )

  -- Clone the assignment operator
  element = Clone( element, stream, context )

  element = SkipIgnorable( element, stream, context )

  Return    self~expression~process( element, stream, context )

::Method "Attribute.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  Return element

::Method "Call.Instruction::process"
  Use Strict Arg element, stream, context

  CALL = PrepareInstruction( element, stream, context )

  element = Clone( CALL, stream, context )

  -- Skip whitespace and comments
  Loop While element \== self~name
    element = Clone( element, stream, context )
  End

  -- Clone the procedure name
  element = Clone( element, stream, context )

  element = SkipIgnorable( element, stream, context )

  arguments = self~arguments

  If arguments~isEmpty Then Return element

  element = arguments~process( element, stream, context )

  Return element

::Method "Call.Value.Instruction::process"
  Use Strict Arg element, stream, context

  CALL    = PrepareInstruction( element, stream, context )
  element = Clone( CALL, stream, context )

  LPAREN  = SkipIgnorable( element, stream, context )
  element = Clone( LPAREN, stream, context )
  element = SkipIgnorable( element, stream, context )

  element = self~expression~process( element, stream, context )
  RPAREN  = SkipIgnorable( element, stream, context )
  element = Clone( RPAREN, stream, context )
  element = SkipIgnorable( element, stream, context )

  arguments = self~arguments

  If arguments~isEmpty Then Return element

  element = arguments~process( element, stream, context )

  Return element

::Method "Class.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  Return element

::Method "Code.Body::process"
  Use Strict Arg element, stream, context

  Do instruction Over self~instructions
    element = instruction~process( element, stream, context )
  End

  Return element

::Method "Compound.Variable.Term::process"
  Use Strict Arg element, stream, context

  element = self~stem~process( element, stream, context )

  Return element

::Method "Concatenation.Expression::process"
  Use Strict Arg element, stream, context

  element = ProcessNAryExpression( self~args, element, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element

::Method "Command.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  element = PrepareInstruction( endOfClause, stream, context )

  element = self~expression~process( element, stream, context )

  endOfClause = SkipIgnorable( element, stream, context )

  Return endOfClause

::Method "Comparison.Expression::process"
  Use Strict Arg element, stream, context

  element = ProcessNAryExpression( self~args, element, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element

::Method "Constant.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  Return element

::Method "Do.Clause::process"
  Use Strict Arg DO, stream, context

  element = Clone( DO, stream, context )

  Do while element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Do.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  DO = PrepareInstruction( endOfClause, stream, context )

  element = self~doClause~process( DO, stream, context )

  Loop instruction Over self~instructions
    element = instruction~process( element, stream, context )
  End

  element = self~endClause~process( element, stream, context )

  Return element

::Method "Drop.Instruction::process"
  Use Strict Arg element, stream, context

  DROP = PrepareInstruction( element, stream, context )
  element = Clone( DROP, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Else.Clause::process"
  Use Strict Arg endOfClause, stream, context

  ELSE        = PrepareClause( endOfClause, stream, context )

  -- The parser inserts a endOfClause immediately
  -- after the ELSE clause.
  endOfClause = Clone( ELSE, stream, context )

  Return endOfClause

::Method "End.Clause::process"
  Use Strict Arg endOfClause, stream, context

  END = PrepareClause( endOfClause, stream, context )
  element = Clone( END, stream, context ) -- TODO options

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  Return element

::Method "Implicit.Exit.Instruction::process"

  Use Strict Arg endOfClause, stream, context

  implicitExit = PrepareInstruction( endOfClause, stream, context )
  endOfClause    = Clone( implicitExit, stream, context )

  Return endOfClause

::Method "Exit.Instruction::process"
  Use Strict Arg element, stream, context

  element = PrepareInstruction( element, stream, context )
  element = Clone( element, stream, context )

  element = SkipIgnorable( element, stream, context )

  expression = self~expression

  If expression == .Nil Then Return element

  Return expression~process( element, stream, context )

::Method "Expose.Instruction::process"
  Use Strict Arg element, stream, context

  EXPOSE = PrepareInstruction( element, stream, context )

  element = Clone( EXPOSE, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Expression.List::process"
  Use Strict Arg element, stream, context

  -- A list of expressions separated by commas, but expressions
  -- may be missing.
  arguments = self~args

  If arguments == .Nil Then Return element

  Do argument Over arguments
    -- Comma elements are instances of Special.Character.Sequence;
    -- when this is not a comma, it's an argument.
    If \argument~isA(.Special.Character.Sequence) Then
      element = argument~process( element, stream, context )
    Else Do
      -- Handling of commas requires some care.
      -- We first clone everything until we find the comma, ...
      Do While element \< .EL.COMMA
        element = Clone( element, stream, context )
      End
      -- ...we then clone the comma itself,...
      element = Clone( element, stream, context )
      -- ... and we finally clone all ignorable elements to the
      -- right of the comma
      element = SkipIgnorable( element, stream, context )
    End
  End

  Return element

::Method "Function.Call.Term::process"

  Use Strict Arg element, stream, context

  functionName = SkipIgnorable( element, stream, context )

  LPAREN = Clone( functionName, stream, context )

  next   = Clone( LPAREN, stream, context )

  element  = SkipIgnorable( next, stream, context )

  If element < .EL.RIGHT_PARENTHESIS Then Do
    next   = Clone( element, stream, context )
    Return next
  End

  element = self~argumentList~process( element, stream, context )

  RPAREN  = SkipIgnorable( element, stream, context )

  next   = Clone( RPAREN, stream, context )

  Return next

::Method "If.Clause::process"
  Use Strict Arg IF, stream, context

  element = Clone( IF, stream, context )

  element = SkipIgnorable( element, stream, context )
  element = self~expressions~process( element, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element

::Method "If.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  IF = PrepareInstruction( endOfClause, stream, context )

  element = self~ifClause         ~process( IF,      stream, context )
  element = self~thenClause       ~process( element, stream, context )
  element = self~thenInstruction  ~process( element, stream, context )

  elseClause = self~elseClause
  If elseClause \== .Nil Then Do
    element = elseClause          ~process( element, stream, context )
    element = self~elseInstruction~process( element, stream, context )
  End

  Return element

::Method "Indexed.Or.Invoked.Term::process"
  Use Strict Arg element, stream, context

  element  = SkipIgnorable( element, stream, context )
  LBRACKET = self~term~process( element, stream, context )
  element  = Clone( LBRACKET, stream, context )
  element  = SkipIgnorable( element, stream, context )
  argumentList = self~argumentList
  If \argumentList~isEmpty Then
    element = argumentList~process( element, stream, context )

  RBRACKET = SkipIgnorable( element, stream, context )

  next     = Clone( RBRACKET, stream, context )

  Return next

::Method "Interpret.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  INTERPRET = PrepareInstruction( endOfClause, stream, context )
  next = Clone( INTERPRET, stream, context )

  element = SkipIgnorable( next, stream, context )

  element = self~expression~process( element, stream, context )

  endOfClause = SkipIgnorable( element, stream, context )

  Return endOfClause

::Method "Inserted.Semicolon::process"
  Use Strict Arg element, stream, context
  Return self~next

::Method "Iterate.Instruction::process"
  Use Strict Arg element, stream, context

  ITERATE = PrepareInstruction( element, stream, context )
  next = Clone( ITERATE, stream, context )

  element = SkipIgnorable( next, stream, context )

  label = self~label

  If label == .Nil Then Return element

  Return label~process( element, stream, context )

::Method "Leave.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  LEAVE   = PrepareInstruction( endOfClause, stream, context )
  element = Clone( LEAVE, stream, context )

  next = SkipIgnorable( element, stream, context )

  If next < .ALL.SYMBOLS Then Do
    next = Clone( next, stream, context )
    next = SkipIgnorable( element, stream, context )
  End

  Return next

::Method "Label.Clause::process"
  Use Strict Arg element, stream, context

  -- Process the semicolon
  element = element~process( element, stream, context )

  -- Process whitespace
  Loop While element < .ALL.WHITESPACE_LIKE
    element = element~process( element, stream, context )
  End

  -- Now element is the label
  element = element~process( element, stream, context )

  -- More whitespace
  Loop While element < .ALL.WHITESPACE_LIKE
    element = element~process( element, stream, context )
  End

  -- Now element is a colon
  stream~charOut(":")
  element = element~next

  -- A (maybe implied) semicolon
  Return element

::Method "Line.Comment::process"
  Use Strict Arg element, stream, context

  stream~charOut( self~source)

  Return element~next

::Method "Literal.String.Term::process"
  Use Strict Arg element, stream, context

  Return self~theString~process( element, stream, context )

::Method "Loop.Clause::process"
  Use Strict Arg LOOP, stream, context

  element = Clone( LOOP, stream, context )

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  Return element

::Method "Loop.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  LOOP = PrepareInstruction( endOfClause, stream, context )

  element = self~loopClause~process( LOOP, stream, context )

  Loop instruction Over self~instructions
    element = instruction~process( element, stream, context )
  End

  element = self~endClause~process( element, stream, context )

  Return element

::Method "Message.Assignment.Instruction::process"
  Use Strict Arg element, stream, context

  element = PrepareInstruction( element, stream, context )

  element = self~lhs~process( element, stream, context )

  -- We have to be careful with extended assignment operators,
  -- because the (oo)Rexx syntax allows us to put whitespace
  -- and/or comments between the characters.
  rhsBegin = self~rhs~begin
  Do While element \==  rhsBegin
    element = Clone( element, stream, context )
  End

  element = self~rhs~process( element, stream, context )

  Return element

::Method "Message.Instruction::process"
  Use Strict Arg element, stream, context

  element = PrepareInstruction( element, stream, context )
  element = self~expression~process( element, stream, context )

  Return element

::Method "Message.Term::process"
  Use Strict Arg element, stream, context

  element = self~term~process( element, stream, context )

  operator = SkipIgnorable( element, stream, context )
  -- operator is now "~" or "~~"
  next         = Clone( operator, stream, context )

  messageName  = SkipIgnorable( next, stream, context )
  next         = Clone( messageName, stream, context )

  scope = self~scope
  If scope \== .Nil Then Do
    COLON  = SkipIgnorable( next, stream, context )
    next   = Clone( COLON, stream, context )
    scope  = SkipIgnorable( next, stream, context )
    next   = Clone( scope, stream, context )
  End

  arguments = self~arguments
  If arguments \== .Nil Then Do
    -- next is a left parenthesis
    element = Clone( next, stream, context )
    element = SkipIgnorable( element, stream, context)
    element = arguments~process( element, stream, context )
    RPAREN  = SkipIgnorable( element, stream, context )
    next    = Clone( RPAREN, stream, context )
  End

  Return next

::Method "Method.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  element = self~body~process( element, stream, context )

  Return element

::Method "Multiplication.Expression::process"
  Use Strict Arg element, stream, context

  element = ProcessNAryExpression( self~args, element, stream, context )

  Return element

::Method "Nop.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  NOP       = PrepareInstruction( endOfClause, stream, context )
  element   = Clone( NOP, stream, context )
  endOfClause = SkipIgnorable( element, stream, context )

  Return endOfClause

::Method "Null.Clause::process"
  Use Strict Arg element, stream, context

  -- Skip over the initial semicolon
  element = Clone( element, stream, context )

  Loop
    Loop While element < .ALL.WHITESPACE_LIKE
      element = element~process( element, stream, context )
    End

    If element < .EL.END_OF_CLAUSE Then Return element

    If element < ( .EL.DOC_COMMENT_MARKDOWN || .EL.LINE_COMMENT ) Then
      Return element~process( element, stream, context )

    -- element has to be a classic comment
    element = element~process( element, stream, context )
  End

::Method "Prefix.Expression::process"
  Use Strict Arg element, stream, context

  element = SkipIgnorable( element, stream, context )
  termBegin = self~term~begin
  Do While element \== termBegin
    element = Clone( element, stream, context )
  End
  element = self~term~process( element, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element


-- Operator character sequences have to be handled manually
-- at the element level, because (oo)Rexx allows whitespace
-- and comments between the characters.
/*
::Method "Operator.Character.Sequence::process"
  Use Strict Arg element, stream, context

  stream~charOut( self~value )

  Return self~next
*/

::Method "Or.Expression::process"
  Use Strict Arg element, stream, context

  element = ProcessNAryExpression( self~args, element, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element

::Method "Otherwise.Clause::process"
  Use Strict Arg endOfClause, stream, context

  OTHERWISE = PrepareClause( endOfClause, stream, context )
  next      = Clone( OTHERWISE, stream, context )

  endOfClause = SkipIgnorable( next, stream, context )
  Return endOfClause

::Method "Parse.Instruction::process"
  Use Strict Arg element, stream, context

  element = PrepareInstruction( element, stream, context )
  element = Clone( element, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Procedure.Instruction::process"
  Use Strict Arg element, stream, context

  PROCEDURE = PrepareInstruction( element, stream, context )
  element = Clone( PROCEDURE, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Raise.Instruction::process"
  Use Strict Arg element, stream, context

  RAISE = PrepareInstruction( element, stream, context )
  element = Clone( RAISE, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Requires.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  Return element

::Method "Resource.Data::process"
  Use Strict Arg element, stream, context

  Do While element \== self
    element = Clone( element, stream, context )
  End

  Parse Value self~from With line1 .
  Parse Value self~to   With line2 .
  source = self~source

  Do line = line1 To line2
    stream~Say( source[line] )
  End

  Return element~next

::Method "Resource.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \< .EL.RESOURCE_DATA -- TODO
    element = Clone( element, stream, context )
  End

  -- Clone the resource data
  element = element~process( element, stream, context )

  Do While element \== self~end
    element = Clone( element, stream, context )
  End

  -- TODO extra stuff

  Return element

::Method "Return.Instruction::process"
  Use Strict Arg element, stream, context

  RETURN = PrepareInstruction( element, stream, context )
  next = Clone( RETURN, stream, context )

  element = SkipIgnorable( next, stream, context )

  expression = self~expression

  If expression == .Nil Then Return element

  Return expression~process( element, stream, context )

::Method "Rexx.Package::process"
  Use Strict Arg element, stream, context

  element = self~prolog~process( element, stream, context )

  Loop directive Over self~directives
    element = directive~process( element, stream, context )
  End

  Return element~next

::Method "Rexx.Routine::process"
  Use Strict Arg element, stream, context

  Return self~body~process( element, stream, context )

::Method "Routine.Directive::process"
  Use Strict Arg element, stream, context

  Do While element \< .EL.DIRECTIVE_START
    element = Clone( element, stream, context )
  End

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  element = self~body~process( element, stream, context )

  Return element


::Method "Say.Instruction::process"
  Use Strict Arg element, stream, context

  SAY = PrepareInstruction( element, stream, context )
  element = Clone( SAY, stream, context )

  element = SkipIgnorable( element, stream, context )

  expression = self~expression

  If expression == .Nil Then Return element

  element = expression~process( element, stream, context )

  element = SkipIgnorable( element, stream, context )

  Return element

::Method "Select.Clause::process"
  Use Strict Arg SELECT, stream, context

  -- Clone the SELECT keyword
  element = Clone( SELECT, stream, context )

  element = SkipIgnorable( element, stream, context )

  If self~label \== "" Then Do
    -- Clone the LABEL keyword
    element  = Clone( element, stream, context )
    element  = SkipIgnorable( element, stream, context )
    -- Clone the label itself
    element = Clone( element, stream, context )
    element  = SkipIgnorable( element, stream, context )
  End

  If self~case \== .Nil Then Do
    CASE = element -- For readability
    element = Clone( CASE, stream, context )
    element  = SkipIgnorable( element, stream, context )
    element = self~case~process( element, stream, context )
    element  = SkipIgnorable( element, stream, context )
  End

  Return element

::Method "Select.Instruction::process"

  Use Strict Arg endOfClause, stream, context

  SELECT = PrepareInstruction( endOfClause, stream, context )
  endOfClause = self~selectClause~process( SELECT, stream, context )

  Do WhenThenInstruction Over self~whenThenInstructions
    whenClause       = WhenThenInstruction[1]
    thenClause       = WhenThenInstruction[2]
    thenInstruction  = WhenThenInstruction[3]

    endOfClause        = whenClause~process( endOfClause, stream, context )
    endOfClause        = thenClause~process( endOfClause, stream, context )
    endOfClause        = thenInstruction~process( endOfClause, stream, context )
  End

  otherwiseClause = self~otherwiseClause
  If otherwiseClause \== .Nil Then Do
    endOfClause = otherwiseClause~process( endOfClause, stream, context )

    Do instruction Over self~otherwiseSequence
      endOfClause = instruction~process( endOfClause, stream, context )
    End
  End

  endOfClause = self~endClause~process( endOfClause, stream, context )

  Return endOfClause

::Method "Signal.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  SIGNAL = PrepareInstruction( endOfClause, stream, context )
  element = Clone( SIGNAL, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Signal.On.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  SIGNAL = PrepareInstruction( endOfClause, stream, context )
  next   = Clone(       SIGNAL,  stream, context )
  ON     = SkipIgnorable( next,  stream, context )
  next   = Clone(       ON,      stream, context )

  If self~userCondition \== .Nil Then Do
    USER          = SkipIgnorable( next,          stream, context )
    next          = Clone(         USER,          stream, context )
    userCondition = SkipIgnorable( next,          stream, context )
    next          = Clone(         userCondition, stream, context )
  End
  Else Do
    condition     = SkipIgnorable( next,          stream, context )
    next          = Clone(         condition,     stream, context )
  End

  If self~label \== .Nil Then Do
    NAME          = SkipIgnorable( next,          stream, context )
    next          = Clone(         NAME,          stream, context )
    trapname      = SkipIgnorable( next,          stream, context )
    next          = Clone(         trapname,      stream, context )
  End

  Return next

::Method "Signal.Value.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  SIGNAL = PrepareInstruction( endOfClause, stream, context )
  element = Clone( SIGNAL, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

-- Special character sequences have to be handled manually
-- at the element level, because (oo)Rexx allows whitespace
-- and comments between the characters.
/*
::Method "Special.Character.Sequence::process"
  Use Strict Arg element, stream, context

  stream~charOut( self~source )

  Return self~next
*/

::Method "SubExpression::process"
  Use Strict Arg element, stream, context

  LPAREN  = SkipIgnorable( element, stream, context )
  element = Clone( LPAREN, stream, context )
  element = SkipIgnorable( element, stream, context )
  element = self~SubExpression~process( element, stream, context )
  RPAREN  = SkipIgnorable( element, stream, context )
  element = Clone( RPAREN, stream, context )
  element = SkipIgnorable( element, stream, context )

  Return element

::Method "Symbol.Term::process"
  Use Strict Arg element, stream, context

  Return self~symbol~process( element, stream, context )

::Method "Standard.Comment::process"
  Use Strict Arg element, stream, context

  stream~charOut( self~source)

  Return element~next

::Method "Stem.Variable.Term::process"
  Use Strict Arg element, stream, context

  element = self~stem~process( element, stream, context )

  Return element

::Method "StringOrSymbol.Element::process"
  Use Strict Arg element, stream, context

  stream~charOut( self~source )

  Return self~next

::Method "Then.Clause::process"
  Use Strict Arg endOfClause, stream, context

  THEN        = PrepareClause( endOfClause, stream, context )

  -- The parser inserts a endOfClause immediately after
  -- the THEN keyword.
  endOfClause = Clone( THEN, stream, context )

  Return endOfClause

::Method "Use.Arg.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  USE = PrepareInstruction( endOfClause, stream, context )
  element = Clone( USE, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "Use.Local.Instruction::process"
  Use Strict Arg endOfClause, stream, context

  USE = PrepareInstruction( endOfClause, stream, context )
  element = Clone( USE, stream, context )

  Do While element \== self~end -- TODO
    element = Clone( element, stream, context )
  End

  Return element

::Method "When.Clause::process"
  Use Strict Arg endOfClause, stream, context

  WHEN      = PrepareClause( endOfClause, stream, context )
  element   = Clone( WHEN, stream, context )

  element   = SkipIgnorable( element, stream, context )

  element   = self~expressions~process( element, stream, context )

  endOfClause = SkipIgnorable( element, stream, context )

  Return endOfClause

::Method "WhiteSpace.Element::process"
  Use Strict Arg element, stream, context

  element = Clone( element, stream, context )

  Return element

--------------------------------------------------------------------------------

::Routine Clone
  Use Strict Arg element, stream, context

  If element~from \== element~to Then stream~charOut( element~source )

  next = element~next

  If element~to~word(1) \== next~from~word(1) Then stream~Say

  Return next

::Routine SkipIgnorable
  Use Strict Arg element, stream, context
  Loop While element~isIgnorable
    element = Clone( element, stream, context )
  End
  Return element

---
--- Process a N-ary expression.
---
--- Operators have to be carefully handled at the element level.

::Routine ProcessNAryExpression
  Use Strict Arg expression, element, stream, context

  N = expression~items
  Do i = 1 To N By 2
    operand = expression[i]
    element = operand~process( element, stream, context )
    If i < N Then Do
      next = expression[i+2]
      Do While element \== next~begin
        element = Clone( element, stream, context )
      End
    End
  End

  Return element

-- Prepares clauses that are not instructions and do not start
-- instructions, like "WHEN", "THEN", "ELSE", "OTHERWISE" or "END".
-- These cannot have labels.

::Routine PrepareClause
  Use Strict Arg element, stream, context

  -- Clone initial end-of-clauses, whitespace, comments and doc-comments
  Do While element < (             -
   .EL.END_OF_CLAUSE    ||         -    -- endOfClauses (implied or not )
   .ALL.WHITESPACE_LIKE ||         -    -- Including continuations
   .ALL.COMMENTS                   -    -- Including doc-comments
    )
    element = Clone( element, stream, context )
  End

  Return element

::Routine PrepareInstruction
  Use Strict Arg element, stream, context

  -- Clone initial end-of-clauses, whitespace, comments,
  -- doc-comments and labels
  Do While element < (             -
   .EL.END_OF_CLAUSE    ||         -    -- endOfClauses (implied or not )
   .ALL.WHITESPACE_LIKE ||         -    -- Including continuations
   .ALL.COMMENTS        ||         -    -- Including doc-comments
   .EL.TAKEN_CONSTANT || .EL.COLON -    -- Labels
    )
    element = Clone( element, stream, context )
  End

  Return element