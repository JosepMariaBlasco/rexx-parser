/******************************************************************************/
/*                                                                            */
/* BIFs.cls - Built-in function support                                       */
/* ====================================                                       */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>       */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20250414    0.2  First version                                             */
/* 20250421    0.2b Major rewrite, add BIF early checking.                    */
/*                                                                            */
/******************************************************************************/

  -- When writing this package, we have uncovered a large number of ooRexx
  -- bugs. Many of them are documented in the code below
  --
  -- See also https://rexx.epbcn.com/rexx-parser/doc/ref/classes/rexx.parser/early-check/#bugs

  If .environment~Parser.BIFInfo.Loaded = 1 Then Return

 .environment~Parser.BIFInfo.Loaded = 1

::Requires "BaseClassesAndRoutines.cls"

/******************************************************************************/
/* LoadBIFInfo -- Load BIF information structures                             */
/*                                                                            */
/*   The purpose of this routine is to load a set of global constants into    */
/*   the environment.                                                         */
/*                                                                            */
/******************************************************************************/

::Routine LoadBIFInfo Public

  -- ANSI Rexx does not define LOWER and UPPER

  BIFARGS.ABBREV       = "rANY rANY oWHOLE>=0"
  BIFARGS.ABS          = "rNUM"
  BIFARGS.ADDRESS      = "oEINO"
  BIFARGS.ARG          = "oWHOLE>0 oENO"
  BIFARGS.B2X          = "rBIN"
  BIFARGS.BITAND       = "rANY oANY oPAD"
  BIFARGS.BITOR        = "rANY oANY oPAD"
  BIFARGS.BITXOR       = "rANY oANY oPAD"
  BIFARGS.C2D          = "rANY oWHOLE>=0"
  BIFARGS.C2X          = "rANY"
  BIFARGS.CENTER       = "rANY rWHOLE>=0 oPAD"
  BIFARGS.CENTRE       = "rANY rWHOLE>=0 oPAD"
  BIFARGS.CHANGESTR    = "rANY rANY rANY"
  BIFARGS.CHARIN       = "oSTREAM oWHOLE>0 oWHOLE>=0"
  BIFARGS.CHAROUT      = "oSTREAM oANY oWHOLE>0"
  BIFARGS.CHARS        = "oSTREAM oCN"
  BIFARGS.COMPARE      = "rANY rANY oPAD"
  BIFARGS.CONDITION    = "oCDEIS"
  BIFARGS.COPIES       = "rANY rWHOLE>=0"
  BIFARGS.COUNTSTR     = "rANY rANY"
  BIFARGS.D2C          = "rD2 oWHOLE>=0"
  -- If Arg(2,"E") Then rD2 = "rD2WHOLE>=0"
  -- Else               rD2 = "rD2WHOLE"
  BIFARGS.D2X          = "rD2 oWHOLE>=0"
  -- If Arg(2,"E") Then rD2 = "rD2WHOLE>=0"
  -- Else               rD2 = "rD2WHOLE"
  BIFARGS.DATATYPE     = "rANY oABLMNSUWX"
  BIFARGS.DATE         = "oBDEMNOSUW oANY oBDENOSU"
  BIFARGS.DELSTR       = "rANY rWHOLE>0 oWHOLE>=0"
  BIFARGS.DELWORD      = "rANY rWHOLE>0 oWHOLE>=0"
  BIFARGS.DIGITS       = ""
  BIFARGS.ERRORTEXT    = "r0_90 oSN"
  BIFARGS.FORM         = ""
  BIFARGS.FORMAT       = "rNUM oWHOLE>=0 oWHOLE>=0 oWHOLE>=0 oWHOLE>=0"
  BIFARGS.FUZZ         = ""
  BIFARGS.INSERT       = "rANY rANY oWHOLE>=0 oWHOLE>=0 oPAD"
  BIFARGS.LASTPOS      = "rANY rANY oWHOLE>0"
  BIFARGS.LEFT         = "rANY rWHOLE>=0 oPAD"
  BIFARGS.LENGTH       = "rANY"
  BIFARGS.LINEIN       = "oSTREAM oWHOLE>0 oWHOLE>=0"
  BIFARGS.LINEOUT      = "oSTREAM oANY oWHOLE>0"
  BIFARGS.LINES        = "oSTREAM oCN"
  BIFARGS.MAX          = "rMAX" -- Strip(Copies("rNUM ",Arg())), Arg() > 0
  BIFARGS.MIN          = "rMIN" -- Strip(Copies("rNUM ",Arg())), Arg() > 0
  BIFARGS.OVERLAY      = "rANY rANY oWHOLE>0 oWHOLE>=0 oPAD"
  BIFARGS.POS          = "rANY rANY oWHOLE>0"
  BIFARGS.QUALIFY      = "oSTREAM"
  BIFARGS.QUEUED       = ""
  BIFARGS.RANDOM       = "oWHOLE>=0 oWHOLE>=0 oWHOLE>=0"
  BIFARGS.REVERSE      = "rANY"
  BIFARGS.RIGHT        = "rANY rWHOLE>=0 oPAD"
  BIFARGS.SIGN         = "rNUM"
  BIFARGS.SOURCELINE   = "oWHOLE>0"
  BIFARGS.SPACE        = "rANY oWHOLE>=0 oPAD"
  BIFARGS.STREAM       = "rSTREAM oCDS oANY" -- Special
  -- Third argument is only correct with 'C'
  --   If Arg(2,"E"), Translate(Left(Arg(2)),1) == "C" Then "rSTREAM rCDS rANY"
  --                                                   Else "rSTREAM oCDS"
  BIFARGS.STRIP        = "rANY oBLT oPAD"
  BIFARGS.SUBSTR       = "rANY rWHOLE>0 oWHOLE>=0 oPAD"
  BIFARGS.SUBWORD      = "rANY rWHOLE>0 oWHOLE>=0"
  BIFARGS.SYMBOL       = "rANY" -- Special. See ANSI 9.8.4
  BIFARGS.TIME         = "oCEHLMNORS oANY oCHLMNS"
  BIFARGS.TRACE        = "oACEFILNOR"     -- Should first check for "?" prefixes
  BIFARGS.TRANSLATE    = "rANY oANY oANY oPAD"
  BIFARGS.TRUNC        = "rNUM oWHOLE>=0"
  -- VALUE: IF the third arg exists, then the first is rSYM, not rANY
  BIFARGS.VALUE        = "rANY oANY oANY"
  BIFARGS.VERIFY       = "rANY rANY oMN oWHOLE>0"
  BIFARGS.WORD         = "rANY rWHOLE>0"
  BIFARGS.WORDINDEX    = "rANY rWHOLE>0"
  BIFARGS.WORDLENGTH   = "rANY rWHOLE>0"
  BIFARGS.WORDPOS      = "rANY rANY oWHOLE>0"
  BIFARGS.WORDS        = "rANY"
  BIFARGS.X2B          = "rHEX"
  BIFARGS.X2C          = "rHEX"
  BIFARGS.X2D          = "rHEX oWHOLE>=0"
  BIFARGS.XRANGE       = "oPAD oPAD"

  -- ooRexx additions and ooRexx-specific functions
  --
  -- NOTE: BEEP, DIRECTORY and FILESPEC are defined as BIFs in rexxref,
  -- but they are treated by the ooRexx interpreter as if they were
  -- part of RexxUtil.
  --
  -- See https://sourceforge.net/p/oorexx/bugs/1885/ for details.
  --
  -- We add them here as BIFs as per rexxref
  --
  -- See also https://sourceforge.net/p/oorexx/bugs/2006/ and
  -- https://sourceforge.net/p/oorexx/documentation/341/
  --
  -- BIFs marked SPECIAL are handled in SecondPass.cls
  --
  -- Created new categories LENGTH, POS, SEP
  -- TODO Check SEP HEX

  BIFARGS.ABBREV       = "rANY rANY oLENGTH"
  BIFARGS.ADDRESS      = ""
  BIFARGS.ARG          = "oWHOLE>0 oAENO"    -- Special
  BIFARGS.BEEP         = "rWHOLE>0 rWHOLE>=0"
  BIFARGS.C2D          = "rANY oLENGTH"
  BIFARGS.CENTER       = "rANY rLENGTH oPAD"
  BIFARGS.CENTRE       = "rANY rLENGTH oPAD"
  BIFARGS.CHANGESTR    = "rANY rANY rANY oWHOLE>=0"
  BIFARGS.CHARS        = "oSTREAM"
  BIFARGS.CHARIN       = "oSTREAM oWHOLE>0 oLENGTH"
  BIFARGS.CONDITION    = "oACDEIORS"
  BIFARGS.D2C          = "rD2 oLENGTH"       -- Special
  -- If Arg(2,"E") Then rD2 = "rD2WHOLE>=0"
  -- Else               rD2 = "rD2WHOLE"
  BIFARGS.D2X          = "rD2 oLENGTH"       -- Special
  -- If Arg(2,"E") Then rD2 = "rD2WHOLE>=0"
  -- Else               rD2 = "rD2WHOLE"
  BIFARGS.DATATYPE     = "rANY oABILMNOSUVWX9"
  BIFARGS.DATE         = "oBDEFILMNOSTUW oANY oBDEFINOSTU oSEP oSEP"
  BIFARGS.DELSTR       = "rANY oPOS oLENGTH"
  BIFARGS.DELWORD      = "rANY rPOS oLENGTH"
  BIFARGS.DIRECTORY    = "oANY"
  BIFARGS.ENDLOCAL     = ""                  -- Linux only
  BIFARGS.ERRORTEXT    = "r0_99"
  BIFARGS.FILESPEC     = "rDELNP rANY"
  -- INSERT Bug: Arg(3) should be POS. See ooRexx bug n. 2012
  BIFARGS.INSERT       = "rANY rANY oLENGTH oLENGTH oPAD"
  BIFARGS.LASTPOS      = "rANY rANY oPOS oLENGTH"
  BIFARGS.LEFT         = "rANY rLENGTH oPAD"
  BIFARGS.LOWER        = "rANY oPOS oLENGTH"
  BIFARGS.OVERLAY      = "rANY rANY oPOS oLENGTH oPAD"
  BIFARGS.POS          = "rANY rANY oPOS oLENGTH"
  BIFARGS.RANDOM       = "oWHOLE oWHOLE oWHOLE>=0"
  BIFARGS.RIGHT        = "rANY rLENGTH oPAD"
  BIFARGS.RXFUNCADD    = "rANY rANY oANY"
  BIFARGS.RXFUNCDROP   = "rANY"
  BIFARGS.RXFUNCQUERY  = "rANY"
  BIFARGS.RXQUEUE      = "rCDEGOS oANY"      -- Special TODO
  BIFARGS.SETLOCAL     = ""                  -- Linux only
  BIFARGS.SPACE        = "rANY oLENGTH oPAD"
  -- STREAM: Order of Arg(2) is different in ooRexx
  BIFARGS.STREAM       = "rSTREAM oSDC oANY"
  BIFARGS.SUBSTR       = "rANY rPOS oLENGTH oPAD"
  BIFARGS.SUBWORD      = "rANY rPOS oLENGTH"
  BIFARGS.QUALIFY      = "rSTREAM"
  BIFARGS.TIME         = "oCEFHLMNORST oANY oCFHLMNOST"
  BIFARGS.TRANSLATE    = "rANY oANY oANY oPAD oPOS oLENGTH"
  BIFARGS.UPPER        = "rANY oPOS oLENGTH"
  BIFARGS.USERID       = ""
  BIFARGS.VAR          = "rSYM"
  BIFARGS.VERIFY       = "rANY rANY oMN oPOS oLENGTH"
  BIFARGS.WORD         = "rANY rPOS"
  BIFARGS.WORDINDEX    = "rANY rPOS"
  BIFARGS.WORDLENGTH   = "rANY rPOS"
  BIFARGS.WORDPOS      = "rANY rANY oPOS"
  BIFARGS.X2D          = "rHEX oLENGTH"      -- TODO
  BIFARGS.XRANGE       = "oRANGE"            -- Special

  -- TUTOR additions. Types "UNI" and "UTF8" added

  -- [Only checked for required an optional args at the moment]
  If .Parser.Options~Unicode == 1 Then Do

    BIFARGS.BYTES      = "rANY"
    BIFARGS.C2U        = "rANY oANY" -- Arg(2): one of CODES, UTF32, U+ or NAmes
    BIFARGS.CODEPOINTS = "rUTF8"
    BIFARGS.DECODE     = "rANY rANY oANY oANY"
    BIFARGS.ENCODE     = "rANY rANY oANY"
    BIFARGS.GRAPHEMES  = "rUTF8"
    BIFARGS.N2P        = "rANY"
    BIFARGS.P2N        = "rANY"
    BIFARGS.STRINGTYPE = "rUTF8"
    BIFARGS.TEXT       = "rUTF8"
    BIFARGS.U2C        = "rUNI"
    BIFARGS.UNICODE    = "rANY rANY oANY" -- See the docs
    BIFARGS.UTF8       = "rANY oANY oANY oANY"

  End

  -- We now construct .Parser.BIF, a set with all the BIF names, and
  -- .Parser.BIFInfo, a directory indexes by these BIF names.
  -- Every indexed item is also a directory, containing three entries:
  --   minArgs: The minimum number of args
  --   maxArgs: The maximum number of args
  --   argType: An array with maxArgs elements defining the respective
  --     argument types.

  BIF = .Set~new
 .environment~Parser.BIF     = BIF
  BIFInfo = .Directory~new
 .environment~Parser.BIFInfo = BIFInfo
  Do bifName Over BIFARGS.~allIndexes~sort
    BIF[] = bifName
    BIFInfo[bifName] = .Directory~new
    args  = BIFARGS.bifName
    maxArgs = Words(args)
    If args == "(special)" Then Iterate
    If WordPos(bifName, "MAX MIN XRANGE") > 0 Then maxArgs = "*"
    BIFInfo[bifName]~maxArgs = maxArgs
    BIFInfo[bifName]~argType = .Array~new
    required      = 0
    foundOptional = 0
    Do word Over args~makeArray(" ")
      Parse var word required? +1 type
      Select Case required?
        When "r" Then Do
          If foundOptional Then Call InternalError "required argument after optional argument in definition of" bifName
          required += 1
        End
        When "o" Then foundOptional = 1
        Otherwise Call InternalError "'r' or 'o' expected, found '"required?"' in '"word"'"
      End
      BIFInfo[bifName]~argType~append(type)
    End
    BIFInfo[bifName]~minArgs = required
  End

