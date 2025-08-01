/******************************************************************************/
/*                                                                            */
/* Rexx.Parser.cls -- The main Rexx Parser class                              */
/* =============================================                              */
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
/* 20241208    0.1a Pass options arg to clauser                               */
/* 20250103    0.1f Add unicode option                                        */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250419    0.2a Fix bug no. 4                                             */
/*                                                                            */
/******************************************************************************/

 .environment~Code.Body    = .Code.Body
 .environment~Rexx.Parser  = .Rexx.Parser
 .environment~Rexx.Package = .Rexx.Package
 .environment~Rexx.Routine = .Rexx.Routine

::Requires "HTMLColors.cls"
::Requires "StyleSheet.cls"
::Requires "DebugSettings.cls"
::Requires "BaseClassesAndRoutines.cls"
::Requires "Globals.cls"
::Requires "Tokenizer.cls"
::Requires "Expressions.cls"
::Requires "PreClauser.cls"
::Requires "Clauses.cls"
::Requires "KeywordInstructions.cls"
::Requires "Directives.cls"
::Requires "UnicodeSupport.cls"
::Requires "SecondPass.cls"

/******************************************************************************/
/*                                                                            */
/* The Rexx.Parser class                                                      */
/*                                                                            */
/******************************************************************************/

::Class Rexx.Parser Public

::Attribute package

::Method firstElement
  Return self~package~firstElement

::Method init
  Expose package

  Use Strict Arg name, source = .Nil, options = .Nil

  -- .Directory~of() crashes the interpreter
 .environment~Parser.Options = .Directory~new

  If Arg(3,'E') Then Do
    .Validate~classType("options",options,.Array)
    If \ options~isEmpty Then Do
      -- Ensure that keys are all in uppercase
      Do option Over options
        option[1] = Upper(option[1])
      End
     .environment~Parser.Options = .Directory~sendWith("of", options)
    End
  End

  -- Default options

  If \.Parser.Options~hasIndex( docComments ) Then
    .Parser.Options[ docComments ] = All

  If \.Parser.Options~hasIndex( earlyCheck ) Then
    .Parser.Options[ earlyCheck ] = Set()

  If Arg(2,'O') | Arg(2) == .Nil Then Do
    source = CharIn(name,1,Chars(name))~makeArray
    Call CharOut name
  End
  Else If source~isA( .String ) Then source = Array( source )

  -- Create the package object
  package = .Rexx.Package~new(name, source)

  -- and fire the parser
  Call Rexx.Package package

/******************************************************************************/
/* CODE.BODY                                                                  */
/*                                                                            */
/*   A code body is an instruction list ended by an implicit EXIT.            */
/*   It may be the prolog of a package, or the body of a routine or a method. */
/*                                                                            */
/******************************************************************************/

::Routine Code.Body Public

  Use Strict Arg package, directive

  inAMethodBody = directive~class == .Method.Directive

  If directive~isA(.Attribute.Directive) Then Do
    -- Logic for attributes w and w/o bodies:
    -- No GET, no SET -> No body
    -- GET or SET -> Body is optional
    -- ABSTRACT -> No body
    options. = directive~options.
    If options.get | options.set Then inAMethodBody = 1
    If options.abstract \== ""   Then inAMethodBody = 1
  End

  body = .Code.Body~new( package, directive )
  If inAMethodBody Then
    body~isAMethodBody = .True
  package~currentBody            = body
  package~blockInstructionsStack = Array()

  -- The following loop will always end, because lower levels of the parser
  -- have taken care that all clause sequences are ended by an implicit exit
  -- instruction. We keep all instructions in the list to be able to
  -- accurately determine the beginning and the end of the code block.

  NoFinalENDClause = 0
  checkguard       = 0

  If .Parser.Options~hasIndex( earlyCheck ) Then
    checkguard     = .Parser.Options~earlyCheck~hasItem( guard )

  -- TODO EXPOSE, USE LOCAL and GUARD should be checked recursively.

  Loop Counter n Until instruction~class == .Implicit.Exit.Instruction
    instruction = package~clauser~Next.Instruction( NoFinalENDClause )
    Select Case instruction~class
      When    .Expose.Instruction Then Call CheckThatExposeIsValid
      When .Use.Local.Instruction Then Call CheckThatUseLocalIsValid
      When     .Guard.Instruction Then Call CheckThatGuardIsValid
      Otherwise Nop
    End
    body~addInstruction( instruction )
  End

  Return body

