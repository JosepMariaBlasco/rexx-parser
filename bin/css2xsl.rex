#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* css2xsl.rex - Generate XSL templates for DocBook Rexx highlighting         */
/* ==================================================================         */
/*                                                                            */
/* Reads a Rexx highlighting CSS theme (e.g. rexx-print.css) and generates   */
/* an XSL stylesheet with fo:inline templates for all rexx_* elements.       */
/* The generated .xsl is meant to be xsl:include'd from the pdf.xsl         */
/* customization layer used by DocBook XSL + Apache FOP.                     */
/*                                                                            */
/* Usage:                                                                     */
/*   css2xsl [options] [output.xsl]                                          */
/*                                                                            */
/* Options:                                                                   */
/*   -s, --style STYLE    CSS theme name (default: print)                    */
/*       --css FILE       CSS file path (overrides --style)                   */
/*       --operator MODE  Operator granularity: group|full|detail             */
/*       --special MODE   Special char granularity: group|full|detail         */
/*       --constant MODE  Constant granularity: group|full|detail             */
/*       --assignment MODE Assignment granularity: group|full|detail          */
/*   -h, --help           Show this help                                     */
/*                                                                            */
/* Granularity modes:                                                         */
/*   group  - All elements in a category share the generic class color.       */
/*   detail - Each element gets its own specific color.                       */
/*   full   - Elements get both generic and specific classes (CSS cascade).   */
/*                                                                            */
/* Default granularity is "group" for all categories, meaning operators       */
/* share one color, specials share one color, etc.                           */
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
/* Build HTMLClasses mapping with the requested granularity                    */
/******************************************************************************/

  hlOptions. = ""
  hlOptions.operator   = opOperator
  hlOptions.special    = opSpecial
  hlOptions.constant   = opConstant
  hlOptions.assignment = opAssignment
  hlOptions.classprefix = "rx-"

  HTMLClass. = HTMLClasses( hlOptions. )

