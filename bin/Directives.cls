/******************************************************************************/
/*                                                                            */
/* Directives.cls                                                             */
/* ==============                                                             */
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
/* 20241209    0.1b Add .PACKAGE.FUNCTION.NAME, .PACKAGE.SUBROUTINE.NAME       */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/*                                                                            */
/******************************************************************************/

.environment ~  Annotate.Directive =  .Annotate.Directive
.environment ~ Attribute.Directive = .Attribute.Directive
.environment ~     Class.Directive =     .Class.Directive
.environment ~  Constant.Directive =  .Constant.Directive
.environment ~    Method.Directive =    .Method.Directive
.environment ~   Options.Directive =   .Options.Directive
.environment ~   Requires.Directive = .Requires.Directive
.environment ~   Resource.Directive = .Resource.Directive
.environment ~    Routine.Directive =  .Routine.Directive

::Requires "BaseClassesAndRoutines.cls"
::Requires "Expressions.cls"

/******************************************************************************/
/* ANNOTATE directive                                                         */
/******************************************************************************/

::Routine Annotate.Directive Public
  -- TODO [LATER] Check that annotations refer to something existent
  -- (and implement 99.945 )

  Use Strict Arg package, begin, end, elements

  ANNOTATE = elements[2]

  ignoreBlanks  = .True
  options.      = .Nil
  options.pairs = Array()

  keyword = TheElementAfter( ANNOTATE )

  If keyword \< .ALL.SYMBOLS Then Signal 20.924

  kValue = keyword~value

  validKeywords = "ATTRIBUTE CLASS CONSTANT METHOD PACKAGE ROUTINE"

  If WordPos(kValue, validKeywords) == 0 Then Signal 25.928

  Call Set.Directive.Keyword keyword

  options.directive = kValue

  If kValue \== "PACKAGE" Then Do
    name = TheElementAfter( keyword )
    If name \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.925
    Select Case kValue
      When "CLASS"   Then Call SetConstantName name, .CLASS.NAME
      When "ROUTINE" Then Call SetConstantName name, .ROUTINE.NAME
      Otherwise           Call SetConstantName name, .METHOD.NAME
    End
    options.["NAME"] = name
    name = TheElementAfter( name, ignoreBlanks )
  End
  Else name = TheElementAfter( keyword )

  Loop
    If name < .EL.END_OF_CLAUSE Then Signal Done
    If name \< .ALL.SYMBOLS Then Signal 20.919
    Call SetConstantName name, .ANNOTATION.NAME
    value = TheElementAfter( name, ignoreBlanks )
    If value < .EL.END_OF_CLAUSE Then Signal 19.924
    If value < .ALL.OPS.ADDITIVE Then Do
      sign = value
      value = TheElementAfter( sign, ignoreBlanks )
    End
    Else sign = .Nil
    If value \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.923
    Call SetConstantName value, .ANNOTATION.VALUE
    options.pairs~append( (name, sign, value) )
    name = TheElementAfter( value, ignoreBlanks )
  End

Done:
  Return .Annotate.Directive~new( package, begin, end, options. )

-- Symbol or string expected as ::ANNOTATE attribute value; found "&1".
19.923: Syntax( 19.923, ANNOTATE, value )

-- Symbol or string expected as ::ANNOTATE attribute value.
19.924: Syntax( 19.924, ANNOTATE )

-- Symbol or string expected after &1 &2 keyword.
19.925: Syntax( 19.925, ANNOTATE, "::ANNOTATE", keyword )

-- Symbol expected as ::ANNOTATE attribute name; found "&1".
20.919: Syntax( 20.919, ANNOTATE, name )

-- Symbol expected for the ::ANNOTATE type.
20.924: Syntax( 20.924, ANNOTATE )

-- Unknown keyword on ::ANNOTATE directive; found "&1".
25.928: Syntax( 25.928, ANNOTATE, keyword )

--------------------------------------------------------------------------------

::Class Annotate.Directive Public SubClass Rexx.Directive
::Method init
  Expose options.
  Use Strict Arg package, begin, end, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* ATTRIBUTE Directive                                                        */
/******************************************************************************/

