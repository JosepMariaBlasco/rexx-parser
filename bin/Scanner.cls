/******************************************************************************/
/*                                                                            */
/* Scanner.cls                                                                */
/* ===========                                                                */
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
/* 20241208    0.1a Accept options arg                                        */
/* 20241208         Implement extraletters option                             */
/* 20241208         c/CLASSIC_COMMENT/STANDARD_COMMENT/                       */
/* 20241209    0.1b Implement shebangs                                        */
/* 20241224    0.1d Add support for doc-comments                              */
/* 20241225         Migrate options arg to .Parser.Options                    */
/* 20250103    0.1f Add TUTOR-flavored Unicode support                        */
/* 20250115         Add "<<" and "\<<" methods                                */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250406         Rename fractional number to decimal                       */
/* 20250531    0.2c Implement more flexible rules for doc-comments            */
/* 20251029    0.2e Add isInserted method to Element class (Thanks, Rony!)    */
/* 20251126    0.3a Add support for Executor                                  */
/* 20251128         (Executor) Support "/==" and "/="                         */
/* 20251128         Add basic Unicode support to the scanner                  */
/* 20251128         (Executor) Support "^" and "¬" as a negators              */
/* 20251128         (Executor) Allow #@$ in identifiers                       */
/* 20251129         (Executor) Allow ¢ in identifiers                         */
/* 20251129         (Executor) Recognize curly brackets                       */
/* 20251201         (Executor) Add support for source literals                */
/* 20251202         Fix line no reported for syntax error 13.001              */
/* 20251202         Support Latin-1 encodings for ¬ and ¢                     */
/* 20251203         Rename to Scanner.cls                                     */
/* 20251214         Allow "AA"X as "¬", like ooRexx does                      */
/*                                                                            */
/******************************************************************************/

::Requires "Elements.cls"               -- Defines the Element classes
::Requires "Globals.cls"                -- Defines categories & subcategories
::Requires "UnicodeSupport.cls"         -- For Unicode string literals
::Requires "BaseClassesAndRoutines.cls" --

/******************************************************************************/
/******************************************************************************/
/*                                                                            */
/* The SCANNER class                                                          */
/*                                                                            */
/* A SCANNER instance receives a program source array, and it produces        */
/* a doubly-linked list of Elements (elements are defined in the required     */
/* package Elements.cls.                                                      */
/*                                                                            */
/* An element can be modified after scanning the following elements.          */
/* For example, a whitespace sequence will be flagged as ignorable when       */
/* an operator character follows it.                                          */
/*                                                                            */
/******************************************************************************/
/******************************************************************************/

--
-- Elements are Rexx tokens, whitespace, comments, and other inserted tokens.
--
-- Every element has a Category, and possibly a SubCategory.
-- See Elements.cls and Globals.cls for details.
--
-- Character set. By default, the scanner recognizes all ooRexx pure ASCII
-- characters (this means that ¬ is not recognized). Every character
-- recognized by the scanner has an associated value (a label), which
-- is stored in the ElementStartedBy stem and later used in a calculated
-- SIGNAL instruction to drive a Finite State Machine (see method
-- initialize.FSM).

-- The scanner accepts a mixture of UTF-8 and Latin-1 characters
-- (although mixing Latin-1 and UTF-8 characters in the same source
-- file is bad practice and should be avoided). Since there are no UTF-8
-- codes that start with characters in XRange("80"X,"C1"X), we handle such
-- characters as Latin-1. This allows us to recognize "AC"X as "¬",
-- or "A2"X as "¢", when certain options are active. Characters starting
-- with bytes >= "C2"X are assumed to start a byte sequence containing
-- a well-formed UTF-8 encoded Unicode codepoint. [--> TODO: 1) Verify
-- that characters are indeed well-formed; 2) provide external options
-- to indicate the encoding used by the source]
--

::Class Scanner Public

::Attribute head                        -- First element scanned
::Attribute tail                        -- Last  element scanned

/******************************************************************************/
/*                                                                            */
/* INIT                                                                       */
/*                                                                            */
/******************************************************************************/

::Method init
  Expose                       -
    package                    -        -- The package we are scanning
    source                     -        -- Source code for our package
    lines                      -        -- Number of lines in source
    line col                   -        -- Current line and column
    len                        -        -- Length of current line
    head                       -        -- First element scanned
    tail                       -        -- Last element scanned
    BOS                        -        -- Begin-of-source marker
    stopScanning               -        -- When an error is encountered
    lastEndOfClause            -        -- To check for ::RESOURCES
    bracketStack               -        -- Stack of "(","[","{"
    StandardDocCommentsAllowed -        --
    MarkdownDocCommentsAllowed          --

  Use Strict Arg package                -- The package we are scanning
  source = package~source               -- An array of lines
  lines  = source~items                 -- Total lines in source
  line   = 1                            -- Current line number
  col    = 1                            -- Current column number
  If lines > 0 Then
    len  = Length(source[1])            -- Length of current line

  BOS = .Inserted.Semicolon~new(1, 1)   -- We will insert a semicolon at BOS
  lastEndOfClause = BOS

  stopScanning = 0                      -- Will be 1 if we find an error

  bracketStack = .Stack~new

  self~initialize.FSM                   -- Finite State Machine
  self~initialize.Other.Tables          -- Other tables

  AllowedDocComments = Upper( ChangeStr(",",Global.Option( DocComments )," ") )

  StandardDocCommentsAllowed = -
    ( WordPos( All,      AllowedDocComments) > 0 ) | -
    ( WordPos( Standard, AllowedDocComments) > 0 ) | -
    ( WordPos( Block   , AllowedDocComments) > 0 ) | -
    ( WordPos( Classic , AllowedDocComments) > 0 )

  MarkdownDocCommentsAllowed = -
    ( WordPos( All,      AllowedDocComments) > 0 ) | -
    ( WordPos( Line    , AllowedDocComments) > 0 ) | -
    ( WordPos( Markdown, AllowedDocComments) > 0 )


  self~Build.Element.Chain

/******************************************************************************/
/*                                                                            */
/* INITIALIZE.FSM                                                             */
/*                                                                            */
/* Define character categories, based on the ANSI standard, with some         */
/* extensions for ooRexx and Executor, and initialize a table for a small     */
/* Finite State Machine used to drive the scanner with a calculated           */
/* SIGNAL instruction.                                                        */
/*                                                                            */
/******************************************************************************/

