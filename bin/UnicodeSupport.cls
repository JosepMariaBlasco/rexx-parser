/******************************************************************************/
/*                                                                            */
/* UnicodeSupport.cls - Optional Unicode support for the Rexx Parser          */
/* =================================================================          */
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
/* 20250103    0.1f First public release                                      */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/*                  Move "resources" dir under "bin"                          */
/*                                                                            */
/******************************************************************************/

package     = .context~package
local       =  package~local
myName      =  package~name
myPath      =  FileSpec( "Location", myName )

-- We will ensure that these two files exist, but we will not load them
-- until they are really needed, because loading them is expensive.
UnicodeData =  myPath"../bin/resources/UnicodeData-15.0.0.txt"
NameAliases =  myPath"../bin/resources/NameAliases-15.0.0.txt"

UnicodeData =  Stream(UnicodeData, "c", "query exists")
NameAliases =  Stream(NameAliases, "c", "query exists")

If UnicodeData == "" Then Do
  Say "File UnicodeData-15.0.0.txt not found in the 'bin/resources' subdirectory."
  Raise Halt
End

If NameAliases == "" Then Do
  Say "File NameAliases-15.0.0.txt not found in 'bin/resources' subdirectory."
  Raise Halt
End

-- Remember the names of out two files...
local~UnicodeData        = UnicodeData
local~NameAliases        = NameAliases

-- ...and the fact that we haven't loaded their string yet
local~UnicodeData.Loaded = 0

/******************************************************************************/
/* Name2Code(name)                                                            */
/*   Returns "" if the name is not found, else the corresponding              */
/*   Unicode codepoint                                                        */
/******************************************************************************/

::Routine Name2Code

  Call LoadNames

  NOT_FOUND = ""

  Use Strict Arg name
  nameIsALabel = 0

  -- Preprocess labels
  If name[1] == "<" Then Do
    -- A malformed label
    If name[Length(name)] \== ">" Then Return NOT_FOUND
    nameIsALabel = 1
    -- Strip name of the enclosing "<" and ">" characters first
    Parse Var name "<"name">"
  End

  -- Handle non-medial dashes
  name = ChangeStr("- ",name,">")
  name = ChangeStr(" -",name,"<")
  name = Upper(ChangeStr("_",Space(name,0),""))
  If name \== "HANGULJUNGSEONGO-E" Then name = ChangeStr("-", name,"")
  name = ChangeStr(">",name,"- ")
  name = ChangeStr("<",name," -")

  -- Restore "<" and ">" for labels
  If nameIsALabel Then name = "<"name">"

  -- Do we have a code? Return it
  code = .Name2Code[name]
  If code \== "" Then Return code

  -- Nope. Try an algorithmic code then

  -- Special case
  If name == "HANGULJUNGSEONGO-E" Then Return "1180"

  -- This is a label, not a name
  -- TODO Check for a dash after the label name
  If name[1] == "<" Then Do
    Parse Var name "<"element">"extra
    If extra \== "" Then Return NOT_FOUND
    labels = "CONTROL PRIVATEUSE RESERVED SURROGATE NONCHARACTER"
    Do word Over labels~makeArray(" ")
      If element~startsWith(word) Then Do
        code = SubStr(element,length(word)+1)
        Return CheckValid()  -- (code, word)
      End
    End
    Return NOT_FOUND
  End

  families = "CJKCOMPATIBILITYIDEOGRAPH"  -
             "CJKUNIFIEDIDEOGRAPH"        -
             "KHITANSMALLSCRIPTCHARACTER" -
             "NUSHUCHARACTER"             -
             "TANGUTIDEOGRAPH"
  -- TODO Check for a dash after the label name
  Do word Over families~makeArray(" ")
    If name~startsWith(word) Then Do
      code = SubStr(name,length(word)+1)
      Return CheckValid() -- (code, word)
    End
  End

  start = "TANGUTCOMPONENT"
  If name~startsWith(start) Then Do
    number = SubStr(name,Length(start)+1)
    If \DataType(number, "W") Then Return NOT_FOUND
    If Length(number) \== 3   Then Return NOT_FOUND
    If number < 1             Then Return NOT_FOUND
    If number > 768           Then Return NOT_FOUND
    Return d2x(number + 6272 - 1)
  End

  start = "HANGULSYLLABE"
  If \name~startsWith(start) Then Return NOT_FOUND
  syllabeName = SubStr(name,Length(start)+1)

  Return Hangul_Syllabe_Code(syllabeName)