::Routine Attribute.Directive Public
  -- TODO [LATER] compare keyword handling with DO/LOOP instructions

  Use Strict Arg package, begin, end, elements

  ATTRIBUTE = elements[2]

  name = TheElementAfter( ATTRIBUTE )

  If name \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.914

  If \ DataType(name~value, "Variable") Then Signal 99.925

  Call SetConstantName name, .METHOD.NAME

  options.get          = 1
  options.set          = 1
  options.class        = 0
  options.guarded      = 1
  options.protected    = 0
  options.abstract     = 0
  options.delegateName = ""
  options.external     = ""
  options.visibility   = "PUBLIC"

  ignoreBlanks = 1

  keyword = TheElementAfter( name, ignoreBlanks )

  allOptions = .set~of(                                   -
    "GET", "SET", "CLASS", "PUBLIC", "PACKAGE", "PRIVATE", -
    "GUARDED", "UNGUARDED", "UNPROTECTED", "PROTECTED",    -
    "ABSTRACT", "DELEGATE", "EXTERNAL"                     -
  )

  Loop While keyword \< .EL.END_OF_CLAUSE

    If \allOptions~hasItem( keyword~value ) Then Signal 25.925

    Call SetKeyword keyword, .True

    kValue = keyword~value

    allOptions~~remove(kValue)

    Select case kValue
      When "GET", "SET" Then Do
        If kValue == "GET" Then options.set = 0
        Else      /* "SET" */   options.get = 0
        allOptions~~remove("GET")~~remove("SET")
      End
      When "GUARDED", "UNGUARDED" Then Do
        If kValue == "UNGUARDED" Then options.guarded = 0
        allOptions~~remove("GUARDED")~~remove("UNGUARDED")
      End
      When "PROTECTED", "UNPROTECTED" Then Do
        If kValue == "PROTECTED" Then options.protected = 1
        allOptions~~remove("PROTECTED")~~remove("UNPROTECTED")
      End
      When "PUBLIC", "PACKAGE", "PRIVATE" Then Do
        options.visibility = kValue
        allOptions~~remove("PUBLIC")~~remove("PACKAGE")~~remove("PRIVATE")
      End
      When "CLASS"    Then Do
        If package~inTheProlog Then Signal 99.905
        options.kValue = 1
      End
      When "ABSTRACT" Then options.abstract = 1
      When "DELEGATE" Then Do
        thisDelegateName = TheElementAfter( keyword )
        If thisDelegateName \< .ALL.SYMBOLS_AND_STRINGS Then Signal 20.926
        options.delegateName = thisDelegateName
        keyword = TheElementAfter( thisDelegateName, ignoreBlanks )
        Iterate -- Jump directly to next keyword, if any
      End
      When "EXTERNAL" Then Do -- Should check spec syntax
        spec = TheElementAfter( keyword )
        If spec  < .EL.END_OF_CLAUSE  Then Signal 19.905
        If spec \< .ALL.STRINGS Then Signal 20.926
        options.external = spec~value
        keyword = TheElementAfter( spec, ignoreBlanks )
        Iterate -- Jump directly to next keyword, if any
      End
    End

    -- Step to next keyword, if any
    keyword = TheElementAfter( keyword, ignoreBlanks )

  End

Done:
  Return .Attribute.Directive~new( package, begin, end, name, options. )

-- String expected after EXTERNAL keyword.
19.905: Syntax( 19.905, ATTRIBUTE)

-- String or symbol expected as ::ATTRIBUTE directive name.
19.914: Syntax( 19.914, ATTRIBUTE)

-- Unknown keyword on ::ATTRIBUTE directive; found "&1".
25.925: Syntax( 25.925, ATTRIBUTE, keyword )

-- Symbol expected after the DELEGATE keyword.
20.926: Syntax( 20.926, ATTRIBUTE)

-- CLASS keyword on ::METHOD directive requires a matching ::CLASS directive.
99.905: Syntax( 99.905, ATTRIBUTE)

-- An ATTRIBUTE method name must be a valid variable name; found "&1".
99.925: Syntax( 99.925, ATTRIBUTE, name)

--------------------------------------------------------------------------------

::Class Attribute.Directive Public SubClass Rexx.Directive
::Attribute name      Get
::Attribute options. Get
::Attribute attribute
::Method init
  Expose name options.
  Use Strict Arg package, begin, end, name, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* CLASS Directive                                                            */
/******************************************************************************/

