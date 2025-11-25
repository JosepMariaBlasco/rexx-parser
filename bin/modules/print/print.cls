/******************************************************************************/
/*                                                                            */
/* print.cls -- The "print" module                                            */
/* ===============================                                            */
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
/* 20250318    0.2  Change syntax to class::method                            */
/* 20250328         Main dir is now rexx-parser instead of rexx[.]parser      */
/*                                                                            */
/******************************************************************************/

loader =                                                ,
  .File~new(.context~package~name)~parentFile~parent || ,
  .File~separator"Load.Parser.Module.rex"
Call (loader) "BaseClassesAndRoutines"

/******************************************************************************/
/* MAKEARRAY Methods                                                          */
/******************************************************************************/

::Method "Do.Instruction::makeArray"
  Expose doClause   instructions  endClause
  Use Strict Arg indent = 0
  Return self~makeArray:super(doClause, instructions, endClause, indent)

--------------------------------------------------------------------------------

::Method "If.Instruction::makeArray"
  Expose ifClause thenClause thenInstruction elseClause elseInstruction
  Use Strict Arg indent = 0
  array = Array(ifClause~string(indent) thenClause~string)
  Do then Over thenInstruction~makeArray(indent+2)
    array~append(then)
  End
  If \elseInstruction~isNil Then Do
    array~append(elseClause~string(indent))
    Do else Over elseInstruction~makeArray(indent+2)
      array~append(else)
    End
  End
  Return array

--------------------------------------------------------------------------------

::Method "Iterative.Instruction::makeArray"
  Use Strict Arg startClause, instructions, endClause, indent = 0
  array = Array(startClause~string(indent))
  Do i = 1 To instructions~items
    instruction = instructions[i]~makeArray(indent + 2)
    Do j = 1 To instruction~items
      array~append(instruction[j])
    End
  End
  array~append(endClause~string(indent))
  Return array

--------------------------------------------------------------------------------

::Method "Loop.Instruction::makeArray"
  Expose loopClause instructions endClause
  Use Strict Arg indent = 0
  Return self~makeArray:super(loopClause, instructions, endClause, indent)

--------------------------------------------------------------------------------

::Method "Select.Instruction::makeArray"
  Expose                   -
    selectClause           -
      whenThenInstructions -
      otherwiseClause      -
        otherwiseSequence  -
    endClause
  Use Strict Arg indent = 0
  array = Array(selectClause~string(indent))
  Do WTI Over whenThenInstructions
    whenClause = WTI[1]~string(indent+2)
    If \ WTI[2]~labels~isEmpty Then
      whenThen = whenClause";" WTI[2]~string
    Else
      whenThen = whenClause "THEN"
    array~append(whenThen)
    thenInstructionArray = WTI[3]~makeArray(indent+4)
    Do j = 1 To thenInstructionArray~items
      array~append(thenInstructionArray[j])
    End
  End
  If \otherwiseSequence~isEmpty Then Do
    array~append(otherwiseClause~string(indent+2))
    Do i = 1 To otherwiseSequence~items
      instructionArray = otherwiseSequence[i]~makeArray(indent+4)
      Do j = 1 To instructionArray~items
        array~append(instructionArray[j])
      End
    End
  End
  array~append(endClause~string(indent))
  Return array

/******************************************************************************/
/* STRING Methods                                                             */
/******************************************************************************/

::Method "End.Of.Source::String"
  Return ""

/******************************************************************************/
/* STRING Methods - Clauses                                                   */
/******************************************************************************/

::Method "Else.Clause::String"
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"ELSE"

--------------------------------------------------------------------------------

::Method "End.Clause::String"
  Expose options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"END"
  If options.~hasIndex(name) Then ret = ret options.name
  Return ret

--------------------------------------------------------------------------------

::Method "If.Clause::String"
  Expose expressions
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"IF" expressions

--------------------------------------------------------------------------------

