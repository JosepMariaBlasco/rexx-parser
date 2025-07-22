/******************************************************************************/
/*                                                                            */
/* Clauses.cls                                                                */
/* ===========                                                                */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
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
/* 20241206    0.1  First public release                                      */
/* 20241208    0.1a Clauser: accept options arg, pass it to preclauser        */
/* 20250116    0.1f Add "assigned" attribute to variable assignment targets   */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250421    0.2b Allow optional empty assignments                          */
/*                                                                            */
/******************************************************************************/

 .environment~                  End.Of.Source =                  .End.Of.Source

 .environment~                      Do.Clause =                      .Do.Clause
 .environment~                     End.Clause =                     .End.Clause
 .environment~                    Else.Clause =                    .Else.Clause
 .environment~                      If.Clause =                      .If.Clause
 .environment~                   Label.Clause =                   .Label.Clause
 .environment~                    Loop.Clause =                    .Loop.Clause
 .environment~                    Null.Clause =                    .Null.Clause
 .environment~               Iterative.Clause =               .Iterative.Clause
 .environment~               Otherwise.Clause =               .Otherwise.Clause
 .environment~                  Select.Clause =                  .Select.Clause
 .environment~                    Then.Clause =                    .Then.Clause
 .environment~                    When.Clause =                    .When.Clause

 .environment~         Assignment.Instruction =         .Assignment.Instruction
 .environment~            Command.Instruction =            .Command.Instruction
 .environment~                 Do.Instruction =                 .Do.Instruction
 .environment~                 If.Instruction =                 .If.Instruction
 .environment~      Implicit.Exit.Instruction =      .Implicit.Exit.Instruction
 .environment~          Iterative.Instruction =          .Iterative.Instruction
 .environment~               Loop.Instruction =               .Loop.Instruction
 .environment~ Message.Assignment.Instruction = .Message.Assignment.Instruction
 .environment~            Message.Instruction =            .Message.Instruction
 .environment~             Select.Instruction =             .Select.Instruction

 .environment~              Block.Instruction =              .Block.Instruction

::Requires "BaseClassesAndRoutines.cls"
::Requires "KeywordInstructions.cls"
::Requires "Directives.cls"
::Requires "Tokenizer.cls"
::Requires "PreClauser.cls"
::Requires "Expressions.cls"

/******************************************************************************/
/******************************************************************************/
/* The CLAUSER class                                                          */
/******************************************************************************/
/******************************************************************************/

::Class Clauser Public

::Attribute tokenizer
::Attribute preClauser

/******************************************************************************/
/* INIT                                                                       */
/******************************************************************************/

::Method init
  Expose package preClauser tokenizer bufferedInstructionFragment

  Use Strict Arg package

  preClauser = .PreClauser~new( package )
  tokenizer  = preClauser~tokenizer

  bufferedInstructionFragment = .Nil

/******************************************************************************/
/* BACKTRACK                                                                  */
/******************************************************************************/

::Method backTrack
  Expose bufferedInstructionFragment

  bufferedInstructionFragment = Arg(1)

/******************************************************************************/
/* NextClause                                                                 */
/******************************************************************************/

::Method NextClause
  Expose package preClauser

  Use Strict Arg

  --
  -- The NextClause method of the PreClauser class returns an array
  -- consisting of four items:
  --
  -- array[1]: type:     is the clause type. Its value will be used to locate
  --                     the corresponding clause handling routine.
  -- array[2]: begin:    the (possibly inserted) semicolon preceding the clause
  -- array[3]: end:      the (possibly inserted) semicolon ending the clause
  -- array[4]: elements: a (possibly empty) array of elements comprised between
  --                     begin and end, without including these.
  --
  array = preClauser~nextClause

  name = array[1]

  -- Locate our routine
  routine = .context~package~findRoutine( name )

  -- This should not happen. It is here for debug purposes.
  If routine == .Nil Then Do
    Say "Routine '"name"' not found!"
    Raise HALT
  End

  array[1] = package

  -- Invoke our routine and pass all the parameters
  Return routine~callWith( array )

/******************************************************************************/
/* NEXT.INSTRUCTION.FRAGMENT                                                  */
/*   get a clause which is not a null clause, a label or a directive;         */
/*   it can be a full non-block instruction. Labels and null clauses will     */
/*   be collected and stored as attributes of the clause.                     */
/******************************************************************************/

::Method Next.Instruction.Fragment
  Expose package bufferedInstructionFragment

  Use Strict Arg

  -- This allows us to implement a very simple backtrack mechanism
  If bufferedInstructionFragment \== .Nil Then Do
    save = bufferedInstructionFragment
    bufferedInstructionFragment = .Nil
    Return save
  End

  labels      = Array()
  nullClauses = Array()

  clause      = self~nextClause

  Loop
    Select Case clause~class
      When .Label.Clause Then Do
        labels     ~append( clause )
        package~currentBody~labels~append( clause~label~value )
      End
      When  .Null.Clause Then nullClauses~append( clause )
      Otherwise Leave
    End
    clause    = self~nextClause
  End

  clause~labels      = labels
  clause~nullClauses = nullClauses

  Do i = 1 To labels~items
    labels[i]~labelFor = clause
  End

  Return clause

/******************************************************************************/
/* NEXTINSTRUCTION                                                            */
/*   Get a instruction. This can be a simple instruction (i.e., a keyword     */
/*   instruction, a message instruction or a command), or a compound or       */
/*   "block" instruction. Labels and null clauses preceding the instruction   */
/*   are collected by the "nextInstructionFragment" method and are returned   */
/*   as part of the instruction. They can be accessed using the "~labels"     */
/*   and "~nullClauses" methods.                                              */
/******************************************************************************/