CheckValid:
  -- Check that "code" is valid
  If \DataType(code,"X")              Then Return NOT_FOUND
  If Length(code) < 4                 Then Return NOT_FOUND
  If Length(code) > 6                 Then Return NOT_FOUND
  If Length(code) > 4, code[1] == "0" Then Return NOT_FOUND
  temp = X2D(code)
  If temp > 1114111                   Then Return NOT_FOUND
  -- Check that code in range
  Select Case word
    When "CJKCOMPATIBILITYIDEOGRAPH"   Then
      /*If WordPos(Upper(code), -
        "FA0E FA0F FA11 FA13 FA14 FA1F FA21 FA23 FA24 FA27 FA28 FA29") > 0
                                  Then Return ""
      Else */
      If      temp <  X2D(  F900) Then Return NOT_FOUND
      Else If temp <= X2D(  FAD9) Then Return code
      Else If temp <  X2D( 2F800) Then Return NOT_FOUND
      Else If temp >  X2D( 2FA1D) Then Return NOT_FOUND
    When "CJKUNIFIEDIDEOGRAPH"         Then
      /*
      If WordPos(Upper(code), -
      "FA0E FA0F FA11 FA13 FA14 FA1F FA21 FA23 FA24 FA27 FA28 FA29") > 0
                                  Then Return code
      Else */
      If      temp <  X2D(  3400) Then Return NOT_FOUND
      Else If temp <= X2D(  4DBF) Then Return code
      Else If temp <  X2D(  4E00) Then Return NOT_FOUND
      Else If temp <= X2D(  9FFF) Then Return code
      Else If temp <  X2D( 20000) Then Return NOT_FOUND
      Else If temp <= X2D( 2A6DF) Then Return code
      Else If temp <  X2D( 2A700) Then Return NOT_FOUND
      Else If temp <= X2D( 2B739) Then Return code
      Else If temp <  X2D( 2B740) Then Return NOT_FOUND
      Else If temp <= X2D( 2B81D) Then Return code
      Else If temp <  X2D( 2B820) Then Return NOT_FOUND
      Else If temp <= X2D( 2CEA1) Then Return code
      Else If temp <  X2D( 2CEB0) Then Return NOT_FOUND
      Else If temp <= X2D( 2EBE0) Then Return code
      Else If temp <  X2D( 2F800) Then Return NOT_FOUND
      Else If temp <= X2D( 2FA1D) Then Return code
      Else If temp <  X2D( 30000) Then Return NOT_FOUND
      Else If temp <= X2D( 3134A) Then Return code
      Else If temp <  X2D( 31350) Then Return NOT_FOUND
      Else If temp <= X2D( 323AF) Then Return code
      Else                             Return NOT_FOUND
    When "KHITANSMALLSCRIPTCHARACTER"  Then
      If      temp <  X2D( 18B00) Then Return NOT_FOUND
      Else If temp >  X2D( 18CD5) Then Return NOT_FOUND
    When "NUSHUCHARACTER"              Then
      If      temp <  X2D( 1B170) Then Return NOT_FOUND
      Else If temp >  X2D( 1B2FB) Then Return NOT_FOUND
    When "TANGUTIDEOGRAPH"             Then
      If      temp <  X2D( 17000) Then Return NOT_FOUND
      Else If temp <= X2D( 187F7) Then Return code
      Else If temp <  X2D( 18D00) Then Return NOT_FOUND
      Else If temp <= X2D( 18D08) Then Return code
      Else                             Return NOT_FOUND
    When "CONTROL"                     Then
      If      temp <  X2D(  0000) Then Return NOT_FOUND
      Else If temp <= X2D(  001F) Then Return code
      Else If temp <  X2D(  007F) Then Return NOT_FOUND
      Else If temp <= X2D(  009F) Then Return code
      Else                             Return NOT_FOUND
    When "PRIVATEUSE"                  Then
      If      temp <  X2D(  E000) Then Return NOT_FOUND
      Else If temp <= X2D(  F8FF) Then Return code
      Else If temp <  X2D( F0000) Then Return NOT_FOUND
      Else If temp <= X2D( FFFFD) Then Return code
      Else If temp <  X2D(100000) Then Return NOT_FOUND
      Else If temp <= X2D(10FFFD) Then Return code
      Else                             Return NOT_FOUND
    When "RESERVED"                    Then Do
      -- The list of reserved characters is very large
      code = Upper(code)
      If \IsReserved(code)        Then Return NOT_FOUND
      -- Noncharacters are not reserved
      If      temp <  X2D(  FDD0) Then Return code
      Else If temp <= X2D(  FDEF) Then Return NOT_FOUND
      Else Do
        temp = temp // 2**16
        If      temp == X2D(FFFE) Then Return NOT_FOUND
        Else If temp == X2D(FFFF) Then Return NOT_FOUND
        Else                           Return code
      End
    End
    When "SURROGATE"              Then
      If      temp <  X2D(  D800) Then Return NOT_FOUND
      Else If temp >  X2D(  DFFF) Then Return NOT_FOUND
    When "NONCHARACTER"           Then
      If      temp <  X2D(  FDD0) Then Return NOT_FOUND
      Else If temp <= X2D(  FDEF) Then Return code
      Else Do
        temp = temp // 2**16
        If      temp == X2D(FFFE) Then Return code
        Else If temp == X2D(FFFF) Then Return code
        Else                           Return NOT_FOUND
      End
    Otherwise                          Return code
  End