::Method initialize.FSM Private         -- Called only from INIT

  Expose whitespace var_symbol_char latin1_var_symbol_char radix -
    extra_letter general_letter ElementStartedBy

  -- We will use .String~digit instead
  -- digit          = .String~digit                  -- ANSI 6.2.2.1
  -- We will use .String~xDigit instead
  -- hex_digit      = .String~xDigit                 -- ANSI 6.2.2.39
  -- We will use the literal "01" instead
  -- binary_digit   = "01"                           -- ANSI 6.2.2.42
  special           = ",;:()"                        -- ANSI 6.2.2.2
  special         ||= "[]"                           -- Rexxref 5.1.0, 1.10.4.7.
  If .Options.Executor Then
    special       ||= "{}"
  -- Special Characters; "~" moved to operator
  not               = "\"                            -- ANSI 6.2.2.3
  not             ||= "AAAC"X                        -- See rexxref 1.10.4.6
  If .Options.Executor Then
    not           ||= "^¬"
  operator_only     = "+-%|&=><\"                    -- ANSI 6.2.2.4
  operator_only   ||= "AAAC"X                        -- See rexxref 1.10.4.6
  If .Options.Executor Then
    operator_only ||= "^¬"
  -- See Rexxref 5.10, 1.11.3. Parentheses and Operator Precedence
  operator_only   ||= "~"
  operator_or_other = "/*"                           -- ANSI 6.2.2.5
  operator_char     = operator_only ||,              -- ANSI 6.2.2.6
                      operator_or_other              -- ANSI 6.2.2.6
  general_letter    = .String~alpha"!?_"             -- ANSI 6.2.2.7
  If .Parser.Options~hasIndex( extraletters ) Then Do
    extra_letter    = .Parser.Options~extraletters   -- ANSI 5.3.2
    general_letter||= extra_letter
  End
  If .Options.Executor Then -- "A2"X is Latin-1 for "¢"
    general_letter||= "#@$¢" || "A2"X
  blank             = "2009"X                        -- ANSI 6.2.2.8
  -- "whitespace" is a better name, and more coherent with ooRexx
  -- nomenclature and with the text of error messages
  whitespace        = blank
  var_symbol_char   = general_letter".".String~digit -- ANSI 6.2.2.30

  radix             = "BX"                           -- Hex and binary strings
  If .Options.Unicode == 1 Then                      -- TUTOR-flavored Unicode
    radix           = "BXYPGTU"

  -- Since there are no UTF-8 combos starting with "80"X.."C1"X,
  -- we can treat these as if they were Latin-1.
  -- Otherwise, we're assuming well formed UTF-8
  latin1_var_symbol_char = Translate(        -
      var_symbol_char,"",XRange("C2"X,"FF"X) -
    )~Space(0)

  -- Table for the Finite State Machine

  ElementStartedBy          = .Stem~new
  ElementStartedBy[]        =  Invalid.Character     -- Default value

  Call Assign var_symbol_char, Symbol.Element
  Call Assign operator_char  , Operator.Char
  Call Assign special        , Special.Char
  Call Assign whitespace     , Whitespace.Sequence
  Call Assign "'"""          , String.Element
  ElementStartedBy["/"]      = Standard.Comment?
  ElementStartedBy["-"]      = Line.Comment?

  Return

Assign:
  chars = Arg(1)
  kind  = Arg(2)
  Do i = 1 To Length(chars)
    c = chars[i]
    -- Since there are no UTF-8 combos starting with "80"X.."C1"X,
    -- we can treat these as if they were Latin-1.
    -- Otherwise, we're assuming that 'chars' contains well formed UTF-8
    Select
      When c <= "C1"X Then Nop -- ASCII + some Latin-1
      When c <= "DF"X Then Do
        i += 1
        c ||= chars[i]
      End
      When c <= "EF"X Then Do
        i += 2
        c ||= chars[i-1]||chars[i]
      End
      Otherwise
        i += 3
        c ||= chars[i-2]||chars[i-1]||chars[i]
    End
    ElementStartedBy[ c ] = kind
  End
Return

/******************************************************************************/
/*                                                                            */
/* INITIALIZE.OTHER.TABLES                                                    */
/*                                                                            */
/* Defines three collections:                                                 */
/*   * ClassOfOperatorChar: operator char     -> element category             */
/*   * CompoundOperator:    operator sequence -> element category             */
/*   * ClassOfSpecialChar:  special char      -> element category             */
/*                                                                            */
/******************************************************************************/

::Method initialize.Other.Tables Private -- Called only from INIT

  Use Local

