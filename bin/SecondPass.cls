/******************************************************************************/
/*                                                                            */
/* SecondPass.cls                                                             */
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
/* 20241209    0.1b New call system                                           */
/* 20241225    0.1d Add support for doc-comments                              */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250414         Move BIF info to BIFs.cls                                 */
/* 20250414         Add argument info to called routine chain                 */
/*                                                                            */
/******************************************************************************/

::Requires "BaseClassesAndRoutines.cls"
::Requires "BIFs.cls"

/******************************************************************************/
--
-- * Label and ::Routine collection
-- * Determination of the call types: internal, BIF, ::Routine, external
--
/******************************************************************************/

::Routine SecondPass Public

  Use Strict Arg package

  Call LoadBIFInfo -- Defined in BIFs.cls

  DocComments = Global.Option( DocComments )

  Call ProcessBody package, package~prolog, package~prolog~body
  Do Counter n fragment Over package~directives
    If DocComments \== "" Then Call ProcessDirectiveDocComment package, n
    body = fragment~body
    If \ body~isEmpty Then Call ProcessBody package, fragment, body
  End

--------------------------------------------------------------------------------

::Routine ProcessDocCommentsOptions

  AllowedDocComments = Upper( ChangeStr(",",Global.Option( DocComments )," ") )

  StandardDocCommentAllowed = -
    ( WordPos( All,      AllowedDocComments) > 0 ) | -
    ( WordPos( Standard, AllowedDocComments) > 0 ) | -
    ( WordPos( Block   , AllowedDocComments) > 0 ) | -
    ( WordPos( Classic , AllowedDocComments) > 0 )

  MarkdownDocCommentAllowed = -
    ( WordPos( All,      AllowedDocComments) > 0 ) | -
    ( WordPos( Line    , AllowedDocComments) > 0 ) | -
    ( WordPos( Markdown, AllowedDocComments) > 0 )

  Return StandardDocCommentAllowed MarkdownDocCommentAllowed
--------------------------------------------------------------------------------

::Routine ProcessDirectiveDocComment

