/******************************************************************************/
/*                                                                            */
/* Expressions.cls                                                            */
/* ===============                                                            */
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
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250416    0.2a Add argument info to called routine chain                 */
/*                                                                            */
/******************************************************************************/

.environment ~ Concatenation.Expression = .Concatenation.Expression
.environment ~ Expression.List          = .Expression.List
.environment ~ NAry.Expression          = .NAry.Expression
.environment ~ Prefix.Expression        = .Prefix.Expression
.environment ~ SubExpression            = .SubExpression

.environment ~ NameSpace.Qualified.ClassName = -
  .NameSpace.Qualified.ClassName
.environment ~ NameSpace.Qualified.Function.Call = -
  .NameSpace.Qualified.Function.Call

.environment ~               Rexx.Term  =               .Rexx.Term

.environment ~  Compound.Variable.Term  =  .Compound.Variable.Term
.environment ~            Indexed.Term  =            .Indexed.Term
.environment ~      Function.Call.Term  =      .Function.Call.Term
.environment ~     Literal.String.Term  =     .Literal.String.Term
.environment ~            Message.Term  =            .Message.Term
.environment ~      Stem.Variable.Term  =      .Stem.Variable.Term
.environment ~             Symbol.Term  =             .Symbol.Term
.environment ~ Variable.Reference.Term  = .Variable.Reference.Term

::Requires "Tokenizer.cls"

/******************************************************************************/
/******************************************************************************/
/* CLASSES DEFINING EXPRESSIONS                                               */
/******************************************************************************/
/******************************************************************************/

::Class Rexx.Expression      Public
::Constant isEmpty 0

/******************************************************************************/
/* This private class implements code common to many subexpression cases      */
/******************************************************************************/

::Class NAry.Expression SubClass Rexx.Expression
::Constant items 1
::Attribute args Get
::Attribute end
::Method init
  Expose args end
  args = arg(1, "A")
  end = args~lastItem~end

/******************************************************************************/
/* EXPRESSION LIST                                                            */
/*   One of:                                                                  */
/*     expression                           -- A classic expression, or...    */
/*     [expression] ("," [expression]) *    -- ...an array term               */
/******************************************************************************/

::Routine Expression.List Public

  Use Strict Arg package, begin, terminators = "", options = ""

  logical        = options~caselessContainsWord( "logical" )

  expressions    = Array()
  element          = begin
  trailingComma  = 0
  stopParsing    = .EL.KEYWORD || .EL.END_OF_CLAUSE
  terminators  ||= stopParsing
  commasFound    = 0

  newTerminators = terminators || .EL.COMMA

  Loop While element \< .ALL.EXPRESSION_TERMINATORS

    trailingComma = 0

    Do While element < .EL.COMMA
      commasFound = 1
      If logical Then Call 35.929 element
      expressions~append( element )
      element = TheElementAfter( element )
      trailingComma = 1
    End

  If element < terminators Then Leave

    trailingComma = 0

    newOrExpression = Or.Expression( package, element, newTerminators )
    element = newOrExpression~end
    expressions~append( newOrExpression )

  If element \< .EL.COMMA Then Leave

    expressions~append( element )

    element = TheElementAfter( element )
    trailingComma = 1
    commasFound = 1
  End


  If trailingComma, logical Then Call 35.929 begin

  Select Case expressions~items
    When 0 Then Return .Expression.List~new(.Nil, begin)
    -- Only one expression and no commas? --> A classic expression
    When 1 Then If \commasFound Then Return expressions[1]
    Otherwise Nop
  End
  Return .Expression.List~new(expressions, .Nil)

-- Missing expression in logical expression list.
35.929: Syntax( 35.929, Arg(1), Arg(1) )

--------------------------------------------------------------------------------

::Class Expression.List Public SubClass Rexx.Expression
::Attribute end
::Attribute args

::Method arg
  Expose argList
  Arg n, option +1
  Select Case Arg()
    When 0 Then Return argList~size
    When 1 Then Return argList[n]
    Otherwise
      Select Case option
        When "E" Then Return  argList~hasIndex(n)
        When "O" Then Return \argList~hasIndex(n)
      End
  End