--------------------------------------------------------------------------------
-- Operator characters                                                        --
--                                                                            --
-- See rexxref 5.1.0 1.10.4.6. Operator Characters                            --
-- and ANSI 6.2.2.3-6                                                         --
--                                                                            --
--   not := '\' | other_negator                                               --
--   operator_only := '+' | '-' | '%' | '|' | '&' | '=' | not | '>' | '<'     --
--   operator_or_other := '/' | '*'                                           --
--   operator_char := operator_only | operator_or_other                       --
--                                                                            --
-- We include "~" here because it works as an operator in ooRexx:             --
-- see for example 1.11.3. Parentheses and Operator Precedence, where "~"     --
-- and "~~" are referred to as "message send operators".                      --
--------------------------------------------------------------------------------

  ClassOfOperatorChar = .StringTable~of( -
    ("&",   .EL.OP.AND              ),     -
    ("=",   .EL.OP.EQUAL            ),     -
    (">",   .EL.OP.GREATER_THAN     ),     -
    ("<",   .EL.OP.LOWER_THAN       ),     -
    ("-",   .EL.OP.MINUS            ),     -
    ("\",   .EL.OP.NEGATION         ),     -
    ("+",   .EL.OP.PLUS             ),     -
    ("~",   .EL.OP.MESSAGE          ),     -
    ("|",   .EL.OP.OR               ),     -
    ("%",   .EL.OP.INTEGER_DIVISION ),     -
    ("/",   .EL.OP.DIVISION         ),     -
    ("*",   .EL.OP.MULTIPLICATION   ),     -
    ("AC"X, .EL.OP.NEGATION         ),     - -- Latin-1 ¬
    ("AA"X, .EL.OP.NEGATION         )      - -- ooRexx ¬ too
  )

  If .Options.Executor Then Do
    ClassOfOperatorChar["^"  ] = .EL.OP.NEGATION
    ClassOfOperatorChar["¬"  ] = .EL.OP.NEGATION
  End

--------------------------------------------------------------------------------
-- Compound operator character sequences and their meaning.                   --
--                                                                            --
-- See ANSI 6.2.2.9                                                           --
--   bo := [blank+]                                                           --
-- and 6.2.2.34,                                                              --
--   Operator := operator_char | '|' bo '|' | '/' bo '/' | '*' bo '*'         --
--     | not bo '=' | '>' bo '<' | '<' bo '>' | '>' bo '=' | not bo '<'       --
--     | '<' bo '=' | not bo '>' | '=' bo '=' | not bo '=' bo '='             --
--     | '>' bo '>' | '<' bo '<' | '>' bo '>' bo '=' | not bo '<' bo '<'      --
--     | '<' bo '<' bo '=' | not bo '>' bo '>' | '&' bo '&'                   --
-- but please note that ANSI does not allow comments between operator         --
-- characters, but only whitespace ("blank+").                                --
--                                                                            --
-- We add "~~" here for reasons explained above, when documenting the         --
-- ClassOfOperatorChar collection.                                            --
--------------------------------------------------------------------------------

  compoundOperator = .StringTable~of(         -
    ("&&" , .EL.OP.XOR                     ), -
    ("||" , .EL.OP.CONCATENATION           ), -
    ("~~" , .EL.OP.CASCADING_MESSAGE       ), -
    ("**" , .EL.OP.POWER                   ), -
    ("==" , .EL.OP.STRICT.EQUAL            ), -
    ("\==", .EL.OP.STRICT.NOT_EQUAL        ), -
    ("\=" , .EL.OP.NOT_EQUAL               ), -
    ("\>" , .EL.OP.NOT_GREATER_THAN        ), -
    ("\<" , .EL.OP.NOT_LOWER_THAN          ), -
    ("<=" , .EL.OP.LOWER_OR_EQUAL          ), -
    ("<>" , .EL.OP.LOWER_OR_GREATER_THAN   ), -
    ("<<" , .EL.OP.STRICT.LOWER_THAN       ), -
    ("\<<", .EL.OP.STRICT.NOT_LOWER_THAN   ), -
    ("<<=", .EL.OP.STRICT.LOWER_OR_EQUAL   ), -
    (">=" , .EL.OP.GREATER_OR_EQUAL        ), -
    (">>" , .EL.OP.STRICT.GREATER_THAN     ), -
    ("\>>", .EL.OP.STRICT.NOT_GREATER_THAN ), -
    (">>=", .EL.OP.STRICT.GREATER_OR_EQUAL ), -
    ("><" , .EL.OP.GREATER_OR_LOWER_THAN   ), -
    ("//" , .EL.OP.REMAINDER               )  -
  )

  -- "AA"X as a negator
  compoundOperator["AA"X"=="] = .EL.OP.STRICT.NOT_EQUAL
  compoundOperator["AA"X"=" ] = .EL.OP.NOT_EQUAL
  compoundOperator["AA"X">" ] = .EL.OP.NOT_GREATER_THAN
  compoundOperator["AA"X"<" ] = .EL.OP.NOT_LOWER_THAN
  compoundOperator["AA"X"<<"] = .EL.OP.STRICT.NOT_LOWER_THAN
  compoundOperator["AA"X">>"] = .EL.OP.STRICT.NOT_GREATER_THAN

  -- "AC"X as a negator
  compoundOperator["AC"X"=="] = .EL.OP.STRICT.NOT_EQUAL
  compoundOperator["AC"X"=" ] = .EL.OP.NOT_EQUAL
  compoundOperator["AC"X">" ] = .EL.OP.NOT_GREATER_THAN
  compoundOperator["AC"X"<" ] = .EL.OP.NOT_LOWER_THAN
  compoundOperator["AC"X"<<"] = .EL.OP.STRICT.NOT_LOWER_THAN
  compoundOperator["AC"X">>"] = .EL.OP.STRICT.NOT_GREATER_THAN

  If .Options.Executor Then Do
    -- TSO/E negations
    compoundOperator["/=="]     = .EL.OP.STRICT.NOT_EQUAL
    compoundOperator["/=" ]     = .EL.OP.NOT_EQUAL
    -- "^" as a negator
    compoundOperator["^=="]     = .EL.OP.STRICT.NOT_EQUAL
    compoundOperator["^=" ]     = .EL.OP.NOT_EQUAL
    compoundOperator["^>" ]     = .EL.OP.NOT_GREATER_THAN
    compoundOperator["^<" ]     = .EL.OP.NOT_LOWER_THAN
    compoundOperator["^<<"]     = .EL.OP.STRICT.NOT_LOWER_THAN
    compoundOperator["^>>"]     = .EL.OP.STRICT.NOT_GREATER_THAN
    -- "¬" as a negator
    compoundOperator["¬=="]     = .EL.OP.STRICT.NOT_EQUAL
    compoundOperator["¬=" ]     = .EL.OP.NOT_EQUAL
    compoundOperator["¬>" ]     = .EL.OP.NOT_GREATER_THAN
    compoundOperator["¬<" ]     = .EL.OP.NOT_LOWER_THAN
    compoundOperator["¬<<"]     = .EL.OP.STRICT.NOT_LOWER_THAN
    compoundOperator["¬>>"]     = .EL.OP.STRICT.NOT_GREATER_THAN
 End

  ClassOfSpecialChar =                        -
    .StringTable~of(                          -
      ("(", .EL.LEFT_PARENTHESIS           ), -
      (")", .EL.RIGHT_PARENTHESIS          ), -
      ("[", .EL.LEFT_BRACKET               ), -
      ("]", .EL.RIGHT_BRACKET              ), -
      ("{", .EL.LEFT_CURLY_BRACKET         ), -
      ("}", .EL.RIGHT_CURLY_BRACKET        ), -
      (":", .EL.COLON                      ), -
      (",", .EL.COMMA                      ), -
      (";", .EL.END_OF_CLAUSE              )  -
    )

--------------------------------------------------------------------------------
-- List of extended assignment character sequences                            --
--------------------------------------------------------------------------------

  assignmentSequence = .Set~of(                -
    "=", "+=", "-=", "*=", "/=", "%=", "//=",  -
    "||=", "&=", "|=", "&&=", "**="            -
  )

  assignmentClass = .StringTable~of(     -
    (   "=", .EL.ASG.EQUAL            ), -
    (  "+=", .EL.ASG.PLUS             ), -
    (  "-=", .EL.ASG.MINUS            ), -
    (  "*=", .EL.ASG.MULTIPLY         ), -
    (  "/=", .EL.ASG.DIVIDE           ), -
    (  "%=", .EL.ASG.INTEGER_DIVISION ), -
    ( "//=", .EL.ASG.REMAINDER        ), -
    ( "||=", .EL.ASG.CONCATENATION    ), -
    (  "&=", .EL.ASG.AND              ), -
    (  "|=", .EL.ASG.OR               ), -
    ( "&&=", .EL.ASG.XOR              ), -
    ( "**=", .EL.ASG.POWER            )  -
  )

/******************************************************************************/
/*                                                                            */
/* Build.Element.Chain                                                        */
/*                                                                            */
/******************************************************************************/

::Method Build.Element.Chain Private    -- Called only from INIT

  Expose package source line col len lines head tail ElementStartedBy -
    BOS stopScanning

  head = BOS                            -- First element is always BOS
  tail = head                           -- We have only one element now

  -- Process shebangs
  If line == 1, line <= lines, col == 1, source[line][1,2] == "#!" Then
    self~Shebang

Main.Loop:
  If stopScanning Then Return 0         -- 0: Errors encountered

  -- Handle the end of source condition
  If line > lines Then Do
    self~EndOfSource
    Return 1                            -- 1: No errors found
  End

  -- Handle the end of line
  If col > len Then Do
    self~endOfLine
    line += 1
    col   = 1
    If line <= lines Then len = Length( source[line] )
    Signal Main.Loop
  End

  -- Pick a character (or, in some cases, a character pair)
  ch  = source[line][ col ]

  -- Since there are no UTF-8 combos starting with "80"X.."C1"X,
  -- we can treat these as if they were Latin-1.
  -- Otherwise, we're assuming well formed UTF-8

  Select
    When ch <= "C1"X Then -- ASCII + some Latin-1
      ch2 = source[line][ col+1 ] -- May be ""
    When ch <= "DF"X Then Do
      ch ||= source[line][ col+1 ]
      ch2 = source[line][ col+2 ] -- May be ""
    End
    When ch <= "EF"X Then Do
      ch ||= source[line][ col+1 ]source[line][ col+2 ]
      ch2 = source[line][ col+3 ] -- May be ""
    End
    Otherwise
      ch ||= source[line][ col+1 ]source[line][ col+2 ]source[line][ col+3 ]
      ch2 = source[line][ col+4 ] -- May be ""
  End

  -- And jump!
  Signal ( ElementStartedBy[ ch ] )

Line.Comment?       : If ch2 == "-" Then self~Line.Comment
                      Else self~Operator.Character.Sequence(ch)
                      Signal Main.Loop

Standard.Comment?   : If ch2 == "*" Then self~Standard.Comment
                      Else self~Operator.Character.Sequence(ch)
                      Signal Main.Loop

Whitespace.Sequence : self~Whitespace.Sequence
                      Signal Main.Loop

Symbol.Element      : self~Symbol.Element
                      Signal Main.Loop

Special.Char        : self~Special.Character.Sequence(ch)
                      Signal Main.Loop

Operator.Char       : self~Operator.Character.Sequence(ch)
                      Signal Main.Loop

String.Element      : self~String.Element(ch)
                      Signal Main.Loop

Invalid.Character   : signal 13.001

-- Incorrect character in program "&1" ('&2'X).
13.001: self~error( 13.001, line col line (col+Length(ch)), ch, c2x(ch) )
Return 0                                -- 0: Error encountered

/******************************************************************************/
/* error                                                                      */
/******************************************************************************/

::Method error
  Expose package stopScanning tail

  Use Strict Arg code, anchor, ...

  additional = Arg(3,"A")

  error = .Error.Element~new( package, code, anchor, additional )
  If anchor~isA(.Element) Then
    If anchor == tail Then self~append( error )
    Else self~insertAfter(anchor, error)
  Else self~append( error )

  stopScanning = 1

/******************************************************************************/
/* endOfLine                                                                  */
/******************************************************************************/

::Method endOfLine
  Expose line lines col len tail

  -- Either this is an implied semicolon, or a continuation char.
  -- Both continuations and semicolons eat blanks at both sides, and
  -- therefore it is safe to mark whitespace to the left as ignorable
  -- (think of "A <eol>" -> "A<generated ;>)

  previous = tail

  Do While previous~ignorable
    previous = TheElementBefore( previous )
  End
  If previous < .ALL.WHITESPACE_LIKE Then Do
    previous~ignorable = 1
    previous = TheElementBefore( previous )
  End

  -- Edge case: if this is a null line, we have to insert a semicolon
  -- unconditionally
  If len = 0, col = 1 Then Signal InsertSemicolon

  -- Continuations in the last source line are not accepted as such
  -- by the ANSI standard (see 6.2.2.1), but are happily processed by
  -- ooRexx. We produce an implied semicolon when we find a
  -- continuation just before EOS.

  If line < lines, previous < .ALL.CONTINUATION_CHARACTERS Then Do
    previous~category = .EL.CONTINUATION
    If TheElementBefore( previous ) < .IGNORE_WHITESPACE_AFTER Then
      previous~ignorable = 1
    Return -- Do not generate an end-of-clause
  End

  -- No continuation? Insert an implied semicolon (EL.END_OF_CLAUSE)

InsertSemicolon:
  semicolon       = .Inserted.Semicolon~new(line, col)

  self~append( semicolon )

  -- A semicolon eats blanks at the left
  beforeSemicolon = TheElementBefore( semicolon )
  If beforeSemicolon < .ALL.WHITESPACE_LIKE Then
    beforeSemicolon~ignorable = 1

  -- Special case: check if this is a ::RESOURCE directive
  self~checkResource

Return

--------------------------------------------------------------------------------
-- checkResource                                                              --
--------------------------------------------------------------------------------

::Method checkResource
  Expose tail lastEndOfClause

  ignoreBlanks = .True

  -- "::"
  first = TheElementAfter( lastEndOfClause )
  If first \< .EL.DIRECTIVE_START      Then Signal NotAResourceDirective

  -- "RESOURCE"
  second = TheElementAfter( first )
  If second \< .ALL.VAR_SYMBOLS        Then Signal NotAResourceDirective
  If second~value \== "RESOURCE"       Then Signal NotAResourceDirective

  -- resource_name
  third  = TheElementAfter( second, ignoreBlanks )
  If third \< .ALL.SYMBOLS_AND_STRINGS Then Signal NotAResourceDirective

  -- Maybe "END delimiter"
  fourth = TheElementAfter( third, ignoreBlanks )
  If fourth < .EL.END_OF_CLAUSE Then delimiter = "::END"
  Else Do
    If fourth \< .ALL.VAR_SYMBOLS  Then Signal 25.926
    Else If fourth~value \== "END" Then Signal 25.926
    Else Do
      fifth = TheElementAfter( fourth, ignoreBlanks )
      If fifth \< .ALL.SYMBOLS_AND_STRINGS Then Signal 19.921
      delimiter = fifth~value

      sixth = TheElementAfter( fifth, ignoreBlanks )
      If sixth \< .EL.END_OF_CLAUSE Then Signal 21.914
    End
  End
  self~processResource( first, third, delimiter )
  Return

-- String or symbol expected after ::RESOURCE END keyword
19.921: self~error( 19.921, fifth, fifth )
Return

-- Data must not follow the ::RESOURCE directive; found "&1"
21.914: self~error( 21.914, sixth, sixth )
Return

-- Unknown keyword on ::RESOURCE directive; found "&1".
25.926: self~error( 25.926, fourth, fourth )
Return

NotAResourceDirective:
  lastEndOfClause = tail
  Return

--------------------------------------------------------------------------------
-- processResource                                                            --
--------------------------------------------------------------------------------
::Method processResource
  Expose source line lines col len tail lastEndOfClause

  Use Strict Arg marker, name, delimiter

  -- "tail" now points to the closing directive semicolon, implied or not

  -- Pick the line and column of the tail
  Parse Value tail~to With tailLine tailEnd

  -- There is some extra stuff in the line?
  -- It has to be ignored (see doc. bug. no. 307),
  -- https://sourceforge.net/p/oorexx/documentation/307/
  If tailLine == line, tailEnd < len | tail~from \== tail~to Then
    self~append( IgnoredData( source, line, tailEnd ) )

  -- The resource starts on the next line
  fromLine = line + 1

  -- We now look for a line starting with the delimiter
  delimiterLength = Length( delimiter )

  -- No more lines? That's an error
  If fromLine >= lines Then Signal 99.943

  Do lineNo = fromLine To lines
    If source[lineNo]~startsWith(delimiter) Then Signal EndDelimiterFound
  End

  -- Not found? That's an error too.
  Signal 99.943

EndDelimiterFound:
  -- Store the resource end line
  toLine = lineNo - 1

  -- Add the resource data element to the end of the element list
  self~append( Resource.Data( source, fromLine, toLine ) )

  -- Create a taken_constant...
  endDelimiter = .StringOrSymbol.Element~new(                           -
   .EL.TAKEN_CONSTANT, lineNo, 1, delimiterLength+1, source[lineNo]  -
  )
  -- ... with a .RESOURCE.DELIMITER.NAME subCategory...
  Call SetConstantName endDelimiter, .RESOURCE.DELIMITER.NAME
  -- ...and insert it into the element list too.
  self~append( endDelimiter )

  delimiterLineLength = source[lineNo]~length

  -- Store final ignored data, if it exists
  If delimiterLineLength > delimiterLength Then Do
    self~append( -
      IgnoredData(source, lineNo, delimiterLength + 1)                 -
    )
  End

  semicolon = .Inserted.Semicolon~new( lineNo, delimiterLineLength + 1 )

  -- Update len and col
  len = delimiterLineLength
  col = len + 1

  self~append( semicolon )

  lastEndOfClause = semicolon

  marker~closing  = semicolon

  Return

IgnoredData: Procedure
  Use Strict Arg source, line, start

  ignored_data           = .Element~new
  ignored_data~category  = .EL.RESOURCE_IGNORED_DATA
  ignored_data~from      = line start
  ignored_data~to        = line (Length(source[line])+1)
  ignored_data~source    = SubStr( source[line], start )
  ignored_data~ignorable = 1
  Return                   ignored_data

99.943: self~error(99.943, marker, delimiter, name)
--------------------------------------------------------------------------------
-- EndOfSource                                                                --
--                                                                            --
--   Add a trailing end-of-clause to ensure that all clauses/instructions     --
--   end with an end-of-clause. This simplifies code.                         --
--------------------------------------------------------------------------------

::Method EndOfSource
  Expose tail

  Parse Value tail~to With line, col

  self~append( .Inserted.Element~new(.EL.END_OF_SOURCE, line, col) )

  self~append( .Inserted.Semicolon    ~after( tail ) )

  Return

/******************************************************************************/
/* SHEBANGS                                                                   */
/******************************************************************************/

::Method Shebang

  Expose package line col len

  self~append( .Shebang~new(package, line, col, len + 1) )

/******************************************************************************/
/* LINE COMMENTS                                                              */
/******************************************************************************/

::Method Line.Comment

  Expose package source line lines col len MarkdownDocCommentsAllowed

  startLine = line
  startCol  = col
  If \MarkdownDocCommentsAllowed Then Signal NormalLineComment
  If \IsADocCommentLine(line)    Then Signal NormalLineComment

  Do While line < lines, IsADocCommentLine(line+1)
    line = line + 1
    len  = source[line]~length
  End

  comment = .Line.Comment~new(package, startLine, startCol, line, len + 1)

  self~Markdown.DocComment( comment )

  Return

IsADocCommentLine: Procedure expose source
  Arg line
  starting = source[line]~strip~left(4)
  If starting[1,3] \== "---" Then Return .False
  If starting[4]    == "-"   Then Return .False
Return .True

NormalLineComment:
  self~append( .Line.Comment~new(package, line, col, line, len + 1) )

/******************************************************************************/
/* MARKDOWN DOC-COMMENT                                                       */
/******************************************************************************/

::Method Markdown.DocComment

  Expose package source commentParts theLine inTagValue inTagDescription -
    summaryFound inMainDescription classicDocComment

  Use Strict Arg comment

  commentParts      = comment~parts

  classicDocComment = 0

  -- Set the right category. This applies when we look at the element
  -- as a whole.
  comment~category = .EL.DOC_COMMENT_MARKDOWN

  -- We now perform a rough parsing of the whole doc-comment, and store
  -- its parts in the "parts" attribute.

  -- We first have to calculate which is the "outer" part of the doc-comment.
  -- See https://docs.oracle.com/en/java/javase/23/javadoc/using-markdown-documentation-comments.html
  --
  -- "The content of the comment is [...] determined as follows:
  --
  --  * Any leading whitespace and the three initial forward slash (/)
  --    characters are removed from each line.
  --
  --  * The lines are then shifted left, by removing leading whitespace
  --    characters, until the non-blank line with the least leading
  --    whitespace characters has no remaining leading whitespace characters.
  --
  --  * Additional leading whitespace characters and any trailing whitespace
  --    characters in each line are preserved."
  --

  Parse Value comment~from With first .
  Parse Value comment~to   With last  .

  leading_whitespace  = 1000
  Do theLine = first To last
    Parse Value source[theLine] With "---"rest
    p = Verify(rest,"2009"X)
    If p == 0 Then p = Length(rest) + 1
    leading_whitespace = Min(leading_whitespace, p)
  End
  leading_whitespace -= 1

  inMainDescription   = 1
  summaryFound        = 0

  Do theLine = first To last
    Parse Value source[theLine] With before"---"line
    after    = Left(line, leading_whitespace)
    armature = before"---"after
    self~AddArmature( armature )
    line     = SubStr(line, leading_whitespace + 1)
    self~ProcessDocCommentLine( line )
  End

  self~append( comment )

::Method ProcessDocCommentLine

  Expose inMainDescription classicDocComment

  Use Arg line

  -- If this is a classic doc-comment ending with "*/", we have to
  -- deal with this final part of the armature at the end.
  endDocComment = ""
  If classicDocComment, line~strip("T")~right(2) == "*/" Then Do
    Parse Var line line"*/"after
    endDocComment = "*/"after
  End

  c = line~strip("L")[1]

  -- A line starting with "@" ends the main description
  If c == "@" Then inMainDescription = 0

  If inMainDescription Then
    self~ProcessDocCommentMainDescriptionLine( line )
  Else -- Process block tags
    self~ProcessDocCommentTagListLine( c, line )

  If endDocComment \== "" Then
    self~AddArmature( endDocComment )

::Method ProcessDocCommentMainDescriptionLine
  Expose summaryFound

  Use Arg line

  -- Summary processed? A main description line
  If summaryFound Then Do
    self~AddMainDescription( line )
    Return
  End

  -- Summary still not found: empty lines before the summary
  If line = "" Then Do
    self~AddWhitespace( line )
    Return
  End

  -- Summary starts, may have some whitespace before
  line = self~InitialBlanks( line )

  -- Is there a dot in the summary line
  p = Pos(".",line)
  -- No ".": summary may continue in next line
  If p == 0 | (p > 0 & p < Length(line) & \ line~matchChar(p+1,"2009"X) )Then Do
    self~AddSummary( line )
    Return
  End

  -- We have a summary ending with a dot.
  summary = Left(line,p)
  self~AddSummary( summary )
  summaryFound = 1

  -- Something left? That's the main description starting
  If p < Length(line) Then self~AddMainDescription( SubStr(line, p + 1) )

::Method ProcessDocCommentTagListLine
  Expose inTagValue inTagDescription

  Use Arg c, line

  If c == "@" Then Do
    self~DocCommentStartBlockTag( line )
    Return
  End

  line = self~InitialBlanks( line )
  If inTagValue Then self~AddTagValue( line )
  Else            self~AddTagDescription( line )

::Method DocCommentStartBlockTag
  Expose inTagValue inTagDescription

  Use Arg line

  inTagValue       = 0
  inTagDescription = 0

  line = self~InitialBlanks( line )
  Parse Var line tag line
  self~AddTag( tag )
  If line \== "" Then line = self~InitialBlanks( " "line )
  Select Case tag
    When "@author" Then Do
      self~AddTagValue( line )
      inTagValue = 1
    End
    When "@param" Then Do
      Parse Var line value line
      self~AddTagValue( value )
      If line \== "" Then line = self~InitialBlanks( " "line )
      self~AddTagDescription( line )
      inTagDescription = 1
    End
    When "@condition" Then Do
      If Words(line) == 1 Then Do
        self~AddTagValue( line )
        inTagDescription = 1
        Return
      End
      Parse Var line name rest
      self~AddTagValue( name )
      If rest \== "" Then rest = self~InitialBlanks( " "rest )
      If WordPos(Lower(name), "error failure syntax user") > 0 Then Do
        Parse Var rest word rest
        self~AddTagValue( word )
        If rest \== "" Then rest = self~InitialBlanks( " "rest )
      End
      If rest \== "" Then self~AddTagDescription( rest )
      inTagDescription = 1
    End
    Otherwise
      self~AddTagDescription( line )
      inTagDescription = 1
  End

--------------------------------------------------------------------------------
-- A series of small methods to construct the doc-comment parts               --
--------------------------------------------------------------------------------

::Method InitialBlanks
  Use arg string
  p = Verify(string, "2009"X)
  If p = 0 Then Do
    self~AddWhitespace( string )
    Return ""
  End
  If p = 1 Then Return string
  blanks = Left(string,p-1)
  self~AddWhitespace( blanks )
Return SubStr(string, p)

::Method AddArmature
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_ARMATURE,         Arg(1) ) )

