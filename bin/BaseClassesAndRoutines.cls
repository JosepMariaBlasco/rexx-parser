/******************************************************************************/
/*                                                                            */
/* BaseClassesAndRoutines.cls                                                 */
/* ==========================                                                 */
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
/* 20241226    0.1d Add GlobalOption routine                                  */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250421    0.2b Modify InternalError to raise a HALT condition            */
/* 20250722    0.2d Add Set.Directive.SubKeyword                              */
/* 20251014    0.2e Add support for Lua constants and Lua table constructors  */
/* 20251014         Add support for lambda expressions                        */
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/* A Rexx Clause                                                              */
/******************************************************************************/

 .environment~Lambda.Do.Block = .Lambda.Do.Block

::Class Rexx.Clause Public

::Attribute labels           -- Label clauses that identify this clause
::Attribute nullClauses      -- Null clauses preceding this clause
::Attribute docComment       -- Documentation comment preceding this clause
::Attribute begin            -- First element in clause (a semicolon)
::Attribute end              -- Last element in clause (a semicolon)
::Attribute package          -- The package we are currently parsing
::Method Init

  Expose package begin end labels nullClauses docComment

  Use Strict Arg package, begin, end

  labels      = Array()
  nullClauses = Array()
  docComment  = .Nil

  body = package~currentBodies~top

  -- body may be .Nil at the start of a body scan
  If \self~isA(.Block.Instruction) Then
    If body \== .Nil Then body~clauses~append( self )

::Method makeArray
  Use Strict Arg indent = 0
  Return Array(self~string(indent))

/******************************************************************************/
/* A Rexx Instruction                                                         */
/******************************************************************************/

::Class Rexx.Instruction Public SubClass Rexx.Clause
::Constant isBlockInstruction 0
::Attribute terminating -- True when all branches end with EXIT or RETURN
::Method init
  Use Strict Arg package, begin, end
  self~init:super( package, begin, end )
  terminating = 0

/******************************************************************************/
/* A Directive                                                                */
/******************************************************************************/

::Class Rexx.Directive Public SubClass Rexx.Clause
::Attribute body

/******************************************************************************/
/* Basic and common routines                                                  */
/******************************************************************************/

-- Create collections in a more intuitive way

::Routine Array       Public; Return Arg(1,"A")
::Routine Set         Public; Return .Set~sendWith("of",Arg(1,"A"))
::Routine StringTable Public
  If Arg() == 0 Then Return .StringTable~new
  Return .StringTable~sendWith("of",Arg(1,"A"))

/******************************************************************************/
/* Global.Option                                                              */
/******************************************************************************/

::Routine Global.Option Public
  Parse Upper Arg key
  If .Parser.Options~hasIndex( key ) Then Return .Parser.Options[ key ]
  Return ""

/******************************************************************************/
/* Generate syntax errors                                                     */
/*   When we detect an internal error or a syntax error, we pack all the      */
/*   information into a directory, and send it inside the ADDITIONAL array    */
/*   of a 98.900 error.                                                       */
/******************************************************************************/

::Routine Syntax Public

  Use Strict Arg code, element, ...

  Parse Var code major"."minor

  -- "element" is any element in a clause. We need to determine the location
  -- or the first element in that clause, to accurately place the error message.

  -- We first go back to the first end-of-clause before the given element,...
  Do While element \< .EL.END_OF_CLAUSE
    prev = TheElementBefore(element)
    If prev == .Nil Then Leave -- In some rare cases, prev may be .Nil
    element = prev
  End
  -- ...and then we move forward one element, so that we are now located
  -- at the beginning of the clause.
  If element~next \== .Nil Then -- In some rare cases, next may be .Nil
    element = TheElementAfter( element )

  Parse Value element~from With line col

  additional = Arg(3,"A")
  message = "Syntax error" major"."minor "at line" line
  minor = minor + 0
  code = major"."minor
  If additional~items > 0 Then Do
    Do i = 1 To additional~items
      If additional[i]~isA(.Element) Then
        additional[i] = additional[i]~value
    End
    message ||= ". Additional:"
    Do i = 1 To additional~items
      If i > 1 Then message ||= ","
      message ||= " "i": '"additional[i]"'"
    End
  End
  directory = .Directory~of( -
    ("CODE",code), ("ADDITIONAL", additional~makeArray), ("POSITION", line) -
  )
  additional~append(directory)
  additional~insert(message, .Nil)
  Raise Syntax 98.900 Additional (additional)

