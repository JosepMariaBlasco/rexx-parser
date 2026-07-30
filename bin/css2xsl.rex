#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* css2xsl.rex - Generate XSL templates for DocBook Rexx highlighting         */
/* ==================================================================         */
/*                                                                            */
/* Reads a Rexx highlighting CSS style (e.g. rexx-print.css) and generates    */
/* an XSL stylesheet with fo:inline templates for the <phrase role="rx-...">  */
/* elements emitted by the DocBook driver.  The generated .xsl is meant to    */
/* be xsl:include'd from the pdf.xsl customization layer used by DocBook XSL  */
/* + Apache FOP.                                                              */
/*                                                                            */
/* Each template matches a token by its role, restricted to listings that     */
/* carry this style on their container:                                       */
/*                                                                            */
/*   <xsl:template match="phrase[@role='rx-kw']                               */
/*     [ancestor::programlisting                                              */
/*        [contains(concat(' ',@role,' '),' highlight-rexx-print ')]]">       */
/*                                                                            */
/* That restriction is what lets one document mix several styles: the token   */
/* markup is identical everywhere, and the container decides which set of     */
/* templates applies.  The concat/contains idiom is the standard way to test  */
/* for a single whitespace-separated token inside an attribute; a bare        */
/* contains() would also match a longer style name starting with this one.    */
/*                                                                            */
/* Only the token templates live here.  The block background is set by the    */
/* caller (hldocprep) in the glue file, which redefines the DocBook           */
/* shade.verbatim.style attribute set once for all styles at once.            */
/*                                                                            */
/* Usage:                                                                     */
/*   css2xsl [options] [output.xsl]                                           */
/*                                                                            */
/* Options:                                                                   */
/*   -s, --style STYLE    CSS style name (default: print)                     */
/*       --css FILE       CSS file path (overrides --style)                   */
/*       --operator MODE  Operator granularity: group|full|detail             */
/*       --special MODE   Special char granularity: group|full|detail         */
/*       --constant MODE  Constant granularity: group|full|detail             */
/*       --assignment MODE Assignment granularity: group|full|detail          */
/*   -h, --help           Show this help                                      */
/*                                                                            */
/* Granularity modes:                                                         */
/*   group  - All elements in a category share the generic class colour.      */
/*   detail - Each element gets its own specific colour.                      */
/*   full   - Elements get both generic and specific classes (CSS cascade).   */
/*                                                                            */
/* Default granularity is "group" for all categories, meaning operators       */
/* share one colour, specials share one colour, etc.                          */
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
/* 20260401    0.5  First version                                             */
/* 20260729    0.6  Match phrase/@role instead of rexx_STYLE_* elements.      */
/*                  Block background moved to the glue file's                 */
/*                  shade.verbatim.style; Tags2Element/StripPrefix removed.   */
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

  CLIhelper    = InitCLI()
  myName       = CLIhelper~name
  myHelp       = CLIhelper~help
  args         = CLIhelper~args