::Method Next.Instruction

  Use Strict Arg ENDClauseIsOK = .False

  clause = self~Next.Instruction.Fragment

  firstElement = TheElementAfter( clause~begin )

  -- Simple, non-block clauses are automatically instructions
  If clause~isA( .Rexx.Instruction ) Then Return clause

  Select Case clause~class

    When        .Do.Clause Then Return self~Do.instruction(     clause )
    When        .If.Clause Then Return self~If.instruction(     clause )
    When      .Loop.Clause Then Return self~Loop.instruction(   clause )
    When    .Select.Clause Then Return self~Select.instruction( clause )

    When      .Then.Clause Then Signal 8.001
    When      .Else.Clause Then Signal 8.002
    When      .When.Clause Then Signal 9.001
    When .Otherwise.Clause Then Signal 9.002
    When       .End.Clause Then
      If ENDClauseIsOK     Then Return clause
      Else                      Signal 10.001
  End

-- THEN has no corresponding IF or WHEN clause.
 8.001: Syntax(  8.001, firstElement )

-- ELSE has no corresponding THEN clause.
 8.002: Syntax(  8.002, firstElement )

-- WHEN has no corresponding SELECT.
 9.001: Syntax(  9.001, firstElement )

-- OTHERWISE has no corresponding SELECT.
 9.002: Syntax(  9.002, firstElement )

-- END has no corresponding DO, LOOP, or SELECT.
10.001: Syntax( 10.001, firstElement )

/******************************************************************************/
/* DO INSTRUCTION                                                             */
/******************************************************************************/

::Method Do.Instruction
  Expose package

  Use Strict Arg doClause

  DO     = TheElementAfter( doClause~begin )
  doLine = DO~from~word(1)

  instructions = Array()

  ENDClauseIsOK = 1

  lastInstruction = doClause

  Loop
    instruction = self~Next.Instruction( ENDClauseIsOK )
    If \instruction~labels~isEmpty Then Signal 47.002
    Select Case instruction~class
      When     .End.Clause                Then Signal End.Clause
      When     .Expose.Instruction        Then Signal 99.907
      When     .Implicit.Exit.Instruction Then Signal 14.001
      Otherwise instructions~append( instruction )
    End
    lastInstruction = instruction
  End

End.Clause:
  END = TheElementAfter( instruction~begin )
  name = instruction~name
  If name \== "" Then Do
    doLabel = doClause~label
    If doLabel == ""        Then Do
      doLabel = doClause~control
      If doLabel == "" Then Signal 10.003
    End
    If name \== doLabel   Then Signal 10.002
  End
  Return .Do.Instruction~new( package, doClause, instructions, instruction )

-- Symbol following END ("&1") must match block specification name ("&2")
-- on line &3 or be omitted.
10.002: Syntax( 10.002, END, name, doLabel, doLine )

-- END corresponding to block on line &2 must not have a symbol
-- following it because there is no LABEL or control variable; found "&1".
10.003: Syntax( 10.003, END, doLine, name )

-- DO instruction on line &1 requires matching END.
14.001: Syntax( 14.001, instruction~end, doLine )

-- Labels are not allowed within a DO/LOOP block; found "&1".
47.002: Syntax( 47.002, instruction~end, instruction~labels[1]~label )

-- EXPOSE must be the first instruction executed after a method invocation.
99.907: Syntax( 99.907, TheElementAfter(instruction~begin) )

/******************************************************************************/
/* IF INSTRUCTION                                                             */
/******************************************************************************/

::Method If.Instruction
  Expose package

  Use Strict Arg ifClause

  IF = TheElementAfter( ifClause~begin )

  thenClause = self~Next.Instruction.Fragment

  THEN = TheElementAfter( thenClause~begin )

  If \thenClause~isA( .Then.Clause ) Then Signal 18.001

  Call NoLabels thenClause

  thenInstruction = self~Next.Instruction

  Call NoLabels thenInstruction

  Select Case thenInstruction~class
    When .Implicit.Exit.Instruction Then Signal 14.003
    When .Expose.Instruction Then Call 99.907 thenInstruction
    Otherwise Nop
  End

  elseClause = self~Next.Instruction.Fragment

  If \elseClause~isA(.Else.Clause) Then Do
    self~backTrack( elseClause )
    Return .If.Instruction~new(                      -
      package, ifClause, thenClause, thenInstruction -
    )
  End

  Call NoLabels elseClause

  ELSE = TheElementAfter( elseClause~begin )

  elseInstruction = self~Next.Instruction

  Call NoLabels elseInstruction

  Select Case elseInstruction~class
    When .Implicit.Exit.Instruction Then Signal 14.004
    When .Expose.Instruction Then Call 99.907 elseInstruction
    Otherwise Nop
  End

  Return .If.Instruction~new(    -
    package, ifClause,           -
    thenClause, thenInstruction, -
    elseClause, elseInstruction  -
  )

NoLabels:
  If \Arg(1)~labels~isEmpty Then Call 47.003 Arg(1)
  Return

-- THEN on line &1 must be followed by an instruction.
14.003: Syntax( 14.003, THEN, IF~from~word(1) )

-- ELSE on line &1 must be followed by an instruction.
14.004: Syntax( 14.004, ELSE, ELSE~from~word(1) )

-- IF instruction on line &1 requires matching THEN clause.
18.001: Syntax( 18.001, THEN, Word(IF~from, 1) )

-- Labels are not allowed within an IF block; found "&1".
47.003: Syntax( 47.003, arg(1)~begin, Arg(1)~labels[1]~label )

-- EXPOSE must be the first instruction executed after a method invocation.
99.907: Syntax( 99.907, TheElementAfter(Arg(1)~begin) )

/******************************************************************************/
/* LOOP INSTRUCTION                                                           */
/******************************************************************************/