::Method isEmpty
  Expose args
  Return args == .Nil
::Method init
  Expose args argList end
  Use Strict Arg args, end
  argList = Array()
  If args \== .Nil Then Do

    -- Calculate end
    last = args~lastItem
    If last~isA( .Special.Character.Sequence ) Then -- A .EL.COMMA
      end = TheElementAfter( last )
    Else end = last~end

    -- Calculate the number of arguments (for argument lists)
    argN = 1
    Do i = 1 To args~items
      If args[i]~isA( .Special.Character.Sequence ) Then argN += 1
      Else argList[argN] = args[i]
    End

  End

/******************************************************************************/
/* OR.EXPRESSION                                                              */
/*   expr       := expr_alias                                   (6.3.2.98)    */
/*   expr_alias := and_expression                               (6.3.2.99)    */
/*              | (expr_alias or_operator and_expression)                     */
/******************************************************************************/

::Routine Or.Expression Public

  Use Strict Arg package, begin, terminators

  and_expressions = Array()
  element           = begin
  newTerminators  = terminators || .ALL.OPS.ALTERNATIVE

  Loop

    newAndExpression = And.Expression( package, element, newTerminators )
    element = newAndExpression~end
    and_expressions~append( newAndExpression )

  If element \< .ALL.OPS.ALTERNATIVE Then Leave

    and_expressions~append( element~value )
    element        = TheElementAfter( element )

  End

  If and_expressions~items == 1 Then Return and_expressions[1]

  expression = .Or.Expression~sendWith("new",and_expressions)

  Return expression

--------------------------------------------------------------------------------

::Class Or.Expression Public SubClass NAry.Expression

/******************************************************************************/
/* AND.EXPRESSION                                                             */
/*   and_expression := comparison                               (6.3.2.101)   */
/*                    | and_expression '&' comparison                         */
/******************************************************************************/

::Routine And.Expression

  Use Strict Arg package, begin, terminators

  comparisons    = Array()
  element          = begin
  newTerminators = terminators || .EL.OP.AND

  Loop

    newComparison = Comparison.Expression( package, element, newTerminators )
    element = newComparison~end
    comparisons~append( newComparison )

  If element \< .EL.OP.AND Then Leave

    comparisons~append( element~value )
    element        = TheElementAfter( element )

  End

  If comparisons~items == 1 Then Return comparisons[1]

  Return .And.Expression~sendWith("new",comparisons)

--------------------------------------------------------------------------------

::Class And.Expression  Public SubClass NAry.Expression

/******************************************************************************/
/* COMPARISON.EXPRESSION                                                      */
/*   comparison := concatenation                                (6.3.2.102)   */
/*              | comparison comparison_operator concatenation                */
/*   comparison_operator:= normal_compare | strict_compare      (6.3.2.103)   */
/*   normal_compare:= '=' | '\=' | '<>' | '><' | '>' | '<'      (6.3.2.104)   */
/*     | '>=' | '<=' | '\>' | '\<'                                            */
/*   strict_compare:= '==' | '\==' | '>>' | '<<' | '>>='        (6.3.2.105)   */
/*     | '<<=' | '\>>' | '\<<'                                                */
/******************************************************************************/

::Routine Comparison.Expression Public

  Use Strict Arg package, begin, terminators

  concatenations = Array()
  element           = begin
  newTerminators  = terminators || .ALL.OPS.COMPARISON

  Loop

    newConcatenation = Concatenation.Expression( package, element, newTerminators )
    element = newConcatenation~end
    concatenations~append( newConcatenation )

    If element \< .ALL.OPS.COMPARISON Then Leave

    concatenations~append( element~value )
    element      = TheElementAfter( element )

  End

  If concatenations~items == 1 Then Return concatenations[1]

  Return .Comparison.Expression~sendWith("new",concatenations)

--------------------------------------------------------------------------------

::Class Comparison.Expression Public SubClass NAry.Expression

/******************************************************************************/
/* CONCATENATION.EXPRESSION                                                   */
/*   concatenation := addition                                (6.3.2.106)     */
/*                 | concatenation [' ' | '||'] addition                      */
/******************************************************************************/