-- TODO: Use ProcessDocCommentBefore

  Use Strict Arg package, n

  Parse Value ProcessDocCommentsOptions() With -
    StandardDocCommentAllowed MarkdownDocCommentAllowed

  -- Pick this directive and the last one
  directive = package~directives[n]
  If n == 1 Then lastDirective = package~prolog
  Else           lastDirective = package~directives[n - 1]

  -- The last instruction after the previous directive is an inserted EXIT...
  exitInstruction = lastDirective~body~instructions~lastItem

  -- ...and this inserted EXIT may have null clauses attached.
  nullClauses     = exitInstruction~nullClauses

  -- No null clauses? No doc-comment
  If nullClauses~isEmpty Then Exit

  -- Pick the first and last non-semicolon elements
  first = nullClauses~lastItem~begin~next
  last  = nullClauses~lastItem~end  ~prev

  -- The null clause has to start at column 1...
  If first~from~word(2) \== 1 Then Exit
  -- ...and it has to end at the end of the last line
  Parse Value last~to With line col
  If col \== Length(package~source[line]) + 1 Then Exit

  -- We may allow for some whitespace before and after...
  If first < .EL.WHITESPACE Then first = first~next
  If last  < .EL.WHITESPACE Then last  = last ~prev
  -- ...but now first and last should be the same
  If first \== last Then Exit

  docComment = first

  If StandardDocCommentAllowed, docComment < .EL.STANDARD_COMMENT Then Do
    -- Comment has to start with "/**", with optional whitespace
    Parse Value docComment~from With line .
    If package~source[line] <> "/**" Then Exit

    -- Absorb whitespace before, if any
    If docComment~from~word(2) \== "1" Then Do
      docComment~from = docComment~prev~from
      prev            = docComment~prev~prev
      prev~next       = docComment
      docComment~prev = prev
    End

    -- Absorb whitespace after, if any
    If docComment~next < .EL.WHITESPACE Then Do
      docComment~to   = docComment~next~to
      next            = docComment~next~next
      next~prev       = docComment
      docComment~next = next
    End

    Call SetCategory docComment, .EL.DOC_COMMENT

    -- We detach the nullClause from the implicit EXIT instruction,
    nullClauses~delete( nullClauses~last )

  End
  Else If MarkdownDocCommentAllowed, docComment < .EL.LINE_COMMENT Then Do
    -- Comment has to start with "---"
    Parse Value docComment~from With line .
    sourceLine = package~source[line]
    -- Comment has to start with "---"
    If sourceLine[1,3] \== "---" Then Exit
    -- "----" is a line comment, not a doc-comment.
    If sourceLine[1,4]  == "----" Then Exit

    -- Absorb whitespace before, if any
    If docComment~from~word(2) \== "1" Then Do
      docComment~from = docComment~prev~from
      prev            = docComment~prev~prev
      prev~next       = docComment
      docComment~prev = prev
    End

    -- We detach the nullClause from the implicit EXIT instruction,
    nullClauses~delete( nullClauses~last )

    Loop While line > 1
      line -= 1
      sourceLine = Strip( package~source[line] )
    -- Three dashes, but not more
    If \sourceLine~startsWith("---")  Then Leave
    If  sourceLine~startsWith("----") Then Leave
      -- Absorb whitespace, if any
      eoc        = docComment~prev
      comment    = eoc~prev
      whitespace = comment~prev
      If whitespace < .EL.WHITESPACE Then Do
         comment~from         = whitespace~from
         whitespace~prev~next = comment
         comment~prev         = whitespace~prev
      End
      docComment~from = comment~from
      docComment~prev = comment~prev
      comment~prev~next = docComment
      nullClauses~delete( nullClauses~last )
    End

    Call SetCategory docComment, .EL.DOC_COMMENT_MARKDOWN

  End

  -- Now the housekeeping becomes quite involved.
  -- We first reattach the newly reformatted comment to the current
  -- directive.

  directive~docComment = docComment

  -- We now relocate the implicit EXIT instruction and the corresponding
  -- inserted end-of-clause marker so that they are located before the
  -- newly qualified docComment.

  -- The end-of-clause marker before the docComment
  before      = docComment~prev
  from        = before~from
  -- The docComment, an end-of-clause, implicit EXIT, another end-of-clause
  exitElement = docComment~next~next
  eoc         = exitElement ~next
  exitElement~from = from
  exitElement~to   = from -- from == to
  eoc        ~from = from
  eoc        ~to   = from -- from == to

  -- Now we move the docComment and its "after" end-of-clause marker
  -- in the element chain so that they appears after this last eoc marker.

  after                = docComment~next

  -- Pass 1: Detach the docComment and after

  docComment~prev~next = docComment~next
  docComment~next~prev = docComment~prev
  after~prev~next      = after~next
  after~next~prev      = after~prev

  -- Pass 2: Re-attach them after eoc

  left                 = eoc
  right                = eoc~next

  left~next            = docComment
  docComment~next      = after
  after~next           = right

  right~prev           = after
  after~prev           = docComment
  docComment~prev      = left

--------------------------------------------------------------------------------

::Routine ProcessBody

  Use Strict Arg package, fragment, body

  Call CheckCallTypes package, body

  -- Check all SIGNAL and SIGNAL ON instructions.

  bodyLabels    = body~labels

  checkSignal   = 0
  If .Parser.Options~hasIndex( earlyCheck ) Then
    checkSignal = .Parser.Options~earlyCheck~hasItem( signal )

  Parse Value ProcessDocCommentsOptions() With -
    StandardDocCommentAllowed MarkdownDocCommentAllowed

  Do clause Over body~clauses
    Select Case clause~class
      When .Signal.Instruction, .Signal.On.Instruction Then
        If checkSignal Then Call CheckSignal clause, bodyLabels
      Otherwise Nop
    End
  End

  Do instruction Over body~instructions
    Do aLabel Over instruction~labels
      Call ProcessLabelDocComment package, instruction, aLabel
    End
  End

  Exit