/******************************************************************************/
/* Internal.Error                                                             */
/*                                                                            */
/* We print a panic error and we raise the HALT condition.                    */
/*                                                                            */
/******************************************************************************/

::Routine Internal.Error
  Use Strict Arg text
  Say Copies("-",80)
  Say "Internal error:"
  Say "  "text
  Say Copies("-",80)
  Raise HALT

/******************************************************************************/
/*   In higher levels of parsing, we will be only interested in non-ignorable */
/*   elements. In these cases, we will be interested in navigating from       */
/*   a certain, non-ignorable, element, to the next non-ignorable element.    */
/*                                                                            */
/*   TheElementAfter and TheElementBefore will take care of this   */
/*   non-ignorable navigation.                                                              */
/******************************************************************************/

::Routine TheElementAfter Public
  Use Strict Arg element, ignoreBlanks = .False
  Loop Until \element~hasIndex(ignored)
    next = element~next
    If next~isNil Then
      Internal.Error( "TheElementAfter was about to return .Nil" )
    element = next
    If ignoreBlanks, element < .ALL.WHITESPACE_LIKE Then element~makeIgnorable
  End
  Return element

--------------------------------------------------------------------------------

::Routine TheElementBefore Public
  Use Strict Arg element
  Loop Until \prev~hasIndex(ignored)
    prev = element~prev
    If prev~isNil Then
      Internal.Error( "TheElementBefore was about to return .Nil" )
    element = prev
  End
  Return element

/*   BEWARE: Our elements are not the same as the tokens defined by Rexx,     */
/*   since we include whitespace and comments as elements. We say that        */
/*   comments are ignorable elements (since they are always ignored), and     */
/*   most whitespace will also happen to be ignorable.                        */
/*                                                                            */
/*   Please note that the fact that a certain whitespace sequence is          */
/*   ignorable or not cannot be determined at the lowest levels of parsing.   */
/*   For example, a blank located between two simple variables acts,          */
/*   in principle, as a concatenation operator, but this ceases to be true    */
/*   when we find out that at least one of the simple variables happens to    */
/*   also be a keyword.                                                       */

--------------------------------------------------------------------------------
-- SetKeyword                                                                 --
--   Mark that this element is a keyword, and ignore whitespace               --
--   surrounding it.                                                          --
--------------------------------------------------------------------------------

::Routine SetKeyword Public
  Use Strict Arg keyword, directive = .False

  If directive Then Call SetCategory keyword, .EL.DIRECTIVE_KEYWORD
  Else              Call SetCategory keyword, .EL.KEYWORD

  before = TheElementBefore( keyword )
  If before < .ALL.WHITESPACE_LIKE Then before~makeIgnorable

  after  = TheElementAfter(  keyword )
  If after  < .ALL.WHITESPACE_LIKE Then after~makeIgnorable

--------------------------------------------------------------------------------

::Routine SetSubkeyword Public
  Use Strict Arg keyword

  Call SetCategory keyword, .EL.SUBKEYWORD

  before = TheElementBefore( keyword )
  If before < .ALL.WHITESPACE_LIKE Then before~makeIgnorable

  after  = TheElementAfter(  keyword )
  If after  < .ALL.WHITESPACE_LIKE Then after~makeIgnorable

--------------------------------------------------------------------------------

::Routine Set.Directive.Keyword Public
  Use Strict Arg keyword

  Call SetCategory keyword, .EL.DIRECTIVE_KEYWORD

  before = TheElementBefore( keyword )
  If before < .ALL.WHITESPACE_LIKE Then before~makeIgnorable

  after  = TheElementAfter(  keyword )
  If after  < .ALL.WHITESPACE_LIKE Then after~makeIgnorable