::Routine Concatenation.Expression Public

  Use Strict Arg package, begin, terminators

  additions      = Array()
  element           = begin
  newTerminators  = terminators || .ALL.OPS.CONCATENATION

  Loop

    newAddition = Addition.Expression( package, element, newTerminators )
    element = newAddition~end
    additions~append( newAddition )

  If element \< .ALL.OPS.CONCATENATION Then Leave

    additions~append( element~value )
    element      = TheElementAfter( element )

  End

  If additions~items == 1 Then Return additions[1]

  Return .Concatenation.Expression~sendWith("new",additions)

--------------------------------------------------------------------------------

::Class Concatenation.Expression Public SubClass NAry.Expression

/******************************************************************************/
/* ADDITION EXPRESSION                                                        */
/*   addition          :=   multiplication                       (6.3.2.107)  */
/*    | addition additive_operator multiplication                             */
/*   additive_operator := '+' | '-'                              (6.3.2.108)  */
/******************************************************************************/

::Routine Addition.Expression

  Use Strict Arg package, begin, terminators

  multiplications = Array()
  element           = begin
  newTerminators  = terminators || .ALL.OPS.ADDITIVE

  Loop

    newMultiplication = Multiplication.Expression( package, element, newTerminators )
    element = newMultiplication~end
    multiplications~append( newMultiplication )

  If element \< .ALL.OPS.ADDITIVE Then Leave

    multiplications~append( element~value )
    element      = TheElementAfter( element )

  End

  If multiplications~items == 1 Then Return multiplications[1]

  Return .Addition.Expression~sendWith("new",multiplications)

--------------------------------------------------------------------------------

::Class Addition.Expression Public SubClass NAry.Expression

/******************************************************************************/
/* MULTIPLICATION.EXPRESSION                                                  */
/*   multiplication := power_expression                         (6.3.2.109)   */
/*     | multiplication multiplicative_operator power_expression              */
/*   multiplicative_operator:= '*' | '/' | '//' | '%'           (6.3.2.110)   */
/******************************************************************************/

::Routine Multiplication.Expression

  Use Strict Arg package, begin, terminators

  powers         = Array()
  element          = begin
  newTerminators = terminators || .ALL.OPS.MULTIPLICATIVE

  Loop

    newPower = Power.Expression( package, element, newTerminators )
    element = newPower~end
    powers~append( newPower )

  If element \< .ALL.OPS.MULTIPLICATIVE Then Leave

    powers~append( element~value )
    element      = TheElementAfter( element )

  End

  If powers~items == 1 Then Return powers[1]

  Return .Multiplication.Expression~sendWith("new",powers)

--------------------------------------------------------------------------------

::Class Multiplication.Expression Public SubClass NAry.Expression

/******************************************************************************/
/* POWER.EXPRESSION                                                           */
/*   power_expression := prefix_expression                      (6.3.2.111)   */
/*     | power_expression '**' prefix_expression                              */
/******************************************************************************/

::Routine Power.Expression

  Use Strict Arg package, begin, terminators

  expressionArray = Array()
  element           = begin
  newTerminators  = terminators || .EL.OP.POWER

  Loop

    newPrefix = Prefix.Expression( package, element, newTerminators )
    element = newPrefix~end
    expressionArray~append( newPrefix )

  If element \< .EL.OP.POWER Then Leave

    expressionArray~append( "**" )
    element        = TheElementAfter( element )

  End

  If expressionArray~items == 1 Then Return expressionArray[1]

  Return .Power.Expression~sendWith("new",expressionArray)

--------------------------------------------------------------------------------

::Class Power.Expression Public SubClass NAry.Expression

/******************************************************************************/
/* PREFIX.EXPRESSION                                                          */
/*   prefix_expression := ('+' | '-' | '\') prefix_expression  (6.3.2.112)    */
/*    | term | Msg35.1                                                        */
/******************************************************************************/

