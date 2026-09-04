/******************************************************************************/
/*                                                                            */
/* Parser.DocBook.cls - Process Rexx code in DocBook XML files                */
/* ===========================================================                */
/*                                                                            */
/* Scans DocBook XML files for <programlisting language="rexx"> blocks and    */
/* replaces the plain-text content with highlighted <phrase role="rx-...">    */
/* elements, using the DocBook highlighting driver.                           */
/*                                                                            */
/* The style is carried by the container, never by the tokens.  Each          */
/* highlighted listing gets                                                   */
/*                                                                            */
/*   role="highlight-rexx-<style>"                                            */
/*                                                                            */
/* which is the same class name the HTML driver puts on its wrapper <div>,    */
/* so a single set of CSS files styles both the Markdown and the DocBook      */
/* paths.  A listing that named its own style is additionally marked          */
/*                                                                            */
/*   role="highlight-rexx-<style> rexx-style-locked"                          */
/*                                                                            */
/* so that a client-side style chooser knows to leave it alone: the author    */
/* asked for that style deliberately.  Any role= the author already put on    */
/* the listing is preserved ahead of ours.                                    */
/*                                                                            */
/* The supported XML attributes on <programlisting> map to the same           */
/* Highlighter options used by FencedCode.cls for Markdown:                   */
/*                                                                            */
/*   language="rexx"         Required. Only "rexx" triggers highlighting.     */
/*   hl-style="print"        Highlighting style (default: print)              */
/*   operator="group"        Operator granularity: group|full|detail          */
/*   special="group"         Special char granularity: group|full|detail      */
/*   constant="full"         Constant granularity: group|full|detail          */
/*   assignment="group"      Assignment granularity: group|full|detail        */
/*   doccomments="detailed"  Doc-comment mode: detailed|block                 */
/*   dialect="executor"      Dialect: executor|cms|rexxvm|tutor|unicode|      */
/*                           experimental.  Anything else is ignored,         */
/*                           leaving standard ooRexx highlighting.            */
/*                                                                            */
/* Public routines:                                                           */
/*                                                                            */
/*   ProcessProgramListings(filename, lines [, defaultStyle])                 */
/*     Scans an array of XML lines in place. Returns the count of blocks      */
/*     that were highlighted. The lines array is modified directly.           */
/*     defaultStyle (default "print") sets the highlighting style for         */
/*     blocks without an explicit hl-style= attribute.                        */
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
/* 20260729    0.6  Style moved to the container as role="highlight-rexx-     */
/*                  <style>"; the rexx_style_* wrapper element is gone.       */
/*                  Header corrected: the attribute is hl-style=, not         */
/*                  style=, and dialect= was undocumented.                    */
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

    -- Preserve any content before <programlisting on the same line
    -- (e.g. <para><programlisting ...>)
    head = line~left(tagPos - 1)

    -- Extract the full opening tag (may span multiple lines)
    openTag = ""
    tagLine = i
    Loop
      If openTag == "" Then
        -- First line: start from <programlisting, skip the head
        openTag = lines[tagLine]~substr(tagPos)
      Else
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
    tail = ""

    -- Case 1: opening tag and content start on the same line
    -- contentAfterTag has the text after ">" on the tag line
    closePos = contentAfterTag~caselessPos(closingTag)
    If closePos > 0 Then Do
      -- Everything on one line (or at least the close is on the same line)
      codeText = contentAfterTag~left(closePos - 1)
      content~append(codeText)
      -- Preserve any tags after </programlisting> (e.g. </example></para>)
      tail = contentAfterTag~substr(closePos + closingTag~length)
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
          -- Preserve any tags after </programlisting>
          tail = lines[j]~substr(closePos + closingTag~length)
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

    If \highlightedArr~isA(.Array) Then Do
      -- Highlighting failed; leave the block unchanged
      Say "  Warning: highlighting failed for block at line" -
        i + linesRemoved "in" filename
      Say "    " highlightedArr
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

    -- The style is carried by the container, never by the tokens.  The
    -- listing gets a role naming the style, using the same
    -- "highlight-rexx-<style>" class the HTML driver puts on its wrapper
    -- <div>, so that one set of CSS files serves both paths.  Listings
    -- that named a style of their own are additionally marked as locked,
    -- so a client-side style chooser leaves them alone.
    containerRole = "highlight-rexx-"options.style
    If attrs~hasIndex("HL-STYLE") Then
      containerRole ||= " rexx-style-locked"

    -- Any role the author already put on the listing comes first.
    If attrs~hasIndex("ROLE") Then
      containerRole = attrs~at("ROLE") containerRole

    newAttrStr = StripAttribute(attrStr, "role")

    -- Reconstruct the block as a single line:
    --   HEAD<programlisting attrs>HIGHLIGHTED</programlisting>TAIL
    -- HEAD preserves any content before <programlisting (e.g. <para>)
    -- TAIL preserves any content after </programlisting> (e.g. </para>)
    newOpenTag = "<programlisting"newAttrStr' role="'containerRole'">'
    newLine = head || newOpenTag || highlighted || closingTag || tail

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
  -- Returns the highlighted Array, or a String with the error message
  -- if highlighting fails.

  Use Strict Arg filename, sourceLines, options.

  Signal On Syntax

  hl = .Highlighter~new(filename, sourceLines, options.)
  Return hl~parse()