Return code

Hangul_Syllabe_Code:
  -- See http://gernot-katzers-spice-pages.com/var/korean_hangul_unicode.html
  Use Strict Arg syllabe
  s1 = syllabe[1]
  s2 = syllabe[1,2]
  leadW = 2
  Select Case s2
    When "GG" Then lead =  2
    When "DD" Then lead =  5
    When "BB" Then lead =  9
    When "SS" Then lead = 11
    When "JJ" Then lead = 14
    Otherwise
      leadW = 1
      Select Case s1
        When "G" Then lead =  1
        When "N" Then lead =  3
        When "D" Then lead =  4
        When "R" Then lead =  6
        When "M" Then lead =  7
        When "B" Then lead =  8
        When "S" Then lead =  10
        When "J" Then lead =  13
        When "C" Then lead =  15
        When "K" Then lead =  16
        When "T" Then lead =  17
        When "P" Then lead =  18
        When "H" Then lead =  19
        Otherwise
          lead  = 12
          leadW = 0
      End
  End
  s1 = syllabe[1+leadW]
  s2 = syllabe[1+leadW,2]
  s3 = syllabe[1+leadW,3]
  vowelW = 3
  Select Case s3
    When "YAE" Then vowel = 4
    When "YEO" Then vowel = 7
    When "WAE" Then vowel = 11
    When "WEO" Then vowel = 15
    Otherwise
      vowelW = 2
      Select Case s2
        When "AE" Then vowel =  2
        When "YA" Then vowel =  3
        When "EO" Then vowel =  5
        When "YE" Then vowel =  8
        When "WA" Then vowel = 10
        When "OE" Then vowel = 12
        When "YO" Then vowel = 13
        When "WE" Then vowel = 16
        When "WI" Then vowel = 17
        When "YU" Then vowel = 18
        When "EU" Then vowel = 19
        When "YI" Then vowel = 20
        Otherwise
          vowelW = 1
          Select Case s1
            When "A" Then vowel = 1
            When "E" Then vowel = 6
            When "O" Then vowel = 9
            When "U" Then vowel = 14
            When "I" Then vowel = 21
            Otherwise Return ""
          End
      End
  End
  rest = SubStr(syllabe,1+leadW+vowelW)
  Select Case rest
    When ""   Then tail =  0
    When "G"  Then tail =  1
    When "GG" Then tail =  2
    When "GS" Then tail =  3
    When "N"  Then tail =  4
    When "NJ" Then tail =  5
    When "NH" Then tail =  6
    When "D"  Then tail =  7
    When "L"  Then tail =  8
    When "LG" Then tail =  9
    When "LM" Then tail = 10
    When "LB" Then tail = 11
    When "LS" Then tail = 12
    When "LT" Then tail = 13
    When "LP" Then tail = 14
    When "LH" Then tail = 15
    When "M"  Then tail = 16
    When "B"  Then tail = 17
    When "BS" Then tail = 18
    When "S"  Then tail = 19
    When "SS" Then tail = 20
    When "NG" Then tail = 21
    When "J"  Then tail = 22
    When "C"  Then tail = 23
    When "K"  Then tail = 24
    When "T"  Then tail = 25
    When "P"  Then tail = 26
    When "H"  Then tail = 27
    Otherwise Return ""
  End