::Routine Prefix.Expression Public

  Use Strict Arg package, begin, terminators

  prefixes = Array()
  element    = begin

  Do While element < .PREFIX_OPERATORS
    -- Assign prefix operators when appropriate
    Select Case element~category
      When .EL.OP.PLUS  Then Call SetCategory element, .EL.OP.PREFIX.PLUS
      When .EL.OP.MINUS Then Call SetCategory element, .EL.OP.PREFIX.MINUS
      Otherwise Nop -- "\" is always a prefix operator
    End
    prefixes~append( element~value )
    element =  TheElementAfter( element )
  End

  term = Term( package, element, terminators )

  If prefixes~isEmpty Then Return term

  Return .Prefix.Expression~new( prefixes, term )

--------------------------------------------------------------------------------

::Class Prefix.Expression Public SubClass Rexx.Expression
::Attribute end
::Attribute prefixes
::Attribute term
::Method arg
  Arg n, option +1
  If Arg() == 0 Then Return 1
  If Arg() == 1 Then
    If n == 1 Then Return self
    Else Return .nil
  Return option = "E"
::Method init
  Expose prefixes term end
  Use Strict Arg prefixes, term
  end = term~end

/******************************************************************************/
/******************************************************************************/
/* TERMS                                                                      */
/******************************************************************************/
/******************************************************************************/

::Class Rexx.Term Public
::Method arg
  Arg n, option +1
  If Arg() == 0 Then Return 1
  If Arg() == 1 Then
    If n == 1 Then Return self
    Else Return .nil
  Return option = "E"
::Constant isEmpty 0

--------------------------------------------------------------------------------
-- Term                                                                  --
--   A term may be:                                                           --
--    1) A function call                                                      --
--    2) A message term                                                       --
--    3) A variable reference term                                            --
--    4) A subexpression                                                      --
--    5) A symbol                                                             --
--    6) A literal string                                                     --
--    Case 7), an array term, is handled elsewhere in the parser.             --
--  See rexxref 5.1.0 1.11.1. Terms and Expressions                           --
--------------------------------------------------------------------------------

::Routine Term
  Use Strict Arg package, begin, terminators

  termArray = Array()
  element     = begin
  newTerminators = terminators || .ALL.OPS.MESSAGE_SEND

  term = Simple.Term( package, element, newTerminators )

  Return Simple.Message.Term( package, term )

--------------------------------------------------------------------------------
-- SIMPLE.TERM                                                                --
--   A simple term is a term that is neither a message term nor an            --
--   unparenthesized array term, namely:                                      --
--    1) A function call                                                      --
--    3) A variable reference term                                            --
--    4) A subexpression                                                      --
--    5) A symbol                                                             --
--    6) A literal string                                                     --
--  See rexxref 5.1.0 1.11.1. Terms and Expressions                           --
--------------------------------------------------------------------------------

::Routine Simple.Term Public
  Use Strict Arg package, begin, terminators

  Select
    When begin < .EL.LEFT_PARENTHESIS Then Return SubExpression( package, begin, terminators )
    When begin < .ALL.SYMBOLS Then Do
      symbol = begin
      element = TheElementAfter( symbol )
      Select Case element~category
        -- Followed by ":"? This is a namespace-qualified symbol
        When .EL.COLON Then
          Exit Namespace.Qualified.Symbol( package, symbol, element )
        -- Followed by "("? This is a function call
        When .EL.LEFT_PARENTHESIS Then
          Exit Function.Call.Term( package, symbol, element, terminators )
        Otherwise
          Exit Symbol.Term( package, begin, terminators )
      End
    End
    When begin < .ALL.STRINGS Then
      Return Literal.String.Term( package, begin, terminators )
    When begin < .ALL.OPS.REFERENCE Then
      Return Variable.Reference.Term( package, begin )
   Otherwise
      -- Incorrect expression detected at "element".
      -- Backtrack one item if expression ends abruptly, to produce
      -- a more understandable error message.

      oneBack = TheElementBefore( begin )

      If begin < .EL.END_OF_CLAUSE Then Call 35.001 oneback
      If begin < .EL.KEYWORD       Then Call 35.001 oneback
      Call 35.001 begin
  End