CheckThatGuardIsValid:
  If \checkGuard Then Return
  If inAMethodBody Then Return
  Signal 99.911

-- GUARD can only be issued in an object method invocation.
99.911: Syntax( 99.911, TheElementAfter(instruction~begin) )

CheckThatExposeIsValid:
  If n == 1 Then Do
    If inAMethodBody Then Return
    Signal 98.992
  End
  Signal 99.907

-- EXPOSE must be the first instruction executed after a method invocation.
99.907: Syntax( 99.907, TheElementAfter(instruction~begin) )

-- The EXPOSE instruction may only be used from method invocations.
98.992: Syntax( 98.992, TheElementAfter(instruction~begin) )

CheckThatUseLocalIsValid:
  If n == 1 Then Do
    If inAMethodBody Then Return
    Signal 98.993
  End
  Signal 99.910

-- USE LOCAL must be the first instruction executed after a method invocation.
99.910: Syntax( 99.910, TheElementAfter(instruction~begin) )

-- The USE LOCAL instruction may only be used from method invocations.
98.993: Syntax( 98.993, TheElementAfter(instruction~begin) )

--------------------------------------------------------------------------------
-- The CODE.BODY class                                                        --
--   We implement it as a form of block instruction                           --
--------------------------------------------------------------------------------

::Class Code.Body SubClass Block.Instruction

::Attribute labels              -- All non trace-only labels
::Attribute clauses             -- All clauses
::Attribute exposed             -- Explicitly EXPOSEd variables
::Attribute uselocal            -- USE LOCAL variables (.Nil -> no USE LOCAL)
::Attribute isAMethodBody       -- This is a METHOD body
::Attribute classMethod         -- True when this is a CLASS method
::Attribute calledRoutineNames  -- Symbols or strings
::Attribute instructions        -- Array of instructions

::Method "[]"
  Expose instructions
  Use Strict Arg index
  Return instructions[index]

::Method init
  Expose instructions labels clauses calledRoutineNames -
    exposed useLocal classMethod isAMethodBody usesExitInstruction

  Use Strict Arg package, directive

  labels              = .StringTable~new
  clauses             = Array()
  calledRoutineNames  = Array()
  instructions        = Array()
  exposed             = Set()
  useLocal            = .Nil
  classMethod         = .False
  isAMethodBody       = .False

  If directive~class == .Method.Directive Then
    classMethod = directive~options.[class]

  -- Set begin and end to nil, will be updated by addInstruction
  self~init:super( package, .Nil, .Nil )

::Method addInstruction
  Expose instructions exposed useLocal

  Use Strict Arg instruction

  -- This is directly called only for top-level instructions.
  -- We update the body labels stringtable with all the non-trace-only
  -- top-level labels.

  labels     = instruction~labels       -- Our labels
  bodyLabels = self~labels              -- Pool of non trace-only labels
  Loop theLabel Over labels             -- One by one...
    value  = theLabel~label~value       -- ...pick the value (may be lowercase)
    If bodyLabels~hasIndex(value) Then  -- Duplicate label? That is allowed,...
      Nop                               -- ... but this is trace-only.
    Else Do                             -- A new, non trace-only label
      bodyLabels[value] = theLabel      -- Store it in the body label pool...
      theLabel~traceOnly = .False       -- ...and mark as not trace-only.
      theLabel~label~traceOnly = .False -- Mark the element itself too.
    End
  End

  -- Update self~begin and self~end to accomodate the new instruction
  If self~begin == .Nil Then Do
    nullClauses = instruction~nullClauses
    If nullClauses \== .Nil, nullClauses~items > 0
      Then null  = nullClauses[1]~begin
      Else null  = .Nil
    If labels      \== .Nil, labels     ~items > 0
      Then label = labels[1]~begin
      Else label = .Nil
    If null == .Nil Then
      If label == .Nil
        Then self~begin = instruction~begin
        Else self~begin = labels[1]~begin
    Else If label == .Nil Then self~begin = null
    Else Do
      Parse Value null ~from With  nullFrom  nullTo
      Parse Value label~from With labelFrom labelTo
      If      nullFrom < labelFrom Then self~begin = null
      Else If nullFrom > labelFrom Then self~begin = labels[1]~begin
      Else If nullTo   < labelTo   Then self~begin = null
      Else                              self~begin = labels[1]~begin
    End
  End
  self~end = instruction~end

  instructions~append( instruction )