::Routine Class.Directive Public

  Use Strict Arg package, begin, end, elements

  CLASS = elements[2]

  name = TheElementAfter( CLASS )

  Call ExpectClassName name, 19.901

  options.             = .Nil
  options.public       = 0

  ignoreBlanks         = 1

  keyword = TheElementAfter( name, ignoreBlanks )

  allOptions = .set~of(                             -
    "METACLASS", "PRIVATE", "PUBLIC", "MIXINCLASS", -
    "SUBCLASS", "ABSTRACT", "INHERIT"               -
  )

  Loop While keyword \< .EL.END_OF_CLAUSE

    If \allOptions~hasItem( keyword~value ) Then Signal 25.901

    Call SetKeyword keyword, .True

    kValue = keyword~value

    allOptions~remove(kValue)

    Select case kValue
      When "METACLASS" Then Do
        metaClass = TheElementAfter( keyword, ignoreBlanks )
        Call ExpectClassName metaClass, 19.906
        options.kValue = metaClass
        keyword = TheElementAfter( metaclass, ignoreBlanks )
      End
      When "SUBCLASS", "MIXINCLASS" Then Do
        option = TheElementAfter( keyword, ignoreBlanks )
        If kValue == "SUBCLASS" Then Call ExpectClassName option, 19.907
        Else                         Call ExpectClassName option, 19.913
        options.kValue = option
        allOptions~~remove("MIXINCLASS")~~remove("SUBCLASS")
        keyword = TheElementAfter( option, ignoreBlanks )
      End
      When "INHERIT" Then Do
        inherit = TheElementAfter( keyword, ignoreBlanks )
        Loop
          Call ExpectClassName inherit, 19.908
          If options.kValue == .Nil Then options.kValue = Array()
          options.kValue~append( inherit )
          inherit = TheElementAfter( inherit, ignoreBlanks )
          If inherit < .EL.END_OF_CLAUSE Then Signal Done
        End
      End
      When "ABSTRACT" Then Do
        options.kValue = 1
        keyword = TheElementAfter( keyword )
      End
      When "PRIVATE", "PUBLIC" Then Do
        options.public = ( kValue == "PUBLIC" )
        allOptions~~remove("PRIVATE")~~remove("PUBLIC")
        keyword = TheElementAfter( keyword )
      End
    End
  End
  Signal Done

Done:
  Exit .Class.Directive~new( package, begin, end, name, options. )

ExpectClassName:
  Use Arg element, code
  If element \< .ALL.SYMBOLS_AND_STRINGS Then Signal (code)
  Call SetConstantName element, .CLASS.NAME
Return

-- String or symbol expected after ::CLASS keyword.
19.901: Syntax( 19.901, CLASS )

-- String or symbol expected after METACLASS keyword.
19.906: Syntax( 19.906, CLASS )

-- String or symbol expected after SUBCLASS keyword.
19.907: Syntax( 19.907, CLASS )

-- String or symbol expected after INHERIT keyword.
19.908: Syntax( 19.908, CLASS )

-- String or symbol expected after MIXINCLASS keyword.
19.913: Syntax( 19.913, CLASS )

-- Unknown keyword on ::CLASS directive; found "&1".
25.901: Syntax( 25.901, CLASS, keyword )

--------------------------------------------------------------------------------

::Class Class.Directive Public SubClass Rexx.Directive
::Attribute name     Get
::Attribute options. Get
::Attribute theClass
::Method init
  Expose name options.
  Use Strict Arg package, begin, end, name, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* CONSTANT Directive                                                         */
/******************************************************************************/

::Routine Constant.Directive Public

  Use Strict Arg package, begin, end, elements

  CONSTANT = elements[2]

  name = TheElementAfter( CONSTANT )

  If name \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.915
  Call SetConstantName name, .METHOD.NAME

  ignoreBlanks = 1

  next = TheElementAfter( name, ignoreBlanks )

  If next < .EL.END_OF_CLAUSE Then Signal NoValue

  If next < .ALL.OPS.ADDITIVE Then Do
    sign = next
    number = TheElementAfter( next, ignoreBlanks )
    If number \< .ALL.NUMBERS Then Signal 19.916
    Call SetConstantName number, .CONSTANT.VALUE
    If NoMoreDataAfter( number ) Then Signal SignedNumber
  End

  If next < .EL.LEFT_PARENTHESIS Then Do
    Call PrepareExpression next, ")"
    expression = SubExpression( package, next, "" )
    element = expression~end
    Call NoMoreDataAfter element
    If package~inTheProlog Then Signal 99.906
    Signal Expression
  End

  If next \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.916
  Call SetConstantName next, .CONSTANT.VALUE
  value = next
  If NoMoreDataAfter( value ) Then Signal "VALUE"

