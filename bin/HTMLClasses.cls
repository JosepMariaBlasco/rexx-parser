/******************************************************************************/
/*                                                                            */
/* HTMLClasses.cls - element category/subcategory to html class translation   */
/* ========================================================================   */
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
/* 20241208    0.1a c/CLASSIC_COMMENT/STANDARD_COMMENT/                       */
/* 20241209    0.1b Add shebang support                                       */
/*                  New call system                                           */
/* 20241225    0.1d Add doc-comment support                                   */
/* 20250103    0.1e Add TUTOR-flavored Unicode classes                        */
/* 20250116    0.1f Add support for EL.SUBKEYWORD                             */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250406         Rename fractional numbers to decimal                      */
/* 20250528    0.2c Add support for detailed string highlighting              */
/* 20250630    0.2d Add support for doc-comment subelements                   */
/* 20250722         Add "dskw" for .EL.DIRECTIVE_SUBKEYWORD                   */
/* 20251213         Add support for curly brackets and argument names         */
/*                                                                            */
/******************************************************************************/

::Routine HTMLClasses Public

--
-- ARGUMENT
-- --------
--
--   "Options.", a stem.
--

  Use Strict Arg Options.

--
-- The following tails are examined:
--
-- * Options.assignment,
--     for (extended) assignment operator characters and character sequences.
-- * Options.constant,
--     for strings or symbols taken as a constant.
-- * Options.operator,
--     for operator characters and operator character sequences.
-- * Options.special,
--     for special characters and special character sequences.
-- * Options.classprefix,
--     a prefix prepended to every HTML class. Default is "".
--
-- The code assigns one or two HTML classes to every element category, and,
-- in the case of symbols taken as a constant, to every element subcategory.
--
-- When two classes are assigned, the first one is generic (for instance,
-- "spe" for special characters), and the second one identifies the
-- corresponding element (for example, "comma", or "colon").
--
-- The value of the corresponding compound variables determine the class
-- associated with every element category and subcategory,
-- in the following way:
--
-- * When the value is "group", only the generic class is assigned.
-- * When the value is "detail", only the detailed class is assigned.
-- * When the value is "full", two classes are assigned, the generic
--   one and the detailed one (in this order).
--
-- RETURNS
-- -------
--
-- A stem ("HTMLClass") mapping element categories and subcategories to html
-- classes. The default HTML class is "rexx".
--

  prefix      = options.classprefix

  HTMLClass   = .Stem~new  --
  HTMLClass[] = "rexx"     -- The default HTML class is 'rexx'

--
-- We will assign HTML classes to a number of element categories
-- using the "Assign" internal routine.
--
-- We include it here and skip over its code for readability.
--
--------------------------------------------------------------------------------

  Signal SkipOverAssign

Assign:
  value = ""                            -- An accumulator
  classes = Arg(2)~makeArray(" ")
  Do Counter c class Over classes
    If c > 1 Then value ||= " "
    value ||= prefix || class           -- Prepend the prefix to each class
  End
  HTMLClass[ Arg(1) ] = value
Return

SkipOverAssign:

/******************************************************************************/
/* SHEBANGS                                                                   */
/******************************************************************************/

  Call Assign   .EL.SHEBANG,                     "shb"

/******************************************************************************/
/* SYMBOLS                                                                    */
/******************************************************************************/

--------------------------------------------------------------------------------
-- Keywords                                                                   --
--------------------------------------------------------------------------------
--
-- Directive keywords and subkeywordshave a special element category, different
-- from instruction keywords, and, correspondingly, they can be assigned
-- a different HTML class, if so desired.
--

  Call Assign   .EL.KEYWORD,                     "kw"
  Call Assign   .EL.SUBKEYWORD,                  "skw"
  Call Assign   .EL.DIRECTIVE_KEYWORD,           "dkw"
  Call Assign   .EL.DIRECTIVE_SUBKEYWORD,        "dskw"