--------------------------------------------------------------------------------
-- ProcessDocCommentBefore                                                    --
--   We have a suitable label or a directive. See if immediately before we    --
--   have an acceptable doc-comment. If we find one, reformat it, change      --
--   its element category, store it in the corresponding clause,              --
--   and return the doc-comment. Otherwise, return .Nil                       --
--------------------------------------------------------------------------------

::Routine ProcessDocCommentBefore

  Use Strict Arg package, clause

  Parse Value ProcessDocCommentsOptions() With -
    StandardDocCommentAllowed MarkdownDocCommentAllowed

  -- Nothing to do
  If \StandardDocCommentAllowed, -
     \MarkdownDocCommentAllowed Then Return .Nil

  -- This is the end of the previous clause
  end = clause~begin~prev

  -- It's a label at the beginning of source
  If end == .Nil Then Return .Nil

  -- Assume it's our doc-comment, or the end of our doc-comment
  docComment = end

  -- We may allow for some whitespace after a standard doc-comment
  If docComment < .EL.WHITESPACE Then docComment = docComment~prev

  -- Standard doc-comment case
  If StandardDocCommentAllowed, docComment < .EL.STANDARD_COMMENT Then Do
    -- Not starting at column 1?
    If docComment~from~word(2) > 1 Then Do
      prev = docComment~prev
      -- It has to be whitespace ...
      If prev \< .EL.WHITESPACE  Then Return .Nil
      -- ...starting at column 1
      If prev~from~word(2) \== 1 Then Return .Nil
      -- Absorb previous whitespace
      Call AbsorbLeft docComment
    End
    -- Absorb whitespace following doc-comment
    If docComment \== end Then Call AbsorbRight docComment
    Call SetCategory docComment, .EL.DOC_COMMENT
    clause~docComment = docComment
    Return docComment
  End

  If \MarkdownDocCommentAllowed     Then Return .Nil

  If docComment \< .EL.LINE_COMMENT Then Return .Nil

  -- May be a Markdown doc-comment
  Parse Value docComment~from With line col

  -- Doc-comment has to start with "---"...
  sourceLine = package~source[line]
  If sourceLine[col,3] \== "---" Then Return .Nil
  -- ...but not with "----".
  If sourceLine[col+3]  == "-"   Then Return .Nil

  -- Absorb preceding whitespace, if any
  If col > 1 Then Do
    prev = docComment~prev
    If prev \< .EL.WHITESPACE  Then Return .Nil
    If prev~from~word(2) \== 1 Then Return .Nil
    Call AbsorbLeft docComment
  End

  Loop
    semicolon = docComment~prev
    prev      = semicolon~prev
  If prev \< .EL.LINE_COMMENT Then Leave
    Parse Value prev~from With line col
    sourceLine = package~source[line]
  If sourceLine[col,3] \== "---" Then Leave
  If sourceLine[col+3]  == "-"   Then Leave
    If col \== 1 Then Do
      whitespace = prev~prev
      If whitespace \< .EL.WHITESPACE  Then Leave
      If whitespace~from~word(2) \== 1 Then Leave
      whitespace~prev~next = docComment
      docComment~prev      = whitespace~prev
      docComment~from      = whitespace~from
    End
    Else Do
      prev~prev~next       = docComment
      docComment~prev      = prev~prev
      docComment~from      = prev~from
    End
  End

  Call SetCategory docComment, .EL.DOC_COMMENT_MARKDOWN
  clause~docComment = docComment
  Return docComment

--------------------------------------------------------------------------------
-- ProcessLabelDocComment                                                     --
--------------------------------------------------------------------------------