Exit

InternalError:
  Say "Internal error in BIFs definitions:" Arg(1)"."
  Raise Halt

/******************************************************************************/
/* CheckBIFArgs -- Check BIF signatures and constant terms                    */
/******************************************************************************/

::Routine CheckBIFArgs Public

  Use Strict Arg label, arguments

If .rxcheck.debug = 1 Then Trace ?a

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

  -- Check if there are less args than the minimum required by the BIF
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
  If maxArgs == "*", BIFName \== "XRANGE" Then checkUpTo = nArgs
  Do argN = 1 To checkUpTo
    missing = argN
    If arguments~arg(argN,"O") Then
      If WordPos(BIFName,"MAX MIN") > 0 Then
        If argN == 1      Then Signal 40.005
        Else                   Signal 93.903
      Else If \asExternal Then Signal 40.005
      Else                     Signal 88.901
  End

  -- Now check statically specified arguments against their declared types
  Do argN = 1 To nArgs
    If arguments~arg(argN,"O") Then Iterate
    arg = arguments~arg(argN)
    Select Case arg~class
      When .Literal.String.Term Then value = arg~theString~value
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

    -- Special cases
    Select Case BIFName
      When "MIN", "MAX" Then type = "NUM"
      When "D2C", "D2X" Then Do
        If argN == 1 Then
          If nArgs == 2 Then type = "D2WHOLE"
          Else               type = "D2WHOLE>=0"
        Else type  = BIFInfo~argType[argN]
      End
      When "XRANGE" Then type = "XRANGE"
      Otherwise type  = BIFInfo~argType[argN]
    End

    Select Case type
      When "ANY" Then Iterate
      When "ACEFILNOR" Then Do
        newValue = Strip(value,"L","?")
        If Length(newValue) > 0 Then Do
          letter = Left(newValue, 1)
          If Pos(Upper(letter), type) == 0 Then Signal 24.001
        End
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
      When "WHOLE", "D2WHOLE", "D2WHOLE>=0" Then Do
        If \DataType(value,"Number") | Pos("E", value) > 0 | Pos(" ", value) > 0 | Pos(".", value) > 0 Then
          Select Case BIFName
            When "RANDOM" Then           Signal 40.012
            When "D2X"    Then           Signal 93.928
            When "D2C"    Then           Signal 93.929
          End
        -- For D2C and D2X, value is a number. See if it is also an integer
        -- We do not accept literal strings, exponents or decimals
        If BIFName \== "RANDOM", nArgs == 1, Left(value,1) = "-" Then Signal 93.927
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
              If BIFName == "RANDOM"                                   Then Signal 40.013
              If WordPos(BIFName, "CHANGESTR COPIES FORMAT TRUNC") > 0 Then Signal 93.906 -- See https://sourceforge.net/p/oorexx/bugs/2010/
            End
            Else If BIFName == "RANDOM", value > 999999999             Then Signal 40.013
          End
        End
      End
      When "NUM" Then Do
        If \DataType(value,"Number")   Then
          If argN > 1, WordPos(BIFName, "MAX MIN") > 0 Then Signal 93.904
          Else                                              Signal 93.943
      End
      When "XRANGE" Then Do
        If Length(value) > 1, -
          WordPos(Upper(value),"ALNUM ALPHA BLANK CNTRL DIGIT GRAPH LOWER PRINT PUNCT SPACE UPPER XDIGIT") == 0 Then
          Signal 40.028
      End
      When "BIN" Then Do
        If \DataType(value,"Binary") Then Do
          -- Only 0,1 and whitespace
          pos = Verify(value,"09"X"01 ")
          If pos > 0 Then do
            char = value[pos]
            Signal 93.934
          End
          -- Groups of four
          pos = 1
          If Pos(value[pos],"01") == 0 Then Signal 93.932
          pos = Length(value)
          If Pos(value[pos],"01") == 0 Then Signal 93.932
          Do i = Words(value) To 2 By -1
            If Length(Word(value,i)) // 4 \== 0 Then  Signal 93.977
          End
        End
      End
      When "HEX" Then Do
        If \DataType(value,"X") Then Do -- Find out why
          -- Only 0-9, A-F1 and whitespace
          pos = Verify(value,"09"X" "XRange("AlNum") )
          If pos > 0 Then do
            char = value[pos]
            Signal 93.933
          End
          -- No whitespace at the extremes
          pos = 1
          If Pos(value[pos],"2009"X) > 0 Then Signal 93.931
          pos = Length(value)
          If Pos(value[pos],"2009"X) > 0 Then Signal 93.931
          -- Groups of two
          Do i = Words(value) To 2 By -1
            If Length(Word(value,i)) // 2 \== 0 Then  Signal 93.976
          End
        End
      End
      When "SEP" Then Do
        If Length(value) > 1 Then Signal 40.043
      End
      When "PAD" Then Do
        If Length(value) \== 1 Then Signal 40.023
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