::Method Loop.Instruction
  Expose package

  Use Strict Arg loopClause

  LOOP     = TheElementAfter( loopClause~begin )
  loopLine = LOOP~from~word(1)

  instructions = Array()

  ENDClauseIsOK = 1

  lastInstruction = loopClause

  Loop
    instruction = self~Next.Instruction( ENDClauseIsOK )
    If \instruction~labels~isEmpty Then Signal 47.002
    Select Case instruction~class
      When     .End.Clause                Then Signal End.Clause
      When     .Expose.Instruction        Then Signal 99.907
      When     .Implicit.Exit.Instruction Then Signal 14.005
      Otherwise instructions~append( instruction )
    End
    lastInstruction = instruction
  End

End.Clause:
  END = TheElementAfter(instruction~begin)
  name = instruction~name
  If name \== "" Then Do
    loopLabel = loopClause~label
    If loopLabel == ""        Then Do
      loopLabel = loopClause~control
      If loopLabel == "" Then Signal 10.003
    End
    If name \== loopLabel   Then Signal 10.002
  End
  Return .Loop.Instruction~new( package, loopClause, instructions, instruction )

-- Symbol following END ("&1") must match block specification name ("&2")
-- on line &3 or be omitted.
10.002: Syntax( 10.002, END, name, loopLabel, loopLine )

-- END corresponding to block on line &2 must not have a symbol
-- following it because there is no LABEL or control variable; found "&1".
10.003: Syntax( 10.003, END, loopLine, name )

-- DO or LOOP instruction on line &1 requires matching END.
14.005: Syntax( 14.005, instruction~end, LOOP~from~word(1) )

-- Labels are not allowed within a DO/LOOP block; found "&1".
47.002: Syntax( 47.002, instruction~end, instruction~labels[1]~label )

-- EXPOSE must be the first instruction executed after a method invocation.
99.907: Syntax( 99.907, TheElementAfter(instruction~begin) )

/******************************************************************************/
/* SELECT INSTRUCTION                                                         */
/******************************************************************************/

::Method Select.Instruction
  Expose package

  Use Strict Arg selectClause

  SELECT               = TheElementAfter( selectClause~begin )
  selectLine           = SELECT~from~word(1)

  whenThenInstructions = Array()

  otherwiseClause      = .Nil

  otherwiseSequence    = Array()

  whenClause = self~Next.Instruction.Fragment

  Call NoLabels whenClause

  If  whenClause~isA( .End.Clause  ) Then Signal 7.001

  If \whenClause~isA( .When.Clause ) Then Call   7.002 whenClause

  WHEN = TheElementAfter( whenClause~begin )

  Loop

    thenClause = self~next.Instruction.Fragment

    Call NoLabels thenClause

    If \thenClause~isA(.Then.Clause) Then Signal 18.002

    THEN     = TheElementAfter( thenClause~begin )
    thenLine = THEN~from~word(1)

    thenInstruction = self~Next.Instruction

    Call NoLabels thenInstruction

    Select Case thenInstruction~class
      When .Implicit.Exit.Instruction Then Signal 14.003
      When .Expose.Instruction Then Call 99.907 thenInstruction
      Otherwise Nop
    End

    whenThenInstructions~append( (whenClause, thenClause, thenInstruction) )

    next = self~Next.Instruction.Fragment

    Select Case next~class
      When .When.Clause               Then whenClause = next
      When .Otherwise.Clause          Then Signal Otherwise
      When .End.Clause                Then Signal End
      When .Implicit.Exit.Instruction Then Signal 14.002
      Otherwise                            Call    7.002 next
    End

    Call NoLabels whenClause

    WHEN = TheElementAfter( whenClause~begin )

  End

Otherwise:

  ENDClauseIsOK   = 1
  otherwiseClause = next
  Call NoLabels otherwiseClause
  OTHERWISE       = TheElementAfter( otherwiseClause~begin )
  otherwiseLine   = OTHERWISE~from~word(1)

  last            = otherwiseClause

  Loop
    next = self~Next.Instruction( ENDClauseIsOK )
    Call NoLabels next
    Select Case next~class
      When .End.Clause Then Signal End
      When .Implicit.Exit.Instruction Then Signal 14.901
      When .Expose.Instruction Then Call 99.907 next
      Otherwise otherwiseSequence~append( next )
    End
    last = next
  End

End:
  END = TheElementAfter( next~begin )
  name = next~name
  If name \== "" Then Do
    selectLabel = selectClause~label
    If selectLabel == ""    Then Signal 10.007
    If name \== selectLabel Then Signal 10.004
  End

  Return .Select.Instruction~new( -
    package,                      -
    selectClause,                 -
    whenThenInstructions,         -
    otherwiseClause,              -
    otherwiseSequence,            -
    next                          -
  )

NoLabels:
  If \Arg(1)~labels~isEmpty Then Call 47.004 Arg(1)
  Return

-- SELECT on line &1 requires WHEN.
 7.001: Syntax(  7.001, SELECT, selectLine )

-- SELECT on line &1 requires WHEN, OTHERWISE, or END.
 7.002: Syntax(  7.002, TheElementAfter( Arg(1)~begin ), selectLine )

-- Symbol following END ("&1") must match LABEL of SELECT specification
-- ("&2") on line &3 or be omitted.
10.004: Syntax( 10.004, END, name, selectLabel, selectLine )

-- END corresponding to SELECT on line &2 must not have a symbol
-- following it because there is no LABEL; found "&1".
10.007: Syntax( 10.007, END, selectLine, name )

-- SELECT instruction on line &1 requires matching END.
14.002: Syntax( 14.002, next~end , selectLine )

-- THEN on line &1 must be followed by an instruction.
14.003: Syntax( 14.003, THEN, WHEN~from~word(1)  )

-- OTHERWISE on line &1 requires matching END.
14.901: Syntax( 14.901, TheElementAfter(next~begin), otherwiseLine )

-- WHEN instruction on line &1 requires matching THEN clause.
18.002: Syntax( 18.002, TheElementAfter(thenClause~begin), WHEN~from~word(1) )