Syntax:
  co = condition("O")
  Return co~code":" co~message

/******************************************************************************/
/* ParseXMLAttributes                                                         */
/******************************************************************************/

::Routine ParseXMLAttributes Private

  -- Parse XML attributes from a string like:
  --   language="rexx" hl-style="print" operator="detail"
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
/* StripAttribute                                                             */
/******************************************************************************/

::Routine StripAttribute Private

  -- Return attrStr with the named attribute (matched case-insensitively)
  -- removed, and everything else preserved verbatim.  The parsing mirrors
  -- ParseXMLAttributes, so that both agree on what counts as an attribute;
  -- anything that does not parse as key="value" is passed through
  -- untouched rather than silently dropped.
  --
  -- The returned string always starts with a blank when non-empty, so that
  -- it can be concatenated straight after "<programlisting".

  Use Strict Arg attrStr, dropName

  kept     = ""
  rest     = Strip(attrStr)
  dropName = Upper(dropName)

  Loop While rest \== ""
    rest = Strip(rest)
    If rest == "" Then Leave

    eqPos = rest~pos("=")
    If eqPos == 0 Then Leave  -- No more key=value pairs

    attrName = Strip(rest~left(eqPos - 1))
    afterEq  = Strip(rest~substr(eqPos + 1))

    If afterEq == "" Then Leave
    quote = afterEq[1]
    If quote \== '"', quote \== "'" Then Leave  -- Not a valid XML attribute

    endQuote = afterEq~pos(quote, 2)
    If endQuote == 0 Then Leave  -- Unclosed quote

    attrValue = afterEq~substr(2, endQuote - 2)
    rest      = afterEq~substr(endQuote + 1)

    If Upper(attrName) \== dropName Then
      kept ||= " "attrName"="quote || attrValue || quote
  End

  -- Whatever we could not parse is appended unchanged.
  If Strip(rest) \== "" Then kept ||= " "Strip(rest)

  Return kept

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

  -- Map the optional dialect= attribute to the Highlighter dialect flags.
  -- Accepted values (case-insensitive), mapped to the parser dialects:
  --   executor               -> Executor
  --   cms, rexxvm            -> CMS (Classic Rexx / Rexx VM)
  --   tutor, unicode         -> TUTOR-flavored Unicode
  --   experimental           -> experimental features
  -- Anything else is ignored, leaving standard ooRexx highlighting.
  If attrs~hasIndex("DIALECT") Then Do
    Select Case Lower(attrs~at("DIALECT"))
      When "executor"            Then Options.executor     = 1
      When "cms", "rexxvm"       Then Options.cms          = 1
      When "tutor", "unicode"    Then Options.unicode      = 1
      When "experimental"        Then Options.experimental = 1
      Otherwise Nop
    End
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