NoMoreDataAfter:
  If Arg(1) < .EL.END_OF_CLAUSE Then Return 1
  next = TheElementAfter( Arg(1), ignoreBlanks )
  If next < .EL.END_OF_CLAUSE Then Return 1
  Signal 21.913

NoValue:
  Return .Constant.Directive~new( package, begin, end, name )

Value:
  Return .Constant.Directive~new( package, begin, end, name, value )

Expression:
  Return .Constant.Directive~new( package, begin, end, name,,expression )

SignedNumber:
  Return .Constant.Directive~new( package, begin, end, name, , ,sign, number )

-- String or symbol expected as ::CONSTANT directive name.
19.915: Syntax( 19.915, CONSTANT )

-- String or symbol expected as ::CONSTANT value.
19.916: Syntax( 19.916, CONSTANT )

-- Data must not follow the ::CONSTANT value; found "&1".
21.913: Syntax( 21.913, CONSTANT, next)

-- A ::CONSTANT directive with an expression requires
-- a matching ::CLASS directive.
99.906: Syntax( 99.906, CONSTANT )

--------------------------------------------------------------------------------

::Class Constant.Directive Public SubClass Rexx.Directive
::Attribute name    Get
::Attribute constant
::Method init
  Expose name value expression sign number
  Use Strict Arg        -
    package, begin, end, name, -
    value      = .Nil,  -
    expression = .Nil,  -
    sign       = .Nil,  -
    number     = .Nil
  self~init:super( package, begin, end )

/******************************************************************************/
/* METHOD Directive                                                           */
/******************************************************************************/

::Routine Method.Directive Public

  Use Strict Arg package, begin, end, elements

  METHOD = elements[2]

  name = TheElementAfter( METHOD )

  If name \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.902

  Call SetConstantName name, .METHOD.NAME

  options.attribute    = 0
  options.class        = 0
  options.visibility   = "PUBLIC"
  options.guarded      = 1
  options.protected    = 0
  options.abstract     = 0
  options.delegateName = ""
  options.external     = ""

  ignoreBlanksToTheRight = 1

  keyword = TheElementAfter( name, ignoreBlanksToTheRight )

  allOptions = .set~of(                                   -
    "ATTRIBUTE", "CLASS", "PUBLIC", "PACKAGE", "PRIVATE", -
    "GUARDED", "UNGUARDED", "UNPROTECTED", "PROTECTED",    -
    "ABSTRACT", "DELEGATE", "EXTERNAL"                     -
  )

  Loop While keyword \< .EL.END_OF_CLAUSE

    If \allOptions~hasItem( keyword~value ) Then Signal 25.902

    Call SetKeyword keyword, .True

    kValue = keyword~value

    allOptions~remove(kValue)

    Select case kValue
      When "ATTRIBUTE" Then options.attribute = 1
      When "GUARDED", "UNGUARDED" Then Do
        If kValue == "UNGUARDED" Then options.guarded = 0
        allOptions~~remove("GUARDED")~~remove("UNGUARDED")
      End
      When "PROTECTED", "UNPROTECTED" Then Do
        If kValue == "PROTECTED" Then options.protected = 1
        allOptions~~remove("PROTECTED")~~remove("UNPROTECTED")
      End
      When "PUBLIC", "PACKAGE", "PRIVATE" Then Do
        options.visibility = kValue
        allOptions~~remove("PUBLIC")~~remove("PACKAGE")~~remove("PRIVATE")
      End
      When "CLASS" Then Do
        If package~inTheProlog Then Signal 99.905
        options.class = 1
      End
      When "ABSTRACT" Then options.abstract = 1
      When "DELEGATE" Then Do
        thisDelegateName = TheElementAfter( keyword )
        ignoreBlanksToTheRight = 1
        If thisDelegateName \< .ALL.SYMBOLS_AND_STRINGS Then
          Signal 20.926
        options.delegateName = thisDelegateName
        keyword = TheElementAfter( thisDelegateName, ignoreBlanksToTheRight )
        Iterate -- Jump directly to next keyword, if any
      End
      When "EXTERNAL" Then Do -- Should check spec syntax
        spec = TheElementAfter( keyword )
        ignoreBlanksToTheRight = 1
        If spec \< .ALL.STRINGS Then Signal 19.905
        options.external = spec~value
        keyword = TheElementAfter( spec, ignoreBlanksToTheRight )
        Iterate -- Jump directly to next keyword, if any
      End
    End
    -- Step to next keyword, if any
    keyword = TheElementAfter( keyword )
  End