Return d2x( tail + (vowel-1)*28 + (lead-1)*588 + 44032 )

IsReserved: Procedure
  Use Strict Arg code

  n = code~x2d

  -- Fast path: Planes 0 & 1
  If n <= 131071 Then Return 0

  Select Case Length(code)
    When 5 Then Do
      Select Case code[1]
        When "2" Then Do
          If              n <= 173791 Then Return 0 -- 20000 2A6DF
          If n >= 173824, n <= 177977 Then Return 0 -- 2A700 2B739
          If n >= 177984, n <= 178205 Then Return 0 -- 2B740 2B81D
          If n >= 178208, n <= 183969 Then Return 0 -- 2B820 2CEA1
          If n >= 183984, n <= 191456 Then Return 0 -- 2CEB0 2EBE0
          If n >= 194560, n <= 195101 Then Return 0 -- 2F800 2FA1D
        End
        When "3" Then Do
          If              n <= 201546 Then Return 0 -- 30000..3134A
          If n >= 201552, n <= 205743 Then Return 0 -- 31350..323AF
        End
        When "E" Then Do
          If n == 917505              Then Return 0 -- E0001
          If n >= 917536, n <= 917631 Then Return 0 -- E0020..E007F
          If n >= 917760, n <= 917999 Then Return 0 -- E0100..E01EF
        End
        When "F" Then
          If n <= 1048573             Then Return 0 -- FFFFD
        Otherwise Return 1
      End
    End
    When 6 Then
          If n <= 1114109             Then Return 0 -- 10FFFD
    Otherwise     Return 1
  End
  Return 1

/******************************************************************************/
/* LoadNames                                                                  */
/*   Read UnicodeData.txt and NameAliases.txt and build a stem storing all    */
/*   the compressed names and their corresponding codes.                      */
/******************************************************************************/

-------------------------------------------------------------------------------
--
-- See The Unicode® Standard. Version 15.0 – Core Specification, p. 181
-- https://www.unicode.org/versions/Unicode15.0.0/UnicodeStandard-15.0.pdf
--
-- "Character Name Matching. When matching identifiers transposed from
-- character names, it is possible to ignore case, whitespace, and all
-- medial hyphen-minus characters (or any “_” replacing a hyphen-minus),
-- except for the hyphen-minus in U+1180 HANGUL JUNGSEONG O-E, and still
-- result in a unique match. For example, “ZERO WIDTH SPACE” is equivalent
-- to “zero-width-space” or “ZERO_WIDTH_SPACE” or “ZeroWidthSpace”. However,
-- “TIBETAN LETTER A” should not match “TIBETAN LETTER -A”, because in that
-- instance the hyphen-minus is not medial between two letters, but is
-- instead preceded by a space. For more information on character name
-- matching, see Section 5.9, “Matching Rules” in Unicode Standard Annex #44,
-- “Unicode Character Database.”
-------------------------------------------------------------------------------