--------------------------------------------------------------------------------

::Routine Set.Directive.SubKeyword Public
  Use Strict Arg keyword

  Call SetCategory keyword, .EL.DIRECTIVE_SUBKEYWORD

  before = TheElementBefore( keyword )
  If before < .ALL.WHITESPACE_LIKE Then before~makeIgnorable

  after  = TheElementAfter(  keyword )
  If after  < .ALL.WHITESPACE_LIKE Then after~makeIgnorable

/******************************************************************************/
/* SetCategory -- A routine to set the category of an element                 */
/******************************************************************************/

::Routine SetCategory Public
  Use Strict Arg element, category

  element~category = category

/******************************************************************************/
/* SetConstantName                                                            */
/******************************************************************************/

::Routine SetConstantName Public
  Use Strict Arg element, subCategory

  element~   category = .EL.TAKEN_CONSTANT
  element~subCategory =  subCategory

/******************************************************************************/
/* PRINTLABELS                                                                */
/******************************************************************************/

::Routine PrintLabels Public
  labels = Arg(1)~labels
  If labels~isEmpty Then Return ""

  ret = ""

  Do i = 1 To labels~items
    label = labels[i]~label
    If label < .ALL.STRINGS Then
      print = label~source
    Else
      print = label~value
    ret ||= print": "
  End

  Return ret

/******************************************************************************/
/* ABSORBRIGHT                                                                */
/******************************************************************************/

::Routine AbsorbRight Public

  Use Strict Arg element

  element~to = element~next~to
  Call RemoveElement element~next

/******************************************************************************/
/* ABSORBLEFT                                                                 */
/******************************************************************************/

::Routine AbsorbLeft Public

  Use Strict Arg element

  element~from = element~prev~from
  Call RemoveElement element~prev

/******************************************************************************/
/* RemoveElement                                                              */
/******************************************************************************/

::Routine RemoveElement Public -- Remove a element from the element chain

  Use Strict Arg element

  left       = element~prev
  right      = element~next

  left ~next = right
  right~prev = left

--------------------------------------------------------------------------------
-- PREPAREEXPRESSION                                                          --
--   Performs a quick scan and sanitizing of an expression list.              --
--   It identifies and reports unbalanced parentheses and brackets            --
--   It produces syntax errors for opening brackets preceded by whitespace,   --
--     except when Options Lua is in effect.                                  --
--   It stops prescanning if one the provided keywords is found, and in this  --
--     case, it marks the keyword as such, which automatically marks          --
--     whitespace before and after the keyword, if any, as ignorable.         --
--   It inserts an implied semicolon before the "THEN" keyword.               --
--   It changes whitespace into blank concatenation operators                 --
--   It inserts abuttal concatenation operators in the following contexts:    --
--     + a string or symbol immediately followed by another string or symbol  --
--     (when Options Lua is not in effect:)                                   --
--     + ")" immediately followed by "(" or a string or a symbol              --
--     + "]" immediately followed by "(" or a string or a symbol              --
--     When Options Lua is in effect, the above are function calls            --
--   It scans for variable reference terms, in the form ">var" or "<var",     --
--     and substitutes the comparison operators for the corresponding         --
--     reference operators.                                                   --
--     Substitution is attempted in the following contexts:                   --
--     ">" or "<" at the beginning of an expression                           --
--     ">" or "<" following a (non-reference) operator                        --
--     ">" or "<" following a "(" or a "["                                    --
--     No check is done to verify that a simple or stem variable name appears --
--     to the right of the operator, since this can produce different errors  --
--     depending on the context (e.g., 20.930 or 20.931).                     --
--                                                                            --
--------------------------------------------------------------------------------