/******************************************************************************/
/* Parse command-line options                                                 */
/******************************************************************************/

  style       = "print"
  cssFile     = ""
  opOperator  = "group"
  opSpecial   = "group"
  opConstant  = "group"
  opAssignment= "group"
  outputFile  = ""

  validModes  = "group full detail"

  Loop While args~size > 0, args[1][1] == "-"
    option = args[1]
    args~delete(1)

    Select Case Lower(option)
      When "-h", "--help"      Then Signal Help
      When "-s", "--style"     Then Do
        If args~size == 0 Then
          Call Error "Missing style after '"option"' option."
        style = args[1]
        args~delete(1)
      End
      When "--css"             Then Do
        If args~size == 0 Then
          Call Error "Missing file after '"option"' option."
        cssFile = args[1]
        args~delete(1)
      End
      When "--operator"        Then Do
        If args~size == 0 Then
          Call Error "Missing mode after '"option"' option."
        opOperator = Lower(args[1])
        args~delete(1)
        If WordPos(opOperator, validModes) == 0 Then
          Call Error "Invalid operator mode '"opOperator"'." -
            "Use group, full, or detail."
      End
      When "--special"         Then Do
        If args~size == 0 Then
          Call Error "Missing mode after '"option"' option."
        opSpecial = Lower(args[1])
        args~delete(1)
        If WordPos(opSpecial, validModes) == 0 Then
          Call Error "Invalid special mode '"opSpecial"'." -
            "Use group, full, or detail."
      End
      When "--constant"        Then Do
        If args~size == 0 Then
          Call Error "Missing mode after '"option"' option."
        opConstant = Lower(args[1])
        args~delete(1)
        If WordPos(opConstant, validModes) == 0 Then
          Call Error "Invalid constant mode '"opConstant"'." -
            "Use group, full, or detail."
      End
      When "--assignment"      Then Do
        If args~size == 0 Then
          Call Error "Missing mode after '"option"' option."
        opAssignment = Lower(args[1])
        args~delete(1)
        If WordPos(opAssignment, validModes) == 0 Then
          Call Error "Invalid assignment mode '"opAssignment"'." -
            "Use group, full, or detail."
      End
      Otherwise
        Call Error "Unknown option '"option"'. Use --help for usage."
    End
  End

  -- Remaining argument is the output file
  If args~size > 0 Then Do
    outputFile = args[1]
    args~delete(1)
  End
  If args~size > 0 Then
    Call Error "Too many arguments. Use --help for usage."

  -- Default output file
  If outputFile == "" Then outputFile = "rexx-highlight.xsl"

/******************************************************************************/
/* Resolve the CSS file path                                                  */
/******************************************************************************/

  myPath = FileSpec("Location", .context~package~name)

  If cssFile \== "" Then Do
    -- Explicit CSS file: use as-is (GetHighlight will validate)
    style = cssFile
  End

/******************************************************************************/
/* Build HTMLClasses mapping with the requested granularity                   */
/******************************************************************************/

  hlOptions. = ""
  hlOptions.operator   = opOperator
  hlOptions.special    = opSpecial
  hlOptions.constant   = opConstant
  hlOptions.assignment = opAssignment
  hlOptions.classprefix = "rx-"

  HTMLClass. = HTMLClasses( hlOptions. )

/******************************************************************************/
/* Collect all unique CSS class combinations from HTMLClasses                 */
/******************************************************************************/

  -- We need to collect all unique CSS class strings.  Each one becomes
  -- the @role of a <phrase> in the highlighted DocBook, so the class
  -- string is used verbatim as the match key -- no name mangling.
  --
  -- We skip whitespace ("rx-ws") since the DocBook driver emits it
  -- as plain text without a wrapper element.

  classSet    = .Set~new      -- Tracks unique CSS class strings
  elements    = .Array~new    -- Array of directories: name, tags

  supplier = HTMLClass.~supplier
  Do While supplier~available
    tags = supplier~item
    supplier~next

    -- Skip the default entry and empty values
    If tags == "rexx" Then Iterate
    If tags == ""     Then Iterate

    -- Skip whitespace (emitted as plain text by the driver)
    If tags == "rx-ws"   Then Iterate

    -- Skip duplicates
    If classSet~hasIndex(tags) Then Iterate
    classSet~put(tags)

    entry       = .Directory~new
    entry~name  = tags
    entry~tags  = tags
    elements~append(entry)
  End

