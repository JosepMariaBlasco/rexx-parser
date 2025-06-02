/******************************************************************************/
/*                                                                            */
/* KeywordInstructions.cls                                                    */
/* =======================                                                    */
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
/* 20241206    0.1  First public release                                      */
/* 20241209    0.1b New call system                                           */
/* 20241216    0.1f Mutate EL.PERIOD -> EL.PARSE_PERIOD in PARSE templates    */
/*                  Mark template target variables and USE targets            */
/*                  as "assigned"                                             */
/* 20251215    0.2  Fix setAssigned for DROP, EXPOSE, USE LOCAL and           */
/*                  PROCEDURE EXPOSE                                          */
/* 20250328         Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250416    0.2a Add argument info to called routine chain                 */
/* 20250419         Fix bug nos. 3, 6 & 7                                     */
/*                                                                            */
/******************************************************************************/

 .environment~             Address.Instruction =             .Address.Instruction
 .environment~                 Arg.Instruction =                 .Arg.Instruction
 .environment~                Call.Instruction =                .Call.Instruction
 .environment~            Call.Off.Instruction =            .Call.Off.Instruction
 .environment~             Call.On.Instruction =             .Call.On.Instruction
 .environment~                Drop.Instruction =                .Drop.Instruction
 .environment~              Expose.Instruction =              .Expose.Instruction
 .environment~             Forward.Instruction =             .Forward.Instruction
 .environment~               Guard.Instruction =               .Guard.Instruction
 .environment~           Interpret.Instruction =           .Interpret.Instruction
 .environment~             Iterate.Instruction =             .Iterate.Instruction
 .environment~               Leave.Instruction =               .Leave.Instruction
 .environment~                 Nop.Instruction =                 .Nop.Instruction
 .environment~             Numeric.Instruction =             .Numeric.Instruction
 .environment~               Parse.Instruction =               .Parse.Instruction
 .environment~ Optional.Expression.Instruction = .Optional.Expression.Instruction
 .environment~             Options.Instruction =             .Options.Instruction
 .environment~           Procedure.Instruction =           .Procedure.Instruction
 .environment~               Raise.Instruction =               .Raise.Instruction
 .environment~              Signal.Instruction =              .Signal.Instruction
 .environment~        Signal.Value.Instruction =        .Signal.Value.Instruction
 .environment~          Signal.Off.Instruction =          .Signal.Off.Instruction
 .environment~           Signal.On.Instruction =           .Signal.On.Instruction
 .environment~               Trace.Instruction =               .Trace.Instruction
 .environment~             Use.Arg.Instruction =             .Use.Arg.Instruction
 .environment~           Use.Local.Instruction =           .Use.Local.Instruction

 .environment~               Call.Value =               .Call.Value
 .environment~ NameSpace.Qualified.Call = .NameSpace.Qualified.Call

 .environment~                        Template =                        .Template
 .environment~                   Template.List =                   .Template.List
 .environment~          Optional.Template.List =          .Optional.Template.List
 .environment~               Prefixed.Template =               .Prefixed.Template

 .environment~                  Trap.Arguments =                  .Trap.Arguments

::Requires "BaseClassesAndRoutines.cls"
::Requires "Expressions.cls"

/******************************************************************************/
/* ADDRESS instruction                                                        */
/******************************************************************************/

::Routine Address.Instruction Public
  Use Strict Arg package, begin, end, elements

  ADDRESS = elements[1]

  element        = TheElementAfter( ADDRESS )

  options.     = .Nil
  ignoreBlanks = .True

  If element < .EL.END_OF_CLAUSE Then Signal Done

  If element \< .ALL.SYMBOLS_AND_STRINGS Then Signal AfterValue
  If element < .ALL.SYMBOLS, element~value == "VALUE" Then Signal (Value)
  Call SetConstantName element, .ENVIRONMENT.NAME

  options.environment = element

  element = TheElementAfter( element, ignoreBlanks )
  If element < .EL.END_OF_CLAUSE Then Signal Done
  If element < .ALL.SYMBOLS, element~value == "WITH" Then Signal With

  Call PrepareExpression element, "WITH"
  expression = Expression.List( package, element )
  options.command = expression
  element = expression~end
  If element < .EL.END_OF_CLAUSE Then Signal Done
  Signal With

Value:
  Call SetSubkeyword element
  element = TheElementAfter( element )
AfterValue:
  Call PrepareExpression element, "WITH"
  options.value = Expression.List( package, element )
  element = options.value~end
  If element < .EL.END_OF_CLAUSE Then Signal Done
  Signal With

With:
  seen. = 0
  duplicate.input  = 25.930
  duplicate.output = 25.931
  duplicate.error  = 25.932
  Call SetSubkeyword element -- Consume "WITH"
  options.with     = 1
  element = TheElementAfter( element )
  If element < .EL.END_OF_CLAUSE Then Signal 20.933
  Loop
    If element \< .ALL.SYMBOLS_AND_KEYWORDS Then Signal 25.934
    tValue = element~value
    If WordPos(tValue, "INPUT OUTPUT ERROR") == 0 Then Signal 25.934
    If seen.tValue Then Signal (duplicate.tValue)
    seen.tValue    = 1
    options.tValue = 1
    Call SetSubkeyword element
    element = TheElementAfter( element )
    If element \< .ALL.SYMBOLS Then Signal 25.933
    If tValue \== "INPUT" Then Do
      replaceOrAppend = element~value
      If WordPos(replaceOrAppend, "REPLACE APPEND") > 0 Then Do
        Call SetSubkeyword element
        options.tValue.replaceOrAppend = 1
        element = TheElementAfter( element )
        If element \< .ALL.SYMBOLS Then Signal 25.933
      End
    End
    IOType = element~value
    If WordPos(IOType, "NORMAL STEM STREAM USING") == 0 Then Signal 25.933
    Call SetSubkeyword element
    Select Case element~value
      When "NORMAL" Then options.tValue.normal = 1
      When "STEM"   Then Do
        element = TheElementAfter( element )
        If element \< .EL.STEM_VARIABLE Then Signal 20.932
        element~setAssigned
        options.tValue.stem = element
      End
      When "STREAM", "USING" Then Do
        next = TheElementAfter( element )
        If next < .EL.END_OF_CLAUSE Then Signal 35.935
        element = next
        If element < .ALL.SYMBOLS_AND_STRINGS Then
          options.tValue.stream = element
        Else Do
          If element \< .EL.LEFT_PARENTHESIS Then Signal 35.001
          Call prepareExpression element, "INPUT OUTPUT ERROR"
          subExpression = SubExpression( package, element )
          options.tValue.stream = subExpression
          element = subExpression~end
          If element < .EL.END_OF_CLAUSE Then Signal Done
          Iterate
        End
      End
    End
    element = TheElementAfter( element, ignoreBlanks )
    If element < .EL.END_OF_CLAUSE Then Signal Done
  End

Done:
  Return .Address.Instruction~new( package, begin, end, options. )

-- Stem symbol expected after STEM keyword.
20.932: Syntax( 20.932, ADDRESS )

-- Symbol expected after WITH keyword.
20.933: Syntax( 20.933, ADDRESS )

-- Duplicate INPUT keyword found.
25.930: Syntax( 25.930, ADDRESS )

-- Duplicate OUTPUT keyword found.
25.931: Syntax( 25.931, ADDRESS )

-- Duplicate ERROR keyword found.
25.932: Syntax( 25.932, ADDRESS )

-- Acceptable ADDRESS WITH I/O types are NORMAL, STEM,
-- STREAM, and USING; found "&1".
25.933: Syntax( 25.933, ADDRESS, element )

-- WITH must be followed by one of the keywords
-- INPUT, OUTPUT, or ERROR; found "&1".
25.934: Syntax( 25.934, ADDRESS, element )

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, ADDRESS, element )

-- Missing expression following &1 keyword of a &2 instruction.
35.935: Syntax( 35.935, ADDRESS, element, "ADDRESS" )

--------------------------------------------------------------------------------

::Class Address.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose options.
  Use Strict Arg package, begin, end, options.
  self~init:super(package, begin, end)

/******************************************************************************/
/* ARG instruction                                                            */
/******************************************************************************/

