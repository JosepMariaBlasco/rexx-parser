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
/*                                                                            */
/******************************************************************************/

  -- The purpose of this package is to load a set of global constants into
  -- the environment

  If .environment~Parser.BIFInfo.Loaded = 1 Then Return

 .environment~Parser.BIFInfo.Loaded = 1

/******************************************************************************/
/* LoadBIFInfo -- Load BIF information structures                             */
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
  BIFARGS.D2C          = "rD2C1 oWHOLE>=0"
  -- If Arg(2,"E") Then rD2C1 = "rWHOLE>=0"
  -- Else               rD2C1 = "rWHOLE"
  BIFARGS.D2X          = "rD2X1 oWHOLE>=0"
  -- If Arg(2,"E") Then rD2X1 = "rWHOLE>=0"
  -- Else               rD2X1 = "rWHOLE"
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
  BIFARGS.TRACE        = "oACEFILNOR"
  BIFARGS.TRANSLATE    = "rANY oANY oANY oPAD"
  BIFARGS.TRUNC        = "rNUM oWHOLE>=0"
  BIFARGS.VALUE        = "rANY oANY oANY" -- ANSI: IF the third arg exists, then the first is rSYM, not rANY
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
  -- Created new categories LENGTH and POS

  BIFARGS.ABBREV       = "rANY rANY oLENGTH"
  BIFARGS.ADDRESS      = ""
  BIFARGS.ARG          = "oWHOLE>0 oAENO"      -- SPECIAL
  BIFARGS.BEEP         = "rWHOLE>0 rWHOLE>=0"
  BIFARGS.C2D          = "rANY oLENGTH"
  BIFARGS.CENTER       = "rANY rLENGTH oPAD"
  BIFARGS.CENTRE       = "rANY rLENGTH oPAD"
  BIFARGS.CHANGESTR    = "rANY rANY rANY oWHOLE>=0"
  BIFARGS.CHARS        = "oSTREAM"
  BIFARGS.CHARIN       = "oSTREAM oWHOLE>0 oLENGTH"
  BIFARGS.CONDITION    = "oACDEIORS"
  BIFARGS.D2C          = "rD2C1 oLENGTH" -- Special TODO Arg1
  -- If Arg(2,"E") Then rD2C1 = "rWHOLE>=0"
  -- Else               rD2C1 = "rWHOLE"
  BIFARGS.D2X          = "rD2X1 oLENGTH" -- Special TODO Arg1
  -- If Arg(2,"E") Then rD2X1 = "rWHOLE>=0"
  -- Else               rD2X1 = "rWHOLE"
  BIFARGS.DATATYPE     = "rANY oABILMNOSUVWX9"
  -- Added "oSEP" category.
  BIFARGS.DATE         = "oBDEFILMNOSTUW oANY oBDEFINOSTU oSEP oSEP"
  BIFARGS.DELSTR       = "rANY oPOS oLENGTH"
  BIFARGS.DELWORD      = "rANY rPOS oLENGTH"
  BIFARGS.DIRECTORY    = "oANY"
  BIFARGS.ENDLOCAL     = ""                     -- Linux only
  BIFARGS.ERRORTEXT    = "r0_99"
  BIFARGS.FILESPEC     = "rDELNP rANY"
  BIFARGS.INSERT       = "rANY rANY oLENGTH oLENGTH oPAD" -- Bug: Arg(3) should be POS. See https://sourceforge.net/p/oorexx/bugs/2012/
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
  BIFARGS.RXQUEUE      = "rCDEGOS oANY"      -- TODO Special
  BIFARGS.SETLOCAL     = ""                  -- Linux only
  BIFARGS.SPACE        = "rANY oLENGTH oPAD"
  BIFARGS.STREAM       = "rSTREAM oSDC oANY" -- Order is different in ooRexx
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
  BIFARGS.X2D          = "rHEX oLENGTH"
  BIFARGS.XRANGE       = "oRANGE" -- Special

  -- TUTOR additions. Types "UNI" and "UTF8" added

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
/*
      If .environment~Parser.check = 1, -
        WordPos(type,"ANY BIN D2C1 D2X1 HEX MAX MIN NUM PAD SEP RANGE STREAM SYM WHOLE>0 WHOLE>=0 0_99") == 0 Then Do
        -- Say "--->" bifname "'"type"'"
      End
*/
    End
    BIFInfo[bifName]~minArgs = required
  End

Exit

InternalError:
  Say "Internal error in BIFs definitions:" Arg(1)"."
  Raise Halt