::Method AddMainDescription
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_MAIN_DESCRIPTION, Arg(1) ) )

::Method AddSummary
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_SUMMARY,          Arg(1) ) )

::Method AddTag
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_TAG,              Arg(1) ) )

::Method AddTagDescription
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_TAG_DESCRIPTION,  Arg(1) ) )

::Method AddTagValue
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_TAG_VALUE,        Arg(1) ) )

::Method AddWhitespace
  Expose commentParts theLine
  commentParts~append( (theLine, .EL.DOC_COMMENT_WHITESPACE,       Arg(1) ) )

/******************************************************************************/
/* CLASSIC COMMENTS                                                           */
/******************************************************************************/

::Method Standard.Comment

  Use Local c startLine startColumn searchStart nesting starting -
    slashPos slashLine

  -- Save the starting point of our comment
  startLine   = line
  startColumn = col

  nesting     = 1
  pos         = col + 2

  currentLine = source[line]
  Loop Until nesting == 0
    Do While pos > len
      line += 1
      col   = 1
      If line > lines Then Signal 6.001
      currentLine = source[line]
      len = Length( currentLine )
      pos = 1
    End

    c = currentLine[pos]
    Select
      When c == "*", currentLine[pos+1] == "/" Then nesting -= 1
      When c == "/", currentLine[pos+1] == "*" Then nesting += 1
      Otherwise
        pos += 1
        Iterate
    End
    pos += 2
  End
  Signal GotAComment