-- Labels are not allowed within a SELECT block; found "&1".
47.004: Syntax( 47.004, Arg(1)~end, Arg(1)~labels[1]~label )

-- EXPOSE must be the first instruction executed after a method invocation.
99.907: Syntax( 99.907, TheElementAfter(Arg(1)~begin) )

/******************************************************************************/
/******************************************************************************/
/* Clause processing                                                          */
/*                                                                            */
/*   See Directives.cls for directive clauses and KeywordInstructions.cls     */
/*   for simple (i.e., non-block) instruction clauses.                        */
/*                                                                            */
/*   This package section contains code to process                            */
/*     Assignments (classical, i.e., non message)                             */
/*     Commands                                                               */
/*     DO clauses (not the whole instruction!)                                */
/*     ELSE clauses                                                           */
/*     END clauses                                                            */
/*     The END-OF-SOURCE clause                                               */
/*     IF clauses (not the whole instruction!)                                */
/*     The implicit EXIT clause, generated automatically before each          */
/*       directive and before end of source                                   */
/*     Iterative clauses (code common to DO and LOOP)                         */
/*     Labels                                                                 */
/*     LOOP clauses (not the whole instruction!)                              */
/*     Message clauses (including message assignments)                        */
/*     Null clauses                                                           */
/*     THEN clauses                                                           */
/*     OTHERWISE clauses                                                      */
/*     SELECT clauses                                                         */
/*     WHEN clauses                                                           */
/*                                                                            */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/* ASSIGNMENT instruction                                                     */
/******************************************************************************/

::Routine Assignment.Instruction Public
  Use Strict Arg package, begin, end, elements

  variable = elements[1]

  variable~setAssigned

  symbol = Symbol.Term( package, variable, .ALL.ASSIGNMENTS )

  operator = elements[2]

  If operator < .EL.OP.EQUAL Then
    Call SetCategory operator, .EL.ASG.EQUAL

  element = TheElementAfter( operator ) -- Start parsing here...

  Call PrepareExpression element

  expression = Expression.List( package, element, .EL.END_OF_CLAUSE )

  -- Allow empty assignments when the "emptyassignments" option
  -- has been specified with a value of "1".
  If expression~isEmpty Then Do
    If Global.Option("emptyassignments") == 1 Then Nop
    Else Signal 35.918
  End

  Return .Assignment.Instruction~new(                 -
    package, begin, end, symbol, operator, expression -
  )

-- Missing expression following assignment instruction.
35.918: Syntax( 35.918, elements[1] )

--------------------------------------------------------------------------------

::Class Assignment.Instruction Public SubClass Rexx.Instruction
::Attribute symbol     Get
::Attribute operator   Get
::Attribute expression Get
::Method init
  Expose symbol operator expression
  Use Strict Arg package, begin, end, symbol, operator, expression
  self~init:super( package, begin, end )

/******************************************************************************/
/* COMMAND                                                                    */
/******************************************************************************/

::Routine Command Public
  Use Strict Arg package, begin, end, elements

  ignoreBlanks = .True

  element = TheElementAfter( begin )

  -- The command expression has been prepared by the preclauser

  expression = Expression.List( package, element )

  Return .Command.Instruction~new( package, begin, end, expression )

--------------------------------------------------------------------------------

::Class Command.Instruction Public SubClass Rexx.Instruction
::Attribute expression Get
::Method init
  Expose expression
  Use Strict Arg package, begin, end, expression
  self~init:super( package, begin, end )

/******************************************************************************/
/* DO Clause                                                                  */
/******************************************************************************/

::Routine Do.Clause Public
  Use Strict Arg package, begin, end, elements
  Return Iterative.Clause( package, .Do.Clause, begin, end, elements )

--------------------------------------------------------------------------------

::Class Do.Clause Public SubClass Iterative.Clause
::Constant InstructionName "DO"

/******************************************************************************/
/* ELSE CLAUSE                                                                */
/******************************************************************************/

::Routine Else.Clause Public
  Use Strict Arg package, begin, end, elements

  Return .Else.Clause~new( package, begin, end )

--------------------------------------------------------------------------------

::Class Else.Clause Public SubClass Rexx.Clause

/******************************************************************************/
/* END Clause                                                                 */
/******************************************************************************/

::Routine End.Clause Public

  Use Strict Arg package, begin, end, elements

  ENDKeyword = elements[1]

  name         = TheElementAfter( ENDKeyword )
  options.     = .False
  ignoreBlanks = .True

  end = name
  If name < .EL.END_OF_CLAUSE Then Signal Done

  If name \< .ALL.SYMBOLS Then Signal 20.909
  Call SetConstantName name, .BLOCK.INSTRUCTION.NAME

  options.["NAME"] = name~value

  element = TheElementAfter( name, ignoreBlanks )

  end = element
  If element \< .EL.END_OF_CLAUSE Then Signal 21.909

Done:
  blockInstructionsStack = package~blockInstructionsStack
  If blockInstructionsStack~items == 0 Then Signal 10.001
  blockInstructionsStack~delete( blockInstructionsStack~last )
  Return .End.Clause~new( package, begin, end, options. )

-- END has no corresponding DO, LOOP, or SELECT.
10.001: Syntax( 10.001, ENDKeyword )

-- Symbol expected after END keyword.
20.909: Syntax( 20.909, ENDKeyword )

-- Data must not follow the END name; found "&1".
21.909: Syntax( 21.909, ENDKeyword, element )

--------------------------------------------------------------------------------

::Class End.Clause Public SubClass Rexx.Clause
::Attribute name Get
::Method init
  Expose name options.
  Use Strict Arg package, begin, end, options.
  name = ""
  If options.~hasIndex("NAME") Then name = options.["NAME"]
  self~init:super( package, begin, end )

/******************************************************************************/
/* END OF SOURCE                                                              */
/******************************************************************************/