::Routine PrepareExpression Public

  Use Strict Arg package, begin, keywords = ""

  subExpression = 0
  If keywords == ")" Then Do
    keywords      = ""
    subExpression =  1
  End

  predecessor = .Nil
  element     = begin
  nesting     = Array()

  Loop
    Select Case element~category
      When .EL.END_OF_CLAUSE Then Leave
      When .EL.SIMPLE_VARIABLE, -
           .EL.LUA.FAIL, .EL.LUA.FALSE, .EL.LUA.NIL, .EL.LUA.TRUE Then Do
        Select
          When nesting~isEmpty, IsAKeyword( element ) Then Do
            -- If we generated a spurious blank operator, we fix it now
            Call FixSpuriousBlanks
            Call SetSubkeyword element
            If element~value == "THEN" Then Do
              Call InsertSemicolonBefore element
            End
            Leave
          End
          Otherwise
            Call CheckAbuttal
        End
      End
      When .EL.OP.GREATER_THAN, .EL.OP.LOWER_THAN Then Do
        switch = 1
        Select
          When predecessor == .Nil               Then Nop
          When predecessor < .EL.COMMA           Then Nop
          When predecessor < .ALL.OPERATORS      Then Nop
          When predecessor < .ALL.LEFT_BRACES    Then Nop
          Otherwise switch = 0
        End
        If switch Then Call SwitchToReference
      End
      -- A left parenthesis will force an abuttal check only when Options Lua
      -- is not in effect: in Lua, they are a function call.
      When .EL.LEFT_PARENTHESIS   Then Do
        nesting~append( element )
        If \.Options.Lua Then Call CheckAbuttal
      End
      -- A left bracket can be found alone when Options Lua is in effect,
      -- as this will start a table constructor (a modified form of
      -- an "initializer", in Dallas draft parlance, or "array
      -- initializers" in NetRexx).
      When .EL.LEFT_BRACKET Then Do
        If \.Options.Lua, \predecessor~isNil, -
          predecessor < .ALL.WHITESPACE_LIKE Then
          Signal 35.001
        nesting~append( element )
      End
      When .EL.LUA.MAPS.TO Then Do
        If \predecessor~isNil, predecessor < .ALL.SIMPLE_VARIABLES Then
          Call SetCategory predecessor, .EL.LUA.LAMBDA.PARAMETER_NAME
        next = TheElementAfter(element)
        If next < .ALL.SIMPLE_VARIABLES, next~value == "DO" Then
          element = Lambda.Do.Block(package, next)~end
      End
      When .EL.RIGHT_PARENTHESIS Then Do
        If nesting~isEmpty Then Signal 37.002
        If nesting~lastItem~value \== "(" Then Signal 37.002
        If .Options.Lua Then Do
          next = TheElementAfter(element)
          If next < .EL.LUA.MAPS.TO Then Do
            Call SetCategory element,          .EL.LUA.LAMBDA.RIGHT_PARENTHESIS
            Call SetCategory nesting~lastItem, .EL.LUA.LAMBDA.LEFT_PARENTHESIS
          End
        End
        nesting~delete( nesting~last )
        If subExpression, nesting~isEmpty Then Return
      End
      When .EL.RIGHT_BRACKET Then Do
        If nesting~isEmpty                Then Signal 37.901
        If nesting~lastItem~value \== "[" Then Signal 37.901
        nesting~delete( nesting~last )
      End
      When .EL.WHITESPACE, .EL.CONTINUATION Then Do
        Call SetCategory element, .EL.OP.BLANK
        element~value = " "
      End
      Otherwise Call CheckAbuttal
    End
    predecessor = element
    element    = TheElementAfter( element )
  End

  If nesting~isEmpty Then Return

  lastItem = nesting~lastItem
  Parse Value lastItem~from With line pos
  Select Case nesting~lastItem~value
    When "(" Then Signal 36.901
    When "[" Then Signal 36.902
  End

FixSpuriousBlanks:
  If \predecessor~isNil, predecessor < .EL.OP.BLANK Then Do
    c = predecessor~source
    If c == "," | c == "-" Then
      Call SetCategory predecessor, .EL.CONTINUATION
    Else
      Call SetCategory predecessor, .EL.WHITESPACE
  End
  Return

SwitchToReference:
  Select Case element~category
    When .EL.OP.LOWER_THAN Then
      Call SetCategory element, .EL.OP.REFERENCE.LOWER_THAN
    When .EL.OP.GREATER_THAN Then
      Call SetCategory element, .EL.OP.REFERENCE.GREATER_THAN
  End
  next = TheElementAfter( element )
  -- Insert abuttals around symbols, strings, and Lua constants
  If next < (.ALL.SYMBOLS_AND_STRINGS || .ALL.LUA_CONSTANTS) Then Do
    next2next = TheElementAfter( next )
    If next2next < (.EL.LEFT_PARENTHESIS || .ALL.STRINGS) Then
      Call InsertAfter next, .EL.OP.ABUTTAL
    Else If next2next < (.ALL.SYMBOLS || .ALL.LUA_CONSTANTS) Then Do
      If nesting == "", IsAKeyword(next2next) Then Return
      Call InsertAfter next, .EL.OP.ABUTTAL
    End
  End
  Return

CheckAbuttal:
  If predecessor~isNil Then Return
  Select
    When element < .EL.LEFT_PARENTHESIS Then
      If predecessor < .ALL.RIGHT_BRACES Then Call InsertAbuttal
    When element < (.ALL.SYMBOLS_AND_STRINGS || .ALL.LUA_CONSTANTS ) Then Do
      Select
        When predecessor < ( .ALL.SYMBOLS_AND_STRINGS || .ALL.LUA_CONSTANTS )
          Then Call InsertAbuttal .True
        When predecessor < .ALL.RIGHT_BRACES        Then Call InsertAbuttal .True
        Otherwise Nop
      End
    End
    Otherwise Nop
  End
  Return

InsertAbuttal:
  Use Strict Arg checkKeyword = .False
  -- Do not insert an abuttal operator before a keyword
  If checkKeyword, nesting == "", IsAKeyword(element) Then Return
  Call InsertAfter predecessor, .EL.OP.ABUTTAL
  result~value = ""
Return

IsAKeyword:
  If Arg(1) \< .ALL.SYMBOLS Then Return 0
  Return WordPos( Arg(1)~value, keywords ) > 0

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, element, "[" )

