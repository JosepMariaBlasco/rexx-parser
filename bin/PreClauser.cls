/******************************************************************************/
/*                                                                            */
/* PreClauser.cls                                                             */
/* ==============                                                             */
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
/* 20241206    0.1  First public release                                      */
/* 20241208    0.1a Accept options arg, pass it to tokenizer                  */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250531    0.2c Fix issue no. 13                                          */
/* 20251014    0.2e (Lua only) Check that Lua constants are not assigned to   */
/* 20251127    0.3a (Executor) Allow "var == expression;"                     */
/*                                                                            */
/******************************************************************************/

::Requires "BaseClassesAndRoutines.cls"

::Class PreClauser Public

::Attribute tokenizer
::Attribute begin

/******************************************************************************/
/*                                                                            */
/* NEXTCLAUSE Method                                                          */
/*                                                                            */
/* The way we have written our tokenizer, a clause is always delimited by two */
/* semicolons (we add one to the beginning of the source to ensure this       */
/* happens.                                                                   */
/*                                                                            */
/* When we are asked for a new clause, we need to go from "begin" (which is   */
/* supposed to be a semicolon, present or implied) to the next semicolon.     */
/* This, or a part of this, will be our clause. Element sequences between     */
/* two semicolons are only broken into smaller clauses in some cases, where   */
/* a supplementary semicolon is added: after a label, before and after THEN,  */
/* and after ELSE and OTHERWISE.                                              */
/*                                                                            */
/* Returns a four-element array:                                              */
/*   a[1] is a character string identifying the clause type                   */
/*                                                                            */
/*        "NULL.CLAUSE"       A null clause                                   */
/*        "LABEL.CLAUSE"      A label                                         */
/*        "COMMAND"           a command                                       */
/*                            The command expression has been prepared        */
/*                            (see the PrepareExpression method below).       */
/*        "MESSAGE"           a message instruction (may be an extended       */
/*                            assignment). The instruction has been prepared  */
/*                            (see the PrepareExpression method below).       */
/*        "ASSIGNMENT"        a (possibly extended) assignment                */
/*        name".DIRECTIVE",   where "name" is a valid directive name.         */
/*        name".CLAUSE",      where "name" is one of DO, LOOP, SELECT,        */
/*                            IF, WHEN, THEN, ELSE or OTHERWISE.              */
/*                            The expressions after IF and WHEN are prepared  */
/*                            (see the PrepareExpression method below).       */
/*        name".INSTRUCTION"  for all ooRexx instructions that are            */
/*                            not identified as clauses.                      */
/*        "END.OF.SOURCE",    returned once, at end of source (EOS).          */
/*        "IMPLICIT.EXIT.INSTRUCTION" added before every directive,           */
/*                            and before EOS                                  */
/*                                                                            */
/*   a[2] is the first element ("begin") of the delimiting semicolon pair     */
/*   a[3] is the second element ("end") of the delimiting semicolon pair      */
/*   a[4] is a n-element element array of a priori non-ignorable elements.    */
/*     1) They are "a priori non ignorable" because further analysis may      */
/*        determine that they are indeed ignorable. For example, in a DO      */
/*        clause like "DO i = 1 To 3", the blanks beyween "1" and "To" and    */
/*        between "To" and "3" are a priori non ignorable; only a full        */
/*        syntactic analysis of the DO clause can determine that "To" is      */
/*        indeed a clause (sub-)keyword, and therefore these blanks are       */
/*        in fact ignorable.                                                  */
/*     2) The array does not contain the "begin" and "end" markers. This      */
/*        means, for example, that a zero-length array will always be a       */
/*        null clause.                                                        */
/*                                                                            */
/******************************************************************************/