--------------------------------------------------------------------------------
-- Variables                                                                  --
--------------------------------------------------------------------------------
--
-- The parser is able to differentiate exposed (instance) variables from
-- local variables.
--

  Call Assign   .EL.SIMPLE_VARIABLE,             "var"
  Call Assign   .EL.COMPOUND_VARIABLE,           "cmp"
  Call Assign   .EL.STEM_VARIABLE,               "stem"

  Call Assign   .EL.EXPOSED_SIMPLE_VARIABLE,     "xvar"
  Call Assign   .EL.EXPOSED_COMPOUND_VARIABLE,   "xcmp"
  Call Assign   .EL.EXPOSED_STEM_VARIABLE,       "xstem"

--------------------------------------------------------------------------------
-- Environment symbols                                                        --
--------------------------------------------------------------------------------

  Call Assign   .EL.ENVIRONMENT_SYMBOL,          "env"

--------------------------------------------------------------------------------
-- Pure constant symbols                                                      --
--------------------------------------------------------------------------------
--
-- That is, constant symbols that are not environment symbols or numbers
--
-- .EL.PERIOD is used when parsing PARSE templates. By default, its
-- highlighting is the same as other symbol literals.
--

  Call Assign   .EL.SYMBOL_LITERAL,              "lit"
  Call Assign   .EL.PERIOD,                      "lit"

/******************************************************************************/
/* COMMENTS AND DOC-COMMENTS                                                  */
/******************************************************************************/

  Call Assign   .EL.LINE_COMMENT,                "lncm"
  Call Assign   .EL.DOC_COMMENT_MARKDOWN,        "doc-comment-markdown"
  Call Assign   .EL.STANDARD_COMMENT,            "cm"
  Call Assign   .EL.DOC_COMMENT,                 "doc-comment"


  Signal SkipOverDocComms

DocComms:
  Call Assign Arg(1), Arg(2)

  pa2  = prefix||Arg(2)
  doc1 = prefix"doc-comment"
  doc2 = prefix"doc-comment-markdown"

  HTMLClass[ .EL.DOC_COMMENT,          Arg(1)   ] = doc1 pa2
  HTMLClass[ .EL.DOC_COMMENT_MARKDOWN, Arg(1)   ] = doc2 pa2

  Return

SkipOverDocComms:

  Call DocComms .EL.DOC_COMMENT_ARMATURE,        "doc-comment-armature"
  Call DocComms .EL.DOC_COMMENT_WHITESPACE,      "doc-comment-whitespace"
  Call DocComms .EL.DOC_COMMENT_SUMMARY,         "doc-comment-summary"
  Call DocComms .EL.DOC_COMMENT_MAIN_DESCRIPTION,"doc-comment-main-description"
  Call DocComms .EL.DOC_COMMENT_TAG,             "doc-comment-tag"
  Call DocComms .EL.DOC_COMMENT_TAG_VALUE,       "doc-comment-tag-value"
  Call DocComms .EL.DOC_COMMENT_TAG_DESCRIPTION, "doc-comment-tag-description"

/******************************************************************************/
/* RESOURCES                                                                  */
/******************************************************************************/
--
-- See also the .RESOURCE.NAME and .RESOURCE.DELIMITER.NAME
-- subcategories below.
--

  Call Assign   .EL.RESOURCE_DATA,               "res-data"
  Call Assign   .EL.RESOURCE_IGNORED_DATA,       "res-ignore"

/******************************************************************************/
/* WHITESPACE AND CONTINUATIONS                                               */
/******************************************************************************/

  Call Assign   .EL.WHITESPACE,                  "ws"
  Call Assign   .EL.CONTINUATION,                "cont"

/******************************************************************************/
/* OPERATORS                                                                  */
/******************************************************************************/

  Signal SkipOverOperator

Operator:
  Select Case Options.operator
    When "group"  Then Call Assign Arg(1), "op"
    When "full"   Then Call Assign Arg(1), "op" Arg(2)
    When "detail" Then Call Assign Arg(1), Arg(2)
  End
Return

SkipOverOperator:

--------------------------------------------------------------------------------
-- Single-character operators                                                 --
--------------------------------------------------------------------------------

  Call Operator .EL.OP.AND,                      "and"
  Call Operator .EL.OP.DIVISION,                 "div"
  Call Operator .EL.OP.EQUAL,                    "eq"
  Call Operator .EL.OP.GREATER_THAN,             "gt"
  Call Operator .EL.OP.INTEGER_DIVISION,         "idiv"
  Call Operator .EL.OP.LOWER_THAN,               "lt"
  Call Operator .EL.OP.MINUS,                    "sub"
  Call Operator .EL.OP.MESSAGE,                  "msg"
  Call Operator .EL.OP.MULTIPLICATION,           "mul"
  Call Operator .EL.OP.NEGATION,                 "not"
  Call Operator .EL.OP.OR,                       "or"
  Call Operator .EL.OP.PLUS,                     "add"
  Call Operator .EL.OP.REFERENCE.LOWER_THAN,     "ref-lt"
  Call Operator .EL.OP.REFERENCE.GREATER_THAN,   "ref-gt"

--------------------------------------------------------------------------------
-- Prefix operators                                                           --
--------------------------------------------------------------------------------
--
-- "\" is always a prefix operator
--

  Call Operator .EL.OP.PREFIX.MINUS,             "prf-sub"
  Call Operator .EL.OP.PREFIX.PLUS,              "prf-add"

--------------------------------------------------------------------------------
-- Multi-character operator sequences                                         --
--------------------------------------------------------------------------------
--
-- There may be some whitespace, comments and continuations inside
-- the sequence; only the relevant characters will be tagged.
--

  Call Operator .EL.OP.CASCADING_MESSAGE,        "cmsg"
  Call Operator .EL.OP.CONCATENATION,            "cat"
  Call Operator .EL.OP.GREATER_OR_EQUAL,         "ge"
  Call Operator .EL.OP.GREATER_OR_LOWER_THAN,    "glt"
  Call Operator .EL.OP.LOWER_OR_EQUAL,           "le"
  Call Operator .EL.OP.LOWER_OR_GREATER_THAN,    "lgt"
  Call Operator .EL.OP.NOT_GREATER_THAN,         "ngt"
  Call Operator .EL.OP.NOT_LOWER_THAN,           "nlt"
  Call Operator .EL.OP.NOT_EQUAL,                "ne"
  Call Operator .EL.OP.POWER,                    "pow"
  Call Operator .EL.OP.REMAINDER,                "rem"
  Call Operator .EL.OP.XOR,                      "xor"

--------------------------------------------------------------------------------
-- Strict comparison operator sequences                                       --
--------------------------------------------------------------------------------
--
-- All are multi-character
--

  Call Operator .EL.OP.STRICT.LOWER_THAN,        "st-lt"
  Call Operator .EL.OP.STRICT.GREATER_OR_EQUAL,  "st-ge"
  Call Operator .EL.OP.STRICT.GREATER_THAN,      "st-gt"
  Call Operator .EL.OP.STRICT.NOT_EQUAL,         "st-ne"
  Call Operator .EL.OP.STRICT.NOT_LOWER_THAN,    "st-nlt"
  Call Operator .EL.OP.STRICT.NOT_GREATER_THAN,  "st-ngt"
  Call Operator .EL.OP.STRICT.LOWER_OR_EQUAL,    "st-le"
  Call Operator .EL.OP.STRICT.EQUAL,             "st-eq"

--------------------------------------------------------------------------------
-- Blank concatenation                                                        --
--------------------------------------------------------------------------------
--
-- The abuttal operator is zero-length, but blank concatenation is not.
--

  Call Operator .EL.OP.BLANK,                    "blank"

/******************************************************************************/
/* ASSIGNMENTS                                                                */
/******************************************************************************/

  Signal SkipOverAssignment

Assignment:
  Select Case Options.assignment
    When "group"  Then Call Assign Arg(1), "asg"
    When "full"   Then Call Assign Arg(1), "asg" Arg(2)
    When "detail" Then Call Assign Arg(1), Arg(2)
  End