/******************************************************************************/
/* Add compound number elements                                               */
/******************************************************************************/

  -- The Highlighter emits compound tags for number sub-parts by
  -- concatenating the parent tag (e.g. "rx-int") with the child tag
  -- (e.g. "rx-ipart"), producing "rx-int rx-ipart".  These compound
  -- tags are converted to element names like "rexx_int_ipart" by the
  -- DocBook driver, but the loop above only sees them as individual
  -- entries.  We generate all valid parent+child combinations here.
  --
  -- The parent is one of: int, deci, exp, or any string type.
  -- The children depend on the number type:
  --   int:  nsign, ipart
  --   deci: nsign, ipart, dpoint, fpart
  --   exp:  nsign, ipart, dpoint, fpart, emark, esign, expon
  --
  -- When a number appears inside a string (e.g. "3.14"), the
  -- Highlighter uses the string type as the parent (str, bstr,
  -- xstr, etc.).  A number inside a string can have all the same
  -- sub-parts as an exponential number, so each string type gets
  -- the full set of children.

  prefix = hlOptions.classprefix

  numberCombinations = .Array~of(  -
    "int  nsign",                  -
    "int  ipart",                  -
    "deci nsign",                  -
    "deci ipart",                  -
    "deci dpoint",                 -
    "deci fpart",                  -
    "exp  nsign",                  -
    "exp  ipart",                  -
    "exp  dpoint",                 -
    "exp  fpart",                  -
    "exp  emark",                  -
    "exp  esign",                  -
    "exp  expon"                   -
  )

  -- Numbers inside strings: each string type can contain a full
  -- number (with all sub-parts).  The string types are defined
  -- in HTMLClasses.cls.
  stringTypes = .Array~of( -
    "str", "bstr", "xstr", "ystr", "pstr", "gstr", "tstr", "ustr" -
  )
  numberChildren = .Array~of( -
    "nsign", "ipart", "dpoint", "fpart", -
    "emark", "esign", "expon"            -
  )
  Do strType Over stringTypes
    Do child Over numberChildren
      numberCombinations~append(strType "  " child)
    End
  End

  Do combo Over numberCombinations
    Parse Var combo parent child
    child = child~strip
    tags = prefix || parent" "prefix || child

    If classSet~hasIndex(tags) Then Iterate
    classSet~put(tags)

    entry       = .Directory~new
    entry~name  = tags
    entry~tags  = tags
    elements~append(entry)
  End

/******************************************************************************/
/* Look up visual properties and generate the XSL                             */
/******************************************************************************/

  -- Sort elements by name for predictable output
  elements = elements~sortWith(.ElementComparator~new)

  -- Collect all templates
  templates = .Array~new

  Do entry Over elements
    tags = entry~tags

    -- Look up visual properties via GetHighlight
    Parse Value GetHighlight(style, tags) -
      With bold italic underline color":"background

    -- Build the fo:inline attributes
    foAttrs = BuildFOAttrs(bold, italic, underline, color, background)

    -- Skip elements with no visual differentiation
    If foAttrs == "" Then Iterate

    templates~append( BuildTemplate(tags, style, foAttrs) )
  End

  -- Generate the complete XSL file.  The block background is NOT set
  -- here: it belongs to the glue file, which redefines DocBook's
  -- shade.verbatim.style once for every style in use.  Doing it per
  -- style file would mean several definitions of the same attribute
  -- set, and only the last one would survive the merge.
  xslContent = BuildXSL(templates, style, -
    opOperator, opSpecial, opConstant, opAssignment)

/******************************************************************************/
/* Write the output file                                                      */
/******************************************************************************/

  -- Delete any previous version to avoid leftovers from CharOut
  If Stream(outputFile, "C", "Q Exists") \== "" Then
    Call SysFileDelete outputFile

  Call CharOut outputFile, xslContent
  Call CharOut outputFile  -- Close the stream

  Say myName": generated" outputFile -
    "("templates~items "templates from style '"style"')."

  Exit 0

/******************************************************************************/
/* BUILDFOSTRS: Build fo:inline attribute string from visual properties       */
/******************************************************************************/

BuildFOAttrs: Procedure
  Use Strict Arg bold, italic, underline, color, background

  attrs = ""

  If bold      == "B" Then attrs ||= ' font-weight="bold"'
  If italic    == "I" Then attrs ||= ' font-style="italic"'
  If underline == "U" Then attrs ||= ' text-decoration="underline"'

  If color \== "" Then Do
    -- Colors from GetHighlight are RRGGBBaa (8 hex chars with alpha).
    -- We take the first 6 hex chars for the #RRGGBB value.
    hex = Left(color, 6)
    If hex~length == 6, hex~dataType("X") Then
      attrs ||= ' color="#'hex'"'
  End

  -- We don't emit background-color for inline elements in FOP;
  -- the programlisting already has a background set by the DocBook XSL.

  Return attrs