Done:
  Return .Method.Directive~new( package, begin, end, name, options. )

-- String or symbol expected after ::METHOD keyword.
19.902: Syntax( 19.902, METHOD )

-- String expected after EXTERNAL keyword.
19.905: Syntax( 19.905, METHOD )

-- Unknown keyword on ::METHOD directive; found "&1".
25.902: Syntax( 25.902, METHOD, keyword )

-- Symbol expected after the DELEGATE keyword.
20.926: Syntax( 20.926, METHOD )

-- CLASS keyword on ::METHOD directive requires a matching ::CLASS directive.
99.905: Syntax( 99.905, METHOD )

--------------------------------------------------------------------------------

::Class Method.Directive Public SubClass Rexx.Directive
::Attribute name     Get
::Attribute options. Get
::Attribute method
::Method init
  Expose name  options.
  Use Strict Arg package, begin, end, name, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* OPTIONS Directive                                                          */
/******************************************************************************/
-- We keep only the most current values

::Routine Options.Directive Public

  Use Strict Arg package, begin, end, elements

  OPTIONS = elements[2]

  element        = TheElementAfter( OPTIONS )
  options.     = .Nil
  ignoreBlanks = .True

  If element < .EL.END_OF_CLAUSE Then Signal Done

  conditions = "ALL ERROR FAILURE LOSTDIGITS NOSTRING NOTREADY NOVALUE"
  numeric    = "DIGITS FORM FUZZ"
  allOptions = numeric conditions "PROLOG NOPROLOG TRACE"

  Loop While element \< .EL.END_OF_CLAUSE
    If element \< .ALL.SYMBOLS            Then Signal 25.924
    tValue = element~value
    If WordPos(tValue, allOptions) == 0 Then Signal 25.924
    Call SetKeyword element, .True
    theCondition = element
    element = TheElementAfter( element )
    Select
      When WordPos(tValue, conditions) > 0 Then Do
        condition = tValue
        If element \< .ALL.SYMBOLS Then Signal 20.929
        If WordPos( element~value, "CONDITION SYNTAX") == 0 Then Signal 25.927
        options.condition = element~value
        Call SetKeyword element, .True
        element = TheElementAfter( element )
      End
      When tValue == "PROLOG"   Then options.prolog = 1
      When tValue == "NOPROLOG" Then options.prolog = 0
      When tValue == "FORM" Then Do
        If element \< .ALL.SYMBOLS Then Signal 20.925
        If WordPos( element~value, "SCIENTIFIC ENGINEERING") == 0 Then Signal 25.011
        options.form = element~value
        Call SetKeyword element, .True
        element = TheElementAfter( element )
      End
      When tValue == "TRACE" Then Do
        If element \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.919
        tValue = element~value
        c = Strip(tValue, "L", "?")[1]
        If c \== "", Pos(c, "ACEFILNOR") == 0 Then Signal 24.001
        If c == "" Then Options.trace = tValue
        Else Do
          Parse Var tValue ? (c)
          If Length( ? ) // 2 Then c = "?"c
          options.trace = c
        End
        element = TheElementAfter( element, ignoreBlanks )
      End
      Otherwise Do -- DIGITS, FUZZ
        If element \< .ALL.SYMBOLS_AND_STRINGS Then
          If tValue == "FUZZ" Then Signal 19.918; Else Signal 19.917
        value = element~value
        If \DataType(value, "W")             | -
          ( tValue == "FUZZ" & value < 0   ) | -
          ( tValue == "DIGITS" & value < 1 ) Then
          If tValue == "DIGITS" Then Signal 26.005; Else Signal 26.006
        options.tValue = value
        element = TheElementAfter( element, ignoreBlanks )
      End
    End
  End

Done:
  Return .Options.Directive~new( package, begin, end, options. )

-- String or symbol expected as DIGITS value.
19.917: Syntax( 19.917, OPTIONS )

-- String or symbol expected as FUZZ value.
19.918: Syntax( 19.918, OPTIONS )

-- String or symbol expected as TRACE value.
19.919: Syntax( 19.919, OPTIONS )