::Routine ProcessLabelDocComment

  Use Strict Arg package, instruction, label

  -- This is a label, and "begin" is the limiting end-of-clause.
  -- Pick the next element
  element = label~begin~next

  -- Skip whitespace (only once: continuations are not acceptable here)
  If element < .EL.WHITESPACE Then element = element~next

  -- We may now have a (small standard) comment, or a label
  If element \< .EL.TAKEN_CONSTANT    Then Exit
  If element~subCategory \== .LABEL.NAME Then Exit

  -- It's a label. See if we have a doc-comment after all
  docComment = ProcessDocCommentBefore( package, label )

  -- No. Nothing to do
  If docComment == .Nil Then Return

  -- Yes: We have to detach the old null clauses from the instruction,
  -- because they no longer make sense (in some cases, they may have
  -- been absorbed into the doc-comment, and this could produce errors
  -- later on).
  Parse Value docComment~from docComment~to With line1 col1 line2 col2
  nullClauses = instruction~nullClauses
  deleted = 0
  Do counter c nullClause Over nullClauses
    -- "begin" is the end-of-clause marker, and
    -- "begin~next" is the first real element in the
    -- null clause.
    Parse Value nullClause~begin~next~from With line col
    If line >= line1 | (line == line1 & col >= col1) Then
      If line < line2 | (line == line2 & col <= col2) Then Do
        nullClauses~delete( c - deleted)
        deleted += 1
      End
  End

--------------------------------------------------------------------------------

::Routine CheckSignal

  Use Strict Arg clause, bodyLabels

  label = clause~label
  If label == .Nil Then Do -- SIGNAL ON only
    label = clause~condition
    If label~value == "USER" Then label = clause~userCondition
  End
  If \bodyLabels~hasItem( label~value ) Then Signal 16.001

-- Label "&1" not found.
16.001: Syntax( 16.001, TheElementAfter( clause~begin ), label )

--------------------------------------------------------------------------------

-- Determine the nature of all (non namespace qualified) function
-- and procedure calls, and perform additional checks for BIFs (only
-- if the earlyCheck option is present and contains a BIFs item).

::Routine CheckCallTypes

  Use Strict Arg package, body

  If .Parser.Options~hasIndex( earlyCheck ) Then
    checkBIFs = .Parser.Options~earlyCheck~hasItem( BIFs )
  Else checkBIFs = .False

  bodyLabels = body~labels
  routines   = package~routines

  Do routine Over body~calledRoutineNames
    name = routine[1]
    label = name~value
    type  = name~invocationType
    Select
      When name < .ALL.SYMBOLS, bodyLabels~hasItem(label) Then Do
        Select Case type
          When "FUNCTION" Then subCategory = .INTERNAL.FUNCTION.NAME
          When "CALL"     Then subCategory = .INTERNAL.SUBROUTINE.NAME
        End
      End
      When .Parser.BIF[ label ] \== .Nil     Then Do
        Select Case type
          When "FUNCTION" Then subCategory = .BUILTIN.FUNCTION.NAME
          When "CALL"     Then subCategory = .BUILTIN.SUBROUTINE.NAME
        End
        If checkBIFs Then Call CheckBIFArgs name, routine[2]
      End
      When routines[ label ] \== .Nil Then Do
        Select Case type
          When "FUNCTION" Then subCategory = .PACKAGE.FUNCTION.NAME
          When "CALL"     Then subCategory = .PACKAGE.SUBROUTINE.NAME
        End
      End
      Otherwise Do
        Select Case type
          When "FUNCTION" Then subCategory = .EXTERNAL.FUNCTION.NAME
          When "CALL"     Then subCategory = .EXTERNAL.SUBROUTINE.NAME
        End
      End
    End
    Call SetConstantName name, subCategory
  End

--------------------------------------------------------------------------------

-- CheckBIFArgs

-- When writing this routine, we have uncovered a large number of ooRexx bugs.
-- Some are documented in the code below, and in the BIFs.cls package.
-- Others are collected here:
--
-- https://sourceforge.net/p/oorexx/bugs/2014/
--