/******************************************************************************/
/* BUILDTEMPLATE: Generate one XSL match template                             */
/******************************************************************************/
/*                                                                            */
/* Matches a token by its role, restricted to listings whose container        */
/* carries this style.  Testing for a whitespace-delimited token rather       */
/* than a bare substring matters: "vim-dark-blue" is a prefix of              */
/* "vim-dark-blue2", and contains() alone would match both.                   */
/*                                                                            */
/******************************************************************************/

BuildTemplate: Procedure
  Use Strict Arg tags, style, foAttrs

  q = "'"

  container = "ancestor::programlisting[contains(concat(" || -
              q" "q",@role,"q" "q")," || -
              q" highlight-rexx-"style" "q")]"

  Return '  <xsl:template match="phrase[@role='q||tags||q']['container']">' || -
                                                  "0A"x || -
         '    <fo:inline'foAttrs'>'               ||     "0A"x || -
         '      <xsl:apply-templates/>'           ||     "0A"x || -
         '    </fo:inline>'                       ||     "0A"x || -
         '  </xsl:template>'

/******************************************************************************/
/* BUILDXSL: Generate the complete XSL file                                   */
/******************************************************************************/

BuildXSL: Procedure
  Use Strict Arg templates, style, -
    opOperator, opSpecial, opConstant, opAssignment

  nl = "0A"x

  xsl = '<?xml version="1.0" encoding="UTF-8"?>'                    || nl
  xsl ||= "<!--"                                                    || nl
  xsl ||= "  rexx-highlight.xsl — XSL templates for Rexx syntax"    || nl
  xsl ||= "  highlighting in DocBook/FOP output."                   || nl
  xsl ||= ""                                                        || nl
  xsl ||= "  Generated by css2xsl.rex from style '"style"'."        || nl
  xsl ||= "  Options: operator="opOperator "special="opSpecial     -
           " constant="opConstant " assignment="opAssignment        || nl
  xsl ||= ""                                                        || nl
  xsl ||= "  Token templates only.  The block background for this"  || nl
  xsl ||= "  style is set by the glue file, which redefines the"    || nl
  xsl ||= "  shade.verbatim.style attribute set for every style"    || nl
  xsl ||= "  at once."                                              || nl
  xsl ||= ""                                                        || nl
  xsl ||= "  Include this file in your pdf.xsl customization:"      || nl
  xsl ||= '    <xsl:include href="rexx-highlight.xsl"/>'            || nl
  xsl ||= "-->"                                                     || nl
  xsl ||= ""                                                        || nl
  xsl ||= '<xsl:stylesheet version="1.0"'                           || nl
  xsl ||= '  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"'      || nl
  xsl ||= '  xmlns:fo="http://www.w3.org/1999/XSL/Format">'         || nl
  xsl ||= ""                                                        || nl

  Do t Over templates
    xsl ||= t || nl
    xsl ||= ""  || nl
  End

  xsl ||= "</xsl:stylesheet>" || nl

  Return xsl

/******************************************************************************/
/* ERROR, HELP, SYNTAX handlers                                               */
/******************************************************************************/

Error:
  Say myName":" Arg(1)
  Exit 1

Help:
  Say ""
  Say "Usage:" myName "[options] [output.xsl]"
  Say ""
  Say "Options:"
  Say "  -s, --style STYLE     CSS style (default: print)"
  Say "      --css FILE        CSS file path (overrides --style)"
  Say "      --operator MODE   group|full|detail (default: group)"
  Say "      --special MODE    group|full|detail (default: group)"
  Say "      --constant MODE   group|full|detail (default: group)"
  Say "      --assignment MODE group|full|detail (default: group)"
  Say "  -h, --help            Show this help"
  Say ""
  Say "See:" myHelp
  Exit 0

Syntax:
  co = Condition("O")
  Say myName": Error" co~rc "running" co~position":" co~message
  Exit 1

/******************************************************************************/
/* Comparator for sorting elements by name                                    */
/******************************************************************************/

::Class ElementComparator Public
::Method compare
  Use Strict Arg left, right
  Return left~name~compareTo(right~name)

/******************************************************************************/
/* Required packages                                                          */
/******************************************************************************/

::Requires "CLISupport.cls"
::Requires "HTMLClasses.cls"
::Requires "StyleSheet.cls"