-- Left parenthesis "(" in position &1 on line &2
-- requires a corresponding right parenthesis ")".
36.901: Syntax( 36.901, lastItem, pos, line )

-- Square bracket "[" in position &1 on line &2
-- requires a corresponding right square bracket "]".
36.902: Syntax( 36.902, lastItem, pos, line )

-- Unmatched ")" in expression.
37.002: Syntax( 37.002, element )

-- Unexpected "]".
37.901: Syntax( 37.901, element )

--------------------------------------------------------------------------------
-- Lambda.Do.Block                                                             --
--------------------------------------------------------------------------------

::Routine Lambda.Do.Block Public

  Use Arg package, DO

  Call SetCategory DO, .EL.KEYWORD

  element = TheElementAfter(DO)

  If element \< .EL.END_OF_CLAUSE Then Signal 21.900

  instructions = Array()

  ENDClauseIsOK = 1

  lastInstruction = .Nil

  package~blockInstructionsStacks~push(.Stack~new())
  package~blockInstructionsStacks~top~push(DO)

  Loop
    instruction = package~clauser~Next.Instruction( ENDClauseIsOK )
    If \instruction~labels~isEmpty Then Signal 47.002
    instrClass = instruction~class
    Select Case instrClass
      When .End.Clause                Then Signal End.Clause
      When .Expose.Instruction        Then Signal 99.907
      When .Implicit.Exit.Instruction Then Signal 14.001
      Otherwise Nop
    End
    instructions~append( instruction )
    lastInstruction = instruction
  End