::Routine CheckBIFArgs

  Use Strict Arg label, arguments

  BIFName = label~value

  -- BEEP, DIRECTORY and FILESPEC are specially handled, even if they are
  -- listed as BIFs.
  asExternal = WordPos(BIFName,"BEEP DIRECTORY FILESPEC") > 0

  BIFInfo = .Parser.BIFInfo[BIFName]

  nArgs = arguments~arg()

  -- Check if there are more args than the BIF allows
  maxArgs = BIFInfo~maxArgs
  If maxArgs \== "*", nArgs > maxArgs Then
    If asExternal Then Signal 88.922
    Else               Signal 40.004

  -- Check if there are less args than the minimun required by the BIF
  minArgs = BIFInfo~minArgs
  missing = nArgs + 1
  If nArgs < minArgs Then
    If \asExternal Then Signal 40.003
    Else                Signal 88.901

  -- Now check that all required args are present

  Select Case BIFName -- Special cases
    When "ARG" Then if nArgs > 0 Then minArgs = 1
    Otherwise Nop
  End

  checkUpTo = minArgs - 1 + (nArgs > minArgs)
  If maxArgs == "*" Then checkUpTo = nArgs
  Do argN = 1 To checkUpTo
    missing = argN
    If arguments~arg(argN,"O") Then
      If \asExternal Then Signal 40.005
      Else                Signal 88.901
  End

If .environment~Parser.check = 1 Then Trace ?a

  -- Now check statically specified arguments against their declared types
  Do argN = 1 To nArgs
    If arguments~arg(argN,"O") Then Iterate
    arg = arguments~arg(argN)
    Select Case arg~class
      When .Literal.String.Term Then value = arg~string~value
      When .Symbol.Term         Then Do
        symbol   = arg~symbol
        If symbol \< .ALL.NUMBERS Then Iterate
        value = symbol~value
      End
      When .Prefix.Expression Then Do -- Allow negative numbers
        term = arg~term
        If \term~isA( .Symbol.Term ) Then Iterate
        symbol   = term~symbol
        If symbol \< .ALL.NUMBERS Then Iterate
        prefixes = arg~prefixes -- An array of "+" and "-"
        minus = 0
        Do sign Over prefixes
          If sign == "-" Then minus = \minus
        End
        value = symbol~value
        digits = Digits()
        -- We may need many digits when the type is NUM
        Numeric Digits Length(value) + 2
        If minus Then value = -value
        Numeric Digits digits
      End
      Otherwise Iterate
    End
    If WordPos(BIFName, "MIN MAX") > 0 Then type = "NUM"
    Else If BIFName == "XRANGE" Then type = "XRANGE"
    Else type  = BIFInfo~argType[argN]
    Select Case type
      When "ANY" Then Iterate
      When "ACEFILNOR" Then Do
        letter = Left(value, 1)
        If Pos(Upper(letter), type) == 0 Then Signal 24.001
      End
      When "AENO", "ACDEIORS", "BDEFILMNOSTUW", "BDEFINOSTU", "CEFHLMNORST", "CFHLMNOST", "CN", "CDEGOS", "DELNP", "SDC" Then Do
        letter = Left(value, 1)
        If Pos(Upper(letter), type) == 0 Then Signal 40.904
        -- TODO RXQUEUE and STREAM special casess
      End
      When "ABILMNOSUVWX9", "BLT", "MN" Then Do -- See https://sourceforge.net/p/oorexx/bugs/2007/
        letter = Left(value, 1)
        If Pos(Upper(letter), type) == 0 Then Signal 93.915
      End
      When "LENGTH", "POS", "WHOLE", "WHOLE>0", "WHOLE>=0" Then Do
        -- See https://sourceforge.net/p/oorexx/bugs/2008/
        If \DataType(value,"Internal") Then Signal 40.012
        Select Case Type
          When "LENGTH"   Then If value <  0 Then
            If WordPos(BIFName, "CHARIN") > 0 Then Nop -- See https://sourceforge.net/p/oorexx/bugs/2011/
            Else                                   Signal 93.923
          When "POS"      Then If value <= 0 Then  Signal 93.924
          When "WHOLE>0"  Then Do
            If BIFName == "BEEP" Then Do
              name = "frequency"
              min = 37
              max = 32767
              If value < min | value > max Then Signal 88.907
            End
            Else If value <= 0 Then
              If WordPos(BIFName, "CHAROUT LINEOUT") > 0    Then Nop -- TODO That would be Signal 93.907, but arg numbers are shifted by two :/
              Else If WordPos(BIFName, "CHARIN LINEIN") > 0 Then Signal 93.907
              Else                                               Signal 40.014
          End
          When "WHOLE>=0" Then Do
            If BIFName == "BEEP" Then Do
              name = "duration"
              min = 0
              max = 60000
              If value < min | value > max Then Signal 88.907
            End
            Else If value <  0 Then Do
              If WordPos(BIFName, "RANDOM")                            Then Signal 40.013
              If WordPos(BIFName, "CHANGESTR COPIES FORMAT TRUNC") > 0 Then Signal 93.906 -- See https://sourceforge.net/p/oorexx/bugs/2010/
            End
          End
          When "WHOLE" Then Nop -- TODO: RANDOM
        End
      End
      When "NUM" Then Do
        If \DataType(value,"Number")   Then
          If argN > 1, WordPos(BIFName, "MAX MIN") > 0 Then Signal 93.904
          Else                                              Signal 93.943
      End
      When "XRANGE" Then Do
        If Length(value) > 1, -
          WordPos(value,"ALNUM ALPHA BLANK CNTRL DIGIT GRAPH LOWER PRINT PUNCT SPACE UPPER XDIGIT") == 0 Then
          Signal 40.028
      End
      When "0_99" Then Do
        If \DataType(value,"Internal") Then Signal 40.012
        If value < 0 | value > 99      Then Signal 40.903
      End
      Otherwise Nop
    End
  End