::Routine End.Of.Source Public
  Use Strict Arg package, begin, end, elements

  Return .End.Of.Source~new( package, begin, end )

--------------------------------------------------------------------------------

::Class End.Of.Source Public SubClass Null.Clause

/******************************************************************************/
/* IF Clause                                                                  */
/******************************************************************************/

::Routine If.Clause Public

  Use Strict Arg package, begin, end, elements

  IF = elements[1]

  element = TheElementAfter( IF )  -- Start parsing here...
  terminators  = .EL.END_OF_CLAUSE       -- ";" terminates parsing

  -- The expression has already been prepared by the preparser

  expressionList = Expression.List( package, element, terminators, "logical" )

  end = expressionList~end

  Return .If.Clause~new( package, begin, end, expressionList )

--------------------------------------------------------------------------------

::Class If.Clause Public SubClass Rexx.Clause
::Attribute expressionList
::Method init
  Expose expressionList
  Use Strict Arg package, begin, end, expressionList
  self~init:super( package, begin, end )

/******************************************************************************/
/* IMPLICIT EXIT INSTRUCTION                                                  */
/******************************************************************************/

::Routine Implicit.Exit.Instruction Public
  Use Strict Arg package, begin, end, elements

  Return .Implicit.Exit.Instruction~new( package, begin, end )

--------------------------------------------------------------------------------

::Class Implicit.Exit.Instruction Public SubClass Rexx.Instruction

/******************************************************************************/
/* ITERATIVE.CLAUSE                                                           */
/*   Code common to the DO and LOOP clauses                                   */
/******************************************************************************/

::Routine Iterative.Clause

  Use Strict Arg package, class, begin, end, elements

  keyword = elements[1]

  ignoreBlanks = .True
  options.     = .False
  conditional  = 0

  element   = TheElementAfter( keyword )
  If element < .EL.END_OF_CLAUSE Then Signal Done

  next    = TheElementAfter( element, ignoreBlanks )

  label   = 0
  counter = 0

Continue:
  If element < .EL.END_OF_CLAUSE Then Signal Done
  If element < .ALL.SYMBOLS Then Do
    tValue = element~value
    If next < .EL.OP.EQUAL           Then Signal "Classic Do/Loop"
    If \label,   tValue == "LABEL"   Then Signal "Label option"
    If \counter, tValue == "COUNTER" Then Signal "Counter option"
    If next < .ALL.SYMBOLS Then Do
      Select Case next~value
        When "OVER"                  Then Signal "Do/Loop ... Over"
        When "ITEM", "INDEX"         Then
          If tValue == "WITH"        Then Signal "Do/Loop With ...  Over"
        Otherwise Nop
      End
    End
    Select Case tValue
      When "FOREVER"                 Then Signal "Do/Loop Forever"
      When "WHILE"                   Then Signal "Do/Loop While"
      When "UNTIL"                   Then Signal "Do/Loop Until"
      Otherwise Nop
    End
  End

  Signal                                         "Simple Repetitive Do/Loop"

"Classic Do/Loop":
  Call ControlVariable
  Call SetCategory next, .EL.ASG.EQUAL
  element = TheElementAfter( next, ignoreBlanks ) -- Consume "="
  Call PrepareExpression element, "TO BY FOR WHILE UNTIL"
  expression = Expression.List( package, element )
  If expression~isEmpty Then Signal 35.904
  options.["="] = expression
  seen. = 0
  Loop
    element = expression~end
    If element < .EL.END_OF_CLAUSE Then Signal Done
    tValue = element~value
    Select Case tValue
      When "WHILE" Then Signal "Do/Loop While"
      When "UNTIL" Then Signal "Do/Loop Until"
      Otherwise Do
        If seen.tValue Then Call 27.902 tValue
        seen.tValue = 1
        Call SetSubkeyword element
        element = TheElementAfter( element )
        Call PrepareExpression element, "TO BY FOR WHILE UNTIL"
        expression = Expression.List( package, element )
        element = expression~end
        If expression~isEmpty Then Select Case tValue
          When "BY"  Then Signal 35.905
          When "TO"  Then Signal 35.906
          When "FOR" Then Signal 35.907
        End
        options.tValue = expression
      End
    End
  End
  Signal Conditional

"Do/Loop ... Over":
  Call SetSubkeyword next
  Call ControlVariable
  element = TheElementAfter( next, ignoreBlanks ) -- Consume "OVER"
  Call PrepareExpression element, "FOR WHILE UNTIL"
  expression = Expression.List( package, element )
  If expression~isEmpty Then Signal 35.911
  options.over = expression
  for = 0
  Loop
    element = expression~end
    If element < .EL.END_OF_CLAUSE Then Signal Done
    tValue = element~value
    Select Case tValue
      When "WHILE" Then Signal "Do/Loop While"
      When "UNTIL" Then Signal "Do/Loop Until"
      Otherwise Do
        If for Then Call 27.902 "FOR"
        for = 1
        Call SetSubkeyword element
        element = TheElementAfter( element )
        Call PrepareExpression element, "FOR WHILE UNTIL"
        expression = Expression.List( package, element )
        element = expression~end
        If expression~isEmpty Then Signal 35.907
        options.["FOR"] = expression
      End
    End
  End

"Simple Repetitive Do/Loop":
  Call PrepareExpression element, "WHILE UNTIL"
  expression = Expression.List( package, element )
  options.simple = expression
  element = expression~end
  Signal Conditional

ControlVariable:
  c = Left( element~value, 1 )
  If c == "."             Then Call 31.003 element
  If c >>= "0", c <<= "9" Then Call 31.002 element
  options.control = element
  element~setAssigned
  Return

Conditional:
  If element < .EL.END_OF_CLAUSE Then Signal Done

  If Keyword(element, "WHILE"    ) Then Signal "Do/Loop While"
  If Keyword(element, "UNTIL"    ) Then Signal "Do/Loop Until"