-- Incorrect expression detected at "&1".
35.001: Syntax( 35.001, begin, Arg(1) )

--------------------------------------------------------------------------------
-- LITERAL.STRING.TERM                                                        --
--------------------------------------------------------------------------------
::Routine Literal.String.Term

  Use Strict Arg package, name, terminators

  element = TheElementAfter( name )

  If element < .EL.LEFT_PARENTHESIS Then Signal FunctionCall

  -- Simple case (not a function call)
  Exit .Literal.String.Term~new( name )

FunctionCall:
  lParen        = element
  next          = TheElementAfter( lParen )  -- Where to start parsing
  terminators ||= .EL.RIGHT_PARENTHESIS      -- Add ")" to terminators

  arguments = Expression.List( package, next, terminators )

  Call ExpectParenPair lParen, arguments~end

  name~invocationType = Function

  package~currentBody~calledRoutineNames~append( (name, arguments) )

  Exit .Function.Call.Term~new(name, arguments )

--------------------------------------------------------------------------------

::Class Literal.String.Term Public SubClass Rexx.Term
::Attribute end
::Attribute string
::Method init
  Expose string end
  Use Strict Arg string
  end = TheElementAfter( string )

/******************************************************************************/
/* SUBEXPRESSION                                                              */
/******************************************************************************/

::Routine SubExpression Public

  Use Strict Arg package, begin, terminators = ""

  lParen = begin

  subExpression = Expression.List( -
    package,                          -
    TheElementAfter( begin ),           - -- Where to begin parsing
    terminators || .EL.RIGHT_PARENTHESIS - -- Add ")" to terminators
  )

  rParen = subExpression~end

  Call ExpectParenPair lParen, rParen

  Return .SubExpression~new( subExpression )

--------------------------------------------------------------------------------

::Class SubExpression Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose subExpression end
  Use Strict Arg subExpression
  end = TheElementAfter( subExpression~end )

--------------------------------------------------------------------------------
-- Simple.Message.Term                                                        --
--   Used when parsing templates too                                          --
--------------------------------------------------------------------------------

::Routine Simple.Message.Term Public

  Use Strict Arg package, term

  Loop

    element = term~end

  If element \< .ALL.OPS.MESSAGE_SEND Then Return term

    If element < .EL.LEFT_BRACKET
      Then term = Indexed.Term( package, term, element, "" )   -- "["
      Else term = Message.Term( package, term, element, "" )   -- "~", "~~"

  End

--------------------------------------------------------------------------------
-- SYMBOL.TERM                                                                --
--------------------------------------------------------------------------------

::Routine Symbol.Term Public

  Use Strict Arg package, symbol, terminators, inExpose = .False

  If symbol < .ALL.COMPOUND_VARIABLES Then
    Exit Compound.Variable.Term( package, symbol, inExpose )

  If symbol < .ALL.STEM_VARIABLES     Then
    Exit     Stem.Variable.Term( package, symbol, inExpose )

  -- Change the element category of variable symbols to reflect whether
  -- they are local or instance variables.
  If symbol < .EL.SIMPLE_VARIABLE Then Do
    varName       = symbol~value
    thisBody      = package~currentBody
    exposed       = thisBody~exposed
    useLocal      = thisBody~useLocal
    If inExpose Then Call Exposed .False
    Else If \exposed~isEmpty   Then Do  -- This body starts with EXPOSE
      If  exposed ~hasItem( varName ) Then Call Exposed .False
    End
    Else If useLocal \ == .Nil Then Do  -- This body starts with USE LOCAL
      If \useLocal~hasitem( varName ) Then Call Exposed .True
    End
  End

  Exit .Symbol.Term~new( package, symbol )

Exposed:
  -- "Note that USE LOCAL will always keep Rexx special variables RC, RESULT,
  --  SIGL, SELF, and SUPER as local variables" (rexxref).
  If Arg(1) Then -- That's USE LOCAL
    If WordPos(symbol~value, "RC RESULT SIGL SELF SUPER") > 0 Then Return
  Call SetCategory symbol, .EL.EXPOSED_SIMPLE_VARIABLE