-- Symbol expected after the FORM keyword.
20.925: Syntax( 20.925, OPTIONS )

-- Symbol expected after &1 keyword.
20.929: Syntax( 20.929, OPTIONS, theCondition )

-- TRACE request letter must be one of "ACEFILNOR"; found "&1".
24.001: Syntax( 24.001, OPTIONS, c )

-- NUMERIC FORM must be followed by one of the keywords
-- SCIENTIFIC or ENGINEERING; found "&1".
25.011: Syntax( 25.011, OPTIONS, element )

-- Unknown keyword on ::OPTIONS directive; found "&1".
25.924: Syntax( 25.924, OPTIONS, element )

-- Unknown keyword following "&1"; found "&2".
25.927: Syntax( 25.927, OPTIONS, condition, element )

-- DIGITS value must be a positive whole number; found "&1".
26.005: Syntax( 26.005, OPTIONS, element )

-- FUZZ value must be zero or a positive whole number; found "&1".
26.006: Syntax( 26.006, OPTIONS, element )

--------------------------------------------------------------------------------

::Class Options.Directive Public SubClass Rexx.Directive
::Method init
  Expose options.
  Use Strict Arg package, begin, end, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* REQUIRES Directive                                                         */
/******************************************************************************/

::Routine Requires.Directive Public

  Use Strict Arg package, begin, end, elements

  REQUIRES = elements[2]

  programName  = TheElementAfter( REQUIRES )

  options.     = .Nil
  ignoreBlanks = .True

  If programName \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.904
  Call SetConstantName programName, .REQUIRES.PROGRAM.NAME

  keyword = TheElementAfter( programName, ignoreBlanks )
  If keyword < .EL.END_OF_CLAUSE Then Signal Done

  If keyword \< .ALL.SYMBOLS Then Call 25.904 keyword

  kValue = keyword~value

  If WordPos(kvalue, "LIBRARY NAMESPACE") == 0 Then Call 25.904 keyword

  Call SetKeyword keyword, .True

  If kValue == "LIBRARY" Then Do
    options.library = 1
    element = TheElementAfter( keyword )
    If element \< .EL.END_OF_CLAUSE Then Call 25.904 element
    Signal Done
  End

  element = TheElementAfter( keyword )

  If element \< .ALL.SYMBOLS Then Signal 20.920
  If element~value == "REXX"  Then Signal 99.944
  options.nameSpace = element

  Call SetConstantName element, .NAMESPACE.NAME

  element = TheElementAfter( element, ignoreBlanks )

  If element \< .EL.END_OF_CLAUSE Then Call 25.904 element

Done:
  Return .Requires.Directive~new( package, begin, end, programName, options. )

-- String or symbol expected after ::REQUIRES keyword.
19.904: Syntax( 19.904, REQUIRES )

-- Symbol expected after NAMESPACE keyword.
20.920: Syntax( 20.920, REQUIRES )

-- Unknown keyword on ::REQUIRES directive; found "&1".
25.904: Syntax( 25.904, REQUIRES, Arg(1) )

-- The REXX name is reserved for the language-provided namespace.
99.944: Syntax( 99.944, REQUIRES )

--------------------------------------------------------------------------------

::Class Requires.Directive Public SubClass Rexx.Directive
::Method init
  Expose programName options.
  Use Strict Arg package, begin, end, programName, options.
  self~init:super( package, begin, end )

/******************************************************************************/
/* RESOURCE Directive                                                         */
/*                                                                            */
/*   ::RESOURCE directives are special, in the sense that they break          */
/*   normal parsing rules. An added complication stems from the fact that     */
/*   there is an ambiguity in the syntax regarding possible extra characters  */
/*   after an explicit semicolon after ::RESOURCE. See documentation bug      */
/*   https://sourceforge.net/p/oorexx/documentation/307/ for details.         */
/*                                                                            */
/*   The syntax we will be using is the following:                            */
/*                                                                            */
/*      ::RESOURCE name [END delimiter] [; [ignored_data_1] ]                 */
/*      [resource_data]*                                                      */
/*      (::END | delimiter) [ignored_data_2]                                  */
/*                                                                            */
/******************************************************************************/

