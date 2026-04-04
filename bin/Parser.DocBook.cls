/******************************************************************************/
/*                                                                            */
/* Parser.DocBook.cls - Process Rexx code in DocBook XML files                */
/* ===========================================================                */
/*                                                                            */
/* Scans DocBook XML files for <programlisting language="rexx"> blocks and    */
/* replaces the plain-text content with highlighted rexx_* elements using     */
/* the DocBook highlighting driver.                                           */
/*                                                                            */
/* The supported XML attributes on <programlisting> map to the same          */
/* Highlighter options used by FencedCode.cls for Markdown:                   */
/*                                                                            */
/*   language="rexx"         Required. Only "rexx" triggers highlighting.     */
/*   style="print"           Highlighting style (default: print)              */
/*   operator="group"        Operator granularity: group|full|detail          */
/*   special="group"         Special char granularity: group|full|detail      */
/*   constant="full"         Constant granularity: group|full|detail          */
/*   assignment="group"      Assignment granularity: group|full|detail        */
/*   doccomments="detailed"  Doc-comment mode: detailed|block                 */
/*                                                                            */
/* Public routines:                                                           */
/*                                                                            */
/*   ProcessProgramListings(filename, lines [, defaultStyle])                 */
/*     Scans an array of XML lines in place. Returns the count of blocks     */
/*     that were highlighted. The lines array is modified directly.           */
/*     defaultStyle (default "print") sets the highlighting style for        */
/*     blocks without an explicit style= attribute.                          */
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
/* 20260403    0.5  First version                                             */
/*                                                                            */
/******************************************************************************/

::Options NoProlog

::Requires "Highlighter.cls"

/******************************************************************************/
/* ProcessProgramListings                                                     */
/******************************************************************************/

::Routine ProcessProgramListings Public

  Use Strict Arg filename, lines, defaultStyle = "print"

  count = 0
  i = 1
  linesRemoved = 0

  Loop While i <= lines~items

    line = lines[i]

    -- Look for <programlisting with language="rexx"
    tagPos = line~caselessPos("<programlisting")
    If tagPos == 0 Then Do
      i += 1
      Iterate
    End

    -- Extract the full opening tag (may span multiple lines)
    openTag = ""
    tagLine = i
    Loop
      openTag = openTag || lines[tagLine]
      If openTag~pos(">") > 0 Then Leave
      tagLine += 1
      If tagLine > lines~items Then Do
        i += 1
        Iterate  -- Malformed tag, skip
      End
      openTag = openTag || "0a"x
    End

    -- Parse attributes from the opening tag
    Parse Var openTag "<programlisting" attrStr ">" contentAfterTag
    attrs = ParseXMLAttributes(attrStr)

    -- Only process language="rexx" (case-insensitive)
    -- Directory uppercases keys, so we use uppercase for hasIndex/at
    If \attrs~hasIndex("LANGUAGE") Then Do
      i = tagLine + 1
      Iterate
    End
    If Lower(attrs~at("LANGUAGE")) \== "rexx" Then Do
      i = tagLine + 1
      Iterate
    End

    -- Collect the content between <programlisting ...> and </programlisting>
    -- The content starts right after ">" on the opening tag line
    -- and ends just before "</programlisting>" on some line
    content = .Array~new
    closingTag = "</programlisting>"

    -- Case 1: opening tag and content start on the same line
    -- contentAfterTag has the text after ">" on the tag line
    closePos = contentAfterTag~caselessPos(closingTag)
    If closePos > 0 Then Do
      -- Everything on one line (or at least the close is on the same line)
      codeText = contentAfterTag~left(closePos - 1)
      content~append(codeText)
      endLine = tagLine
    End
    Else Do
      -- Content starts after ">" and continues on subsequent lines
      content~append(contentAfterTag)
      j = tagLine + 1
      Loop While j <= lines~items
        closePos = lines[j]~caselessPos(closingTag)
        If closePos > 0 Then Do
          content~append(lines[j]~left(closePos - 1))
          endLine = j
          Leave
        End
        content~append(lines[j])
        j += 1
      End
      If j > lines~items Then Do
        -- No closing tag found; skip this block
        i = tagLine + 1
        Iterate
      End
    End

    -- Build Highlighter options from XML attributes
    options. = BuildOptions(attrs, defaultStyle)

    -- The content needs to be XML-unescaped before highlighting,
    -- because the source is XML and entities like &amp; &lt; &gt; &quot;
    -- have been escaped.  The Highlighter expects plain Rexx source.
    sourceLines = XMLUnescape(content)

    -- Highlight the code
    highlightedArr = HighlightBlock(filename, sourceLines, options.)

    If highlightedArr == .Nil Then Do
      -- Highlighting failed; leave the block unchanged
      Say "  Warning: highlighting failed for block at line" -
        i + linesRemoved "in" filename
      i = endLine + 1
      Iterate
    End

    -- Convert highlighted output to a string.
    -- parse() returns an Array; join with newline to preserve line structure.
    highlighted = highlightedArr~makeString("L", "0a"x)

    -- Strip any leading newline — the content array may start with an
    -- empty first element (from the tag/content line split), which would
    -- insert a blank line after the wrapper opening tag.
    If highlighted~left(1) == "0a"x Then
      highlighted = highlighted~substr(2)

    -- Wrap the highlighted content in a rexx_style_STYLE element so that
    -- the XSL can apply the correct background-color to the fo:block.
    -- DocBook 4.5's DTD discards unknown attributes, but custom elements
    -- pass through, so we use a wrapper element instead of an attribute.
    styleTag = "rexx_style_" || options.style~changeStr("-", "_")
    highlighted = "<"styleTag">" || highlighted || "</"styleTag">"

    -- Reconstruct the block as a single line:
    --   <programlisting attrs>HIGHLIGHTED</programlisting>
    -- This is the correct format for DocBook: the content sits directly
    -- between the tags with no extra whitespace around it.
    newOpenTag = "<programlisting" attrStr ">"
    newLine = newOpenTag || highlighted || closingTag

    -- Replace lines[i..endLine] with the single new line
    lines[i] = newLine

    -- Delete the remaining original lines (i+1 through endLine)
    removeCount = endLine - i
    linesRemoved += removeCount
    Loop removeCount
      lines~delete(i + 1)
    End

    count += 1
    i += 1

  End

  Return count