"Do/Loop While":
  If conditional Then Signal 27.001
  Call SetSubkeyword element
  element = TheElementAfter( element )
  Call PrepareExpression element, "WHILE UNTIL"
  expression = Expression.List( package, element, "", "logical" )
  options.while = expression
  element = expression~end
  conditional = 1
  Signal Conditional

"Do/Loop Until":
  If conditional Then Signal 27.001
  Call SetSubkeyword element
  element = TheElementAfter( element )
  Call PrepareExpression element, "WHILE UNTIL"
  expression = Expression.List( package, element, "", "logical" )
  options.until = expression
  element = expression~end
  conditional = 1
  Signal Conditional

Done:
  If options.~hasIndex("COUNTER") Then Do
    If options.~items == 1 Then Signal 27.905
    If options.~items == 2, options.~hasIndex("LABEL") Then Signal 27.905
  End
  iteration = class~new( package, begin, element, options. )
  package~blockInstructionsStack~append( iteration )
  Return iteration

Keyword:
  If Arg(1) \< .ALL.VARIABLES_AND_KEYWORDS Then Return .False
  If Arg(1)~value \== Arg(2)   Then Return .False
  Call SetSubkeyword Arg(1)
  Return .True

"Label option":
  label = 1
  Call SetSubkeyword element
  labelName = next
  If labelName \< .ALL.SYMBOLS Then Signal 20.918
  Call SetConstantName labelName, .BLOCK.INSTRUCTION.NAME
  options.["LABEL"] = labelName~value
  element = TheElementAfter( labelName, ignoreBlanks )
  If element < .EL.END_OF_CLAUSE Then Signal Continue
  next  = TheElementAfter( element    , ignoreBlanks )
  Signal Continue

"Counter option":
  counter = 1
  Call SetSubkeyword element
  counterVar = next
  If counterVar \< .ALL.SYMBOLS Then Signal 20.934
  c = Left( counterVar~value, 1 )
  If c == "."             Then Call 31.003 counterVar
  If c >>= "0", c <<= "9" Then Call 31.002 counterVar
  counterVar~setAssigned
  options.["COUNTER"] = counterVar
  element = TheElementAfter( counterVar, ignoreBlanks )
  If element < .EL.END_OF_CLAUSE Then Signal Continue
  next  = TheElementAfter( element     , ignoreBlanks )
  Signal Continue

"Do/Loop Forever":
  Call SetSubkeyword element
  options.forever = 1
  element = next
  If element  < .EL.END_OF_CLAUSE Then Signal Done
  If element \< .ALL.VAR_SYMBOLS                    Then Signal 27.901
  If WordPos( element~value, "WHILE UNTIL" ) == 0   Then Signal 27.901
  Signal Conditional

"Do/Loop With ...  Over":
  Call SetSubkeyword element
  Call SetSubkeyword next
  element = next
  index = 0
  item  = 0
  for   = 0
  Loop
    If element \< .ALL.VARIABLES_AND_KEYWORDS              Then Signal 27.904
    tValue = element~value
    If WordPos( tValue, "ITEM INDEX OVER" ) == 0  Then Signal 27.904
    Call SetSubkeyword element
  If tvalue == "OVER" Then Leave
    If tValue == "ITEM" Then Do
      If item Then Call 27.902 tValue
      item = 1
    End
    Else Do
      If index Then Call 27.902 tValue
      index = 1
    End
    element = TheElementAfter( element  )
    If element \< .ALL.SYMBOLS Then Call 20.929 tValue
    c = Left( element~value, 1 )
    If c == "."             Then Call 31.003 element
    If c >>= "0", c <<= "9" Then Call 31.002 element
    element~setAssigned
    options.tValue = element
    element = TheElementAfter( element, ignoreBlanks )
  End
  element = TheElementAfter( element )
  Call PrepareExpression element, "FOR WHILE UNTIL"
  expression = Expression.List( package, element )
  If expression~isEmpty Then Signal 35.911
  options.over = expression
  element = expression~end
  If element < .ALL.SYMBOLS_AND_KEYWORDS, element~value == "FOR" Then Do
    Call SetSubkeyword element
    element = TheElementAfter( element )
    Call PrepareExpression element, "FOR WHILE UNTIL"
    expression = Expression.List( package, element )
    If expression~isEmpty Then Signal 35.907
    options.["FOR"] = expression
    element = expression~end
    If element < .ALL.SYMBOLS_AND_KEYWORDS, element~value == "FOR" Then
      Call 27.902 element
  End
  Signal Conditional

-- Symbol expected after LABEL keyword.
20.918: Syntax( 20.918, keyword )

-- Symbol expected after &1 keyword.
20.929: Syntax( 20.929, keyword, Arg(1) )

-- Symbol expected after COUNTER keyword.
20.934: Syntax( 20.934, keyword )

-- Only one WHILE or UNTIL condition can be used on the same loop.
27.001: Syntax( 27.001, keyword, element )

-- Incorrect data following FOREVER keyword on the loop; found "&1".
27.901: Syntax( 27.901, keyword, element )

-- DO or LOOP keyword &1 can be specified only once.
27.902: Syntax( 27.902, keyword, Arg(1) )

-- OVER keyword expected for a WITH loop.
27.904: Syntax( 27.904, keyword )

-- COUNTER keyword not allowed on a simple DO instruction.
27.905: Syntax( 27.905, keyword )

-- Variable symbol must not start with a number; found "&1".
31.002: Syntax( 31.002, keyword, Arg(1) )

-- Variable symbol must not start with a "."; found "&1".
31.003: Syntax( 31.003, keyword, Arg(1) )

-- Missing initial expression for DO or LOOP control variable.
35.904: Syntax( 35.904, keyword )

-- Missing expression following BY keyword.
35.905: Syntax( 35.905, keyword )