Return

--------------------------------------------------------------------------------

::Class Symbol.Term Public SubClass Rexx.Term
::Attribute symbol
::Attribute end
::Method value
  Return self~symbol
::Method init
  Expose symbol end

  Use Strict Arg package, symbol

  end = TheElementAfter( symbol )

--------------------------------------------------------------------------------
-- COMPOUND.VARIABLE.TERM                                                     --
--------------------------------------------------------------------------------

::Routine Compound.Variable.Term

  Use Strict Arg package, variable, inExpose

  thisBody      = package~currentBody
  exposed       = thisBody~exposed
  useLocal      = thisBody~useLocal

  Parse Value variable~from With line col
  sourceLine    = package~source[line]

  Parse Value variable~value With stemName"."tail
  stemName = stemName"."
  offset = Length(stemName)

  stemClass = StemClass()

  Select Case stemClass
    When .EL.STEM_VARIABLE         Then variableClass =         .EL.COMPOUND_VARIABLE
    When .EL.EXPOSED_STEM_VARIABLE Then variableClass = .EL.EXPOSED_COMPOUND_VARIABLE
  End

  Call SetCategory variable, variableClass

  stem = .StringOrSymbol.Element~new( -
    stemClass, line, col, col+offset, sourceLine -
  )

  parts = Array(stem) -- Parts of the tail

  col += offset
  Do While tail~contains(".")
    Parse Var tail fragment"."tail
    If fragment \== "" Then Call AddFragment
    Call AddDot
  End
  fragment = tail
  Call AddFragment

  term = .Compound.Variable.Term~new( variable, parts )

  variable~term  = term
  variable~parts = parts

  Exit term

StemClass:
  If inExpose Then Return .EL.EXPOSED_STEM_VARIABLE
  If \exposed~isEmpty Then Do        -- This body starts with EXPOSE
    If  exposed ~hasItem( stemName ) Then Return .EL.EXPOSED_STEM_VARIABLE
  End
  Else If useLocal \ == .Nil Then Do -- This body starts with USE LOCAL
    If \useLocal~hasitem( stemName ) Then Return .EL.EXPOSED_STEM_VARIABLE
  End
  Return .EL.STEM_VARIABLE

AddDot:
  dot = .Tail.Separator.Element~new(.EL.TAIL_SEPARATOR, line, col)
  parts ~ append( dot )
  col += 1
Return

AddFragment:
  If fragment == "" Then Return
  Select
    When DataType(fragment, "Variable") Then Do
      partClass = .EL.SIMPLE_VARIABLE
      Select
        When exposed~hasItem( Upper(fragment) ) Then
          partClass = .EL.EXPOSED_SIMPLE_VARIABLE
        When exposed~isEmpty Then Do
          If useLocal \== .Nil, \ useLocal~hasitem( fragment ) Then
            partClass = .EL.EXPOSED_SIMPLE_VARIABLE
        End
        Otherwise Nop
      End
    End
    When DataType(fragment, "Whole")    Then partClass = .EL.INTEGER_NUMBER
    Otherwise                                partClass = .EL.SYMBOL_LITERAL
  End
  newCol = col+Length(fragment)
  fragment = .StringOrSymbol.Element~new(      -
    partClass, line, col, newCol, sourceLine -
  )
  col = newCol
  parts ~ append( fragment )
Return

--------------------------------------------------------------------------------

::Class Compound.Variable.Term Public SubClass Rexx.Term
::Attribute stem
::Attribute parts
::Attribute end
::Method init
  Expose stem parts end
  Use Strict Arg stem, parts
  end = TheElementAfter( stem )

--------------------------------------------------------------------------------
-- STEM.VARIABLE.TERM                                                         --
--------------------------------------------------------------------------------