Return

SkipOverAssignment:

--------------------------------------------------------------------------------

  Call Assignment .EL.ASG.EQUAL,                 "asg-equal"

  Call Assignment .EL.ASG.PLUS,                  "asg-add"
  Call Assignment .EL.ASG.MINUS,                 "asg-sub"
  Call Assignment .EL.ASG.MULTIPLY,              "asg-mul"
  Call Assignment .EL.ASG.DIVIDE,                "asg-div"
  Call Assignment .EL.ASG.INTEGER_DIVISION,      "asg-idiv"
  Call Assignment .EL.ASG.AND,                   "asg-and"
  Call Assignment .EL.ASG.OR,                    "asg-or"
  Call Assignment .EL.ASG.REMAINDER,             "asg-rem"
  Call Assignment .EL.ASG.CONCATENATION,         "asg-cat"
  Call Assignment .EL.ASG.XOR,                   "asg-xor"
  Call Assignment .EL.ASG.POWER,                 "asg-pow"

/******************************************************************************/
/* SPECIAL CHARACTERS                                                         */
/******************************************************************************/

  Signal SkipOverSpecial

Special:
  Select Case Options.special
    When "group"  Then Call Assign Arg(1), "spe"
    When "full"   Then Call Assign Arg(1), "spe" Arg(2)
    When "detail" Then Call Assign Arg(1), Arg(2)
  End
Return

SkipOverSpecial:

--------------------------------------------------------------------------------

  Call Special .EL.COMMA,                        "comma"
  Call Special .EL.COLON,                        "colon"
  Call Special .EL.LEFT_PARENTHESIS,             "paren"
  Call Special .EL.RIGHT_PARENTHESIS,            "paren"
  Call Special .EL.LEFT_BRACKET,                 "bracket"
  Call Special .EL.RIGHT_BRACKET,                "bracket"
  Call Special .EL.LEFT_CURLY_BRACKET,           "curly"
  Call Special .EL.RIGHT_CURLY_BRACKET,          "curly"

--
-- Directive start. Although technically this is a sequence of special
-- characters, we assign a new class using "Assign" instead of "Special",
-- since we will probably want to highlight "::" differently from other
-- specials and special .
--

  Call Assign  .EL.DIRECTIVE_START,              "dir"

-- The period as a compound variable tail separator is a pseudo-special, ...

  Call Special .EL.TAIL_SEPARATOR,               "period"

  -- ... as is the "..." construct at the end of an argument list.

  Call Special .EL.ELLIPSIS,                     "ellipsis"

/******************************************************************************/
/* NUMBERS                                                                    */
/******************************************************************************/

--------------------------------------------------------------------------------
-- Numbers                                                                    --
--------------------------------------------------------------------------------

  Call Assign   .EL.EXPONENTIAL_NUMBER,          "exp"
  Call Assign   .EL.DECIMAL_NUMBER,              "deci"
  Call Assign   .EL.INTEGER_NUMBER,              "int"

  Call Assign   .EL.NUMBER_SIGN,                 "nsign"
  Call Assign   .EL.INTEGER_PART,                "ipart"
  Call Assign   .EL.DECIMAL_POINT,               "dpoint"
  Call Assign   .EL.FRACTIONAL_PART,             "fpart"
  Call Assign   .EL.EXPONENT_MARK,               "emark"
  Call Assign   .EL.EXPONENT_SIGN,               "esign"
  Call Assign   .EL.EXPONENT,                    "expon"

/******************************************************************************/
/* STRINGS                                                                    */
/******************************************************************************/

  Call String   .EL.BINARY_STRING,               "bstr"
  Call String   .EL.STRING,                      "str"
  Call String   .EL.HEX_STRING,                  "xstr"
  Call String   .EL.BYTES_STRING,                "ystr"
  Call String   .EL.CODEPOINTS_STRING,           "pstr"
  Call String   .EL.GRAPHEMES_STRING,            "gstr"
  Call String   .EL.TEXT_STRING,                 "tstr"
  Call String   .EL.UNICODE_STRING,              "ustr"

  Signal SkipOverStrings