::Routine Resource.Directive Public

  Use Strict Arg package, begin, end, elements

  RESOURCE     = elements[2]
  ignoreBlanks = .True

  name = TheElementAfter( RESOURCE )
  If name \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.920
  Call SetConstantName name, .RESOURCE.NAME

  end = TheElementAfter( name, ignoreBlanks )

  If end < .EL.END_OF_CLAUSE Then delimiter = "::END"
  Else Do
    keyword = end

    If keyword \< .ALL.SYMBOLS Then Signal 25.926
    If keyword~value \== "END" Then Signal 25.926
    Call SetKeyword keyword, .True

    delimiterElement = TheElementAfter( keyword )
    If delimiterElement \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.921
    Call SetConstantName delimiterElement, .RESOURCE.DELIMITER.NAME

    delimiter = delimiterElement~value

    end = TheElementAfter( delimiterElement, ignoreBlanks )
    If end \< .EL.END_OF_CLAUSE Then Signal 21.914

  End

  Return .Resource.Directive~new( package, begin, end, name, delimiter )

-- String or symbol expected as ::RESOURCE directive name.
19.920: Syntax( 19.920, RESOURCE )

-- String or symbol expected after ::RESOURCE END keyword.
19.921: Syntax( 19.921, RESOURCE )

-- Data must not follow the ::RESOURCE directive; found "&1".
21.914: Syntax( 21.914, delimiterElement, end )

-- Unknown keyword on ::RESOURCE directive; found "&1".
25.926: Syntax( 25.926, RESOURCE, keyword )

--------------------------------------------------------------------------------

::Class Resource.Directive Public SubClass Rexx.Directive
::Attribute name
::Attribute delimiter
::Attribute fromLine
::Attribute toLine
::Method init
  Expose name delimiter
  Use Strict Arg package, begin, end, name, delimiter
  fromLine = ""
  toLine   = ""
  self~init:super( package, begin, end )

/******************************************************************************/
/* ROUTINE Directive                                                          */
/******************************************************************************/

::Routine Routine.Directive Public

  Use Strict Arg package, begin, end, elements

  ROUTINE = elements[2]

  ignoreBlanks = .True

  routineName =  TheElementAfter( ROUTINE )

  If routineName \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.903

  Call SetConstantName routineName, .ROUTINE.NAME

  allOptions = .Set~of("PUBLIC", "PRIVATE", "EXTERNAL")
  possibleKeywords = "public private external"

  private  = 1
  external = 0
  spec     = .Nil

  keyword = TheElementAfter( routineName, ignoreBlanks )

  Loop While keyword \< .EL.END_OF_CLAUSE

    If \allOptions~hasItem( keyword~value ) Then Signal 25.903

    Call SetKeyword keyword, .True

    Select Case keyword~value
      When "PUBLIC", "PRIVATE" Then Do
        allOptions~~remove("PUBLIC")~~remove("PRIVATE")
        If keyword~value == "PUBLIC" Then private = 0
        keyword = TheElementAfter( keyword )
      End
      When "EXTERNAL" Then Do
        external = 1
        allOptions~~remove("EXTERNAL")
        spec = TheElementAfter( keyword )
        If spec  < .EL.END_OF_CLAUSE  Then Signal 19.925
        If spec \< .ALL.STRINGS Then Signal 19.925
        Parse Value spec~value With one two three four
        -- Note: we only check a few things here.
        If Pos(Upper(one), "LIBRARY REGISTERED") == 0 Then Signal 99.917
        If four \== ""                                Then Signal 99.917
        keyword = TheElementAfter( spec, ignoreBlanks )
     End
    End
  End

  Return .Routine.Directive~new(-
    package, begin, end, routineName, private, spec -
  )

-- String or symbol expected after ::ROUTINE keyword.
19.903: Syntax( 19.903, ROUTINE )

-- Symbol or string expected after &1 &2 keyword.
19.925: Syntax( 19.925, ROUTINE )

-- Unknown keyword on ::ROUTINE directive; found "&1".
25.903: Syntax( 25.903, ROUTINE, keyword )

-- Incorrect external name specification "&1".
99.917: Syntax( 99.917, ROUTINE, spec )

--------------------------------------------------------------------------------

::Class Routine.Directive Public SubClass Rexx.Directive
::Attribute body
::Attribute routine
::Method init
  Expose name  private  spec
  Use Strict Arg package, begin, end, name, private, spec = .Nil
  body = .Nil
  self~init:super( package, begin, end )
::Attribute name     Get
::Attribute private  Get
-- TODO attributes can have bodies
--::Attribute external Get
::Method external
  Expose spec
  Return spec