::Method nextClause
  Expose tokenizer begin end elements instructions lastClauseWas

  -- First pass. This applies Rexx rules, as implemented by the tokenizer,
  -- to the element sequence

  next = begin
  Loop Until next < .EL.END_OF_CLAUSE
    If next~next == .Nil Then Do
      tokenizer~nextElement
      next = result
    End
    Else next = next~next
  End

  -- We now collect the (supposedly) non-ignorable elements in an array
  self~generateElementsArray

  c = elements~items

  -- Now the clause begins at 'begin' and ends at 'end', and it has
  -- exactly 'c' non ignorable elements in between.

  -- Case 0: Null clauses
  If c == 0 Then Exit self~Null.Clause

  t1 = elements[1]

  -- Case 1: End-of-source
  If t1 < .EL.END_OF_SOURCE Then Exit self~End.Of.Source

  -- Case 2: "::" --> A directive
  If t1 < .EL.DIRECTIVE_START Then Exit self~directive

  -- Only a non-ignorable element in the clause
  If c == 1 Then Do
    -- Case 3: A keyword? It's a keyword instruction
    If t1 < .ALL.VARIABLES_AND_KEYWORDS, instructions~hasItem( t1~value ) Then
      Exit self~Keyword.Clause
    -- Case 4: Not a keyword? A command or message instruction
    Exit self~Command.Or.Message.Instruction
  End

  t2 = elements[2]

  -- Case 5: Symbol or string + colon? --> A label
  If t2 < .EL.COLON , t1 < .ALL.SYMBOLS_AND_STRINGS Then Exit self~Label.Clause

  -- Case 6: Symbol + assignment operator? --> An assignment
  If t1 < .ALL.SYMBOLS Then Do
    If \.Options.Executor, t2 < .EL.OP.STRICT.EQUAL Then Signal 35.001 -- Special case
    If t2 < .ALL.ASSIGNMENTS    Then Exit self~Assignment.Instruction
  End

  -- Case 6b: (Lua only) Lua constant + assignment operator? --> Error
  If .Options.Lua, t1 < .ALL.LUA_CONSTANTS Then Do
    If t2 < .EL.OP.STRICT.EQUAL Then Signal 35.001 -- Special case
    If t2 < .ALL.ASSIGNMENTS Then Signal 31.900
  End

  -- Case 4 (bis): Symbol + "[", "~" or "~~" -> Message instruction
  If t1 < .ALL.SYMBOLS, t2 < .ALL.OPS.MESSAGE_SEND Then
    Exit self~Command.Or.Message.Instruction

  If t1 < .ALL.VARIABLES_AND_KEYWORDS, instructions~hasItem( t1~value ) Then
    -- Case 3 (bis): keyword instructions
    Exit self~Keyword.Clause

  -- Case 4 (ter): Command or message instruction
  Exit self~Command.Or.Message.Instruction

31.900: Syntax( 31.900, t1, "Lua fail, false, nil and true cannot be assigned to")

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, t1, "==" )

/******************************************************************************/
/* generateElementsArray collects all the a priori non-ignorable elements     */
/*   between two semicolons and stores then in an array.                      */
/*   It also updates the "end" marker                                         */
/******************************************************************************/

::Method generateElementsArray
  Expose begin end elements

  elements = Array()

  next = begin
  Loop
    next = TheElementAfter( next )
  If next < .EL.END_OF_CLAUSE, next~assignment \== 1 Then Leave
    elements~append( next )
  End

  end = next

/******************************************************************************/
/* INIT                                                                       */
/*   We store the argument tokenizer, and initialize it and some few sets.    */
/*                                                                            */
/******************************************************************************/

::Method init
  Expose tokenizer begin lastClauseWas package  -
    instructions clauses directives assignments

  Use Strict Arg package

  tokenizer = .Tokenizer~new( package )

  begin = tokenizer~nextElement

  lastClauseWas = ""

  -- Keyword instructions, including some clauses like WHEN, THEN, ELSE
  -- or OTHERWISE.

  instructions = Set()

  Do keyword Over (address, arg, call, do, drop, else, end, exit, if,   -
    interpret, iterate, leave, nop, numeric, options, otherwise, parse, -
    procedure, pull, push, queue, return, say, select, signal, then,    -
    trace, when)
    instructions[] = keyword
  End

  -- The following are ooRexx-only
  Do keyword Over (expose, forward, guard, loop, raise, reply, use)
    instructions[] = keyword
  End

  -- Directives

  directives = Set()

  Do keyword Over (annotate, attribute, class, constant, -
    method, options, requires, resource, routine)
    directives[] = keyword
  End

  -- These are pure clauses (i.e., not complete instructions).
  -- The rest of the keywords produce clauses that are also instructions.

  clauses = Set()

  Do keyword Over (Do, End, Loop, Select, If, When, Then, Else, Otherwise)
    clauses[] = keyword
  End

  -- Extended assignments

  assignments = Set()

  Do seq Over ("+", "-", "*", "/", "%", "&", "|", "//", "||", "&&", "**")
    assignments[] = seq"="
  End