-- &1 argument &2 must be a single character; found "&3".
40.023: Syntax( 40.023, label, BIFName, argN, value )

-- &1 argument &2 must be a character class name or a single character; found "&3".
40.028: Syntax( 40.028, label, BIFName, argN, value )

-- &1 argument &2 must be a single non-alphanumeric character or the null string; found "&3".
40.043: Syntax( 40.043, label, BIFName, argN, value )

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

-- Missing argument in method; argument &1 is required.
93.903: Syntax( 93.903, label, argN-2 )

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

-- Length must be specified to convert a negative value.
93.927: Syntax( 93.927, label  )

-- D2X value must be a valid whole number; found "&1".
93.928: Syntax( 93.928, label, value  )

-- D2C value must be a valid whole number; found "&1".
93.929: Syntax( 93.929, label, value  )

-- Incorrect location of whitespace character in position &1 in hexadecimal string.
93.931: Syntax( 93.931, label, pos  )

-- Incorrect location of whitespace character in position &1 in binary string.
93.932: Syntax( 93.932, label, pos  )

-- Only 0-9, a-f, A-F, and whitespace characters are valid in a hexadecimal string; character found "&1".
93.933: Syntax( 93.933, label, char  )

-- Only 0, 1, and whitespace characters are valid in a binary string; character found "&1".
93.934: Syntax( 93.934, label, char  )

-- &1 method target must be a number; found "&2".
93.943: Syntax( 93.943, label, BIFName, value )

-- Hexadecimal strings must be grouped in units that are multiples of two characters.
93.976: Syntax( 93.976, label )

-- Binary strings must be grouped in units that are multiples of four characters.
93.977: Syntax( 93.977, label )