Return

-- TRACE request letter must be one of "ACEFILNOR"; found "&1".
24.001: Syntax( 24.001, label, letter )

-- Not enough arguments in invocation of &1; minimum expected is &2.
40.003: Syntax( 40.003, label, BIFName, minArgs )

-- Too many arguments in invocation of &1; maximum expected is &2.
40.004: Syntax( 40.004, label, BIFName, maxArgs )

-- Missing argument in invocation of &1; argument &2 is required.
40.005: Syntax( 40.005, label, BIFName, argN )

-- &1 argument &2 must be a whole number; found "&3".
40.012: Syntax( 40.012, label, BIFName, argN, value )

-- &1 argument &2 must be zero or positive; found "&3".
40.013: Syntax( 40.013, label, BIFName, argN, value )

-- &1 argument &2 must be positive; found "&3".
40.014: Syntax( 40.014, label, BIFName, argN, value )

-- &1 argument &2 must be a character class name or a single character; found "&3".
40.028: Syntax( 40.028, label, BIFName, argN, value )

-- &1 argument &2 must be in the range 0-99; found "&3".
40.903: Syntax( 40.903, label, BIFName, argN, value )

-- &1 argument &2 must be one of &3; found "&4".
40.904: Syntax( 40.904, label, BIFName, argN, type, letter )

-- Missing argument; argument &1 is required.
88.901: Syntax( 88.901, label, missing )

-- Argument &1 must be in the range &2 to &3; found "&4".
88.907: Syntax( 88.907, label, name, min, max, value )

-- Too many arguments in invocation; &1 expected.
88.922: Syntax( 88.922, label, maxArgs )

-- Method argument &1 must be a number; found "&2".
93.904: Syntax( 93.904, label, argN-1, value )

-- Method argument &1 must be zero or a positive whole number; found "&2".
93.906: Syntax( 93.906, label, argN-1, value )

-- Method argument &1 must be a positive whole number; found "&2".
93.907: Syntax( 93.907, label, argN-1, value )

-- Method option must be one of "&1"; found "&2".
93.915: Syntax( 93.915, label, type, letter )

-- Invalid length argument specified; found "&1".
93.923: Syntax( 93.923, label, value )

-- Invalid position argument specified; found "&1".
93.924: Syntax( 93.924, label, value )

-- &1 method target must be a number; found "&2".
93.943: Syntax( 93.943, label, BIFName, value )