GotAComment:

  len = Length( source[line] )

  comment = .Standard.Comment~new( package, startLine, startColumn, line, pos )

  If StandardDocCommentsAllowed Then Do
    starting = source[startLine]~strip~Left(4)
    If starting[1,3] \== "/**" Then Signal Done
    If starting[4]    == "*"   Then Signal Done
    ending   = source[line]~strip~Right(3)
    If ending[2,2]   \== "*/"  Then Signal Done
    If ending[1]      == "*"   Then Signal Done

    self~Classic.DocComment( comment )

    Return

  End

Done:
  self~append( comment )
  Return

-- Unmatched comment delimiter ("/*") on line &1.
 6.001: Syntax(  6.001, tail, startLine )

/******************************************************************************/
/* CLASSIC DOC-COMMENT                                                        */
/******************************************************************************/

::Method Classic.DocComment

  Expose package source commentParts theLine inTagValue inTagDescription -
    summaryFound inMainDescription classicDocComment

  Use Strict Arg comment

  commentParts   = comment~parts

  classicDocComment = 1

  -- Set the right category. This applies when we look at the element
  -- as a whole.
  comment~category = .EL.DOC_COMMENT

  Parse Value comment~from With first firstCol
  Parse Value comment~to   With last  lastCol

  inMainDescription   = 1
  summaryFound        = 0

  Do theLine = first To last
    Select Case theLine
      When first Then Do
        thisLine = SubStr(source[theLine], firstCol)
        Parse Value thisLine With before"/**"line
        p = Verify(line,"2009"X)
        If p == 0 Then Do
          self~AddArmature( thisLine )
          self~ProcessDocCommentLine( "" )
        End
        Else Do
          self~AddArmature( before"/**"Left(line,p-1) )
          self~ProcessDocCommentLine( SubStr(line,p) )
        End
      End
      Otherwise
        thisLine = source[theLine]
        c = thisLine~strip("L")[1]
        If c == "*" Then Do
          Parse Var thisLine before"*"thisLine
          before = before"*"
        End
        Else before = ""
        p = Verify(thisLine, "2009"X)
        If p == 0 Then self~AddArmature( before || thisLine )
        Else Do
          self~AddArmature( before || Left(thisLine, p - 1) )
          self~ProcessDocCommentLine( SubStr(thisLine,p) )
        End
    End
  End

  self~append( comment )