::Method isEmpty
  Expose instructions
  -- More than 1 instruction? Not empty
  If instructions~items > 1 Then Return .False
  -- Only 1 instruction (implicit exit) + no labels: empty
  Return instructions[1]~labels~isEmpty

::Method makeString
  Return self~makeArray
::Method makeArray
  Expose instructions
  Use Strict Arg indent = 0
  array = Array()
  Do i = 1 To instructions~items
    instruction = instructions[i]~makeArray(indent)
    Do j = 1 To instruction~items
      array~append(instruction[j])
    End
  End
  Return array

/******************************************************************************/
/* REXX.PACKAGE                                                               */
/******************************************************************************/

::Routine Rexx.Package Public

  Use Strict Arg package

  -- The package prolog is the first code body
  prolog = Code.Body( package, .Nil )
  package~addProlog( .Rexx.Routine~new("", prolog ) )

  Loop

    directive = package~clauser~next.Instruction.Fragment()

    Select Case directive~class

      When       .End.Of.Source Then Leave

      When  .Annotate.Directive Then Call Annotate   package, directive
      When .Attribute.Directive Then Call Attribute  package, directive
      When     .Class.Directive Then Call Class      package, directive
      When  .Constant.Directive Then Call Constant   package, directive
      When    .Method.Directive Then Call Method     package, directive
      When   .Options.Directive Then Call Options    package, directive
      When  .Requires.Directive Then Call Requires   package, directive
      When  .Resource.Directive Then Call Resource   package, directive
      When   .Routine.Directive Then Call Routine    package, directive

    End

  End

  Call SecondPass package

  Return package

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

::Class Rexx.Package Public

::Attribute Clauser                 -- The clauser
::Attribute preClauser              -- The preClauser
::Attribute tokenizer               -- The tokenizer
::Attribute currentClass            -- Current class (.Nil --> prolog)
::Attribute currentBody             -- Body being currently parsed
::Attribute directives              -- Sequential list of directives
::Attribute source                  -- [Similar to the ooRexx Package class]
::Attribute prolog                  -- [Similar to the ooRexx Package class]
::Attribute name                    -- [Similar to the ooRexx Package class]
::Attribute resources               -- [Similar to the ooRexx Package class]
::Attribute publicClasses           -- [Similar to the ooRexx Package class]
::Attribute privateClasses
::Attribute publicRoutines          -- [Similar to the ooRexx Package class]
::Attribute privateRoutines
::Attribute definedMethods          -- [Similar to the ooRexx Package class]
::Attribute blockInstructionsStack  -- Stack of active block instructions

::Method firstElement -- Convenient shortcut
  Return self~prolog~body~begin

::Method inTheProlog
  Expose currentClass
  Return currentClass == .Nil

::Method init
  Expose name source -
    Clauser          -
    preclauser       -
    tokenizer        -
    privateClasses   -
    publicClasses    -
    privateRoutines  -
    publicRoutines   -
    definedMethods   -
    currentClass     -
    currentBody      -
    directives       -
    resources

  Use Strict Arg name, source

  self~init:super

  Clauser                = .Clauser~new( self )
  preClauser             =  Clauser~preClauser
  tokenizer              =  Clauser~tokenizer
  definedMethods         = .StringTable~new
  privateClasses         = .StringTable~new
  publicClasses          = .StringTable~new
  privateRoutines        = .StringTable~new
  publicRoutines         = .StringTable~new
  resources              = .StringTable~new
  currentClass           = .Nil
  currentBody            = .Nil
  directives             =  Array()
  blockInstructionsStack = .Nil

::Method addClass -- [As in in the ooRexx Package class]
  Expose privateClasses
  Use Strict Arg name, class
  privateClasses[name] = class