String:
  Call Assign Arg(1), Arg(2)
  pa2 = prefix||Arg(2)

  HTMLClass[ Arg(1), .EL.STRING_OPENING_DELIMITER ] = pa2 prefix"oquo"
  HTMLClass[ Arg(1), .EL.STRING_CLOSING_DELIMITER ] = pa2 prefix"cquo"
  HTMLClass[ Arg(1), .EL.STRING_SUFFIX            ] = pa2 prefix"ssuf"

  Return

SkipOverStrings:

  HTMLClass[ .EL.STRING_OPENING_DELIMITER ] = prefix"oquo"
  HTMLClass[ .EL.STRING_CLOSING_DELIMITER ] = prefix"cquo"
  HTMLClass[ .EL.STRING_SUFFIX            ] = prefix"ssuf"


/******************************************************************************/
/* STRINGS OR SYMBOLS TAKEN AS A CONSTANT                                     */
/******************************************************************************/

  Signal SkipOverConstant

Constant:
  Select Case Options.["CONSTANT"]
    When "group"  Then value = prefix"const"
    When "full"   Then value = prefix"const" prefix||Arg(2)
    When "detail" Then value = prefix||Arg(2)
  End
  HTMLClass[ constant, Arg(1) ] = value

  open   = .EL.STRING_OPENING_DELIMITER
  close  = .EL.STRING_CLOSING_DELIMITER
  suffix = .EL.STRING_SUFFIX

  HTMLClass[ constant, Arg(1), open   ] = value prefix"oquo"
  HTMLClass[ constant, Arg(1), close  ] = value prefix"cquo"
  HTMLClass[ constant, Arg(1), suffix ] = value prefix"ssuf"

Return

SkipOverConstant:

--------------------------------------------------------------------------------

  constant = .EL.TAKEN_CONSTANT

-- Function and subroutine call constants

  Call Constant .INTERNAL.FUNCTION.NAME,           "int-func"
  Call Constant .INTERNAL.SUBROUTINE.NAME,         "int-proc"
  Call Constant .BUILTIN.FUNCTION.NAME,            "bif-func"
  Call Constant .BUILTIN.SUBROUTINE.NAME,          "bif-proc"
  Call Constant .PACKAGE.FUNCTION.NAME,            "pkg-func"
  Call Constant .PACKAGE.SUBROUTINE.NAME,          "pkg-proc"
  Call Constant .EXTERNAL.PACKAGE.FUNCTION.NAME,   "ext-pkg-func"
  Call Constant .EXTERNAL.PACKAGE.SUBROUTINE.NAME, "ext-pkg-func"
  Call Constant .EXTERNAL.FUNCTION.NAME,           "ext-func"
  Call Constant .EXTERNAL.SUBROUTINE.NAME,         "ext-proc"

-- Other constants

  Call Constant .ANNOTATION.NAME,                  "annotation"
  Call Constant .ARGUMENT.NAME,                    "argument-name"
  Call Constant .BLOCK.INSTRUCTION.NAME,           "block"
  Call Constant .CLASS.NAME,                       "class"
  Call Constant .ENVIRONMENT.NAME,                 "environment"
  Call Constant .LABEL.NAME,                       "label"
  Call Constant .METHOD.NAME,                      "method"
  Call Constant .NAMESPACE.NAME,                   "namespace"
  Call Constant .ROUTINE.NAME,                     "routine"
  Call Constant .REQUIRES.PROGRAM.NAME,            "requires"
  Call Constant .RESOURCE.NAME,                    "resource"
  Call Constant .RESOURCE.DELIMITER.NAME,          "res-delimiter"
  Call Constant .USER.CONDITION.NAME,              "user-condition"

  Call Constant .TABLE.FIELD.NAME,                 "table-field-name"

  Call Constant .ANNOTATION.VALUE,                 "annotation-value"
  Call Constant .CONSTANT.VALUE,                   "constant-value"

--------------------------------------------------------------------------------

Return HTMLClass