::Method "Iterative.Clause::String"
  Expose options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)self~InstructionName
  If options.~hasIndex(label)   Then ret = ret "LABEL"   options.label
  If options.~hasIndex(counter) Then ret = ret "COUNTER" options.counter
  If options.~hasIndex(simple)  Then ret = ret options.simple
  If options.~hasIndex(forever) Then ret = ret "FOREVER"
  If options.~hasIndex(item)    Then Do
    ret = ret "WITH ITEM" options.item
    If options.~hasIndex(index) Then ret = ret "INDEX" options.index
    ret = ret "OVER" options.over
  End
  Else If options.~hasIndex(index) Then
    ret = ret "WITH INDEX" options.index "OVER" options.over
  Else If options.~hasIndex(over)    Then Do
    ret = ret options.control "OVER" options.over
    If options.~hasIndex(for)   Then ret = ret "FOR"     options.for
  End
  If options.~hasIndex("=")    Then Do
    ret = ret options.control "=" options.["="]
    If options.~hasIndex(to)    Then ret = ret "TO"      options.to
    If options.~hasIndex(by)    Then ret = ret "BY"      options.by
    If options.~hasIndex(for)   Then ret = ret "FOR"     options.for
  End
  If options.~hasIndex(while)   Then ret = ret "WHILE"   options.while
  If options.~hasIndex(until)   Then ret = ret "UNTIL"   options.until
  Return ret

--------------------------------------------------------------------------------

::Method "Label.Clause::String"
  Expose label
  Return label~value":"

--------------------------------------------------------------------------------

::Method "Null.Clause::String"
  Return ";"

--------------------------------------------------------------------------------

::Method "Otherwise.Clause::String"
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"OTHERWISE"

--------------------------------------------------------------------------------

::Method "Select.Clause::String"
  Expose options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"SELECT"
  If options.~hasIndex(label) Then ret = ret "LABEL" options.label
  If options.~hasIndex(case)  Then ret = ret "CASE"  options.case
  Return ret

--------------------------------------------------------------------------------

::Method "Then.Clause::String"
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"THEN"

--------------------------------------------------------------------------------

::Method "When.Clause::String"
  Expose expressions
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"WHEN" expressions

/******************************************************************************/
/* STRING Methods - Directives                                                */
/******************************************************************************/

::Method "Annotate.Directive::String"
  Expose options.
  ret = "::ANNOTATE" options.directive
  If options.directive \== "PACKAGE" Then ret = ret options.name
  Do i = 1 To options.pairs~items
    pair = options.pairs[i]
    If pair[2] \== .Nil Then ret = ret pair[1] pair[2] pair[3] -- signed
    Else                     ret = ret pair[1]         pair[3] -- not signed
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Attribute.Directive::String"
  Expose name options.
  ret = "::ATTRIBUTE" name
  If  options.get, \options.set Then ret = ret "GET"
  If \options.get,  options.set Then ret = ret "SET"
  If options.class      Then ret = ret "CLASS"
  ret = ret options.visibility
  If \options.guarded   Then   ret = ret "UNGUARDED"
  If  options.protected Then ret = ret "PROTECTED"
  If  options.abstract  Then ret = ret "ABSTRACT"
  If options.delegateName \== "" Then ret = ret "DELEGATE" options.delegateName
  If options.external     \== "" Then ret = ret "EXTERNAL" options.external
  Return ret

--------------------------------------------------------------------------------

::Method "Class.Directive::String"
  Expose name options.
  ret = "::CLASS" name
  Do word Over ("METACLASS", "MIXINCLASS", "SUBCLASS")
    If options.word \== .Nil Then ret = ret word options.word
  End
  Do word Over ("PRIVATE", "PUBLIC", "ABSTRACT")
    If options.word \== .Nil Then ret = ret word
  End
  If options.inherit \== .Nil Then Do
    ret = ret "INHERIT"
    Do i = 1 To options.inherit~items
      ret = ret options.inherit[i]
    End
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Constant.Directive::String"
  Expose name value expression sign number
  Select
    When \value~isNil Then
      If value < .ALL.STRINGS Then
        Return "::CONSTANT" name~value value~source
      Else
        Return "::CONSTANT" name~value value~value
    When \expression~isNil Then
      Return "::CONSTANT" name~value expression
    When \sign~isNil Then
      Return "::CONSTANT" name~value sign~value number~value
    Otherwise
      Return "::CONSTANT" name~value
  End