/******************************************************************************/
/* HighlightBlock                                                             */
/******************************************************************************/

::Routine HighlightBlock Private

  -- Highlight a block of Rexx source code using the DocBook driver.
  -- Returns the highlighted string, or .Nil if highlighting fails.

  Use Strict Arg filename, sourceLines, options.

  Signal On Syntax

  hl = .Highlighter~new(filename, sourceLines, options.)
  Return hl~parse()

Syntax:
  Return .Nil

/******************************************************************************/
/* ParseXMLAttributes                                                         */
/******************************************************************************/

::Routine ParseXMLAttributes Private

  -- Parse XML attributes from a string like:
  --   language="rexx" style="print" operator="detail"
  -- Returns a Directory with attribute name -> value pairs.

  Use Strict Arg attrStr

  attrs = .Directory~new
  attrStr = Strip(attrStr)

  Loop While attrStr \== ""
    -- Skip whitespace
    attrStr = Strip(attrStr)
    If attrStr == "" Then Leave

    -- Extract attribute name (up to "=")
    eqPos = attrStr~pos("=")
    If eqPos == 0 Then Leave  -- No more key=value pairs

    attrName = Strip(attrStr~left(eqPos - 1))
    attrStr = Strip(attrStr~substr(eqPos + 1))

    -- Extract attribute value (quoted)
    If attrStr == "" Then Leave
    quote = attrStr[1]
    If quote \== '"', quote \== "'" Then Leave  -- Not a valid XML attribute

    endQuote = attrStr~pos(quote, 2)
    If endQuote == 0 Then Leave  -- Unclosed quote

    attrValue = attrStr~substr(2, endQuote - 2)
    attrStr = Strip(attrStr~substr(endQuote + 1))

    attrs~setEntry(attrName, attrValue)
  End

  Return attrs

/******************************************************************************/
/* BuildOptions                                                               */
/******************************************************************************/

::Routine BuildOptions Private

  -- Build a Highlighter options. stem from a Directory of XML attributes.
  -- Defaults match what makes sense for DocBook/PDF output.
  -- The defaultStyle parameter sets the style for blocks without an
  -- explicit style= attribute (comes from hldocprep --style).

  Use Strict Arg attrs, defaultStyle = "print"

  Options.             = 0
  Options.mode         = "DOCBOOK"
  Options.doccomments  = "detailed"
  Options.operator     = "group"
  Options.special      = "group"
  Options.constant     = "group"
  Options.assignment   = "group"
  Options.classprefix  = "rx-"
  Options.style        = defaultStyle
  Options.startFrom    = 1

  validModes = "group full detail"

  -- Map XML attributes to Highlighter options
  -- Directory uppercases keys, so we use uppercase for hasIndex/at
  If attrs~hasIndex("HL-STYLE") Then
    Options.style = attrs~at("HL-STYLE")

  If attrs~hasIndex("OPERATOR") Then Do
    val = Lower(attrs~at("OPERATOR"))
    If WordPos(val, validModes) > 0 Then Options.operator = val
  End

  If attrs~hasIndex("SPECIAL") Then Do
    val = Lower(attrs~at("SPECIAL"))
    If WordPos(val, validModes) > 0 Then Options.special = val
  End

  If attrs~hasIndex("CONSTANT") Then Do
    val = Lower(attrs~at("CONSTANT"))
    If WordPos(val, validModes) > 0 Then Options.constant = val
  End

  If attrs~hasIndex("ASSIGNMENT") Then Do
    val = Lower(attrs~at("ASSIGNMENT"))
    If WordPos(val, validModes) > 0 Then Options.assignment = val
  End

  If attrs~hasIndex("DOCCOMMENTS") Then Do
    val = Lower(attrs~at("DOCCOMMENTS"))
    If WordPos(val, "detailed block") > 0 Then Options.doccomments = val
  End

  Return options.

/******************************************************************************/
/* XMLUnescape                                                                */
/******************************************************************************/

::Routine XMLUnescape Private

  -- Unescape XML entities in an array of content lines.
  -- Returns a new array with unescaped lines.

  Use Strict Arg content

  sourceLines = .Array~new

  Loop line Over content
    line = line~changeStr("&lt;",   "<")
    line = line~changeStr("&gt;",   ">")
    line = line~changeStr("&quot;", '"')
    line = line~changeStr("&apos;", "'")
    line = line~changeStr("&amp;",  "&")  -- Must be last
    sourceLines~append(line)
  End

  Return sourceLines