/******************************************************************************/
/* OPERATOR character sequences                                               */
/******************************************************************************/

::Method Operator.Character.Sequence
  Use Local element predecessor category sequence

  Use Strict Arg ch

  category = ClassOfOperatorChar[ ch ]

  -- Since there are no UTF-8 combos starting with "80"X.."C1"X,
  -- we can treat these as if they were Latin-1.
  -- Otherwise, we're assuming well formed UTF-8

  c1 = ch[1]
  Select
    When c1 <= "C1"X Then chlen = 1 -- ASCII and some Latin-1
    When c1 <= "DF"X Then chlen = 2
    When c1 <= "EF"X Then chlen = 3
    Otherwise             chlen = 4
  End

  element = .Operator.Character.Sequence~new( -
    category, line, col, col+chlen, ch        -
  )

  self~append( element )

  -- Now apply Rexx rules about ignoring whitespace before operator chars
  predecessor = TheElementBefore( element )
  If predecessor < .ALL.WHITESPACE_LIKE Then Do
    predecessor~ignorable = 1
    -- Recalculate predecessor
    predecessor = TheElementBefore(predecessor)
  End

  -- If now predecessor is not an operator, we are done
  If predecessor \< .ALL.OPERATORS Then Return element

  -- Check if this is a compound operator or an extended assignment
  sequence = predecessor~value || element~value

  category = CompoundOperator[sequence]
  If category == .Nil Then Do
    If \assignmentSequence~hasItem(sequence) Then Return element
    -- An extended assignment
    category = assignmentClass[sequence]
    predecessor~category = category
    -- If this is a three-character extended assignment sequence,
    -- we need to get to the intermediate (i.e., second) character
    -- to set its category
    If predecessor < .ALL.3CHARS_ASSIGNMENT_SEQUENCES Then
      Call SetMiddlecategory
  End
  Else Do -- A compound operator
    -- If this is a three-character operator sequence, we need to get to the
    -- intermediate (i.e., second) character to set its category.
    predecessor~category = category
    If predecessor < .ALL.OPS.3CHARS Then
      Call SetMiddlecategory
  End

-- Common path for compound operators and extended assignments
CompoundOperatorOrExtendedAssignment:
  predecessor~value = sequence
  element~category  = category
  element~ignorable = 1

Return element

SetMiddlecategory:
  second = element~prev
  Do While second \< .ALL.OPERATORS
    second = second~prev
  End
  second~category = category
Return

/******************************************************************************/
/* SPECIAL characters                                                         */
/******************************************************************************/