--------------------------------------------------------------------------------

::Method "Method.Directive::String"
  Expose name options.
  ret = "::METHOD" name
  If options.attribute    Then ret = ret "ATTRIBUTE"
  If options.class        Then ret = ret "CLASS"
  ret = ret options.visibility
  If options.guarded      Then ret = ret "GUARDED"
  If options.protected    Then ret = ret "PROTECTED"
  If options.abstract     Then ret = ret "ABSTRACT"
  If options.delegateName \== "" Then
    ret = ret "DELEGATE" options.delegateName
  If options.external     \== "" Then
    ret = ret "EXTERNAL" options.external
  Return ret

--------------------------------------------------------------------------------

::Method "Options.Directive::String"
  Expose options.
  ret = "::OPTIONS"
  Do word Over ("DIGITS", "FORM", "FUZZ", "ALL", "ERROR", "FAILURE",  -
    "LOSTDIGITS", "NOSTRING", "NOTREADY", "NOVALUE", "TRACE",         -
  )
    If options.word \== .Nil Then ret = ret word options.word
  End
  If options.prolog  == 1    Then ret = ret "PROLOG"
  If options.prolog  == 0    Then ret = ret "NOPROLOG"
  Return ret

--------------------------------------------------------------------------------

::Method "Requires.Directive::String"
  Expose programName options.
  ret = "::REQUIRES" programName
  If options.library   \== .Nil Then ret = ret "LIBRARY"
  If options.nameSpace \== .Nil Then ret = ret "NAMESPACE" options.nameSpace
  Return ret

--------------------------------------------------------------------------------

::Method "Resource.Directive::String"
  Expose name delimiter
  ret = "::RESOURCE" name
  If delimiter \== "::END" Then
  ret = ret "END" delimiter
  Return ret

--------------------------------------------------------------------------------

::Method "Routine.Directive::String"
  Expose name private spec
  If private Then visibility = "PRIVATE"
  Else            visibility = "PUBLIC"
  If spec~isNil Then
    Return "::ROUTINE" name~value visibility
  Else
    Return "::ROUTINE" name~value visibility spec~source

/******************************************************************************/
/* STRING Methods - Expressions                                               */
/******************************************************************************/

::Method "Concatenation.Expression::String"
  args = self~args
  str = ""
  Do i = 1 To args~items - 1 By 2
    Select Case args[i+1]
      When " " Then Op = "' '"
      When ""  Then Op = "''"
      Otherwise     Op = "||"
    End
    str ||= args[i]Op
  End
  str ||= args~lastItem
  Return str

--------------------------------------------------------------------------------

::Method "Expression.List::String"
  Expose args
  If args == .Nil Then Return ""
  str = ""
  Do arg over args
    str ||= arg
  End
  Return str

--------------------------------------------------------------------------------

::Method "NAry.Expression::String"
  Expose args
  str = ""
  Do i = 1 To args~items - 1 By 2
    str ||= args[i]args[i+1]
  End
  str ||= args~lastItem
  Return Strip(str)

--------------------------------------------------------------------------------

::Method "Prefix.Expression::String"
  Expose prefixes term
  Return prefixes~toString(c)term

--------------------------------------------------------------------------------

::Method "SubExpression::String"
  Expose subExpression
  Return "("subExpression")"

--------------------------------------------------------------------------------

::Method "Compound.Variable.Term::String"
  Expose parts

  ret = ""
  nParts = parts~items
  Do i = 1 To nParts
    ret ||= parts[i]
  End
  Return ret


--------------------------------------------------------------------------------

::Method "Stem.Variable.Term::String"
  Expose stem
  Return stem~value

--------------------------------------------------------------------------------

::Method "Tail.Separator.Element::String"
  Return "."

--------------------------------------------------------------------------------

::Method "Message.Term::String"
  Expose term operator messageName scope arguments
  name = messageName~value
  op   = operator   ~value
  If \scope~isNil Then name ||= ":"scope~value
  If arguments~isNil Then
    Return ""term||op||name
  Else
    Return ""term||op||name"("arguments")"