::Method addDirective
  Expose directives
  Use Strict Arg directive
  directives~append( directive )

::Method addMethod -- Add a floating method, attribute or constant
  Expose definedMethods
  Use Strict Arg name, method
  definedMethods[name] = method

::Method addResource
  Expose resources
  Use Strict Arg name, resource
  resources[name] = resource

::Method addProlog
  Expose prolog
  Use Strict Arg prolog

::Method addRoutine -- [As in in the ooRexx Package class]
  Expose privateRoutines
  Use Strict Arg name, routine
  privateRoutines[name] = routine

::Method addPublicClass -- [As in in the ooRexx Package class]
  Expose publicClasses
  Use Strict Arg name, class
  publicClasses[name] = class

::Method addPublicRoutine -- [As in in the ooRexx Package class]
  Expose publicRoutines
  Use Strict Arg name, routine
  publicRoutines[name] = routine

::Method classes -- [As in in the ooRexx Package class]
  Expose privateClasses publicClasses
  Return privateClasses~union( publicClasses )

::Method routines -- [As in in the ooRexx Package class]
  Expose privateRoutines publicRoutines
  Return privateRoutines~union( publicRoutines )

::Method sourceLine -- [As in in the ooRexx Package class]
  Expose source
  Use Strict Arg n
  line = source[n]
  If line~isNil Then Return ""
  Return line

/******************************************************************************/
/* ANNOTATE                                                                   */
/******************************************************************************/

::Routine Annotate
  Use Strict Arg package, directive
  directive~body = Empty.Body( package, directive )
  package~addDirective(directive)
  Return

/******************************************************************************/
/* ATTRIBUTE                                                                  */
/******************************************************************************/

::Routine Attribute
  Use Strict Arg package, directive
  codeBody = Code.Body( package, directive )
  options. = directive~options.
  If \codeBody~isEmpty Then Do
    instructionBegin = TheElementAfter( codeBody~instructions[1]~begin )
    If options.get & options.set        Then Signal 99.937
    Else If options.abstract            Then Signal 99.940
    Else If options.delegateName \== "" Then Signal 99.947
    Else If options.external \== ""     Then Signal 99.935
  End
  name = directive~name
  attribute = .Attribute.Method~new(name, directive, codeBody)
  name = Upper( name~value )
  If options.get Then Do
    If package~inTheProlog Then Do
      If package~definedMethods~hasIndex(name) Then Signal 99.931
      package~addMethod( name, attribute )
    End
    Else Do
      lastClass = package~currentClass
      If options.["CLASS"] Then Do
        If lastClass~classMethods~hasIndex(name) Then Signal 99.931
        lastClass~addClassMethod( name, attribute )
      End
      Else Do
        If lastClass~instanceMethods~hasIndex(name) Then Signal 99.931
        lastClass~addInstanceMethod( name, attribute )
      End
    End
  End
  If options.set Then Do
    name = name"="
    If package~inTheProlog Then Do
      If package~definedMethods~hasIndex(name) Then Signal 99.931
      package~addMethod( name, attribute )
    End
    Else Do
      lastClass = package~currentClass
      If options.["CLASS"] Then Do
        If lastClass~classMethods~hasIndex(name) Then Signal 99.931
        lastClass~addClassMethod( name, attribute )
      End
      Else Do
        If lastClass~instanceMethods~hasIndex(name) Then Signal 99.931
        lastClass~addInstanceMethod( name, attribute )
      End
    End
  End
  directive~body = codeBody
  directive~attribute = attribute
  package~addDirective( directive )
Return

-- Duplicate ::ATTRIBUTE directive instruction.
99.931: Syntax( 99.931, TheElementAfter( directive~begin ) )

-- External attributes cannot have a method body.
99.935: Syntax( 99.935, instructionBegin )

-- Attribute methods without a SET or GET designation
-- cannot have a method body.
99.937: Syntax( 99.937, instructionBegin)

-- Abstract attributes cannot have a method body.
99.940: Syntax( 99.940, instructionBegin )

-- Delegate attributes cannot have a method body.
99.947: Syntax( 99.947, instructionBegin )

--------------------------------------------------------------------------------

::Class Attribute.Method