::Routine Stem.Variable.Term

  Use Strict Arg package, stem, inExpose

  thisBody        = package~currentBody
  newClass = .EL.EXPOSED_STEM_VARIABLE

  -- Special handling for EXPOSE instructions
  If inExpose Then Call SetCategory stem, newClass
  Else Do -- Not an EXPOSE instruction
    stemName      = stem    ~value
    thisBody      = package ~currentBody
    exposed       = thisBody~exposed
    useLocal      = thisBody~useLocal
    If \exposed~isEmpty        Then Do  -- This body starts with EXPOSE
      If  exposed ~hasItem( stemName ) Then Call SetCategory stem, newClass
    End
    Else If useLocal \ == .Nil Then Do  -- This body starts with USE LOCAL
      If \useLocal~hasitem( stemName ) Then Call SetCategory stem, newClass
    End
  End

  Exit .Stem.Variable.Term~new( stem )

--------------------------------------------------------------------------------

::Class Stem.Variable.Term Public SubClass Rexx.Term
::Constant items 1
::Attribute end
::Attribute stem
::Method init
  Expose stem end
  Use Strict Arg stem
  end = TheElementAfter( stem )

--------------------------------------------------------------------------------
-- Namespace-qualified symbols                                                --
--------------------------------------------------------------------------------

::Routine Namespace.Qualified.Symbol Public

  Use Strict Arg package, nameSpace, colon

  Call SetConstantName nameSpace, .NAMESPACE.NAME

  symbol    = TheElementAfter( colon )
  If symbol \< .ALL.SYMBOLS Then Signal 20.923
  element = TheElementAfter( symbol )
  If element \< .EL.LEFT_PARENTHESIS Then
    Exit .NameSpace.Qualified.ClassName~new( nameSpace, symbol )

-- xxx

  routineName  = symbol
  Call SetConstantName routineName, .EXTERNAL.PACKAGE.FUNCTION.NAME
  lParen       = element

  next         = TheElementAfter( lParen )

  arguments = Expression.List(        -
    package,                          -
    next,                             - -- Where to begin parsing
    terminators || .EL.RIGHT_PARENTHESIS - -- Add ")" to terminators
  )

  Call ExpectParenPair lParen, arguments~end

  Exit .NameSpace.Qualified.Function.Call~new( -
    nameSpace, routineName, arguments          -
  )

-- Symbol expected as a name of namespace-qualified symbol.
20.923: Syntax( 20.923, colon )

--------------------------------------------------------------------------------
-- FUNCTION.CALL.TERM                                                         --
--------------------------------------------------------------------------------

::Routine Function.Call.Term Public

  Use Strict Arg package, name, lParen, terminators

  next = TheElementAfter( lParen )

  arguments = Expression.List(           -
    package,                             -
    next,                                - -- Where to begin parsing
    terminators || .EL.RIGHT_PARENTHESIS - -- Add ")" to terminators
  )

  Call ExpectParenPair lParen, arguments~end

  name~invocationType = Function

  package~currentBody~calledRoutineNames~append( (name, arguments) )

  Exit .Function.Call.Term~new( name, arguments )

--------------------------------------------------------------------------------

::Class Function.Call.Term Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose name argumentList end
  Use Strict Arg name, argumentList
  end = TheElementAfter( argumentList~end )

--------------------------------------------------------------------------------

::Class NameSpace.Qualified.Function.Call Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose nameSpace name argumentList end
  Use Strict Arg nameSpace, name, argumentList
  end = argumentList~end~next

--------------------------------------------------------------------------------

::Class NameSpace.Qualified.ClassName Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose nameSpace className end
  Use Strict Arg nameSpace, className
  Call SetConstantName nameSpace, .NAMESPACE.NAME
  Call SetConstantName className, .CLASS.NAME
  end = TheElementAfter( className )

--------------------------------------------------------------------------------
-- Indexed.Term                                                               --
--                                                                            --
-- Cfr. Dallas report                                                         --
--   message_term := term '['[ expression_list ] (']' | Msg36.2)              --
-- See also rexxref 5.1.0, 1.11.4. Message Terms                              --
--   message_term := receiver '[' [[expression] ,]* ']'                       --
--                                                                            --
--------------------------------------------------------------------------------