-- Missing expression following TO keyword.
35.906: Syntax( 35.906, keyword )

-- Missing expression following FOR keyword.
35.907: Syntax( 35.907, keyword )

-- Missing expression following OVER keyword.
35.911: Syntax( 35.911, keyword )

--------------------------------------------------------------------------------

::Class Iterative.Clause Public SubClass Rexx.Clause
::Attribute label   Get
::Attribute counter Get
::Attribute control Get
::Attribute while   Get
::Attribute until   Get
::Attribute type    Get
::Method init
  Expose label counter control while until type options.
  Use Strict Arg package, begin, end, options.
  label   = ""
  counter = ""
  control = ""
  until   = .Nil
  while   = .Nil
  count   = 0
  type    = ""

  -- Count LABEL and COUNTER
  If HasOption("label")   Then Do
    count  += 1
    label   = Option("label")
  End
  If HasOption("counter") Then Do
    count  += 1
    counter = Option("counter")
  End

  -- Control variable
  If HasOption("control") Then control = Option("control")

  -- Compute the loop type
  Select Case options.~items - count
    When 0 Then type = "simple"
    When 1 Then
      Select
        When HasOption("while") Then Do
          type = "while"
          while = Option("while")
        End
        When HasOption("until") Then Do
          type = "until"
          until = Option("until")
        End
        Otherwise Nop
      End
    Otherwise Nop
  End
  self~init:super( package, begin, end )
  Return

HasOption: Return options.~hasIndex(Upper(Arg(1)))
Option:    Return options.[         Upper(Arg(1))]

/******************************************************************************/
/* LABEL                                                                      */
/******************************************************************************/

::Routine Label.Clause Public
  Use Strict Arg package, begin, end, elements

  label = elements[1]

  Call SetConstantName label, .LABEL.NAME

  Return .Label.Clause~new( package, begin, end, label )

--------------------------------------------------------------------------------

::Class Label.Clause Public SubClass Rexx.Clause
::Attribute labelFor
::Attribute label
::Method init
  Expose label labelFor
  Use Strict Arg package, begin, end, label
  labelFor = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* LOOP Clause                                                              */
/******************************************************************************/

::Routine Loop.Clause Public
  Use Strict Arg package, begin, end, elements
  Return Iterative.Clause( package, .LOOP.Clause, begin, end, elements )

--------------------------------------------------------------------------------

::Class Loop.Clause Public SubClass Iterative.Clause
::Constant InstructionName "LOOP"

/******************************************************************************/
/* MESSAGE                                                                    */
/******************************************************************************/

::Routine Message Public
  Use Strict Arg package, begin, end, elements

  ignoreBlanks = .True

  element = TheElementAfter( begin )

  -- The expression has already been prepared by the preparser

  expression = Expression.List( package, element )

  element = expression~end

  If element~assignment \== 1 Then Signal Message.Instruction

-- The IsAMessageInstruction routine will have inserted
-- a dummy semicolon to  facilitate parsing. We will remove it now.
MessageAssignment:
  elements[1]~setAssigned
  lhs           = expression
  semicolon     = expression~end
  next          = TheElementAfter( semicolon )
  Call RemoveElement semicolon
  expression~end = next
  operator       = next
  If operator < .EL.OP.EQUAL Then
    Call SetCategory operator, .EL.ASG.EQUAL
  element          = TheElementAfter( operator )
  If element < .EL.END_OF_CLAUSE Then Signal 35.001
  rhs = Expression.List( package, element )
  Return .Message.Assignment.Instruction~new( -
    package, begin, end, lhs, operator, rhs   -
  )

Message.Instruction:
  Return .Message.Instruction~new( package, begin, end, expression )

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, operator, operator )

--------------------------------------------------------------------------------

::Class Message.Instruction Public SubClass Rexx.Instruction
::Attribute expression
::Method init
  Expose expression
  Use Strict Arg package, begin, end, expression
  self~init:super( package, begin, end)

--------------------------------------------------------------------------------

::Class Message.Assignment.Instruction Public SubClass Rexx.Instruction
::Attribute lhs      Get
::Attribute operator Get
::Attribute rhs      Get
::Method init
  Expose lhs operator rhs
  Use Strict Arg package, begin, end, lhs, operator, rhs
  self~init:super( package, begin, end )

/******************************************************************************/
/* NULL CLAUSE                                                                */
/******************************************************************************/

::Routine Null.Clause Public
  Use Strict Arg package, begin, end, elements

  Return .Null.Clause~new( package, begin, end )

--------------------------------------------------------------------------------

::Class Null.Clause Public SubClass Rexx.Clause

/******************************************************************************/
/* THEN Clause                                                                */
/******************************************************************************/

::Routine Then.Clause Public
  Use Strict Arg package, begin, end, elements
  Return .Then.Clause~new( package, begin, end )

--------------------------------------------------------------------------------

::Class Then.Clause Public SubClass Rexx.Clause

/******************************************************************************/
/* OTHERWISE Clause                                                           */
/******************************************************************************/

::Routine Otherwise.Clause Public
  Use Strict Arg package, begin, end, elements

  OTHERWISE = elements[1]

  Call SetKeyword OTHERWISE

  Return .Otherwise.Clause~new( package, begin, end )

--------------------------------------------------------------------------------

::Class Otherwise.Clause Public SubClass Rexx.Clause

/******************************************************************************/
/* SELECT Clause                                                              */
/******************************************************************************/