::Attribute name      Get
::Attribute body      Get
::Attribute directive Get

::Method init
  Expose         name  directive  body
  Use Strict Arg name, directive, body

/******************************************************************************/
/* CLASS                                                                      */
/******************************************************************************/

::Routine Class
  Use Strict Arg package, directive
  body = Empty.Body( package, directive )
  class = .Rexx.Class~new( directive~name, directive, body )
  package~currentClass = class
  name = Upper( directive~name~value )
  options. = directive~options.
  If package~publicClasses~hasIndex( name ) Then Signal 99.901
  If package~      classes~hasIndex( name ) Then Signal 99.901
  Select Case options.public
    When 1 Then package~addPublicClass( name, class )
    When 0 Then package~addClass(       name, class )
  End
  directive~body = body
  directive~theClass = class
  package~addDirective( directive )
  Return

-- Duplicate ::CLASS directive instruction.
99.901: Syntax( 99.901, TheElementAfter(directive~begin) )

--------------------------------------------------------------------------------

::Class Rexx.Class

::Attribute name      Get
::Attribute directive Get
::Attribute classMethods    Get -- Different than ooRexx Class class!
::Attribute instanceMethods Get -- Different than ooRexx Class class!

::Method init
  Expose         name  directive body classMethods instanceMethods
  Use Strict Arg name, directive, body
  classMethods    = .StringTable~new
  instanceMethods = .StringTable~new
::Method addClassMethod
  Expose classMethods
  Use Strict Arg name, method
  classMethods[name] = method
::Method addInstanceMethod
  Expose instanceMethods
  Use Strict Arg name, method
  instanceMethods[name] = method

/******************************************************************************/
/* CONSTANT                                                                   */
/******************************************************************************/

::Routine Constant
  Use Strict Arg package, directive
  codeBody = Code.Body( package, directive )
  If \codeBody~isEmpty Then Do
    instructionBegin = TheElementAfter( codeBody~instructions[1]~begin )
    Signal 99.938
  End
  constant = .Constant.Method~new(directive~name, directive, codeBody)
  name = Upper( directive~name~value )
  If package~inTheProlog Then Do
    If package~definedMethods~hasIndex(name) Then Signal 99.932
    package~addMethod( name, constant )
  End
  Else Do
    lastClass = package~currentClass
    If lastClass~classMethods~hasIndex(name) Then Signal 99.932
    lastClass~addClassMethod( name, constant )
    If lastClass~instanceMethods~hasIndex(name) Then Signal 99.932
    lastClass~addInstanceMethod( name, constant )
  End
  directive~body = codeBody
  directive~constant = constant
  package~addDirective( directive )
  Return

-- Duplicate ::CONSTANT directive instruction.
99.932: Syntax( 99.932, TheElementAfter( directive~begin ) )

-- Constant methods cannot have a method body.
99.938: Syntax( 99.938, instructionBegin )

--------------------------------------------------------------------------------

::Class Constant.Method
::Method init
  Expose         name  directive  body
  Use Strict Arg name, directive, body
::Attribute name      Get
::Attribute directive Get
::Attribute body      Get

/******************************************************************************/
/* METHOD                                                                     */
/******************************************************************************/

::Routine Method
  Use Strict Arg package, directive
  codeBody = Code.Body( package, directive )
  options. = directive~options.
  If \codeBody~isEmpty Then Do
    firstInstruction = codeBody~instructions[1]
    instructionBegin = TheElementAfter( firstInstruction~begin )
    If options.abstract                 Then Signal 99.933
    Else If options.["ATTRIBUTE"]       Then Signal 99.934
    Else If options.external \== ""     Then Signal 99.936
    Else If options.delegateName \== "" Then Signal 99.946
  End
  name = Upper( directive~name~value )
  method = .Rexx.Method~new(name, directive, codeBody)
  If package~inTheProlog Then Do
    If package~definedMethods~hasIndex( name ) Then Signal 99.902
    package~addMethod( name, method )
  End
  Else Do
    lastClass = package~currentClass
    If options.["CLASS"] Then Do -- Class method
      If lastClass~classMethods~hasIndex(name) Then Signal 99.902
      lastClass~addClassMethod( name, method )
      If options.attribute Then Do
        name = name"="
        If lastClass~classMethods~hasIndex( name ) Then Signal 99.902
        lastClass~addClassMethod( name, method )
      End
    End
    Else Do -- Instance method
      If lastClass~instanceMethods~hasIndex(name) Then Signal 99.902
      lastClass~addInstanceMethod( name, method )
      If options.attribute Then Do
        name = name"="
        If lastClass~instanceMethods~hasIndex(name) Then Signal 99.902
        lastClass~addInstanceMethod( name, method )
      End
    End
  End
  directive~body = codeBody
  directive~method = method
  package~addDirective( directive )