::Routine Indexed.Term Public

  Use Strict Arg package, receiver, lBracket, terminators

  -- Store parenthesis location information
  Parse Value lBracket~from With line pos

  arguments = Expression.List( -
    package,                    -
    TheElementAfter( lBracket ),  - -- Where to start parsing
    terminators || .EL.RIGHT_BRACKET    - -- Add "]" to terminators
  )

  -- Expecting a closing bracket now
  If arguments~end \< .EL.RIGHT_BRACKET Then Signal 36.902

  Return .Indexed.Term~new( receiver, arguments )

-- Square bracket "[" in position &1 on line &2 requires
-- a corresponding right square bracket "]".
36.902: Syntax( 36.902, lBracket, pos, line)

--------------------------------------------------------------------------------

::Class Indexed.Term Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose term argumentList end
  Use Strict Arg term, argumentList
  rBracket = argumentList~end
  end      = TheElementAfter( rBracket )

--------------------------------------------------------------------------------
-- Message.Term                                                               --
--                                                                            --
-- Cfr. Dallas report                                                         --
--   message_term:= term ('~' | '~~') method_name [arguments]                 --
-- See also rexxref 5.1.0, 1.11.4. Message Terms                              --
--   message_term:= receiver ('~' | '~~') messagename [: symbol] [arguments]  --
--                                                                            --
--------------------------------------------------------------------------------

::Routine Message.Term Public

  Use Strict Arg package, receiver, operator, terminators = ""

  messageName = TheElementAfter( operator )

  If messageName \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.909

  scope = .Nil
  next = TheElementAfter( messageName )

  If next < .EL.COLON Then Do
    scope = TheElementAfter( next )

    If scope \< .ALL.MESSAGE_SCOPE_ELEMENTS Then Signal 20.917

    lParen = TheElementAfter( scope )
  End
  Else lParen  = next

  arguments = .Nil
  If lParen < .EL.LEFT_PARENTHESIS Then Do

    arguments = Expression.List(        -
      package,                          -
      TheElementAfter( lParen ),          - -- Where to start parsing
      terminators || .EL.RIGHT_PARENTHESIS - -- Add ")" to terminators
    )

    Call ExpectParenPair lParen, arguments~end

  End

  Exit .Message.Term~new(                             -
    receiver, operator, messageName, scope, arguments -
  )

-- String or symbol expected after tilde (~).
19.909: Syntax( 19.909, messageName )

-- Symbol expected after superclass colon (:).
20.917: Syntax( 20.917, next )

--------------------------------------------------------------------------------

::Class Message.Term Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose term operator messageName scope arguments end
  Use Strict Arg term, operator, messageName, scope, arguments
  Call SetConstantName messageName, .METHOD.NAME
  If arguments == .Nil Then
    If scope \== .Nil Then end = TheElementAfter( scope       )
    Else                   end = TheElementAfter( messageName )
  Else Do
    rParen = arguments~end
    end = TheElementAfter( rParen )
  End

--------------------------------------------------------------------------------
-- VARIABLE.REFERENCE.TERM                                                    --
--  See rexxref 5.1.0 1.11.7. Variable Reference Term                         --
--------------------------------------------------------------------------------
::Routine Variable.Reference.Term

  Use Strict Arg package, operator

  variable     = TheElementAfter( operator )

  If variable < .ALL.REFERENCED_SYMBOLS Then
    Return .Variable.Reference.Term~new(operator, variable)

  Signal 20.930

-- Simple variable or stem symbol expected after
-- > or < prefix operator; found &1.
20.930: Syntax( 20.930, operator, variable )

--------------------------------------------------------------------------------

::Class Variable.Reference.Term Public SubClass Rexx.Term
::Attribute end
::Method init
  Expose operator variable end
  Use Strict Arg operator, variable
  end = TheElementAfter( variable )

--------------------------------------------------------------------------------
-- ExpectParenPair                                                        --
--------------------------------------------------------------------------------

::Routine ExpectParenPair Public
  Use Strict Arg lParen, rParen
  If rParen < .EL.RIGHT_PARENTHESIS Then Return
  Parse Value lParen~from With line Pos

-- Left parenthesis "(" in position &1 on line &2 requires
-- a corresponding right parenthesis ")".
36.901: Syntax( 36.901, lParen, pos, line)