--------------------------------------------------------------------------------

::Method "Symbol.Term::String"
  Expose symbol
  Return symbol~value

--------------------------------------------------------------------------------

::Method "Indexed.Or.Invoked.Term::String"
  Expose term arguments
  Return ""term"["arguments"]"

--------------------------------------------------------------------------------

::Method "Literal.String.Term::String"
  Expose string
  Return string~source

--------------------------------------------------------------------------------

::Method "Variable.Reference.Term::String"
  Expose operator variable
  Return operator~value||variable~value

--------------------------------------------------------------------------------

::Method "NameSpace.Qualified.ClassName::String"
  Expose nameSpace className
  Return nameSpace~value":"className~value

--------------------------------------------------------------------------------

::Method "Function.Call.Term::String"
  Expose name argumentList
  Return name~value"("argumentList")"

--------------------------------------------------------------------------------

::Method "NameSpace.Qualified.Function.Call::String"
  Expose nameSpace name argumentList
  Return nameSpace~value":"name~value"("argumentList")"

/******************************************************************************/
/* STRING Methods - Instructions                                              */
/******************************************************************************/

::Method "Address.Instruction::String"
  Expose options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"ADDRESS"
  If options.environment \== .Nil Then ret = ret options.environment
  If options.command     \== .Nil Then ret = ret options.command
  If options.value       \== .Nil Then ret = ret "VALUE" options.value
  If options.with == 1 Then Do
    ret = ret "WITH"
    Do word Over ("INPUT", "OUTPUT", "ERROR")
      If options.word == 1 Then Call Process word
    End
  End
  Return ret

Process:
  Parse Arg variant
  ret = ret variant
  If variant \== "INPUT" Then Do
    If options.variant.replace == 1    Then ret = ret "REPLACE"
    If options.variant.append  == 1    Then ret = ret "APPEND"
  End
  If options.variant.normal    == 1    Then ret = ret "NORMAL"
  If options.variant.stem     \== .Nil Then ret = ret "STEM"   options.variant.stem
  If options.variant.stream   \== .Nil Then ret = ret "STREAM" options.variant.stream
  If options.variant.using    \== .Nil Then ret = ret "USING"  options.variant.using
  Return

--------------------------------------------------------------------------------

::Method "Assignment.Instruction::String"
  Expose symbol operator expression
  Use Strict Arg indent = 0
  Return Copies(" ", indent)PrintLabels(self)symbol~value -
    operator~value expression

--------------------------------------------------------------------------------

::Method "Call.Instruction::String"
  Expose name arguments
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"CALL"
  ret = ret name
  If \arguments~isNil Then ret = ret arguments
  Return ret

--------------------------------------------------------------------------------

::Method "Call.Value.Instruction::String"
  Expose expression arguments
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"CALL ("expression")"
  If \arguments~isNil Then ret = ret arguments
  Return ret

--------------------------------------------------------------------------------

::Method "Call.Off.Instruction::String"
  Expose condition userCondition
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"CALL OFF" condition
  If condition~value == "USER" Then ret = ret userCondition
  Return ret

--------------------------------------------------------------------------------

::Method "Call.On.Instruction::String"
  Expose condition userCondition trapName
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"CALL ON" condition
  If condition~value == "USER" Then ret = ret userCondition
  If \ trapName~isNil Then ret = ret "NAME" trapName
  Return ret

--------------------------------------------------------------------------------

::Method "Command.Instruction::String"
  Expose expression
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)expression

--------------------------------------------------------------------------------

::Method "Drop.Instruction::String"
  Expose nameList
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"DROP"
  Do i = 1 To nameList~items
    If nameList[i]~isA(.Array) Then ret = ret "("nameList[i][1]")"
    Else                            ret = ret    nameList[i]
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Expose.Instruction::String"
  Expose exposed
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"EXPOSE"
  Do i = 1 To exposed~items
    If exposed[i]~isA(.Array) Then ret = ret "("exposed[i][1]")"
    Else                            ret = ret    exposed[i]
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Forward.Instruction::String"
  Expose options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"FORWARD"
  If options.~hasIndex(continue)  Then ret = ret "CONTINUE"
  If options.~hasIndex(arguments) Then ret = ret "ARGUMENTS" options.arguments
  If options.~hasIndex(array)     Then ret = ret "ARRAY"     options.array
  If options.~hasIndex(message)   Then ret = ret "MESSAGE"   options.message
  If options.~hasIndex(class)     Then ret = ret "CLASS"     options.class
  If options.~hasIndex(to)        Then ret = ret "TO"        options.to
  Return ret