::Routine Select.Clause Public

  Use Strict Arg package, begin, end, elements

  SELECT = elements[1]

  Call SetKeyword SELECT

  ignoreBlanks = .True
  options.     = .False

  element = TheElementAfter( SELECT )

  If element  < .EL.END_OF_CLAUSE   Then Signal Done

  If element \< .ALL.VAR_SYMBOLS    Then Signal 25.923

  kValue = element~value
  If Pos(kValue, "LABEL CASE") == 0 Then Signal 25.923

  Call SetSubkeyword element

  If kValue == "LABEL" Then Do
    element = TheElementAfter( element )
    If element \< .ALL.SYMBOLS Then Signal 20.918
    Call SetConstantName element, .BLOCK.INSTRUCTION.NAME
    options.label = element~value
    element = TheElementAfter( element, ignoreBlanks )
  End

  If element < .EL.END_OF_CLAUSE Then Signal Done

  If element \< .ALL.VARIABLES_AND_KEYWORDS Then Signal 25.923

  If element~value \== "CASE"   Then Signal 25.923

  Call SetSubkeyword element

  element = TheElementAfter( element, ignoreBlanks )

  If element < .EL.END_OF_CLAUSE Then Signal 35.933

  Call PrepareExpression element
  options.case = Expression.List( package, element )

Done:
  selectClause = .Select.Clause~new( package, begin, element, options. )
  package~blockInstructionsStack~append( selectClause )
  Return selectClause

-- Symbol expected after LABEL keyword.
20.918: Syntax( 20.918, SELECT )

-- SELECT must be followed by the keyword LABEL or CASE; found "&1".
25.923: Syntax( 25.923, SELECT, element )

-- Missing expression following CASE keyword of a SELECT instruction.
35.933: Syntax( 35.933, SELECT )

--------------------------------------------------------------------------------

::Class Select.Clause Public SubClass Rexx.Clause
::Attribute label Get
::Attribute case  Get
::Method init
  Expose label case options.
  Use Strict Arg package, begin, end, options.
  label = ""
  case  = .Nil

  If options.~hasIndex("LABEL") Then label = options.["LABEL"]
  If options.~hasIndex("CASE")  Then case  = options.["CASE"]

  self~init:super( package, begin, end )

/******************************************************************************/
/* WHEN Clause                                                                  */
/******************************************************************************/

::Routine When.Clause
  Use Strict Arg package, begin, end, elements

  WHEN = elements[1]

  Call SetKeyword WHEN

  element = TheElementAfter( WHEN )

  Call PrepareExpression element, "THEN"

  expression = Expression.List(package, element, .EL.END_OF_CLAUSE, "logical")

  Return .When.Clause~new( package, begin, end, expression )

--------------------------------------------------------------------------------

::Class When.Clause Public SubClass Rexx.Clause
::Attribute expressionList Get
::Method init
  Expose expressionList
  Use Strict Arg package, begin, end, expressionList
  self~init:super( package, begin, end )

/******************************************************************************/
/******************************************************************************/
/* Classes supporting block instructions                                      */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/* Methods common to all block instructions                                   */
/******************************************************************************/

::Class Block.Instruction Public SubClass Rexx.Instruction
::Constant isBlockInstruction 1

/******************************************************************************/
/* Methods common to Do.Instruction and Loop.Instruction                      */
/******************************************************************************/

::Class Iterative.Instruction Public SubClass Block.Instruction

/******************************************************************************/
/* DO Instruction                                                             */
/******************************************************************************/

::Class Do.Instruction Public SubClass Iterative.Instruction
::Attribute doClause
::Attribute instructions
::Attribute endClause
::Method init
  Expose doClause  instructions  endClause
  Use Strict Arg package, doClause, instructions, endClause
  self~init:super(package, doClause~begin, endClause~end)
::Method labels
  Expose doClause
  Return doClause~labels
::Method nullClauses
  Expose doClause
  Return doClause~nullClauses

/******************************************************************************/
/* IF Instruction                                                             */
/******************************************************************************/

::Class If.Instruction Public SubClass Block.Instruction
::Method labels
  Expose ifClause
  Return ifClause~labels
::Method nullClauses
  Expose ifClause
  Return ifClause~nullClauses
::Attribute ifClause        Get
::Attribute thenClause      Get
::Attribute thenInstruction Get
::Attribute elseClause      Get
::Attribute elseInstruction Get
::Method init
  Expose ifClause thenClause thenInstruction elseClause elseInstruction
  Use Strict Arg package,                      -
    ifClause,                                  -
    thenClause,        thenInstruction,        -
    elseClause = .Nil, elseInstruction = .Nil
  If elseInstruction~isNil Then
    self~init:super( package, ifClause~begin, thenInstruction~end )
  Else
    self~init:super( package, ifClause~begin, elseInstruction~end )

/******************************************************************************/
/* LOOP Instruction                                                           */
/******************************************************************************/

::Class Loop.Instruction Public SubClass Iterative.Instruction
::Attribute loopClause
::Method doClause -- Simplifies code
  Return self~loopClause
::Attribute instructions
::Attribute endClause
::Method init
  Expose loopClause instructions endClause
  Use Strict Arg package, loopClause, instructions, endClause
  self~init:super( package, loopClause~begin, endClause~end )
::Method labels
  Expose loopClause
  Return loopClause~labels
::Method nullClauses
  Expose loopClause
  Return loopClause~nullClauses

/******************************************************************************/
/* SELECT Instruction                                                         */
/******************************************************************************/

::Class Select.Instruction Public SubClass Block.Instruction

::Attribute SelectClause           Get
::Attribute   WhenThenInstructions Get
::Attribute   OtherwiseClause      Get
::Attribute     OtherwiseSequence  Get
::Attribute EndClause              Get

::Method init
  Expose                    -
    selectClause            -
      whenThenInstructions  -
      otherwiseClause       -
        otherwiseSequence   -
    endClause
  Use Strict Arg            -
    package,                -
    selectClause,           -
      whenThenInstructions, -
      otherwiseClause,      -
        otherwiseSequence,  -
    endClause

  self~init:super(package, selectClause~begin, endClause~end )

::Method labels
  Expose selectClause
  Return selectClause~labels
::Method nullClauses
  Expose selectClause
  Return selectClause~nullClauses