/******************************************************************************/
/* Common method to return clauses                                            */
/******************************************************************************/

::Method Return
  Expose begin end elements lastClauseWas
  Use Strict Arg clauseType

  lastClauseWas = clauseType

  clauseInfo = clauseType, begin, end, elements
  begin = end
  Return clauseInfo

/******************************************************************************/
/* ASSIGNMENT instructions                                                    */
/******************************************************************************/

::Method Assignment.Instruction; Return self~return( Assignment.Instruction )

/******************************************************************************/
/* END OF SOURCE                                                              */
/******************************************************************************/

::Method End.Of.Source
  Expose lastClauseWas

  If lastClauseWas \== Implicit.Exit.Instruction Then
    Exit self~Implicit.Exit.Instruction

  Return self~return( End.Of.Source )

/******************************************************************************/
/* NULL CLAUSES                                                               */
/******************************************************************************/

::Method Null.Clause;   Return self~return( Null.Clause )

/******************************************************************************/
/* IMPLICIT EXIT                                                              */
/******************************************************************************/

::Method Implicit.Exit.Instruction
  Expose begin end elements

  elements = Array()

  semicolon = InsertSemicolonAfter( begin )

  inserted = .Inserted.Implicit.Exit~after( begin )

  end = semicolon

  Return self~return( Implicit.Exit.Instruction )

/******************************************************************************/
/* DIRECTIVES                                                                 */
/******************************************************************************/

::Method directive
  Expose elements directives lastClauseWas

  If lastClauseWas \== Implicit.Exit.Instruction Then
    Exit self~Implicit.Exit.Instruction

  directive_start = elements[1]

  If elements~items == 1          Then Signal 20.916

  name = elements[2]

  If name \< .ALL.SYMBOLS       Then Signal 20.916

  If \ directives~hasItem( name~value ) Then Signal 99.916

  Call SetKeyword name, .True

  If elements~items > 2, elements[3]~isIgnorable Then elements~delete( 3 )

  Return self~return( name~value"."directive )

-- Symbol expected after ::.
20.916: Syntax( 20.916, directive_start )

-- Unrecognized directive instruction.
99.916: Syntax( 99.916, directive_start )

/******************************************************************************/
/* KEYWORD INSTRUCTIONS                                                       */
/******************************************************************************/

::Method Keyword.Clause
  Expose package begin end elements clauses

  keyword = elements[1]

  Call SetKeyword keyword

  -- keyword + blank -> ignorable blank. Recalculate elements
  If elements~items > 1, elements[2]~isIgnorable Then elements~delete( 2 )

  name = elements[1]~value

  If WordPos(name, "IF WHEN THEN ELSE OTHERWISE") > 0 Then Signal (name)

Done:
  If clauses~hasItem( name ) Then Exit self~return( name"."clause      )
  Else                            Exit self~return( name"."instruction )

THEN: ELSE: OTHERWISE:
  -- Do not insert an extra semicolon if we already have an end-of-clause
  semicolon? = TheElementAfter( keyword )
  If semicolon? < .EL.END_OF_CLAUSE Then semicolon = semicolon?
  Else semicolon = InsertSemicolonAfter( keyword )
  elements    = Array( keyword )
  end       = semicolon
  Signal Done

IF: WHEN:
  If elements~items == 1 Then Signal Done
  Call PrepareExpression package, elements[2], "THEN"

  elements = Array()
  element = TheElementAfter( begin )
  Loop
    elements~append( element )
    next = TheElementAfter( element )
  If next < .EL.END_OF_CLAUSE Then Leave
    element = next
  End
  end = next
  Signal Done

/******************************************************************************/
/* COMMAND OR MESSAGE INSTRUCTION                                             */
/******************************************************************************/

::Method Command.Or.Message.Instruction
  Expose elements

  element = elements[1]

  Call PrepareExpression package, element

  messageInstruction = IsAMessageInstruction( element )

  -- Regen element and end, because PrepareExpression and IsAMessageInstruction
  -- may have changed some elements.
  self~generateElementsArray

  If messageInstruction Then Return self~return( Message )
  Else                       Return self~return( Command )

/******************************************************************************/
/* LABEL                                                                      */
/******************************************************************************/