::Routine Arg.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Template.List(                   -
    package, .Arg.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Arg.Instruction Public SubClass Optional.Template.List
::Constant instructionName "ARG"

/******************************************************************************/
/* CALL instruction                                                           */
/******************************************************************************/

::Routine Call.Instruction Public
  Use Strict Arg package, begin, end, elements

  CALL = elements[1]

  ignoreBlanks = .True
  expression   = .Nil

  element = TheElementAfter( CALL )

  If element < .ALL.VAR_SYMBOLS, WordPos(element~value, "ON OFF") > 0 Then do
    If element~value == "ON"
      Then Return Call.On.Instruction(  package, begin, end, elements )
      Else Return Call.Off.Instruction( package, begin, end, elements )
  End

  If element  < .EL.LEFT_PARENTHESIS     Then Signal GetExpression
  If element \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.002

  nameSpace = .Nil
  name = element
  If element < .ALL.SYMBOLS Then Do
    next = TheElementAfter( element, ignoreBlanks )
    If next < .EL.COLON Then Do
      nameSpace = element
      name = TheElementAfter( next, ignoreBlanks )
      If name \< .ALL.SYMBOLS Then Signal 20.922
      element = TheElementAfter( name, ignoreBlanks )
    End
    Else element = next
  End
  Else element = TheElementAfter( name, ignoreBlanks )
  Signal Arguments

GetExpression:
  Parse Value element~from With line col
  Call PrepareExpression element, ""
  element = TheElementAfter( element, ignoreBlanks )
  expression = Or.Expression( package, element, .EL.RIGHT_PARENTHESIS )
  rParen = expression~end
  If rParen \< .EL.RIGHT_PARENTHESIS Then Signal 36.901
  element = TheElementAfter( rParen, ignoreBlanks ) -- Consume the RPAREN
  -- prepareExpression above may have promoted whitespace after the
  -- closing ")" to a blank operator.
  If element < .EL.OP.BLANK Then Do
    c = element~source
    If c == "-" | c == "," Then
      Call SetCategory element, .EL.CONTINUATION       -- Demote, ..
    Else
      Call SetCategory element, .EL.WHITESPACE         -- Demote, ..
    element~makeIgnorable                              -- .. make ignorable..
    element = TheElementAfter( element, ignoreBlanks ) -- .. and skip.
  End
  Signal Arguments

Arguments:
  Call PrepareExpression element, ""
  arguments = Expression.List( package, element, "" )
  element = arguments~end
  If expression~isNil Then Do
    If nameSpace == .Nil Then Do
      name~invocationType = "CALL"
      package~currentBody~calledRoutineNames~append( (name, arguments) )
      -- We don't need to assign a subcategory here, because We
      -- will assign a finer subcategory in the second pass.
      Return .Call.Instruction~new( package, begin, element, name, arguments )
    End
    Else Do
      Call SetConstantName nameSpace, .NAMESPACE.NAME
      Call SetConstantName name     , .EXTERNAL.PACKAGE.SUBROUTINE.NAME
      Return .NameSpace.Qualified.Call~new(      -
        package, begin, element, nameSpace, name, arguments -
      )
    End
  End
  Else
    Return .Call.Value~new(           -
      package, begin, element, expression, arguments -
    )

-- String or symbol expected after CALL keyword.
19.002: Syntax( 19.002, CALL )

-- Symbol expected as a routine name of qualified CALL instruction.
20.922: Syntax( 20.922, CALL, name )

-- Left parenthesis "(" in position &1 on line &2
-- requires a corresponding right parenthesis ")".
36.901: Syntax( 36.901, CALL, col, line )

--  A simple call, i.e. call name args                                        --

::Class Call.Instruction Public SubClass Rexx.Instruction
::Attribute name
::Method init
  Expose name arguments
  Use Strict Arg package, begin, end, name, arguments
  self~init:super(package, begin, end)

-- A namespace-qualified call, i.e. call namespace:name args                                                   --

::Class NameSpace.Qualified.Call Public SubClass Rexx.Instruction
::Attribute nameSpace
::Attribute name
::Method init
  Expose nameSpace name arguments
  Use Strict Arg package, begin, end, nameSpace , name, arguments
  self~init:super(package, begin, end)

-- Call (expression) args                                                     --

::Class Call.Value Public SubClass Rexx.Instruction
::Method init
  Expose expression arguments
  Use Strict Arg package, begin, end, expression, arguments
  self~init:super( package, begin, end )

/******************************************************************************/

-- Common constant for CALL ON & OFF
::Routine CallOnOffConditions
  Return "ERROR FAILURE HALT NOTREADY USER ANY "

/******************************************************************************/
/* Call Off instruction                                                       */
/******************************************************************************/

::Routine Call.Off.Instruction Public
  Use Strict Arg package, begin, end, elements

  OFF = elements[2]

  Call SetSubkeyword OFF

  ignoreBlanks = .True

  condition = TheElementAfter( OFF )

  If condition \< .ALL.SYMBOLS Then Signal 20.912

  name = condition~value

  If WordPos(name, CallOnOffConditions() ) == 0 Then Signal 25.002

  Call SetSubkeyword condition

  userCondition = .Nil

  If name == "USER" Then Do
    userCondition = TheElementAfter( condition, ignoreBlanks )
    If userCondition \< .ALL.SYMBOLS Then Signal 20.915
    Call SetConstantName userCondition, .USER.CONDITION.NAME
    element = TheElementAfter( userCondition, ignoreBlanks )
  End
  Else element = TheElementAfter( condition, ignoreBlanks )

  If element \< .EL.END_OF_CLAUSE Then Signal 21.904

  Return .Call.Off.Instruction~new(        -
    package, begin, element, condition, userCondition -
  )

-- Data must not follow the condition name; found "&1".
21.904: Syntax( 21.904, OFF, element )

-- Symbol expected after OFF keyword.
20.912: Syntax( 20.912, OFF )

-- Symbol expected after USER keyword.
20.915: Syntax( 20.915, OFF )

-- CALL OFF must be followed by one of the keywords ERROR, FAILURE,
-- HALT, NOTREADY, USER, or ANY; found "&1".
25.002: Syntax( 25.002, OFF, condition )

--------------------------------------------------------------------------------

::Class Call.Off.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose condition userCondition
  Use Strict Arg package, begin, end, condition, userCondition = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* CALL ON instruction                                                        */
/******************************************************************************/

-- Special class to identify the arguments to a trap specified in
-- a CALL ON instruction
::Class Trap.Arguments Public
::Method Arg
  Arg n, option +1
  If Arg() == 0 Then Return 1
  If option == "E" Then Return n == 1
  Return n \== 1

::Routine Call.On.Instruction Public
  Use Strict Arg package, begin, end, elements

  ON = elements[2]

  Call SetSubkeyword ON

  ignoreBlanks = .True

  condition = TheElementAfter( ON )

  If condition \< .ALL.SYMBOLS Then Signal 20.911

  name = condition~value

  If WordPos(name, CallOnOffConditions() ) == 0 Then Signal 25.001

  Call SetSubkeyword condition

  userCondition = .Nil

  If name == "USER" Then Do
    userCondition = TheElementAfter( condition, ignoreBlanks )
    If userCondition \< .ALL.SYMBOLS Then Signal 20.915
    Call SetConstantName userCondition, .USER.CONDITION.NAME
    element = TheElementAfter( userCondition, ignoreBlanks )
  End
  Else element = TheElementAfter( condition, ignoreBlanks )

  If element < .EL.END_OF_CLAUSE Then
    Exit .Call.On.Instruction~new(                    -
      package, begin, element, condition, userCondition -
    )

  If \( element < .ALL.VAR_SYMBOLS ) Then Signal 25.914
  If element~value \== "NAME"   Then Signal 25.914

  Call SetSubkeyword element

  trapName = TheElementAfter( element )

  If trapName \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.003

  trapName~invocationType = "CALL"

  package~currentBody~calledRoutineNames~append( -
    (trapName, .Trap.Arguments~new)              -
  )

  end = TheElementAfter( trapName, ignoreBlanks )

  If end \< .EL.END_OF_CLAUSE Then Signal 21.903

  Return .Call.On.Instruction~new(-
    package, begin, element, condition, userCondition, trapName -
  )

-- String or symbol expected after NAME keyword.
19.003: Syntax( 19.003, ON )

-- Data must not follow the NAME trap name; found "&1".
21.903: Syntax( 21.903, ON, end )

-- Symbol expected after ON keyword.
20.911: Syntax( 20.911, ON )

-- Symbol expected after USER keyword.
20.915: Syntax( 20.915, ON )

-- CALL ON must be followed by one of the keywords ERROR, FAILURE, HALT,
-- NOTREADY, USER, or ANY; found "&1".
25.001: Syntax( 25.001, ON, condition )

-- CALL ON condition must be followed by the keyword NAME; found "&1".
25.914: Syntax( 25.914, ON, element )

--------------------------------------------------------------------------------

::Class Call.On.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose condition userCondition trapName
  Use Strict Arg package, begin, end, condition, -
    userCondition = .Nil, trapName = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* Drop instruction                                                           */
/******************************************************************************/

::Routine Drop.Instruction Public
  Use Strict Arg package, begin, end, elements

  Return Name.List.Instruction( package, .Drop.Instruction, begin, end, elements )

--------------------------------------------------------------------------------
--   nameList format: a list of valid symbols; a parenthesized symbol is      --
--   stored as a 1-element array.                                             --
--------------------------------------------------------------------------------

::Class Drop.Instruction Public SubClass Rexx.Instruction
::Attribute nameList
::Method init
  Expose nameList
  Use Strict Arg package, begin, end, nameList
  self~init:super( package, begin, end )

/******************************************************************************/
/* EXIT instruction                                                           */
/******************************************************************************/

::Routine Exit.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Expression.Instruction( -
    package, .Exit.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Exit.Instruction Public SubClass Optional.Expression.Instruction
::Constant instructionName "EXIT"

/******************************************************************************/
/* EXPOSE instruction                                                         */
/******************************************************************************/

::Routine Expose.Instruction Public
  Use Strict Arg package, begin, end, elements

  Return Name.List.Instruction( package, .Expose.Instruction, begin, end, elements )

--------------------------------------------------------------------------------
--   exposed format: a list of valid symbols; a parenthesized symbol is      --
--   stored as a 1-element array.                                             --
--------------------------------------------------------------------------------

::Class Expose.Instruction Public SubClass Rexx.Instruction
::Attribute exposed
::Method init
  Expose exposed
  Use Strict Arg package, begin, end, exposed
  self~init:super( package, begin, end)

/******************************************************************************/
/* FORWARD instruction                                                        */
/******************************************************************************/

::Routine Forward.Instruction Public
  Use Strict Arg package, begin, end, elements

  FORWARD = elements[1]

  seen.         = 0
  options.      = 0
  ignoreBlanks  = .True

  element = TheElementAfter( FORWARD )
  keywords = "CONTINUE ARGUMENTS ARRAY MESSAGE CLASS TO"

  duplicate.to        = 25.917
  duplicate.arguments = 25.918
  duplicate.array     = 25.918
  duplicate.continue  = 25.919
  duplicate.class     = 25.921
  duplicate.message   = 25.922

  missing.array       = 35.924
  missing.to          = 35.925
  missing.arguments   = 35.926
  missing.message     = 35.927
  missing.class       = 35.928

  Loop
    If element  < .EL.END_OF_CLAUSE       Then Signal Done
    If element \< .ALL.VARIABLES_AND_KEYWORDS Then Signal 25.916
    tValue = element~value
    If WordPos( tValue, keywords ) == 0 Then Signal 25.916
    Call SetSubkeyword element
    element = TheElementAfter( element )

    If seen.tValue Then Signal (duplicate.tValue)
    seen.tValue = 1
    If tValue = "ARGUMENTS" then seen.array     = 1
    If tValue = "ARRAY"     then seen.arguments = 1

    If tValue == "CONTINUE" Then Do
      options.continue = 1
      Iterate
    End

    If element < .EL.END_OF_CLAUSE Then Signal (missing.tValue)

    Select Case tValue
      When "ARGUMENTS" Then Do
        Call PrepareExpression element, keywords
        expression = Expression.List( package, element )
        element = expression~end
        options.tValue = expression
      End
      When "ARRAY" Then Do
        If element \< .EL.LEFT_PARENTHESIS Then Signal 35.924
        Call PrepareExpression element, keywords
        expression = SubExpression( package, element )
        element = expression~end
        options.tValue = expression
      End
      Otherwise Do
        If element < .ALL.CONSTANT_SYMBOLS_AND_STRINGS Then Do
          options.tValue = element
          element = TheElementAfter( element, ignoreBlanks )
        End
        Else Do
          If element \< .EL.LEFT_PARENTHESIS Then Signal 35.001
          Call PrepareExpression element, keywords
          subExpression = SubExpression( package, element )
          options.tValue = subExpression
          element = subExpression~end
        End
      End
    End
  End

Done:

  Return .Forward.Instruction~new( package, begin, end, options. )

-- Unknown keyword on FORWARD instruction; found "&1".
25.916: Syntax( 25.916, FORWARD, element )

-- Duplicate TO keyword found.
25.917: Syntax( 25.917, FORWARD )

-- Duplicate ARGUMENTS or ARRAY keyword found.
25.918: Syntax( 25.918, FORWARD )

-- Duplicate RETURN or CONTINUE keyword found.
25.919: Syntax( 25.919, FORWARD )

-- Duplicate CLASS keyword found.
25.921: Syntax( 25.921, FORWARD )

-- Duplicate MESSAGE keyword found.
25.922: Syntax( 25.922, FORWARD )

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, FORWARD, element )

-- Missing "(" on expression list of the ARRAY keyword.
35.924: Syntax( 35.924, FORWARD )

-- Missing expression following TO keyword of a FORWARD instruction.
35.925: Syntax( 35.925, FORWARD )

-- Missing expression following ARGUMENTS keyword of a FORWARD instruction.
35.926: Syntax( 35.926, FORWARD )

-- Missing expression following MESSAGE keyword of a FORWARD instruction.
35.927: Syntax( 35.927, FORWARD )

-- Missing expression following CLASS keyword of a FORWARD instruction.
35.928: Syntax( 35.928, FORWARD )

--------------------------------------------------------------------------------

::Class Forward.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose options.
  Use Strict Arg package, begin, end, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* GUARD instruction                                                          */
/******************************************************************************/

::Routine Guard.Instruction Public
  Use Strict Arg package, begin, end, elements

  GUARD = elements[1]

  keyword = TheElementAfter( GUARD )

  If keyword \< .ALL.VAR_SYMBOLS            Then Signal 25.913
  If WordPos( keyword~value, "ON OFF") == 0 Then Signal 25.913

  onOff = keyword~value == "ON"

  Call SetSubkeyword keyword

  when = TheElementAfter( keyword )

  If when < .EL.END_OF_CLAUSE Then
    Return .Guard.Instruction~new( package, begin, end, onOff )

  If when \< .ALL.VAR_SYMBOLS Then Signal 25.912
  If when~value \== "WHEN"    Then Signal 25.912

  Call SetSubkeyword when

  element = TheElementAfter( when )

  -- TODO [LATER] Implement 99.913 (see message text below)

  Call PrepareExpression element
  expression = Expression.List( package, element, , "logical")

  end = expression~end

  Return .Guard.Instruction~new( package, begin, end, onOff, expression )

-- GUARD ON or GUARD OFF must be followed by the keyword WHEN; found "&1".
25.912: Syntax( 25.912, GUARD, when )

-- GUARD must be followed by the keyword ON or OFF; found "&1".
25.913: Syntax( 25.913, GUARD, keyword )

-- GUARD instruction did not include references to exposed variables.
99.913: Syntax( 99.913, GUARD )

--------------------------------------------------------------------------------

::Class Guard.Instruction Public SubClass Rexx.Instruction
::Attribute expression
::Method init
  Expose on expression
  Use Strict Arg package, begin, end, on, expression = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* INTERPRET instruction                                                      */
/******************************************************************************/

::Routine Interpret.Instruction Public
  Use Strict Arg package, begin, end, elements

  INTERPRET = elements[1]

  If elements~items == 1 Then Signal 35.912

  element = elements[2]

  Call PrepareExpression element

  expression = Expression.List( package, element, .EL.END_OF_CLAUSE )

  Return .Interpret.Instruction~new( package, begin, end, expression )

-- Missing expression following INTERPRET keyword.
35.912: Syntax( 35.912, INTERPRET )

--------------------------------------------------------------------------------

::Class Interpret.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose expression
  Use Strict Arg package, begin, end, expression
  self~init:super( package, begin, end )

/******************************************************************************/
/* ITERATE instruction                                                        */
/******************************************************************************/

::Routine Iterate.Instruction Public

  Use Strict Arg package, begin, end, elements

  ITERATE = elements[1]

  element = TheElementAfter( ITERATE )

  blockLabel       = .Nil
  blockInstruction = .Nil
  ignoreBlanks     = .True

  If element < .EL.END_OF_CLAUSE Then Signal Done

  If element \< .ALL.SYMBOLS Then Signal 20.908
  label = element
  Call SetConstantName label, .BLOCK.INSTRUCTION.NAME

  element = TheElementAfter( element, ignoreBlanks )
  If element \< .EL.END_OF_CLAUSE Then Signal 21.908

  blockInstructionsStack = package~blockInstructionsStack
  Do i = blockInstructionsStack~items To 1 By -1
    instruction = blockInstructionsStack[i]
    blockLabel = instruction~label
    If blockLabel == "",  \instruction~isA(.Select.Clause) Then
      blockLabel = instruction~control
    If blockLabel~isA(.String) Then theLabel = blockLabel
    Else theLabel = blockLabel~value
    If blockLabel \== "", theLabel == label~value Then Do
      If instruction~class = .Select.Clause Then Signal 28.005
      blockLabel       = label
      blockInstruction = instruction
      Signal Done
    End
  End
  Signal 28.004

Done:
  Return .Iterate.Instruction~new(            -
    package, begin, end, blockLabel, blockInstruction  -
  )

-- Symbol expected after ITERATE keyword.
20.908: Syntax( 20.908, ITERATE )

-- Data must not follow the ITERATE name; found "&1".
21.908: Syntax( 21.908, ITERATE, element )

-- Symbol following ITERATE ("&1") must either match the label
-- of a current loop or be omitted.
28.004: Syntax( 28.004, ITERATE, label )

-- Symbol following ITERATE ("&1") does not match
-- a repetitive block instruction.
28.005: Syntax( 28.005, ITERATE, label )

--------------------------------------------------------------------------------

::Class Iterate.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose label iteration
  Use Strict Arg package, begin, end, label, iteration
  self~init:super( package, begin, end )

/******************************************************************************/
/* LEAVE instruction                                                          */
/******************************************************************************/

::Routine Leave.Instruction Public
  Use Strict Arg package, begin, end, elements

  LEAVE = elements[1]

  element = TheElementAfter( LEAVE )

  blockLabel   = .Nil
  iteration    = .Nil
  ignoreBlanks = .True

  -- No label? We are done.
  If element < .EL.END_OF_CLAUSE Then Signal Done

  -- Label should be a symbol.
  If element \< .ALL.SYMBOLS Then Signal 20.907

  -- Set the element subcategory
  label = element
  Call SetConstantName label, .BLOCK.INSTRUCTION.NAME

  -- Instruction should end here
  element = TheElementAfter( label, ignoreBlanks )
  If element \< .EL.END_OF_CLAUSE Then Signal 21.907

  -- Now the label can refer to any label or control variable in
  -- the block instruction stack.
  blockInstructionsStack = package~blockInstructionsStack
  Do i = blockInstructionsStack~items To 1 By -1
    instruction = blockInstructionsStack[i]
    blockLabel = instruction~label
    If blockLabel == "",  \instruction~isA(.Select.Clause) Then
      blockLabel = instruction~control
    If blockLabel~isA(.String) Then theLabel = blockLabel
    Else theLabel = blockLabel~value
    If blockLabel \ == "", theLabel == label~value Then Do
      blockLabel     = label
      iteration = instruction
      Signal Done
    End
  End
  Signal 28.003

Done:
  Return .Leave.Instruction~new( package, begin, end, blockLabel, iteration )

-- Symbol expected after LEAVE keyword.
20.907: Syntax( 20.907, LEAVE )

-- Data must not follow the LEAVE name; found "&1".
21.907: Syntax( 21.907, LEAVE, element )

-- Symbol following LEAVE ("&1") must either match the label
-- of a current loop or block instruction.
28.003: Syntax( 28.003, LEAVE, label )

--------------------------------------------------------------------------------

::Class Leave.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose label iteration
  Use Strict Arg package, begin, end, label, iteration
  self~init:super( package, begin, end )

/******************************************************************************/
/* NOP instruction                                                            */
/******************************************************************************/

::Routine Nop.Instruction Public
  Use Strict Arg package, begin, end, elements

  NOP = elements[1]

  If elements~items > 1  Then Signal 21.901

  Return .Nop.Instruction~new( package, begin, end )

-- Data must not follow the NOP keyword; found "&1".
21.901: Syntax( 21.901, NOP, elements[2] )

--------------------------------------------------------------------------------

::Class Nop.Instruction Public SubClass Rexx.Instruction

/******************************************************************************/
/* NUMERIC instruction                                                        */
/******************************************************************************/

::Routine Numeric.Instruction Public
  Use Strict Arg package, begin, end, elements

  NUMERIC = elements[1]

  ignoreBlanks = .True

  keyword = TheElementAfter( NUMERIC )

  If keyword \< .ALL.SYMBOLS Then Signal 20.905

  kValue = keyword~value

  If WordPos(kValue, "DIGITS FORM FUZZ") == 0 Then Signal 25.015

  Call SetSubkeyword keyword

  element = TheElementAfter( keyword, ignoreBlanks )

  Select Case kValue
    When "DIGITS" Then Call Expression "Digits"
    When "FUZZ"   Then Call Expression "Fuzz"
    When "FORM"   Then Nop
  End

  -- NUMERIC FORM

  If element \< .ALL.SYMBOLS Then Call Expression "Form"

  keyword = element
  kValue = keyword~value

  If WordPos(kValue, "SCIENTIFIC ENGINEERING VALUE") == 0 Then
    Signal 25.011

  Call SetSubkeyword keyword

  element = TheElementAfter( keyword )

  If kValue == "VALUE" Then
    If element < .EL.END_OF_CLAUSE Then Signal 35.917
    Else Call Expression "Form Value"

  If element \< .EL.END_OF_CLAUSE Then Signal 21.911

  If kValue == "SCIENTIFIC" Then Call Form "Form Scientific"
  Else                           Call Form "Form Engineering"

Form:
  Exit .Numeric.Instruction~new( package, begin, end, Arg(1), .Nil )

Expression:
  If element < .EL.END_OF_CLAUSE Then expression = .Nil
  Else Do
    Call PrepareExpression element
    expression = Expression.List( package, element )
  End

  Exit .Numeric.Instruction~new( package, begin, end, Arg(1), expression )

-- NUMERIC must be followed by one of the keywords
-- DIGITS, FORM, or FUZZ; found "&1".
20.905: Syntax( 20.905, NUMERIC, keyword )

-- Data must not follow the NUMERIC FORM specification; found "&1".
21.911: Syntax( 21.911, NUMERIC, element )

-- NUMERIC FORM must be followed by one of the keywords
-- SCIENTIFIC or ENGINEERING; found "&1".
25.011: Syntax( 25.011, NUMERIC, keyword )

-- NUMERIC must be followed by one of the keywords
-- DIGITS, FORM, or FUZZ; found "&1".
25.015: Syntax( 25.015, NUMERIC, keyword )

-- Missing expression following VALUE keyword of a NUMERIC FORM instruction.
35.917: Syntax( 35.917, NUMERIC )

--------------------------------------------------------------------------------

::Class Numeric.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose option expression
  Use Strict Arg package, begin, end, option, expression = .Nil
  self~init:super( package, begin, end)

/******************************************************************************/
/* OptionalExpressionInstruction                                              */
/*   Code common to all instructions that consist of a single keyword         */
/*   followed by an optional expression, like EXIT, PUSH, QUEUE, REPLY,       */
/*   RETURN and SAY.                                                          */
/*                                                                            */
/*   See rexxref 5.1.0 1.11.6. Array Term                                     */
/******************************************************************************/

::Routine Optional.Expression.Instruction Public

  Use Strict Arg package, class, begin, end, elements

  -- When there is an end-of-clause after the keyword,
  -- this is an empty expression
  If elements~items == 1 Then expression = .Nil
  Else Do
    element = elements[2]
    Call PrepareExpression element
    expression = Expression.List( package, element, .EL.END_OF_CLAUSE )
  End

  Return class~new( package, begin, end, expression )

--------------------------------------------------------------------------------

::Class Optional.Expression.Instruction Public SubClass Rexx.Instruction
::Attribute expression Get
::Method init
  Expose expression
  Use Strict Arg package, begin, end, expression = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* OPTIONS instruction                                                        */
/******************************************************************************/

::Routine Options.Instruction Public
  Use Strict Arg package, begin, end, elements

  OPTIONS = elements[1]

  If elements~items == 1 Then Signal 35.913

  element = elements[2]

  expression = Expression.List( package, element, .EL.END_OF_CLAUSE )

  Return .Options.Instruction~new( package, begin, end, expression )

-- Missing expression following OPTIONS keyword.
35.913: Syntax( 35.913, OPTIONS )

--------------------------------------------------------------------------------

::Class Options.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose expression
  Use Strict Arg package, begin, end, expression
  self~init:super( package, begin, end )

/******************************************************************************/
/* PARSE instruction                                                          */
/******************************************************************************/

::Routine Parse.Instruction Public
  Use Strict Arg package, begin, end, elements

  PARSE = elements[1]

  keyword      = TheElementAfter( PARSE )
  options.     = .False

  ignoreBlanks = .True
  upperLower   = .False
  caseLess     = .False

  Loop
    If keyword \< .ALL.SYMBOLS Then Signal 20.903
    kValue = keyword~value
    Select Case kValue
      When "LOWER", "UPPER" Then Call UpperLower
      When "CASELESS"       Then Call CaseLess
      When "VAR"            Then Signal Var
      When "VALUE"          Then Signal (Value)
      When "ARG", "LINEIN", "PULL", "SOURCE", "VERSION"
                            Then Signal SimpleCase
      Otherwise                  Signal 25.012
    End
  End

Templates:
  If element < .EL.END_OF_CLAUSE
    Then templateList = .Nil
    Else templateList = Template.List( package, element )
  Return .Parse.Instruction~new( package, begin, end, options., templateList )

SimpleCase:
  Call SetSubkeyword keyword
  options.variant = kValue
  element = TheElementAfter( keyword )
  Signal Templates

Var:
  Call SetSubkeyword keyword
  name = TheElementAfter( keyword )
  If name \< .ALL.SYMBOLS Then Signal 20.904
  c = Left( name~value , 1 )
  If c == "."             Then Signal 31.003
  If c >>= "0", c <<= "9" Then Signal 31.002
  options.variant = VAR
  options.var     = name
  element = TheElementAfter( name, ignoreBlanks )
  Signal Templates

Value:
  Call SetSubkeyword keyword
  element = TheElementAfter( keyword )
  If element < .EL.END_OF_CLAUSE Then Signal 38.003
  Call PrepareExpression element, "WITH"
  options.variant = VALUE
  expression = Expression.List( package, element )
  options.value   = expression
  element = expression~end
  If element < .EL.END_OF_CLAUSE Then Signal 38.003
  -- Now element is a .ALL.VAR_SYMBOLS with a value of WITH for sure
  Call SetSubkeyword keyword
  element = TheElementAfter( element )
  Signal Templates

UpperLower:
  If upperLower Then Signal 25.012
  upperLower = 1
  Signal FirstOptions

CaseLess:
  If caseLess Then Signal 25.012
  caseLess = 1
  Signal FirstOptions

FirstOptions:
  options.kValue = 1
  Call SetSubkeyword keyword
  keyword = TheElementAfter( keyword )
  Return

-- Symbol expected after PARSE keyword.
20.903: Syntax( 20.903, PARSE )

-- Symbol expected after PARSE VAR.
20.904: Syntax( 20.904, PARSE )

-- PARSE must be followed by optional keywords LOWER or UPPER,
-- by an optional keyword CASELESS, and by one of the keywords
-- ARG, LINEIN, PULL, SOURCE, VALUE, VAR, or VERSION; found "&1".
25.012: Syntax( 25.012, PARSE, keyword )

-- Variable symbol must not start with a number; found "&1".
31.002: Syntax( 31.002, PARSE, name )

-- Variable symbol must not start with a "."; found "&1".
31.003: Syntax( 31.003, PARSE, name )

-- PARSE VALUE instruction requires WITH keyword.
38.003: Syntax( 38.003, PARSE )

--------------------------------------------------------------------------------

::Class Parse.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose options. templateList
  Use Strict Arg package, begin, end, options., templateList
  self~init:super( package, begin, end )

/******************************************************************************/
/* PROCEDURE instruction                                                      */
/******************************************************************************/

::Routine Procedure.Instruction Public
  Use Strict Arg package, begin, end, elements

  If elements~items == 1 Then
    Return .Procedure.Instruction~new( package, begin, end, .Nil )

  PROCEDURE = elements[1]
  EXPOSE    = elements[2]

  If EXPOSE < .ALL.VAR_SYMBOLS, EXPOSE~value = "EXPOSE" Then Do
    Call SetSubkeyword EXPOSE
    If elements[3] < .ALL.WHITESPACE_LIKE Then elements~delete( 3 )
    Return Name.List.Instruction(                -
      package, .Procedure.Instruction, begin, end, elements -
    )
  End

  Signal 25.017

-- PROCEDURE must be followed by the keyword EXPOSE or nothing; found "&1".
25.017: Syntax( 25.017, PROCEDURE, EXPOSE )

--------------------------------------------------------------------------------
--   exposed format: a list of valid symbols; a parenthesized symbol is      --
--   stored as a 1-element array.                                             --
--------------------------------------------------------------------------------

::Class Procedure.Instruction Public SubClass Rexx.Instruction
::Attribute exposed
::Method init
  Expose exposed
  Use Strict Arg package, begin, end, exposed
  self~init:super( package, begin, end )

/******************************************************************************/
/* PULL instruction                                                           */
/******************************************************************************/

::Routine Pull.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Template.List(                    -
    package, .Pull.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Pull.Instruction Public SubClass Optional.Template.List
::Constant instructionName "PULL"

/******************************************************************************/
/* PUSH instruction                                                           */
/******************************************************************************/

::Routine Push.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Expression.Instruction( -
    package, .Push.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Push.Instruction Public SubClass Optional.Expression.Instruction
::Constant instructionName "PUSH"

/******************************************************************************/
/* QUEUE instruction                                                          */
/******************************************************************************/

::Routine Queue.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Expression.Instruction( -
    package, .Queue.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Queue.Instruction Public SubClass Optional.Expression.Instruction
::Constant instructionName "QUEUE"

/******************************************************************************/
/* RAISE instruction                                                          */
/******************************************************************************/

::Routine Raise.Instruction Public
  Use Strict Arg package, begin, end, elements

  RAISE = elements[1]

  ignoreBlanks = .True

  condition = TheElementAfter( RAISE )

  If condition \< .ALL.SYMBOLS Then Signal 20.914

  expectCode      = "ERROR FAILURE SYNTAX"
  expectCondition = "USER"
  expectNothing   = "HALT LOSTDIGITS NOMETHOD NOSTRING NOTREADY NOVALUE",
                    "PROPAGATE"
  allKeywords     = expectCode expectCondition expectNothing

  cValue = condition~value

  If WordPos( cValue, allKeywords ) == 0 Then Signal 25.906

  Call SetSubkeyword condition

  element = TheElementAfter( condition, ignoreBlanks )

  options = .Set~of("ADDITIONAL", "ARRAY", "DESCRIPTION", "EXIT", "RETURN")

  additional  = .False -- ADDITIONAL or ARRAY already processed
  return      = .False -- RETURN or EXIT already processed
  description = .False -- DESCRIPTION already processed

  Select
    When cValue == "USER" Then Do
      If element \< .ALL.SYMBOLS Then Signal 20.915
      Call SetConstantName element, .USER.CONDITION.NAME
      condition = ( condition, element )
      Call NextElement
    End
    When WordPos( cValue, expectCode ) > 0 Then Do
      condition = ( condition, Expression() )
    End
    Otherwise -- Expect nothing
      condition = Array( condition )
  End

  options. = .Nil

  Loop
    kValue   = element~value
    keywords = options~makeArray~makeString("L"," ")
    Select
      When element < .EL.END_OF_CLAUSE Then Exit .Raise.Instruction~new( -
        package, begin, end, condition, options.                      -
      )
      When element \< .ALL.VARIABLES_AND_KEYWORDS Then Signal 25.907
      When WordPos( kValue, keywords ) == 0     Then Signal 25.907
      Otherwise
        Call SetSubkeyword element
        Call ("OPTION."kValue)
    End
  End

Option.Additional:
  If additional Then Signal 25.909
  additional = .True
  Call NextElement
  If element < .EL.END_OF_CLAUSE Then Signal 35.923
  options.["ADDITIONAL"] = Expression()
  Return

Option.Array:
  If additional Then Signal 25.909
  additional = .True
  Call NextElement
  If element \< .EL.LEFT_PARENTHESIS Then Signal 35.924
  options.["ARRAY"] = Expression()
  Return

Option.Description:
  If description Then Signal 25.908
  description = .True
  Call NextElement
  If element < .EL.END_OF_CLAUSE Then Signal 35.922
  options.["DESCRIPTION"] = Expression()
  Return

Option.Exit:
  If return Then Signal 25.911
  return = .True
  Call NextElement
  If element < .EL.END_OF_CLAUSE Then
       options.["EXIT"] = .Nil
  Else options.["EXIT"] = Expression()
  Return

Option.Return:
  If return Then Signal 25.911
  return = .True
  Call NextElement
  If element < .EL.END_OF_CLAUSE Then
       options.["RETURN"] = .Nil
  Else options.["RETURN"] = Expression()
  Return

NextElement:
  element = TheElementAfter( element, ignoreBlanks )
  Return

Expression:
  If element < .ALL.SYMBOLS_AND_STRINGS Then Do
    value = element
    Call NextElement -- Consume element
    Return value
  End
  Else If element \< .EL.LEFT_PARENTHESIS Then Signal 35.001
  Else Do
    Call PrepareExpression element, options~makeArray~makeString("L"," ")
    Call NextElement -- Consume the "("
    expression = Expression.List( package, element, .EL.RIGHT_PARENTHESIS )
    element = expression~end
    Call NextElement -- Consume the ")"
    Return expression
  End

-- Duplicate RETURN or EXIT keyword found.
25.911: Syntax( 25.911, RAISE )

-- Symbol expected after RAISE keyword.
20.914: Syntax( 20.914, RAISE )

-- Symbol expected after USER keyword.
20.915: Syntax( 20.915, RAISE )

-- RAISE must be followed by one of the keywords ERROR, FAILURE, HALT,
-- LOSTDIGITS, NOMETHOD, NOSTRING, NOTREADY, NOVALUE, PROPAGATE, SYNTAX, or
-- USER; found "&1".
25.906: Syntax( 25.906, RAISE, condition )

-- Unknown keyword on RAISE instruction; found "&1".
25.907: Syntax( 25.907, RAISE, element )

-- Duplicate DESCRIPTION keyword found.
25.908: Syntax( 25.908, RAISE )

-- Duplicate ADDITIONAL or ARRAY keyword found.
25.909: Syntax( 25.909, RAISE )

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, RAISE, element )

-- Missing expression following DESCRIPTION keyword of a RAISE instruction.
35.922: Syntax( 35.922, RAISE )

-- Missing expression following ADDITIONAL keyword of a RAISE instruction.
35.923: Syntax( 35.923, RAISE )

-- Missing "(" on expression list of the ARRAY keyword.
35.924: Syntax( 35.924, RAISE )

--------------------------------------------------------------------------------

::Class Raise.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose condition options.
  Use Strict Arg package, begin, end, condition, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* REPLY instruction                                                          */
/******************************************************************************/

::Routine Reply.Instruction Public
  -- Message 99.919 is run-time only
  Use Strict Arg package, begin, end, elements
  Return Optional.Expression.Instruction( -
    package, .Reply.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Reply.Instruction Public SubClass Optional.Expression.Instruction
::Constant instructionName "REPLY"

/******************************************************************************/
/* RETURN instruction                                                         */
/******************************************************************************/

::Routine Return.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Expression.Instruction( -
    package, .Return.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Return.Instruction Public SubClass Optional.Expression.Instruction
::Constant instructionName "RETURN"

/******************************************************************************/
/* SAY instruction                                                            */
/******************************************************************************/

::Routine Say.Instruction Public
  Use Strict Arg package, begin, end, elements
  Return Optional.Expression.Instruction( -
    package, .Say.Instruction, begin, end, elements  -
  )

--------------------------------------------------------------------------------

::Class Say.Instruction Public SubClass Optional.Expression.Instruction
::Constant instructionName "SAY"

/******************************************************************************/
/* SIGNAL instruction  (signal labelname, signal value expression)            */
/******************************************************************************/

::Routine Signal.Instruction Public
  Use Strict Arg package, begin, end, elements

  SIGNAL = elements[1]

  If elements~items == 1 Then Signal 19.004

  ignoreBlanks = .True

  element            = TheElementAfter( SIGNAL )

  value            = .False -- VALUE keyword found

  If element \< .ALL.SYMBOLS_AND_STRINGS Then Signal Expression

  If element < .ALL.VAR_SYMBOLS Then Do
    Select Case element~value
      When "ON"  Then
        Return Signal.On.Instruction(  package, begin, end, elements )
      When "OFF" Then
        Return Signal.Off.Instruction( package, begin, end, elements )
      When "VALUE" Then Do
        Call SetSubkeyword element
        element = TheElementAfter( element )
        If element < .EL.END_OF_CLAUSE Then Signal 35.915
        value = .True
        Signal Expression
      End
      Otherwise Nop
    End
  End

  labelName = element

  Call SetConstantName labelName, .LABEL.NAME

  element     = TheElementAfter( labelName, ignoreBlanks )
  If element \< .EL.END_OF_CLAUSE Then Signal 21.905

  Return .Signal.Instruction~new( package, begin, end, labelName )

Expression:
  Call PrepareExpression element
  expression = Expression.List( package, element )
  element = expression~end

  Return .Signal.Value.Instruction~new( package, begin, end, expression )

-- String or symbol expected after SIGNAL keyword.
19.004: Syntax( 19.004, SIGNAL )

-- Data must not follow the SIGNAL label name; found "&1".
21.905: Syntax( 21.905, SIGNAL, element )

-- Missing expression following VALUE keyword of a SIGNAL instruction.
35.915: Syntax( 35.915, SIGNAL )

--------------------------------------------------------------------------------

::Class Signal.Instruction Public SubClass Rexx.Instruction -- SIGNAL labelName
::Attribute label
::Method init
  Expose label
  Use Strict Arg package, begin, end, label
  self~init:super( package, begin, end )

--------------------------------------------------------------------------------

::Class Signal.Value.Instruction Public SubClass Rexx.Instruction
::Attribute expression
::Method init
  Expose expression
  Use Strict Arg package, begin, end, expression
  self~init:super( package, begin, end )

/******************************************************************************/
-- Common constant for SIGNAL ON & OFF
::Routine SignalOnOffConditions
  Return "ERROR FAILURE HALT LOSTDIGITS NOMETHOD"     -
         "NOSTRING NOTREADY NOVALUE SYNTAX USER ANY "

/******************************************************************************/
/* SIGNAL OFF instruction                                                     */
/******************************************************************************/

::Routine Signal.Off.Instruction Public

  Use Strict Arg package, begin, end, elements

  OFF = elements[2]

  Call SetSubkeyword OFF

  ignoreBlanks = .True

  condition = TheElementAfter( OFF )

  If condition \< .ALL.SYMBOLS Then Signal 20.912

  name = condition~value

  If WordPos(name, SignalOnOffConditions() ) == 0 Then Signal 25.004

  Call SetSubkeyword condition

  userCondition = .Nil

  If name == "USER" Then Do
    userCondition = TheElementAfter( condition, ignoreBlanks )
    If userCondition \< .ALL.SYMBOLS Then Signal 20.915
    Call SetConstantName userCondition, .USER.CONDITION.NAME
    element = TheElementAfter( userCondition, ignoreBlanks )
  End
  Else element = TheElementAfter( condition, ignoreBlanks )

  If element \< .EL.END_OF_CLAUSE Then Signal 21.904

  Return .Signal.Off.Instruction~new(-
    package, begin, end, condition, userCondition -
  )

-- Data must not follow the condition name; found "&1".
21.904: Syntax( 21.904, OFF, element )

-- Symbol expected after OFF keyword.
20.912: Syntax( 20.912, OFF )

-- Symbol expected after USER keyword.
20.915: Syntax( 20.915, OFF )

-- SIGNAL OFF must be followed by one of the keywords ERROR, FAILURE,
-- HALT, LOSTDIGITS, NOTREADY, NOMETHOD, NOSTRING, NOVALUE, SYNTAX,
-- USER, or ANY; found "&1".
25.004: Syntax( 25.004, OFF, condition )

--------------------------------------------------------------------------------

::Class Signal.Off.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose condition userCondition
  Use Strict Arg package, begin, end, condition, userCondition = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* SIGNAL ON instruction                                                      */
/******************************************************************************/

::Routine Signal.On.Instruction Public

  Use Strict Arg package, begin, end, elements

  ON = elements[2]

  Call SetSubkeyword ON

  ignoreBlanks = .True

  condition = TheElementAfter( ON )

  If condition \< .ALL.SYMBOLS Then Signal 20.911

  name = condition~value

  If WordPos(name, SignalOnOffConditions() ) == 0 Then Signal 25.003

  Call SetSubkeyword condition

  userCondition = .Nil

  If name == "USER" Then Do
    userCondition = TheElementAfter( condition, ignoreBlanks )
    If userCondition \< .ALL.SYMBOLS Then Signal 20.915
    Call SetConstantName userCondition, .USER.CONDITION.NAME
    element = TheElementAfter( userCondition, ignoreBlanks )
  End
  Else element = TheElementAfter( condition, ignoreBlanks )

  If element < .EL.END_OF_CLAUSE Then Return .Signal.On.Instruction~new(-
    package, begin, end, condition, userCondition -
  )

  If element \< .ALL.VAR_SYMBOLS Then Signal 25.915
  If element~value \== "NAME"     Then Signal 25.915

  Call SetSubkeyword element

  trapName = TheElementAfter( element )

  If trapName \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.003

  Call SetConstantName trapName, .LABEL.NAME

  end = TheElementAfter( trapName, ignoreBlanks )

  If end \< .EL.END_OF_CLAUSE Then Signal 21.903

  Return .Signal.On.Instruction~new(-
    package, begin, end, condition, userCondition, trapName -
  )

-- String or symbol expected after NAME keyword.
19.003: Syntax( 19.003, ON )

-- Data must not follow the NAME trap name; found "&1".
21.903: Syntax( 21.903, ON, end )

-- Symbol expected after ON keyword.
20.911: Syntax( 20.911, ON )

-- Symbol expected after USER keyword.
20.915: Syntax( 20.915, ON )

-- SIGNAL ON must be followed by one of the keywords ERROR, FAILURE,
-- HALT, LOSTDIGITS, NOTREADY, NOMETHOD, NOSTRING, NOVALUE, SYNTAX,
-- USER, or ANY; found "&1".
25.003: Syntax( 25.003, ON, condition )

-- SIGNAL ON condition must be followed by the keyword NAME; found "&1".
25.915: Syntax( 25.915, ON, element )

--------------------------------------------------------------------------------

::Class Signal.On.Instruction Public SubClass Rexx.Instruction
::Attribute label
::Attribute condition
::Attribute userCondition
::Method init
  Expose condition userCondition label
  Use Strict Arg package, begin, end, condition, -
    userCondition = .Nil, label = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* TRACE instruction                                                          */
/******************************************************************************/

::Routine Trace.Instruction Public
  Use Strict Arg package, begin, end, elements

  TRACE = elements[1]

  options.     = .False
  ignoreBlanks = .True

  element = TheElementAfter( TRACE )

  If element < .EL.END_OF_CLAUSE Then Signal Done

  If element < .ALL.STRINGS Then Do
    options.string = element
    element = TheElementAfter( element, ignoreBlanks )
    Signal Processed
  End

  If element < .ALL.NUMBERS Then Do
    options.number = element
    element = TheElementAfter( element, ignoreBlanks )
    Signal Processed
  End

  If element < .ALL.SYMBOLS Then Do
    If element~value == "VALUE" Then Signal (Value)
    value = Strip( element~value, "L", "?" )
    If value \== "", Pos( value[1], "ACEFILNOR") == 0 Then Signal 24.001
    options.symbol = element
    element = TheElementAfter( element, ignoreBlanks )
    Signal Processed
  End

  If element < .EL.LEFT_PARENTHESIS Then Do
    Call PrepareExpression element, ")"
    expression = Expression.List( package, element )
    options.value = expression
    element = expression~end
    Signal Processed
  End

Value:
  Call SetSubkeyword element
  element = TheElementAfter( element, ignoreBlanks )
  If element < .EL.END_OF_CLAUSE Then Signal 35.916
  Call PrepareExpression element
  expression = Expression.List( package, element )
  options.value = expression
  Signal Done

Processed:
  If element < .EL.END_OF_CLAUSE Then Signal Done
  Signal 21.906

Done:
  Return .Trace.Instruction~new( package, begin, end, options. )

-- Data must not follow the TRACE setting; found "&1".
21.906: Syntax( 21.906, TRACE, element )

-- TRACE request letter must be one of "ACEFILNOR"; found "&1".
24.001: Syntax( 24.001, TRACE, value[1] )

-- Missing expression following VALUE keyword of a TRACE instruction.
35.916: Syntax( 35.916, TRACE )

--------------------------------------------------------------------------------

::Class Trace.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose options.
  Use Strict Arg package, begin, end, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* USE instruction                                                            */
/******************************************************************************/

::Routine Use.Instruction Public
  Use Strict Arg package, begin, end, elements

  USE = elements[1]

  keyword = TheElementAfter( USE )

  nextKeywords = .Set~of("ARG", "LOCAL", "STRICT")

  If keyword < .ALL.VAR_SYMBOLS, nextKeywords~hasItem( keyword~value ) Then Do
    Call SetSubkeyword keyword
    Select Case keyword~value
      When "LOCAL" Then
        Return Use.Local.Instruction( package, begin, keyword )
      When "STRICT" Then Do
        keyword = TheElementAfter( keyword )
        If keyword < .ALL.VAR_SYMBOLS, keyword~value == "ARG" Then Do
          Call SetSubkeyword keyword
          Return Use.Arg.Instruction( package, begin, keyword, .True )
        End
        Signal 25.929
      End
      When "ARG"   Then
        Return Use.Arg.Instruction( package, begin, keyword, .False )
    End
  End

-- USE must be followed by the keyword ARG, LOCAL or STRICT; found "&1".
25.905: Syntax( 25.905, USE, keyword )

-- USE STRICT must be followed by the keyword ARG; found "&1".
25.929: Syntax( 25.929, USE, keyword )

/******************************************************************************/
/* USE ARG instruction                                                        */
/******************************************************************************/

::Routine Use.Arg.Instruction

  Use Strict Arg package, begin, keyword, strict

  argList        =  Array()
  ignoreBlanks   = .True
  argProcessed   = .False
  continue       = .EL.COMMA || .EL.END_OF_CLAUSE
  afterEqualSign = .EL.LEFT_PARENTHESIS || .ALL.CONST_SYMBOLS || .ALL.NUMBERS || .ALL.STRINGS

  element           = keyword

  Call NextElement

  Call PrepareExpression element

  Loop While element \< .EL.END_OF_CLAUSE
    Select
      When element < .EL.COMMA Then Do
        If \argProcessed Then argList~append( Array("Nil") )
        argProcessed = .False -- Mark as processed
        Call NextElement        -- Consume the comma
        Iterate               -- Don't reset argProcessed at loop end
      End
      When element < .ALL.SYMBOLS Then Do
        If element~value == "..." Then Signal Ellipsis
        c = element~value[1]
        If c >= "0", c <= "9" Then Signal 31.002
        -- Check for "." moved below: .o is invalid, but .o~m is not
        -- Mark the element as assigned
        element~setAssigned
        -- Build a symbol term
        term = Symbol.Term( package, element, continue )
        -- Now collect "[...]" and "~[~](...)" sequences
        term = Simple.Message.Term( package, term )
        If term~isA(.Symbol.Term), Left(term~symbol~value,1) == "." Then
          Signal 31.003
        element = term~end
        -- Consume blanks after ")" and "]"
        If element < .ALL.WHITESPACE_LIKE Then Do
          element~makeIgnorable
          element = TheElementAfter( element )
        End
        If element < continue Then Do
          argList~append( ("Assign", term) )
          Call BackTrack
        End
        Else Do
          If element \< .EL.OP.EQUAL Then Call 46.902 element
          Call NextElement
          If \( element < afterEqualSign ) Then Signal 35.001
          If element < .EL.LEFT_PARENTHESIS Then Do
            subExpression = SubExpression( package, element, "" )
            argList~append( ("SubExpression", term, subExpression) )
            element = subExpression~end
          End
          Else Do
            argList~append( ("Constant", var, element) )
            Call NextElement
            If \( element < continue ) Then Signal 35.930
          End
          Call BackTrack
        End
      End
      When element < .ALL.OPS.REFERENCE Then Do
        Call NextElement
        If \( element < (.EL.SIMPLE_VARIABLE || .EL.STEM_VARIABLE) ) Then Signal 20.931
        element~setAssigned
        argList~append( (">", element) )
        Call NextElement
        If element < .EL.OP.EQUAL Then Signal 99.950
        Call BackTrack
      End
      Otherwise Signal 89.001
    End
    Call NextElement
    argProcessed = .True
  End

Return:

  If \argProcessed Then argList~append( Array("Nil") )

  Return .Use.Arg.Instruction~new( package, begin, element, strict, argList)

Ellipsis:
  Call SetCategory element, .EL.ELLIPSIS
  argProcessed = .True
  argList~append( Array("...") )
  element = TheElementAfter( element, ignoreBlanks )
  If element \< .EL.END_OF_CLAUSE Then Signal 99.930
  Signal Return

BackTrack:
  element = TheElementBefore( element )
  Return

NextElement:
  element = TheElementAfter( element, ignoreBlanks )
  Return

-- Simple variable or stem symbol expected after > or < USE ARG
-- reference operator; found &1.
20.931: Syntax( 20.931, keyword, element )

-- Variable symbol must not start with a number; found "&1".
31.002: Syntax( 31.002, keyword, element )

-- Variable symbol must not start with a "."; found "&1".
31.003: Syntax( 31.003, keyword, element )

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, keyword, element )

-- Invalid or missing expression following "=" token of a USE ARG instruction.
35.930: Syntax( 35.930, keyword )

-- Extra token ("&1") found in USE ARG variable reference;
-- "," or end of instruction expected.
46.902: Syntax( 46.902, keyword, Arg(1) )

-- The USE instruction requires a comma-separated list
-- of variables or assignment message terms.
89.001: Syntax( 89.001, keyword, element )

-- The "..." argument marker can only appear at the end of the argument list.
99.930: Syntax( 99.930, keyword )

-- A USE ARG default value is not allowed for variable references.
99.950: Syntax( 99.950, keyword )

--------------------------------------------------------------------------------

::Class Use.Arg.Instruction Public SubClass Rexx.Instruction
::Method init
  Expose strict argList
  Use Strict Arg package, begin, end, strict, argList
  self~init:super( package, begin, end )

/******************************************************************************/
/* USE LOCAL instruction                                                      */
/******************************************************************************/

::Routine Use.Local.Instruction

  Use Strict Arg package, begin, LOCAL

  list          = Array()
  name          = TheElementAfter( LOCAL )
  ignoreBlanks  = .True

  body          = package~currentBody
  UseLocal      = Set()
  body~UseLocal = UseLocal

  Loop
    Select
      When name < .EL.END_OF_CLAUSE Then Leave
      When name < .ALL.VAR_SYMBOLS  Then Do
        If name < .EL.COMPOUND_VARIABLE Then Signal 99.948
        name~setAssigned
        list~append( name )
        UseLocal[] = name~value
      End
      Otherwise Signal 20.927
    End
    name = TheElementAfter( name, ignoreBlanks )
  End

  Return .Use.Local.Instruction~new( package, begin, name, list )

-- Symbol expected after USE LOCAL.
20.927: Syntax( 20.927, LOCAL )

-- USE LOCAL cannot process compound variables; found "&1".
99.948: Syntax( 99.948, LOCAL, name )

--------------------------------------------------------------------------------

::Class Use.Local.Instruction Public SubClass Rexx.Instruction
::Attribute local
::Method init
  Expose local
  Use Strict Arg package, begin, end, local
  self~init:super( package, begin, end )

/******************************************************************************/
/******************************************************************************/
/* COMMON CODE                                                                */
/******************************************************************************/
/******************************************************************************/

/******************************************************************************/
/* Code common to DROP, EXPOSE and PROCEDURE EXPOSE                           */
/******************************************************************************/

::Routine Name.List.Instruction Public
  Use Strict Arg package, class, begin, end, elements

  keyword = elements[1]

  If class == .Procedure.Instruction Then element = elements[3]
  Else                                    element = elements[2]

  inExpose = class == .Expose.Instruction

  If element == .Nil Then Call 20.902 elements[1]

  ignoreBlanks = .True

  nameList = Array( )

  Loop Until element < .EL.END_OF_CLAUSE
    If element < .EL.LEFT_PARENTHESIS Then Do
      element = TheElementAfter( element, ignoreBlanks )
      Call GetASymbol 1
      pName = Symbol.Term( -
        package,           -
        element,           -
       .ALL.WHITESPACE_LIKE || .EL.RIGHT_PARENTHESIS || .EL.LEFT_PARENTHESIS, -
        inExpose           -
      )
      element = TheElementAfter( element, ignoreBlanks )
      If element \< .EL.RIGHT_PARENTHESIS Then Signal 46.901
      nameList~append( Array( pName ) )
      package~currentBody~exposed[] = element~value
    End
    Else Do
      Call GetASymbol 0
      nameList~append( Symbol.Term(                  -
        package,                                     -
        element,                                     -
       .ALL.WHITESPACE_LIKE || .EL.LEFT_PARENTHESIS, -
        inExpose                                     -
      ) )
      If class == .Expose.Instruction Then
        package~currentBody~exposed[] = element~value
    End
    element = TheElementAfter( element, ignoreBlanks )
  End

  Return class~new( package, begin, end, nameList )

GetASymbol:
  Arg insideParens
  If element \< .ALL.SYMBOLS Then
    If insideParens                 Then Signal 20.906
    Else
      If class == .Drop.Instruction Then Signal 20.901
      Else                               Call   20.902 element
  c = Left(element~value,1)
  If c == "."                       Then Signal 31.003
  If c >= "0", c <= "9"             Then Signal 31.002
  element~setAssigned
  Return

-- Variable symbol must not start with a number; found "&1".
31.002: Syntax( 31.002, keyword, element )

-- Variable symbol must not start with a "."; found "&1".
31.003: Syntax( 31.003, keyword, element )

-- Symbol expected after DROP keyword.
20.901: Syntax( 20.901, element )

-- Symbol expected after EXPOSE keyword.
20.902: Syntax( 20.902, Arg(1) )

-- Symbol expected after "(" of a variable reference.
20.906: Syntax( 20.906, element )

-- Missing ")" in variable reference.
46.901: Syntax( 46.901, keyword )

/******************************************************************************/
/* OPTIONAL.TEMPLATE.LIST                                                     */
/*   Code common to all instructions that consist of a single keyword         */
/*   followed by an optional template list, like ARG or PULL                  */
/******************************************************************************/

::Routine Optional.Template.List Public

  Use Strict Arg package, class, begin, end, elements

  ARG = elements[1]

  next = TheElementAfter( ARG )

  -- When there is an end-of-clause after the keyword,
  -- this is an empty template list
  If next < .EL.END_OF_CLAUSE Then templateList = .Nil
  Else                          templateList = Template.List( package, next )

  Return class~new( package, begin, end, templateList )

--------------------------------------------------------------------------------

::Class Optional.Template.List Public SubClass Rexx.Instruction
::Method init
  Expose templateList
  Use Strict Arg package, begin, end, templateList = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* TEMPLATE.LIST                                                              */
/******************************************************************************/

::Routine Template.List Public

  Use Strict Arg package, begin

  templateList  = Array()
  element         = begin
  trailingComma = 0
  ignoreBlanks  = .True

  Loop While element \< .EL.END_OF_CLAUSE

    Do While element < .EL.COMMA
      templateList~append( .Nil )
      element = TheElementAfter( element, ignoreBlanks )
      trailingComma = 1
    End

  If element < .EL.END_OF_CLAUSE Then Leave

    trailingComma = 0

    template = Template( package, element )

    templateList~append( template )

    element = template~end

  If element \< .EL.COMMA Then Leave

    element = TheElementAfter( element, ignoreBlanks )
    trailingComma = 1

  End

  If trailingComma Then Do
    templateList~append(.Nil)
  End

  -- Only one template and no commas? --> A single template
  If templateList~items == 1 Then Return templateList[1]

  Return .Template.List~new(templateList)

--------------------------------------------------------------------------------

::Class Template.List
::Method init
  Expose list
  Use Strict Arg list
::Method isEmpty
  Expose list
  Return list~items == 0

--------------------------------------------------------------------------------
-- TEMPLATE                                                                   --
--   See ANSI 6.3.2.87-95:                                                    --
--   template                  := (trigger | target | Msg38.1)+               --
--     target                  := VAR_SYMBOL | '.'                            --
--     trigger                 := pattern | positional                        --
--       pattern               := STRING | vrefp                              --
--         vrefp               := '(' (VAR_SYMBOL | Msg19.7) (')' | Msg46.1)  --
--       positional            := absolute_positional | relative_positional   --
--         absolute_positional := NUMBER | '=' position                       --
--           position          := NUMBER | vrefp | Msg38.2                    --
--         relative_positional := ('+' | '-') position                        --
--                                                                            --
--   ooRexx modifies the definition of "target" to also include message terms --
--   and allows full expressions between parenthesis in vrefp                 --
--------------------------------------------------------------------------------

::Routine Template Public

  Use Strict Arg package, begin

  list = Array()

  ignoreBlanks = .true

  element = begin

  terminators      = .EL.COMMA || .EL.END_OF_CLAUSE

  Loop Until element < terminators

    Select
      When element < .ALL.VAR_SYMBOLS Then Do

        -- Mark the element as assigned
        element~setAssigned

        -- Build a symbol term
        term = Symbol.Term( package, element, terminators )

        -- Now collect "[args]" and "~[~](args)" sequences
        term = Simple.Message.Term( package, term )

        element = term~end

        -- Consume blanks after ")" and "]"
        If element < .ALL.WHITESPACE_LIKE Then Do
          element~makeIgnorable
          element = TheElementAfter( element )
        End

        list~append(term)

        Iterate

      End
      When element < .EL.PERIOD      Then Do
        Call SetCategory element, .EL.PARSE_PERIOD
        list~append(element)
      End
      When element < .ALL.STRINGS Then list~append(element)
      When element < .ALL.NUMBERS Then Do
        If \DataType(element~value,"I") Then Signal 26.004
        list~append(element)
      End
      When element < .ALL.POSITION_PREFIXES  Then Do
        template = Positional.Template( package, element )
        list~append( template )
        element = template~end
        If element < .ALL.WHITESPACE_LIKE Then
          element = TheElementAfter( element, ignoreBlanks )
        Iterate
      End
      When element < .EL.LEFT_PARENTHESIS           Then Do
        template = Subexpression.Template( package, element )
        list~append( template )
        element = template~end
        If element < .ALL.WHITESPACE_LIKE Then
          element = TheElementAfter( element, ignoreBlanks )
        Iterate
      End
      Otherwise Signal 38.001
    End

    element = TheElementAfter( element, ignoreBlanks )

  End

  Return .Template~new( begin, element, list )

-- Positional pattern of PARSE template must be a whole number; found "&1".
26.004: Syntax( 26.004, begin, element )

-- Incorrect PARSE template detected at "&1".
38.001: Syntax( 38.001, begin, element )

--------------------------------------------------------------------------------

::Class Template
::Attribute end
::Method init
  Expose end list
  Use Strict Arg begin, end, list
::Method isEmpty
  Expose list
  Return list~items == 0

/******************************************************************************/
/* POSITIONAL.TEMPLATE                                                        */
/*   ("=" | "+" | "-") position                                               */
/******************************************************************************/

::Routine Positional.Template Public

  Use Strict Arg package, prefix

  ignoreBlanks = .True

  element = TheElementAfter( prefix )

  If element < .ALL.NUMBERS Then Do
    If \DataType(element~value,"I") Then Signal 26.004
    Return .Prefixed.Template~new( prefix, element )
  End

  If element < .EL.LEFT_PARENTHESIS Then
    Return .Prefixed.Template~new( -
      prefix, Subexpression.Template( package, element ) -
    )

  Signal 38.002

-- Positional pattern of PARSE template must be a whole number; found "&1".
26.004: Syntax( 26.004, prefix, element )

-- Incorrect PARSE position detected at "&1".
38.002: Syntax( 38.002, prefix, element )

--------------------------------------------------------------------------------

::Class Prefixed.Template Public
::Attribute end
::Method init
  Expose prefix elementOrSubExpression end
  Use Strict Arg prefix, elementOrSubExpression
  If elementOrSubExpression~isA( .Element ) Then
    end = TheElementAfter( elementOrSubExpression )
  Else
    end = elementOrSubExpression~end

/******************************************************************************/
/* SUBEXPRESSION.TEMPLATE                                                     */
/******************************************************************************/

::Routine Subexpression.Template

  Use Strict Arg package, lParen

  Call PrepareExpression lParen, ")"

  subExpression = SubExpression( package, lParen )

  element = subExpression~end

  -- Generally speaking, a closing parenthesis does not eat blanks
  -- to the right, but in this case we do need to ignore such blanks,
  -- if present.

  If element < .ALL.WHITESPACE_LIKE Then Do
    next = TheElementAfter( element )
    element~makeIgnorable
    subExpression~end = next
  End

  Return subExpression