/******************************************************************************/
/* Collect all unique CSS class combinations from HTMLClasses                  */
/******************************************************************************/

  -- We need to collect all unique CSS class strings and, for each one,
  -- derive the DocBook element name and look up its visual properties.
  --
  -- The element name is derived from the CSS classes:
  --   - For single-class entries (e.g. "rx-kw"): rexx_kw
  --   - For multi-class entries (e.g. "rx-op rx-add"): rexx_add
  --     (the most specific class, i.e. the last one)
  --   - For TAKEN_CONSTANT compound entries with 3 classes
  --     (e.g. "rx-const rx-method rx-oquo"): rexx_method_oquo
  --     (specific class + variant)
  --
  -- We skip whitespace ("rx-ws") and continuation ("rx-cont") since
  -- they are structural, not highlighted in DocBook.

  classSet    = .Set~new      -- Tracks unique CSS class strings
  elements    = .Array~new    -- Array of directories: name, tags

  supplier = HTMLClass.~supplier
  Do While supplier~available
    tags = supplier~item
    supplier~next

    -- Skip the default entry and empty values
    If tags == "rexx" Then Iterate
    If tags == ""     Then Iterate

    -- Skip whitespace and continuation (structural, not visual)
    If tags == "rx-ws"   Then Iterate
    If tags == "rx-cont" Then Iterate

    -- Skip duplicates
    If classSet~hasIndex(tags) Then Iterate
    classSet~put(tags)

    -- Derive the DocBook element name from the CSS classes
    elementName = Tags2Element(tags, style)

    entry       = .Directory~new
    entry~name  = elementName
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
  -- The parent is one of: int, deci, exp.
  -- The children depend on the number type:
  --   int:  nsign, ipart
  --   deci: nsign, ipart, dpoint, fpart
  --   exp:  nsign, ipart, dpoint, fpart, emark, esign, expon

  prefix = hlOptions.classprefix

  numberCombinations = .Array~of( -
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

  Do combo Over numberCombinations
    Parse Var combo parent child
    child = child~strip
    tags = prefix || parent" "prefix || child

    If classSet~hasIndex(tags) Then Iterate
    classSet~put(tags)

    elementName = Tags2Element(tags, style)

    entry       = .Directory~new
    entry~name  = elementName
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
    elementName = entry~name
    tags        = entry~tags

    -- Look up visual properties via GetHighlight
    Parse Value GetHighlight(style, tags) -
      With bold italic underline color":"background

    -- Build the fo:inline attributes
    foAttrs = BuildFOAttrs(bold, italic, underline, color, background)

    -- Skip elements with no visual differentiation
    If foAttrs == "" Then Iterate

    templates~append( BuildTemplate(elementName, foAttrs) )
  End

  -- Get the block-level background and default text color from the
  -- "rexx" class.  This will be used to generate an XSL template for
  -- programlisting[@style='STYLE'] that sets the fo:block background.
  Parse Value GetHighlight(style, "rexx") -
    With . . . blockColor":"blockBackground

  -- Generate the complete XSL file
  xslContent = BuildXSL(templates, style, -
    opOperator, opSpecial, opConstant, opAssignment, -
    blockColor, blockBackground)

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
/* TAGS2ELEMENT: Convert CSS class string to DocBook element name              */
/******************************************************************************/
/*                                                                            */
/* Converts a CSS class string to a DocBook element name by stripping the    */
/* "rx-" prefix from each class, replacing "-" with "_", and joining them    */
/* with "_" under the "rexx_STYLE" prefix.                                   */
/*                                                                            */
/* The style name is always included in the element name for symmetry:       */
/*   Tags2Element("rx-kw", "print")  -> "rexx_print_kw"                     */
/*   Tags2Element("rx-op rx-add", "dark") -> "rexx_dark_op_add"             */
/*   Tags2Element("rx-const rx-method rx-oquo", "print")                    */
/*                                       -> "rexx_print_const_method_oquo"  */
/*                                                                            */
/******************************************************************************/

Tags2Element:
  Use Strict Arg cssTags, xslStyle

  words = cssTags~makeArray(" ")
  name  = "rexx_" || xslStyle~changeStr("-", "_")
  Do w Over words
    name ||= "_" || StripPrefix(w)~changeStr("-", "_")
  End
  Return name

/******************************************************************************/
/* STRIPPREFIX: Remove the "rx-" prefix from a CSS class name                 */
/******************************************************************************/

StripPrefix:
  Use Strict Arg className
  If className~caselessStartsWith("rx-") Then
    Return className~substr(4)
  Return className

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
/* BUILDTEMPLATE: Generate one XSL match template                              */
/******************************************************************************/

BuildTemplate: Procedure
  Use Strict Arg elementName, foAttrs

  Return '  <xsl:template match="'elementName'">' ||     "0A"x || -
         '    <fo:inline'foAttrs'>'               ||     "0A"x || -
         '      <xsl:apply-templates/>'           ||     "0A"x || -
         '    </fo:inline>'                       ||     "0A"x || -
         '  </xsl:template>'

/******************************************************************************/
/* BUILDXSL: Generate the complete XSL file                                   */
/******************************************************************************/

BuildXSL: Procedure
  Use Strict Arg templates, style, -
    opOperator, opSpecial, opConstant, opAssignment, -
    blockColor, blockBackground

  nl = "0A"x
  styleSafe = style~changeStr("-", "_")

  xsl = '<?xml version="1.0" encoding="UTF-8"?>'                    || nl
  xsl ||= "<!--"                                                    || nl
  xsl ||= "  rexx-highlight.xsl — XSL templates for Rexx syntax"   || nl
  xsl ||= "  highlighting in DocBook/FOP output."                   || nl
  xsl ||= ""                                                        || nl
  xsl ||= "  Generated by css2xsl.rex from style '"style"'."       || nl
  xsl ||= "  Options: operator="opOperator "special="opSpecial     -
           " constant="opConstant " assignment="opAssignment        || nl
  xsl ||= ""                                                        || nl
  xsl ||= "  Include this file in your pdf.xsl customization:"     || nl
  xsl ||= '    <xsl:include href="rexx-highlight.xsl"/>'           || nl
  xsl ||= "-->"                                                     || nl
  xsl ||= ""                                                        || nl
  xsl ||= '<xsl:stylesheet version="1.0"'                          || nl
  xsl ||= '  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"'    || nl
  xsl ||= '  xmlns:fo="http://www.w3.org/1999/XSL/Format">'       || nl
  xsl ||= ""                                                        || nl

  -- Block-level template: matches the rexx_style_STYLE wrapper element
  -- emitted by ProcessProgramListings, and sets background-color and
  -- default text color on an fo:block.  This fo:block sits inside the
  -- standard DocBook programlisting fo:block (which provides monospace
  -- font, padding, borders, etc.), overriding its background and color.
  bgHex = Left(blockBackground, 6)
  fgHex = Left(blockColor, 6)
  If bgHex~length == 6, bgHex~dataType("X") Then Do
    foAttrs = ' background-color="#'bgHex'"'
    If fgHex~length == 6, fgHex~dataType("X") Then
      foAttrs ||= ' color="#'fgHex'"'
    wrapperName = "rexx_style_"styleSafe

    xsl ||= '  <!-- Block background for style "'style'" -->'        || nl
    xsl ||= '  <!-- Negative margins expand the inner fo:block to cover -->' || nl
    xsl ||= '  <!-- the padding of the outer shade.verbatim.style block. -->' || nl
    xsl ||= '  <xsl:template match="'wrapperName'">'                 || nl
    xsl ||= '    <fo:block'foAttrs                                       -
                 ' margin-top="-6pt" margin-bottom="-6pt"'               -
                 ' margin-left="-6pt"'                                   -
                 ' padding-top="6pt" padding-bottom="6pt"'               -
                 ' padding-left="6pt">'                               || nl
    xsl ||= '      <xsl:apply-templates/>'                           || nl
    xsl ||= '    </fo:block>'                                        || nl
    xsl ||= '  </xsl:template>'                                      || nl
    xsl ||= ""                                                        || nl
  End

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
  Say "  -s, --style STYLE     CSS theme (default: print)"
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