End.Clause:
  END = TheElementAfter( instruction~begin )

  package~blockInstructionsStacks~pop

  Lambda.Do.Block = .Lambda.Do.Block~new( DO, END, instructions )

  DO~Lambda.Do.Block = Lambda.Do.Block

  Return Lambda.Do.Block


-- DO instruction on line &1 requires matching END.
14.001: Syntax( 14.001, instruction~end, doLine )


21.900: Syntax( 21.900, DO, "Data must not follow the DO keyword;",
   "found "element~source".")

-- Labels are not allowed within a DO/LOOP block; found "&1".
47.002: Syntax( 47.002, instruction~end, instruction~labels[1]~label )

-- EXPOSE must be the first instruction executed after a method invocation.
99.907: Syntax( 99.907, DO )

--------------------------------------------------------------------------------

::Class Lambda.Do.Block Public
::Attribute DO
::Attribute END
::Method begin; Return self~DO
::Attribute instructions
::Method Init
  Expose  DO  END  instructions
  Use Arg DO, END, instructions

--------------------------------------------------------------------------------
-- InsertSemicolonBefore                                                      --
--------------------------------------------------------------------------------

::Routine InsertSemicolonBefore Public

  Use Strict Arg element

  Parse Value element~from With line col

  semicolon      = .Inserted.Semicolon~new(line, col)

  -- Insert it between element~prev and element

  left           = element~prev

  semicolon~next = element
  semicolon~prev = left
  left~next      = semicolon
  element~prev   = semicolon

  -- Apply Rexx whitespace rules
  left           = TheElementBefore( semicolon )
  right          = TheElementAfter(  semicolon )
  If left  < .ALL.WHITESPACE_LIKE Then left ~makeIgnorable
  If right < .ALL.WHITESPACE_LIKE Then right~makeIgnorable

  Return semicolon

--------------------------------------------------------------------------------
-- IsKeyword                                                                  --
--   If the element is not a symbol, or it is not the keyword we are looking  --
--   for, return 0. Else mark that this is a keyword, ignore whitespace to    --
--   the right, if any, and return 1.                                         --
--------------------------------------------------------------------------------

::Routine IsKeyword Public
  Use Strict Arg element, keyword

  -- Not a symbol? This is not a keyword
  If element \< .ALL.SYMBOLS_AND_KEYWORDS Then Return 0

  -- Not the keyword we are looking for
  If element~value \== keyword Then Return 0

  -- Mark that this is a keyword
  Call SetCategory element, .EL.KEYWORD

  -- And ignore whitespace to its right when necessary
  next = TheElementAfter( element )
  If next~category < .ALL.WHITESPACE_LIKE Then next~makeIgnorable

  Return 1

--------------------------------------------------------------------------------
-- Resource.Data -- For ::RESOURCE directives                                 --
--------------------------------------------------------------------------------

::Routine Resource.Data Public
  Use Strict Arg source, first, last

  resource_data          = .Resource.Data~new
  resource_data~category = .EL.RESOURCE_DATA
  resource_data~from     = first 1
  resource_data~to       = last (Length(source[last])+1)
  resource_data~source   = source
  Return                   resource_data

--------------------------------------------------------------------------------
-- IgnoredData -- For ::RESOURCE directives                                   --
--------------------------------------------------------------------------------

::Routine IgnoredData Public
  Use Strict Arg source, line, start

  ignored_data          = .Element~new
  ignored_data~category = .EL.RESOURCE_IGNORED_DATA
  ignored_data~from     = line start
  ignored_data~to       = line (Length(source[line])+1)
  ignored_data~source   = SubStr( source[line], start )
  ignored_data~makeIgnorable
  Return                  ignored_data

--------------------------------------------------------------------------------
-- InsertAfter                                                                --
--------------------------------------------------------------------------------

::Routine InsertAfter Public

  use Strict Arg element, class

  Parse Value element~to With line col

  inserted      = .Inserted.Element~new(class, line,col)

  -- Insert it between element and element~next

  next          = element~next

  inserted~next = next
  inserted~prev = element
  element~next  = inserted
  next~prev     = inserted

  Return          inserted