::Routine LoadNames

  -- Run once and cache results in .context~package~local
  If .UnicodeData.Loaded Then Return

  -- (Compressed) names to Unicode codepoints
  name2Code. = ""

  -- We know that these two files exist because we checked it in the prolog
  UnicodeData = CharIn(.UnicodeData, 1, Chars(.UnicodeData))~makeArray
  Call Stream .UnicodeData, "c", "close"
  NameAliases = CharIn(.NameAliases, 1, Chars(.NameAliases))~makeArray
  Call Stream .NameAliases, "c", "close"

  skipNextLine = 0

  Do line Over UnicodeData
    If skipNextLine Then Do
      skipNextLine = 0
      Iterate
    End
    Parse Var line code";"name ";" ";"ccc";"
    If name[1] == "<" Then Iterate
    If name~endsWith("First>") Then Do
      skipNextLine = 1
      Iterate
    End
    -- Skip computed codes
    If name~startsWith("NUSHU CHARACTER-")               Then Iterate
    If name~startsWith("TANGUT IDEOGRAPH-")              Then Iterate
    If name~startsWith("KHITAN SMALL SCRIPT CHARACTER-") Then Iterate
    If name~startsWith("CJK COMPATIBILITY IDEOGRAPH-")   Then Iterate
    If name~startsWith("CJK UNIFIED IDEOGRAPH-")         Then Iterate

    -- An exceptional name
    If name = "HANGUL JUNGSEONG O-E" Then key = "HANGULJUNGSEONGO-E"
    -- The standard case
    Else key = Compress(name)

    -- Store in our stem
    name2Code.key = code
  End

  -- Now parse NameAliases.txt

  Do line Over NameAliases
    If line[1] == "#" Then Iterate
    If line     = ""  Then Iterate
    Parse Var line code";"name";"
    key = Compress(name)
    name2Code.key = code
  End

  local = .context~package~local
  local~UnicodeData.Loaded = 1
  local~name2Code = name2Code.

Return

--------------------------------------------------------------------------------

Compress:
  key = ChangeStr("- ",Arg(1),">") -- Preserve non-medial dash-blank sequences
  key = ChangeStr(" -",key, "<")   -- Preserve non-medial blank-dash sequences
  key = ChangeStr("-" ,key, "")    -- Delete all dashed (will all be medial)
  key = Space(key,0)               -- Delete all blanks too
  key = ChangeStr(">",key,"- ")    -- Restore non-medial dash-blank sequences..
  key = ChangeStr("<",key," -")    -- ..and non-medial blank-slash sequences too
Return key

/******************************************************************************/
/* Well.Formed.UString(string)                                                */
/*   Returns an array containing two items. The first item is the null string */
/*   when string contains a well-formed U string, and then the second item    */
/*   is the interpreted (i.e., translated) string value. If the U string is   */
/*   not well-formed, then the first item in the array is a custom error      */
/*   message (for syntax error 22.900), and the second item can be discarded. */
/******************************************************************************/

::Routine Well.Formed.UString Public

  Use Strict Arg string
  res = ""
  Do While string \= " "
    string = Strip(string)
    If string[1] == "(" Then Do
      Parse var string "("name")"extra
      If extra == "" Then If \string~endsWith(")") Then Exit BadName("("name)
      If \.UnicodeData.Loaded Then Call LoadNames
      string = Strip(extra)
      code = Name2Code(name)
      If code = "" Then Exit BadName(name)
      res ||= IUTF8(code)
      Iterate
    End
    Parse Var string word string
    If Upper(word) == "U+"         Then Exit BadCodepoint(word)
    If Upper(Left(word,2)) == "U+" Then word = SubStr(word,3)
    If \DataType(word,"X")         Then Exit BadCodepoint(word)
    If X2D(word) > X2D(10FFFF)     Then Exit BadCodepoint(word)
    If X2D(word) >= X2D(D800), X2D(word) <= X2D(DFFF)
                                   Then Exit BadCodepoint(word)
    res ||= IUTF8(word)
  End

  Return "", res