::Method Special.Character.Sequence
  Expose line col tail ClassOfSpecialChar bracketStack

  Arg ch

  category = ClassOfSpecialChar[ch]

  element = .Special.Character.Sequence~new(     -
    category, line, col, col+1, ch -
  )

  self~append( element )

  -- Apply Rexx rules about ignoring whitespace
  predecessor = TheElementBefore( element )

  -- Whitespace not before an opening bracket is ignorable
  If element < .ALL.LEFT_BRACES Then Nop
  Else If predecessor < .ALL.WHITESPACE_LIKE Then Do
    predecessor~ignorable = 1
    -- Recalculate predecessor
    predecessor = TheElementBefore( predecessor )
  End


  -- See that brackets are correctly paired
  Select Case element~category
    When .EL.LEFT_PARENTHESIS Then Do
      bracketStack~push( element )
      Return
    End
    When .EL.RIGHT_PARENTHESIS Then Do
      -- See that "(" and ")" are paired
      If bracketStack~isEmpty           Then Signal 37.002
      If bracketStack~top~value \== "(" Then Signal 37.002
      bracketStack~top~closing = element
      bracketStack~pop
      Return
    End
    When .EL.LEFT_BRACKET Then Do
      bracketStack~push( element )
      Return
    End
    When .EL.RIGHT_BRACKET Then Do
      -- See that "[" and "]" are paired
      If bracketStack~isEmpty           Then Signal 37.901
      If bracketStack~top~value \== "[" Then Signal 37.901
      bracketStack~top~closing = element
      bracketStack~pop
      Return
    End
    When .EL.LEFT_CURLY_BRACKET Then Do
      bracketStack~push( element )
      -- Add an extra semicolon after "{"
      Parse Value element~to With line col
      self~append(.Inserted.Semicolon~new(line, col))
      Return
    End
  -- Add an extra semicolon before "}"
    When .EL.RIGHT_CURLY_BRACKET Then Do
      -- See that "{" and "}" are paired
      If bracketStack~isEmpty           Then Signal 37.900
      If bracketStack~top~value \== "{" Then Signal 37.900
      bracketStack~top~closing = element
      bracketStack~pop
      -- Add an extra semicolon before "}"
      Parse Value element~to With line col
      self~insertBefore(element, .Inserted.Semicolon~new(line, col))
      Return
    End
    Otherwise Nop
  End

  -- Handle "::"
  If ch == ":", predecessor < .EL.COLON Then Do
    element~category = .EL.DIRECTIVE_START
    -- In the most common case, the two colons will be adjacent.
    -- We generate a new "::" element and remove the predecessor element.
    If predecessor~to == element~from Then Do
      element~from   = predecessor~from
      element~source = "::"
      element~value  = "::"
      predecessor~remove
    End
    Else Do
      element~ignorable = 1
      predecessor~category = .EL.DIRECTIVE_START
    End
  End

  Return

-- Unexpected ")"
37.002: self~error( 37.002, element)
Return

-- Unexpected "}"
37.900: self~error( 37.900, element, 'Unexpected "}"')
Return

-- Unexpected "]"
37.901: self~error( 37.901, element)
Return

/******************************************************************************/
/* WHITESPACE                                                                 */
/******************************************************************************/

::Method Whitespace.Sequence
  Expose source line col len whitespace

  p = source[line]~verify(whitespace,,col)
  If p == 0 Then p = len + 1

  -- Special case: a markdown doc-comment preceded by whitespace
  If col == 1, source[line][p,3] == "---", source[line][p+3] \== "-" Then Do
    self~Line.Comment
    Return
  End

  element = .WhiteSpace.Element~new( line, col, p, source[line] )
  self~append( element )

  -- Apply Rexx rules about ignoring posterior whitespace

  If TheElementBefore( element ) < .IGNORE_WHITESPACE_AFTER Then
    element~ignorable = 1

  Return

/******************************************************************************/
/* SYMBOL:                                                                    */
/*                                                                            */
/*   VAR_SYMBOL   : SIMPLE_VARIABLE, COMPOUND_VARIABLE, STEM_VARIABLE         */
/*   CONST_SYMBOL : PERIOD, EL.SYMBOL_LITERAL, EL.ENVIRONMENT_SYMBOL          */
/*   NUMBER       : EL.INTEGER_NUMBER, EL.DECIMAL_NUMBER,                     */
/*                  EL.EXPONENTIAL_NUMBER                                     */
/******************************************************************************/

::Method Symbol.Element

  Expose source line col len var_symbol_char latin1_var_symbol_char -
    extra_letter general_letter ElementStartedBy

  currentLine = source[line]
  p = col
  Loop
    p = currentLine~verify( latin1_var_symbol_char,,p)
    If p == 0 Then Do
      p = len + 1
      Leave
    End
    Else Do -- p \== 0
      -- Since there are no UTF-8 combos starting with "80"X.."C1"X,
      -- we can treat these as if they were Latin-1.
      -- Otherwise, we're assuming well formed UTF-8
      If currentLine[p] <<= "C1"X Then Leave -- ASCII and some Latin-1
      c = currentLine[p]
      Select
        When c << "E0"X Then clen = 2
        When c << "F0"X Then clen = 3
        Otherwise            clen = 4
      End
      If ElementStartedBy[currentLine[p,clen]] \== "SYMBOL.ELEMENT" Then
        Leave
      p += clen
      Iterate
    End
  End
  symbol = currentLine[col, p - col]

  self~append(                                                            -
    .StringOrSymbol.Element~new(SymbolKind(), line, col, p, source[line]) -
  )

  Return

-- Determine the kind of symbol we are dealing with
-- This gets complex for exponential numbers with a signed exponent
SymbolKind:

  Select
    -- Numbers (without signed exponents)
    When Number(symbol) Then Select
      When Exponential(symbol)            Then Return .EL.EXPONENTIAL_NUMBER
      When HasADot(symbol)                Then Return .EL.DECIMAL_NUMBER
      Otherwise                                Return .EL.INTEGER_NUMBER
    End
    -- Variables (simple, compound, stems)
    When IsAVariable(symbol) Then Select
      When \HasADot(symbol)               Then Return .EL.SIMPLE_VARIABLE
      When ManyDots(symbol)               Then Return .EL.COMPOUND_VARIABLE
      When symbol~endsWith(".")           Then Return .EL.STEM_VARIABLE
      Otherwise                                Return .EL.COMPOUND_VARIABLE
    End
    -- Constant symbols and numbers with signed exponents
    Otherwise Select
      When symbol == "."                  Then Return .EL.PERIOD
      When IsANumberWithASignedExponent() Then Return .EL.EXPONENTIAL_NUMBER
      When ContainsExecutorNumber()       Then Signal SymbolKind
      When symbol[1] == "."               Then Return .EL.ENVIRONMENT_SYMBOL
      Otherwise                                Return .EL.SYMBOL_LITERAL
    End
  End

ContainsExecutorNumber:
  -- If Executor support is active, handle cases like 2i or 3.42pq
  If .Options.Executor, DataType(symbol) \== "NUM" Then Do
    Loop q = p-1 To col By -1
      If DataType(currentLine[col, q - col]) == "NUM" Then Do
        p = q
        symbol = currentLine[col, p - col]
        Return 1
      End
    End
  End
  Return 0

Number:
  Return DataType(Arg(1)) == "NUM"

IsAVariable:
  c = Arg(1)[1]
  If c == "." Then Return .False
  If c >>= "0", c <<= "9" Then Return .False
  Return .True

--------------------------------------------------------------------------------
-- See if this is an exponential number with a signed exponent                --
--------------------------------------------------------------------------------

IsANumberWithASignedExponent:
  If p == len + 1             Then Return 0 -- Symbol must end with..
  If Lower(currentLine[p-1]) \== "e"
    Then Return 0                           -- .. an "E" or an "e".
  before = Lower(currentLine[col,p-col-1])
  If Exponential(before)      Then Return 0 -- ..preceded by a plain..
  If \Number(before)          Then Return 0 -- ..number, and followed by..
  If Pos(currentLine[p],"+-") == 0
    Then Return 0                           -- ..a "+" or "-" sign..
  q = p + 1
  If q == len + 1             Then Return 0 -- ..in turn followed by..
  If Pos(currentLine[q],.String~digit) == 0 -- ..one or more digits.
    Then Return 0
  p2 = currentLine~verify(.String~digit,,q) -- If this ends the line, then..
  If p2 = 0 Then Do                         -- ..this is an exponential,
    p = len + 1                             -- ..and also if..
    Signal ExponentDone
  End
  If \.Options.Executor Then                -- ..Executor support is off...
  If Pos(currentLine[p2], general_letter".") > 0 -- ..and the following char..
                              Then Return 0 -- ..is not a letter or a dot.
  p = p2
  -- Recalculate symbol
ExponentDone:
  symbol = currentLine[ col, p - col ]