--------------------------------------------------------------------------------

::Method "Guard.Instruction::String"
  Expose on expression
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"GUARD"
  If on Then ret = ret "ON"
  Else       ret = ret "OFF"
  If \ expression~isNil Then ret = ret "WHEN" expression
  Return ret

--------------------------------------------------------------------------------

::Method "Implicit.Exit.Instruction::String"
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self) -- "/* Implicit exit */"

--------------------------------------------------------------------------------

::Method "Interpret.Instruction::String"
  Expose expression
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"INTERPRET" expression

--------------------------------------------------------------------------------

::Method "Iterate.Instruction::String"
  Expose label
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"ITERATE"
  If \ label~isNil Then ret = ret label~value
  Return ret

--------------------------------------------------------------------------------

::Method "Leave.Instruction::String"
  Expose label
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"LEAVE"
  If \ label~isNil Then ret = ret label~value
  Return ret

--------------------------------------------------------------------------------

::Method "Message.Assignment.Instruction::String"
  Expose lhs operator rhs
  Use Strict Arg indent = 0
  Return Copies(" ", indent)PrintLabels(self)lhs operator rhs

--------------------------------------------------------------------------------

::Method "Message.Instruction::String"
  Expose expression
  Use Strict Arg indent = 0
  Return Copies(" ", indent)PrintLabels(self)expression

--------------------------------------------------------------------------------

::Method "NameSpace.Qualified.Call.Instruction::String"
  Expose nameSpace name arguments
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"CALL"
  ret = ret nameSpace":"name
  If \arguments~isNil Then ret = ret arguments
  Return ret

--------------------------------------------------------------------------------

::Method "Nop.Instruction::String"
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"NOP"

--------------------------------------------------------------------------------

::Method "Numeric.Instruction::String"
  Expose option expression
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"NUMERIC"
  Select Case option
    When "Digits", "Fuzz", "Form", "Form Value" Then
      If expression~isNil Then ret = ret Upper(option)
      Else                     ret = ret Upper(option) expression
    Otherwise ret = ret Upper(option)
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Optional.Expression.Instruction::String"
  Expose expression
  Use Strict Arg indent = 0
  If expression~isNil Then
    Return Copies(" ", indent)PrintLabels(self)self~instructionName
  Else
    Return Copies(" ", indent)PrintLabels(self)self~instructionName expression

--------------------------------------------------------------------------------

::Method "Options.Instruction::String"
  Expose expression
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"OPTIONS" expression

--------------------------------------------------------------------------------

::Method "Parse.Instruction::String"
  Expose options. templateList
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"PARSE"
  If options.upper    Then ret = ret "UPPER"
  If options.lower    Then ret = ret "LOWER"
  If options.caseless Then ret = ret "CASELESS"
  ret = ret options.variant
  Select Case options.variant
    When "VAR"   Then ret = ret options.var
    When "VALUE" Then ret = ret options.value "WITH"
    Otherwise Nop
  End
  If \templateList~isNil Then ret = ret templateList
  Return ret

--------------------------------------------------------------------------------