Return

-- Duplicate ::METHOD directive instruction.
99.902: Syntax( 99.902, TheElementAfter( directive~begin ) )

-- Abstract methods cannot have a method body.
99.933: Syntax( 99.933, instructionBegin )

-- Attribute methods cannot have a method body.
99.934: Syntax( 99.934, instructionBegin )

-- External methods cannot have a method body.
99.936: Syntax( 99.936, instructionBegin )

-- Delegate methods cannot have a method body.
99.946: Syntax( 99.946, instructionBegin )

--------------------------------------------------------------------------------

::Class Rexx.Method
::Method init
  Expose         name  directive  body
  Use Strict Arg name, directive, body
::Attribute name      Get
::Attribute body      Get
::Attribute directive Get

/******************************************************************************/
/* OPTIONS                                                                    */
/******************************************************************************/

::Routine Options
  Use Strict Arg package, directive
  body = Empty.Body( package, directive )
  directive~body = body
  package~addDirective( directive )

/******************************************************************************/
/* REQUIRES                                                                   */
/******************************************************************************/

::Routine Requires
  Use Strict Arg package, directive
  body = Empty.Body( package, directive )
  directive~body = body
  package~addDirective( directive )

/******************************************************************************/
/* RESOURCE                                                                   */
/******************************************************************************/

::Routine Resource
  Use Strict Arg package, directive
  package~tokenizer~resource.data( package, directive )
  body = Empty.Body( package, directive )
  directive~body = body
  package~addDirective( directive )

  name = Upper( directive~name~value )
  If package~resources~hasIndex(name) Then Signal 99.942
  package~addResource( name, directive )
  Exit

-- Duplicate ::RESOURCE directive instruction.
99.942: Syntax( 99.942, TheElementAfter( directive~begin ) )

/******************************************************************************/
/* ROUTINE                                                                    */
/******************************************************************************/

::Routine Routine
  Use Strict Arg package, directive

  name = directive~name
  codeBody = Code.Body( package, directive )
  If \codeBody~isEmpty Then Do
    instructionBegin = TheElementAfter( codeBody~instructions[1]~begin )
    If directive~external \== .Nil Then Signal 99.939
  End
  routine = .Rexx.Routine~new( name, codeBody )
  name = Upper( name~value )
  If package~routines~hasIndex(name) Then Signal 99.903
  If directive~private Then package~addRoutine(name, routine)
  Else                      package~addPublicRoutine(name, routine)

  directive~body    = codeBody
  directive~routine = routine
  package~addDirective( directive )
  Return

-- Duplicate ::ROUTINE directive instruction.
99.903: Syntax( 99.903, TheElementAfter( directive~begin ) )

-- External routines cannot have a code body.
99.939: Syntax( 99.939, instructionBegin )

--------------------------------------------------------------------------------

::Class Rexx.Routine
::Attribute body Get
::Attribute name Get
::Method init
  Expose         name  body
  Use Strict Arg name, body

--------------------------------------------------------------------------------
-- Common routine: check that a directive body is empty (i.e., it consists    --
-- only of null clauses) and return that body. Otherwise, raise               --
-- a 99.916 error.                                                            --
--------------------------------------------------------------------------------

::Routine Empty.Body
  Use Strict Arg package, directive
  body = Code.Body( package, directive )
  If body~isEmpty Then Return body
  instruction = body~instructions[1]
  If \instruction~labels~isEmpty Then
    Call 99.916 instruction~labels[1]~label
  Call 99.916 TheElementAfter(instruction~begin)

-- Unrecognized directive instruction.
99.916: Syntax( 99.916, Arg(1) )