Return 1

ManyDots:
  Return CountStr(".",Arg(1)) > 1
HasADot:
  Return Pos(".",Arg(1)) > 0
Exponential:
  Return Pos("e",Lower(Arg(1))) > 0

/******************************************************************************/
/* ALL.STRINGS                                                            */
/******************************************************************************/

::Method String.Element
  Expose source line col len radix var_symbol_char whitespace tail

  anchor = tail -- Element to reference for syntax errors
  currentLine = source[line]

  Use Strict Arg ch -- "ch" is the starting quote
  endQ = Pos( ch, currentLine, col+1 )
  Loop
    If endQ == 0 Then
      If ch == "'" Then Signal 6.002; Else Signal 6.003
    length = endQ - col + 1
  If currentLine[ endQ+1 ] \== ch Then Leave
    endQ = Pos(ch, currentLine, endQ + 2)
  End
  If Pos(Upper(currentLine[endQ+1]), radix) > 0 Then Do
    If endQ +1 == len                                 Then Signal RADIX
    If Pos(currentLine[endQ+2], var_symbol_char) == 0 Then Signal RADIX
  End
  Call Element .EL.STRING, col + length
  Return

RADIX: -- ANSI 6.2.1.1
  string = currentLine[col+1, length-2]
  Select Case Upper( currentLine[endQ+1] )
    When "B" Then Signal BinaryString
    When "X" Then Signal HexString
    When "Y" Then Signal BytesString
    When "P" Then Signal CodepointsString
    When "G" Then Signal GraphemesString
    When "T" Then Signal TextString
    When "U" Then Signal UnicodeString
  End

-- Unmatched single quote (').
 6.002: Syntax(  6.002, anchor )

-- Unmatched double quote (").
 6.003: Syntax(  6.003, anchor )

--------------------------------------------------------------------------------
-- BYTES STRINGS                                                              --
--------------------------------------------------------------------------------

BytesString:
  Call Element .EL.BYTES_STRING, col + length + 1
  Return

--------------------------------------------------------------------------------
-- CODEPOINTS STRINGS                                                         --
--------------------------------------------------------------------------------

CodePointsString:
  If CheckUTF8() Then
    Call Element .EL.CODEPOINTS_STRING, col + length + 1
  Return

--------------------------------------------------------------------------------
-- GRAPHEMES STRINGS                                                          --
--------------------------------------------------------------------------------

GraphemesString:
  If CheckUTF8() Then
    Call Element .EL.GRAPHEMES_STRING, col + length + 1
  Return

--------------------------------------------------------------------------------
-- TEXT STRINGS                                                               --
--------------------------------------------------------------------------------

TextString:
  If CheckUTF8() Then
    Call Element .EL.TEXT_STRING, col + length + 1
  Return

--------------------------------------------------------------------------------
-- UNICODE STRINGS                                                            --
--------------------------------------------------------------------------------

UnicodeString:
  value = CheckUnicode()
  Call UString .EL.UNICODE_STRING, col + length + 1, value
  Return

--------------------------------------------------------------------------------
-- BINARY STRINGS                                                             --
--------------------------------------------------------------------------------

BinaryString:
  If DataType(string, "B") Then Do
    Call Element .EL.BINARY_STRING, col + length + 1
    Return
  End

  -- The DATATYPE function has complained: determine the cause of the error

  bad = Verify(string, "01"whitespace)
  If bad \== 0 Then Signal 15.004

  If Pos(string[1],      whitespace) > 0 Then Call 15.002 1
  length = Length(string)
  If Pos(string[length], whitespace) > 0 Then Call 15.002 length

  Signal 15.006

-- Binary strings must be grouped in units that are multiples of four characters.
15.006: Syntax( 15.006, anchor )

-- Incorrect location of whitespace character in position &1 in binary string.
15.002: Syntax( 15.002, anchor, Arg(1) )

-- Only 0, 1, and whitespace characters
-- are valid in a binary string; found "&1".
15.004: Syntax( 15.004, anchor, source[line][col + bad] )

--------------------------------------------------------------------------------
-- HEXADECIMAL STRINGS                                                        --
--------------------------------------------------------------------------------

HexString:
  If DataType(string, "X") Then Do
    Call Element .EL.HEX_STRING, col + length + 1
    Return
  End

  -- The DATATYPE function has complained: determine the cause of the error

  bad = Verify(string, .String~XDigit || whitespace)
  If bad \== 0 Then Signal 15.003

  If Pos(string[1],      whitespace) > 0 Then Call 15.001 1
  length = Length(string)
  If Pos(string[length], whitespace) > 0 Then Call 15.001 length

  Signal 15.005

-- Incorrect location of whitespace character
-- in position &1 in hexadecimal string.
15.001: Syntax( 15.001, anchor, Arg(1) )

-- Only 0-9, a-f, A-F, and whitespace characters are valid in
-- a hexadecimal string; found "&1".
15.003: Syntax( 15.003, anchor, source[line][col + bad])

-- Hexadecimal strings must be grouped in units
-- that are multiples of two characters.
15.005: Syntax( 15.005, anchor )

--------------------------------------------------------------------------------
-- CheckUTF8: Check that currentline[col, length] is valid UTF8
--------------------------------------------------------------------------------

CheckUTF8:
  bad = Well.Formed.UTF8( currentline[col, length] )
  If bad == "" Then Return .True
  Signal 22.001

-- Incorrect character string "&1" ('&2'X).
22.001: Syntax( 22.001, anchor, bad, C2X(bad) )

--------------------------------------------------------------------------------
-- CheckUnicode: Check that currentline[col, length] is a valid U string
--------------------------------------------------------------------------------

CheckUnicode:
  array = Well.Formed.UString( currentline[col+1, length-2] )
  bad = array[1]
  If bad == "" Then Return array[2]
  Signal 22.900

-- "bad" is the error message returned by the Well.Formed.UString routine

-- &1.
22.900: Syntax( 22.900, anchor, bad )

--------------------------------------------------------------------------------

Element:
  sourceString = source[line][col, Arg(2)-col]

  self~append(                                                             -
    .StringOrSymbol.Element~new( Arg(1), line, col, Arg(2), source[line] ) -
  )

  Exit

UString:
  sourceString = source[line][col, Arg(2)-col]

  self~append(                                             -
    .UString.Element~new( Arg(1), line, col, Arg(2), source[line], Arg(3) ) -
  )

  Exit

/******************************************************************************/
/*                                                                            */
/* insertAfter -- Insert an element after another element which is not        */
/*                the tail (use append in that case)                          */
/*                                                                            */
/******************************************************************************/

::Method insertAfter
  Use Strict Arg element, new

  new~next      = element~next
  new~prev      = element

  element~next  = new
  new~next~prev = new

/******************************************************************************/
/*                                                                            */
/* insertBefore -- Insert an element before another element which is not      */
/*                 the head                                                   */
/*                                                                            */
/******************************************************************************/

::Method insertBefore
  Use Strict Arg element, new

  new~next          = element
  new~prev          = element~prev

  element~prev~next = new
  element~prev      = new

/******************************************************************************/
/*                                                                            */
/* append -- Append an element to the end of the element chain                */
/*                                                                            */
/******************************************************************************/

::Method append
  Expose tail line col

  Use Strict Arg element

  -- Insert the element into the chain

  tail~next    = element                -- tail~next was .Nil
  element~prev = tail                   --

  -- Update tail

  tail         = element

  -- Update line and col

  Parse Value tail~to With line col