::Method "Procedure.Instruction::String"
  Expose exposed
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"PROCEDURE"
  If exposed~isNil Then Return ret
  ret = ret "EXPOSE"
  Do i = 1 To exposed~items
    If exposed[i]~isA(.Array) Then ret = ret "("exposed[i][1]")"
    Else                            ret = ret    exposed[i]
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Raise.Instruction::String"
  Expose condition options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"RAISE"
  condName = condition[1]~value
  ret = ret condName
  Select Case condName
    When "ERROR", "FAILURE", "SYNTAX" Then Do
      code = condition[2]
      If code~isA( .Element ) Then ret = ret    code
      Else                       ret = ret "("code")"
    End
    When "USER" Then ret = ret condition[2]
    Otherwise Nop
  End
  If options.~hasIndex(array) Then ret = ret array "("options.array")"
  If options.~hasIndex(additional) Then
    If options.additional~isA(.Element) Then
      ret = ret additional    options.additional
    Else
      ret = ret additional "("options.additional")"
  If options.~hasIndex(description) Then
    If options.description~isA(.Element) Then
      ret = ret description    options.description
    Else
      ret = ret description "("options.description")"
  If options.~hasIndex(exit) Then Do
    ret = ret "EXIT"
    If \ options.exit~isNil Then
      If options.exit~isA(.Element) Then ret = ret    options.exit
      Else                             ret = ret "("options.exit")"
  End
  If options.~hasIndex(return) Then Do
    ret = ret "RETURN"
    If \ options.return~isNil Then
      If options.return~isA(.Element) Then ret = ret    options.return
      Else                               ret = ret "("options.return")"
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Signal.Instruction::String"
  Expose label
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"SIGNAL" label

--------------------------------------------------------------------------------

::Method "Signal.Value.Instruction::String"
  Expose expression
  Use Strict Arg indent = 0
  Return Copies(" ",indent)PrintLabels(self)"SIGNAL VALUE" expression

--------------------------------------------------------------------------------

::Method "Signal.Off.Instruction::String"
  Expose condition userCondition
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"SIGNAL OFF" condition
  If condition~value == "USER" Then ret = ret userCondition
  Return ret

--------------------------------------------------------------------------------

::Method "Signal.On.Instruction::String"
  Expose condition userCondition label
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"SIGNAL ON" condition
  If condition~value == "USER" Then ret = ret userCondition
  If \ label~isNil Then ret = ret "NAME" label
  Return ret

--------------------------------------------------------------------------------

::Method "Trace.Instruction::String"
  Expose options.
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"TRACE"
  Do ix over options.~allIndexes
    If ix == "VALUE" Then ret = ret "VALUE" options.ix
    Else                  ret = ret         options.ix
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Use.Arg.Instruction::String"
  Expose strict arguments
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"USE"
  If strict Then ret = ret "STRICT"
  ret = ret "ARG "
  Do i = 1 To arguments~items
    If i > 1 Then ret = ret","
    Select Case arguments[i]~items
      When 1         Then ret = ret arguments[i][1]
      When 2         Then ret = ret arguments[i][1] "=" arguments[i][2]
    End
  End
  Return ret

--------------------------------------------------------------------------------

::Method "Use.Local.Instruction::String"
  Expose local
  Use Strict Arg indent = 0
  ret = Copies(" ",indent)PrintLabels(self)"USE LOCAL"
  Do i = 1 To local~items
    ret = ret local[i]
  End
  Return ret

/******************************************************************************/
/* STRING Methods - Templates                                                 */
/******************************************************************************/

::Method "Template::String"
  Expose list
  ret = ""
  Do i = 1 To list~items
    ret = ret list[i]
  End
  Return ret~strip("L")

--------------------------------------------------------------------------------

::Method "Optional.Template.List::String"
  Expose templateList
  Use Strict Arg indent = 0
  ret = Copies(" ", indent)PrintLabels(self)self~instructionName
  If \ templateList~isNil Then ret ||= templateList
  Return ret

--------------------------------------------------------------------------------

::Method "Prefixed.Template::String"
  Expose prefix elementOrSubExpression
  Return prefix || elementOrSubExpression

--------------------------------------------------------------------------------

::Method "Template.List::String"
  Expose list
  ret = ""
  Do i = 1 To list~items
    If i > 1 Then ret = ret ","
    If \list[i]~isNil Then ret = ret list[i]
  End
  Return ret

/******************************************************************************/
/* STRING Methods - Elements                                                  */
/******************************************************************************/

::Method "Operator.Character.Sequence::String"
  Return self~value

::Method "Special.Character.Sequence::String"
  Return self~value

::Method "StringOrSymbol.Element::String"
  Return self~value

::Method "WhiteSpace.Element::String"
  Return " "