::Method Label.Clause
  Expose begin end elements

  label = elements[1]
  colon = elements[2]

  elements = ( label, colon )

  -- Don't insert a semicolon if we already have one
  If colon~next < .EL.END_OF_CLAUSE Then Nop
  Else end = InsertSemicolonAfter( colon )

  Return self~return( Label.Clause )

--------------------------------------------------------------------------------
-- InsertSemicolonAfter                                                       --
--------------------------------------------------------------------------------

::Routine InsertSemicolonAfter Public

  Use Strict Arg element

  Parse Value element~to With line col

  semicolon      = .Inserted.Semicolon~new(line, col)

  -- Insert it between element and element~next

  next           = element~next

  semicolon~next = next
  semicolon~prev = element
  element~next     = semicolon
  next~prev      = semicolon

  -- Apply Rexx whitespace rules
  left           = TheElementBefore( semicolon )
  right          = TheElementAfter(  semicolon )
  If left  < .ALL.WHITESPACE_LIKE Then left ~setIgnorable
  If right < .ALL.WHITESPACE_LIKE Then right~setIgnorable

  Return semicolon

--------------------------------------------------------------------------------
-- ISAMESSAGEINSTRUCTION                                                      --
--   Determines whether an expression is a command or a message instruction,  --
--   including an (extended) message term assignment (standard assignments    --
--   are processed elsewhere). The expression is supposed to have been        --
--   prepared first by the PREPAREEXPRESSION method above.                    --
--                                                                            --
--   In case we determine that this is a message instruction, we will insert  --
--   a special, temporary, semicolon, with an "~assignment" attribute,        --
--   before the assignment operator.                                          --
--------------------------------------------------------------------------------

-- "Terms are literal strings, symbols, message terms and sequences,
--  Array terms, Variable Reference terms, function calls, or subexpressions".

::Routine isAMessageInstruction

  Use Strict Arg element

  notAMessageInstruction = 0

  -- Subexpressions
  -- Parentheses balancing has been checked by PREPAREEXPRESSION
  If element < .EL.LEFT_PARENTHESIS Then Do
    Call BalanceParens
    Signal ExpectMessageOperator
  End
  -- Literal strings, symbols, and function calls
  If element < .ALL.SYMBOLS_AND_STRINGS Then Do
    element = TheElementAfter( element )
    If element < .EL.LEFT_PARENTHESIS Then Call BalanceParens
    Signal ExpectMessageOperator
  End
  -- Variable reference terms
  If element < .ALL.OPS.REFERENCE Then Do
    element = TheElementAfter( element )
    element = TheElementAfter( element )
    Signal ExpectMessageOperator
  End
  -- Array terms cannot be lhs
  Return 0

ExpectMessageOperator:
  malformed = .False
  Loop
    If element \< .ALL.OPS.MESSAGE_SEND Then
      Return notAMessageInstruction
    If element < .EL.LEFT_BRACKET Then Call BalanceBrackets
    Else Do -- ~ or ~~
      element = TheElementAfter( element )
      If element \< .ALL.SYMBOLS_AND_STRINGS Then Return malformed
      element = TheElementAfter( element )
      If element < .EL.COLON Then Do
        element = TheElementAfter( element )
        If element \< .ALL.MESSAGE_SCOPE_ELEMENTS Then Return malformed
        element = TheElementAfter( element )
      End
      If element < .EL.LEFT_PARENTHESIS Then Call BalanceParens
    End
    If element < .EL.END_OF_CLAUSE Then Return 1
    If element < .ALL.ASSIGNMENTS Then Do
      -- Insert a temporary semicolon and return 1
      Call InsertSemicolonBefore element
      element~prev~assignment = 1
      Return 1
    End
  End

BalanceParens:
  level = 0
  Loop Until level == 0
    Select Case element~category
      When .EL.LEFT_PARENTHESIS Then level += 1
      When .EL.RIGHT_PARENTHESIS Then level -= 1
      Otherwise Nop
    End
    element = TheElementAfter( element )
  End
  Return

BalanceBrackets:
  level = 0
  Loop Until level == 0
    Select Case element~category
      When .EL.LEFT_BRACKET Then level += 1
      When .EL.RIGHT_BRACKET Then level -= 1
      Otherwise Nop
    End
    element = TheElementAfter( element )
  End
  Return

::Requires "Tokenizer.cls"