BadCodepoint: Return .Array~of("Invalid Unicode codepoint '"Arg(1)"'")
BadName:      Return .Array~of("Invalid Unicode name '"Arg(1)"'")

IUTF8: Procedure -- Internal, fast
  Use Arg code
  If code~length < 4 Then code = Right(code,4,0)
  Do While code~length > 4, code[1] == 0
    code = Substr(code,2)
  End
  n = X2D(code)
  b = X2B(code)
  If b~length == 20 Then b = "0000"||b
  If b~length == 8, n >= 128 Then b = "0000"||b
  Select
    When n <= 127   Then Return X2C(code[3,2])
    When n <= 2047  Then Return X2C(B2X("110"SubStr(b,6,5)"10"Right(b,6)))
    When n <= 65535 Then Return X2C(B2X("1110"Left(b,4)"10"SubStr(b,5,6)"10"Right(b,6)))
    Otherwise            Return X2C(B2X("11110"SubStr(b,4,3) "10"SubStr(b,7,6) "10"SubStr(b,13,6) "10"Right(b,6)))
  End



/******************************************************************************/
/* Well.Formed.UTF8(string)                                                   */
/*   Returns the null string when string is a well-formed UTF-8 string,       */
/*   and the first offending character sequence when it is not.               */
/******************************************************************************/

-- See The Unicode® Standard. Version 15.0 – Core Specification
-- https://www.unicode.org/versions/Unicode15.0.0/UnicodeStandard-15.0.pdf,
-- table 3-7, p. 125.

::Routine Well.Formed.UTF8 Public

  Use Strict Arg string

  ASCII       =  XRange("00"x,"7F"x)

  length      =  Length(string)
  pos         =  0

  WELL_FORMED =  ""

--------------------------------------------------------------------------------

NextChar: -- Look for the first character that is not ASCII
  pos = Verify(string, ASCII,, pos+1)

  -- All ASCII? That's a well-formed UTF-8 string
  If pos == 0 Then Exit WELL_FORMED

  -- See what kind of char we have
  ch   = string[pos]

  -- Lone continuations, or illegal characters
  If ch << "C2"X Then Exit ch
  If ch >> "F4"X Then Exit ch

  -- "C2".."DF"? We need exactly one continuation character
  If ch << "E0"X Then Do
    next   = string[pos+1]
    If \ContinuationChar( next )   Then Signal Error2
    pos += 1
    Signal NextChar
  End

  -- "E0".."EF"? We need exactly two continuation characters
  If ch << "F0"X Then Do
    next1   = string[pos+1]
    next2   = string[pos+2]
    If \ContinuationChar( next1 )  Then Signal Error3
    If \ContinuationChar( next2 )  Then Signal Error3
    -- Special cases
    If ch == "E0"X, next1 << "A0"X Then Signal Error3
    Else
    If ch == "ED"X, next1 >> "9F"X Then Signal Error3
    pos += 2
    Signal NextChar
  End

  -- "F0".."F4"? We need exactly three continuation characters
  Do
    next1   = string[pos+1]
    next2   = string[pos+2]
    next3   = string[pos+3]
    If \ContinuationChar( next1 )  Then Signal Error4
    If \ContinuationChar( next2 )  Then Signal Error4
    If \ContinuationChar( next3 )  Then Signal Error4
    -- Special cases
    If ch == "F0"X, next1 << "90"X Then Signal Error4
    Else
    If ch == "F4"X, next1 >> "8F"X Then Signal Error4
    pos += 3
    Signal NextChar
  End

--------------------------------------------------------------------------------

Error2: Exit ch || next
Error3: Exit ch || next1 || next2
Error4: Exit ch || next1 || next2 || next3

--------------------------------------------------------------------------------

ContinuationChar:
  If Arg(1) >= "80"X, Arg(1) <= "BF"X Then Return 1
  Return 0
