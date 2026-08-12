#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2020-2026 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* http://www.oorexx.org/license.html                                         */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/
/* Name: HLDOCPREP.REX                                                        */
/* Type: Object REXX Script                                                   */
/*                                                                            */
/* Highlighted document preparation.  Drop-in companion for DOCPREP that      */
/* adds Rexx syntax highlighting to <programlisting language="rexx"> blocks   */
/* and generates the XSL templates required by the PDF and the HTML builds.   */
/*                                                                            */
/* Usage:                                                                     */
/*   [rexx] hldocprep [options] <bookname>                                    */
/*                                                                            */
/* Options:                                                                   */
/*   --style STYLE   Default highlighting style (default: print).             */
/*                   Individual blocks can override with hl-style="X".        */
/*   --regen         Force regeneration of XSL files even if they exist.      */
/*                                                                            */
/* Then build as usual:                                                       */
/*   [rexx] hldoc2pdf      -- for the PDF                                     */
/*   [rexx] hldoc2HTML     -- for the chunked HTML                            */
/*                                                                            */
/* Requires the Rexx Parser to be installed (bin/ directory on REXX_PATH      */
/* or system PATH so that Parser.DocBook.cls can be found).                   */
/*                                                                            */
/*----------------------------------------------------------------------------*/

/******************************************************************************/
/* Make a locally unpacked Rexx Parser discoverable                           */
/******************************************************************************/

  -- If setup.rex has unpacked the Parser into .\rexx-parser, add its bin/
  -- directory to the package search path for this process so that the
  -- findProgram calls below resolve it without a system-wide install.
  Call AddLocalParser

/******************************************************************************/
/* Check that the Rexx Parser is available                                    */
/******************************************************************************/

  If .Context~package~findProgram( "Rexx.Parser.cls" ) == .Nil Then Do
    Say "Error: The Rexx Parser is not installed or not in the search path."
    Say ""
    Say "The Rexx Parser provides the syntax highlighting engine used by"
    Say "hldocprep.  Please ensure that the Rexx Parser's bin/ directory"
    Say "is on your PATH or REXX_PATH."
    Say ""
    Say "You can download the Rexx Parser from:"
    Say "  https://rexx.epbcn.com/rexx-parser/"
    Exit 1
  End

  -- Parser.DocBook.cls resides in the same directory as Rexx.Parser.cls
 .Context~package~loadPackage( "Parser.DocBook.cls" )

/******************************************************************************/
/* Parse command-line options                                                 */
/******************************************************************************/

  defaultStyle = "print"
  regen = .False
  bookname = ""

  -- Parse the command-line string into an array of words.
  -- ArgArray (from BaseClassesAndRoutines.cls, loaded transitively
  -- via Parser.DocBook.cls) handles quoting and escaping.
  If arg(1, "E")
    Then args = ArgArray(arg(1))
    Else args = .Array~new

  -- Parse options
  i = 1
  Loop While i <= args~items, args[i][1] == "-"
    Select Case Lower(args[i])
      When "--style" Then Do
        i += 1
        If i > args~items Then Do
          Say "Error: missing style name after --style."
          Exit 1
        End
        defaultStyle = args[i]
      End
      When "--regen" Then
        regen = .True
      Otherwise
        Say "Error: unknown option '"args[i]"'."
        Exit 1
    End
    i += 1
  End

  If i > args~items Then Do
    If regen Then
      Say "Error: --regen cannot be used alone." -
        "You must also specify the document name."
    Else
      Say "You must specify the name of the ooRexx document to be built."
    Exit 1
  End

  bookname = args[i]

/******************************************************************************/
/* Run standard docprep first                                                 */
/******************************************************************************/

  Call docprep bookname

  If result \== 0 Then Exit 1

/******************************************************************************/
/* Highlight <programlisting language="rexx"> blocks                          */
/******************************************************************************/

  props = .doc.props
  _ = props~getProperty("dir_sep")
  wf_name = props~getProperty("work_folder")
  whichdoc = props~getProperty("whichdoc")

  Say time() "- Highlighting Rexx code in" whichdoc "source files" -
    "(default style:" defaultStyle")."

  totalBlocks = 0
  totalFiles  = 0

  wfDir = .File~new(wf_name)
  Loop aFile Over CollectXmlFiles(wfDir)
    -- Read the file
    src = .Stream~new(aFile)
    theLines = src~arrayIn
    src~close

    -- Check if it contains any <programlisting language="rexx">
    hasRexx = .False
    Loop line Over theLines
      If line~caselessPos('<programlisting') > 0, -
         line~caselessPos('language="rexx"') > 0 Then Do
        hasRexx = .True
        Leave
      End
    End
    If \hasRexx Then Iterate

    -- Process the file, passing the default style
    count = ProcessProgramListings(aFile~name, theLines, defaultStyle)

    If count > 0 Then Do
      -- Write the modified file back (replace, not append)
      outStream = .Stream~new(aFile)~~open("write replace")
      outStream~~arrayOut(theLines)~close
      totalBlocks += count
      totalFiles  += 1
      Say "  " aFile~name":" count "block(s) highlighted"
    End
  End

  If totalBlocks == 0 Then
    Say "  No <programlisting language=""rexx""> blocks found."
  Else
    Say time() totalBlocks "block(s) highlighted in" totalFiles "file(s)."

/******************************************************************************/
/* Scan highlighted files to collect all styles used                          */
/******************************************************************************/

  -- The default style is always in the set (for blocks without hl-style=).
  -- We also scan the highlighted XML files for the container marker
  -- role="highlight-rexx-<style>" to discover per-block styles.

  usedStyles = .Set~new
  usedStyles~put(defaultStyle)

  marker = "highlight-rexx-"
  mLen   = Length(marker)

  Loop aFile Over CollectXmlFiles(wfDir)
    src = .Stream~new(aFile)
    chunk = src~charIn(,src~chars)
    src~close

    pos = 1
    Loop
      pos = Pos(marker, chunk, pos)
    If pos == 0 Then Leave
      -- The style name runs up to the next blank or quote.  A role can
      -- hold more than one token -- "highlight-rexx-dark
      -- rexx-style-locked", or an author's own role ahead of ours -- so
      -- we cannot just read to the closing quote.
      startPos = pos + mLen
      endPos   = startPos
      Loop While endPos <= Length(chunk)
        c = chunk[endPos]
        If c == " " | c == '"' | c == "'" Then Leave
        endPos += 1
      End
      style = chunk~substr(startPos, endPos - startPos)
      If style \== "" Then
        usedStyles[] = style
      pos = endPos
    End
  End

  sorted = usedStyles~makeArray~sortWith(.CaselessComparator~new)

  Say time() usedStyles~items "style(s) found:" -
    sorted~makeString("L", ", ")"."

/******************************************************************************/
/* Generate XSL templates for each style                                      */
/******************************************************************************/

  hlDir = "hl-styles"
  Call SysMkDir hlDir  -- No error if it already exists

  Do aStyle Over usedStyles
    xslFile = hlDir"/"  || "rexx-highlight-"aStyle".xsl"

    If \.File~new(xslFile)~exists | regen Then Do
      Say time() "- Generating" xslFile "..."
      Call css2xsl "--style" aStyle xslFile  -- Single string for InitCLI
    End
    Else
      Say time() xslFile "already exists; skipping."
  End

/******************************************************************************/
/* Read pdf.xsl and pick up the stock verbatim shading                        */
/******************************************************************************/

  -- We are about to redefine DocBook's shade.verbatim.style so that each
  -- highlighted listing gets its own background.  Listings that are NOT
  -- highlighted must keep looking exactly as they do in a plain build, so
  -- we read the current values out of pdf.xsl rather than hardcoding
  -- them: if the book's shading is ever retuned, the fallback follows.

  If \.File~new("pdf.xsl")~exists Then Do
    Say "Error: pdf.xsl not found in the current directory."
    Say "Make sure you are running hldocprep from the tools/bldoc_orx/ directory."
    Exit 1
  End

  pdfXsl   = .Stream~new("pdf.xsl")
  pdfLines = pdfXsl~arrayIn
  pdfXsl~close

  stockBackground = ShadeDefault(pdfLines, "background-color", "#f5f5f5")
  stockColor      = ShadeDefault(pdfLines, "color",            "black")

/******************************************************************************/
/* Generate rexx-highlights.xsl (glue file with xsl:include directives)       */
/******************************************************************************/

  glueFile = "rexx-highlights.xsl"

  Say time() "- Generating" glueFile "..."

  nl = "0A"x
  q  = "'"   -- Single quote, for XPath string literals inside attributes

  glue = '<?xml version="1.0" encoding="UTF-8"?>'                       || nl
  glue ||= "<!--"                                                       || nl
  glue ||= "  rexx-highlights.xsl — Glue file for Rexx syntax"          || nl
  glue ||= "  highlighting XSL stylesheets."                            || nl
  glue ||= ""                                                           || nl
  glue ||= "  Generated by hldocprep.  Do not edit manually."           || nl
  glue ||= "-->"                                                        || nl
  glue ||= ""                                                           || nl
  glue ||= '<xsl:stylesheet version="1.0"'                              || nl
  glue ||= '  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"'         || nl
  glue ||= '  xmlns:fo="http://www.w3.org/1999/XSL/Format">'            || nl
  glue ||= ""                                                           || nl

  -- Add an xsl:include for each style, sorted for reproducibility
  sorted = usedStyles~makeArray~sortWith(.CaselessComparator~new)
  Do aStyle Over sorted
    xslFile = hlDir"/"  || "rexx-highlight-"aStyle".xsl"
    glue ||= '  <xsl:include href="'xslFile'"/>'                        || nl
  End

  glue ||= ""                                                           || nl

  -- Block background and default text colour, one branch per style.
  --
  -- This redefines DocBook's shade.verbatim.style.  Attribute sets are
  -- instantiated with the current node, so @role inside is the role of
  -- the programlisting being shaded, which is what lets every listing
  -- pick its own background.  Only background-color and color are
  -- given here; padding, borders and the rest merge in from the
  -- original definition in pdf.xsl.  Listings that carry no
  -- highlight-rexx-* role -- everything not highlighted -- fall through
  -- to the stock values read from pdf.xsl.
  --
  -- Testing for a blank-delimited token rather than a bare substring
  -- matters: "vim-dark-blue" is a prefix of "vim-dark-blue2".

  glue ||= '  <!-- Per-style verbatim shading. Generated; do not edit. -->'  || nl
  glue ||= '  <xsl:attribute-set name="shade.verbatim.style">'          || nl

  glue ||= '    <xsl:attribute name="background-color">'                || nl
  glue ||= '      <xsl:choose>'                                         || nl
  Do aStyle Over sorted
    Parse Value GetHighlight(aStyle, "rexx") With . . . fg":"bg
    glue ||= '        <xsl:when test="'RoleTest(aStyle)'">' || -
             HexColour(bg, stockBackground) || '</xsl:when>'            || nl
  End
  glue ||= '        <xsl:otherwise>'stockBackground'</xsl:otherwise>'   || nl
  glue ||= '      </xsl:choose>'                                        || nl
  glue ||= '    </xsl:attribute>'                                       || nl

  glue ||= '    <xsl:attribute name="color">'                           || nl
  glue ||= '      <xsl:choose>'                                         || nl
  Do aStyle Over sorted
    Parse Value GetHighlight(aStyle, "rexx") With . . . fg":"bg
    glue ||= '        <xsl:when test="'RoleTest(aStyle)'">' || -
             HexColour(fg, stockColor) || '</xsl:when>'                 || nl
  End
  glue ||= '        <xsl:otherwise>'stockColor'</xsl:otherwise>'        || nl
  glue ||= '      </xsl:choose>'                                        || nl
  glue ||= '    </xsl:attribute>'                                       || nl

  glue ||= '  </xsl:attribute-set>'                                     || nl

  glue ||= ""                                                           || nl
  glue ||= "</xsl:stylesheet>"                                          || nl

  -- Write the glue file (always regenerated)
  If Stream(glueFile, "C", "Q Exists") \== "" Then
    Call SysFileDelete glueFile
  Call CharOut glueFile, glue
  Call CharOut glueFile  -- Close

  Say time() glueFile "created with" usedStyles~items "include(s)."

/******************************************************************************/
/* Generate pdf-hl.xsl (if it does not already exist)                         */
/******************************************************************************/

  hlXsl = "pdf-hl.xsl"
  If .File~new(hlXsl)~exists, \regen Then
    Say time() hlXsl "already exists; skipping."
  Else Do
    Say time() "- Generating" hlXsl "..."

    -- Insert the include just before the closing </xsl:stylesheet>, so
    -- that it comes LAST in document order.  This is not cosmetic: the
    -- glue redefines the shade.verbatim.style attribute set, and when
    -- an attribute set is defined more than once at the same import
    -- precedence, the definitions are merged and the LAST one in
    -- document order wins for any attribute defined twice.  Anywhere
    -- earlier and pdf.xsl's own definition would take the shading back.
    insertLine = 0
    Loop j = pdfLines~items To 1 By -1
      If pdfLines[j]~pos("</xsl:stylesheet>") > 0 Then Do
        insertLine = j
        Leave
      End
    End

    If insertLine == 0 Then Do
      Say "Error: could not find insertion point in pdf.xsl."
      Say "Expected a closing </xsl:stylesheet> tag."
      Exit 1
    End

    -- Insert the include directive for the glue file
    includeLine = '  <xsl:include href="'glueFile'"/>  ' -
                  "<!-- Generated by hldocprep -->"
    pdfLines~insert(includeLine, insertLine - 1)
    pdfLines~insert("", insertLine - 1)
    pdfLines~insert("  <!-- Rexx syntax highlighting templates -->", -
                    insertLine - 1)

    -- Write pdf-hl.xsl
    If Stream(hlXsl, "C", "Q Exists") \== "" Then
      Call SysFileDelete hlXsl
    .Stream~new(hlXsl)~~arrayOut(pdfLines)~close

    Say time() hlXsl "created with Rexx highlighting support."
  End

/******************************************************************************/
/* Generate rexx-highlights-html.xsl (glue file for the HTML branch)         */
/******************************************************************************/

  -- The HTML branch needs far less than the PDF one.  The stock DocBook
  -- XSL already turns <phrase role="rx-kw"> into <span class="rx-kw">, so
  -- there are no per-token templates to generate at all -- and none per
  -- style either, because in HTML the style is a matter of CSS cascade.
  -- What is left is: wrap each highlighted listing the way the HTML
  -- driver does, and put the stylesheets and the chooser in the page.

  htmlGlue = "rexx-highlights-html.xsl"

  Say time() "- Generating" htmlGlue "..."

  styles = AvailableStyles()

  If styles~items == 0 Then
    Say "  Warning: no rexx-*.css files found; the HTML will be unstyled."

  g = '<?xml version="1.0" encoding="UTF-8"?>'                          || nl
  g ||= "<!--"                                                          || nl
  g ||= "  rexx-highlights-html.xsl — Glue file for Rexx syntax"       || nl
  g ||= "  highlighting in the chunked HTML output."                    || nl
  g ||= ""                                                              || nl
  g ||= "  Generated by hldocprep.  Do not edit manually."             || nl
  g ||= "-->"                                                           || nl
  g ||= ""                                                              || nl
  g ||= '<xsl:stylesheet version="1.0"'                                 || nl
  g ||= '  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"'           || nl
  g ||= '  xmlns="http://www.w3.org/1999/xhtml">'                      || nl
  g ||= ""                                                              || nl

  -- The container.  One template, and it is style-agnostic: the style
  -- name is read out of the role rather than baked in, so adding a style
  -- needs no regeneration.  The result is deliberately the same shape the
  -- HTML driver emits -- <div class="highlight-rexx-X"><pre>...</pre></div>
  -- -- so that the very same CSS files style both paths.
  g ||= '  <!-- Wrap a highlighted listing the way the HTML driver does. -->'  || nl
  g ||= '  <xsl:template match="programlisting['                              -
        'contains(concat('q" "q',@role,'q" "q'),'q" highlight-rexx-"q')]">'   || nl
  g ||= '    <xsl:variable name="r" select="concat('q" "q',@role,'q" "q')"/>' || nl
  g ||= '    <xsl:variable name="tail"'                                       -
        ' select="substring-after($r,'q" highlight-rexx-"q')"/>'              || nl
  g ||= '    <xsl:variable name="style"'                                      -
        ' select="substring-before($tail,'q" "q')"/>'                         || nl
  g ||= '    <div class="highlight-rexx-{$style}">'                     || nl
  g ||= '      <xsl:if test="contains($r,'q" rexx-style-locked "q')">'  || nl
  g ||= '        <xsl:attribute name="data-rexx-style-locked">true</xsl:attribute>' || nl
  g ||= '      </xsl:if>'                                               || nl
  g ||= '      <xsl:apply-imports/>'                                    || nl
  g ||= '    </div>'                                                    || nl
  g ||= '  </xsl:template>'                                             || nl
  g ||= ""                                                              || nl

  -- Stylesheets, the chooser's own layout, and the chooser script.
  -- Every sheet but the default is linked with media="not all", so the
  -- browser fetches it only when a reader actually picks that style.
  g ||= '  <!-- Highlighting stylesheets and the style chooser. -->'    || nl
  g ||= '  <xsl:template name="user.head.content">'                     || nl

  -- The chooser's layout ships here rather than in the book's CSS,
  -- because these class names come with the chooser and the book knows
  -- nothing about them.  It goes in the banner, on the right, where the
  -- page template already reserves room for a right-hand image, and it
  -- is anchored to the body rather than the viewport because the book
  -- content is centred inside a max-width.
  g ||= '    <style type="text/css">'                                   || nl
  g ||= '      body { position: relative; }'                            || nl
  g ||= '      .code-style-bar {'                                       || nl
  g ||= '        position: absolute; top: 1.6em; right: 0; margin: 0;'  || nl
  g ||= '      }'                                                       || nl
  g ||= '      .code-style-bar__label { margin-right: .5em; }'          || nl
  g ||= '      /* Too narrow for the banner: back into the flow. */'    || nl
  g ||= '      @media (max-width: 32em) {'                              || nl
  g ||= '        .code-style-bar {'                                     || nl
  g ||= '          position: static; margin: .5em 0;'                   || nl
  g ||= '        }'                                                     || nl
  g ||= '      }'                                                       || nl
  g ||= '    </style>'                                                  || nl

  Do aStyle Over styles
    If aStyle == defaultStyle Then media = ""
                              Else media = ' media="not all"'
    g ||= '    <link rel="stylesheet" type="text/css"'                      -
          ' href="Common_Content/css/rexx-'aStyle'.css"'media               -
          ' data-rexx-style="'aStyle'"/>'                                || nl
  End
  g ||= '    <script src="Common_Content/js/style-chooser.js"><xsl:comment/></script>' || nl
  g ||= '  </xsl:template>'                                             || nl
  g ||= ""                                                              || nl

  -- The chooser itself.  It ships hidden; style-chooser.js reveals it
  -- only on pages that actually have highlighted blocks to restyle.
  g ||= '  <!-- The style chooser, revealed by the script when useful. -->' || nl
  g ||= '  <xsl:template name="user.header.content">'                   || nl
  g ||= '    <div class="code-style-bar" hidden="hidden">'              || nl
  g ||= '      <label class="code-style-bar__label"'                        -
        ' for="rexx-style-chooser">Code style</label>'                  || nl
  g ||= '      <select id="rexx-style-chooser"'                             -
        'class="code-style-bar__select"'                                    -
        'data-rexx-default-style="'defaultStyle'">'                     || nl
  Do aStyle Over styles
    If aStyle == defaultStyle Then sel = ' selected="selected"'
                              Else sel = ""
    g ||= '        <option value="'aStyle'"'sel'>'aStyle'</option>'     || nl
  End
  g ||= '      </select>'                                               || nl
  g ||= '    </div>'                                                    || nl
  g ||= '  </xsl:template>'                                             || nl
  g ||= ""                                                              || nl
  g ||= "</xsl:stylesheet>"                                             || nl

  If Stream(htmlGlue, "C", "Q Exists") \== "" Then
    Call SysFileDelete htmlGlue
  Call CharOut htmlGlue, g
  Call CharOut htmlGlue  -- Close

  Say time() htmlGlue "created;" styles~items "style(s) linked" -
    "(default:" defaultStyle")."

/******************************************************************************/
/* Generate html-hl.xsl                                                       */
/******************************************************************************/

  htmlHl = "html-hl.xsl"
  If .File~new(htmlHl)~exists, \regen Then
    Say time() htmlHl "already exists; skipping."
  Else Do
    Say time() "- Generating" htmlHl "..."

    If \.File~new("html.xsl")~exists Then Do
      Say "Error: html.xsl not found in the current directory."
      Say "Make sure you are running hldocprep from the tools/bldoc_orx/ directory."
      Exit 1
    End

    htmlXsl   = .Stream~new("html.xsl")
    htmlLines = htmlXsl~arrayIn
    htmlXsl~close

    -- As with pdf-hl.xsl, the include goes last, so that our templates
    -- override anything html.xsl defines for the same names.
    insertLine = 0
    Loop j = htmlLines~items To 1 By -1
      If htmlLines[j]~pos("</xsl:stylesheet>") > 0 Then Do
        insertLine = j
        Leave
      End
    End

    If insertLine == 0 Then Do
      Say "Error: could not find insertion point in html.xsl."
      Say "Expected a closing </xsl:stylesheet> tag."
      Exit 1
    End

    includeLine = '  <xsl:include href="'htmlGlue'"/>  ' -
                  "<!-- Generated by hldocprep -->"
    htmlLines~insert(includeLine, insertLine - 1)
    htmlLines~insert("", insertLine - 1)
    htmlLines~insert("  <!-- Rexx syntax highlighting for HTML -->", -
                     insertLine - 1)

    If Stream(htmlHl, "C", "Q Exists") \== "" Then
      Call SysFileDelete htmlHl
    .Stream~new(htmlHl)~~arrayOut(htmlLines)~close

    Say time() htmlHl "created with Rexx highlighting support."
  End

  Say time() whichdoc "source files are ready (with highlighting)."

/******************************************************************************/
/* ShadeDefault - Read one attribute out of pdf.xsl's shade.verbatim.style    */
/* ======================================================================     */
/*                                                                            */
/* Returns the value the stock stylesheet gives to the named attribute of     */
/* the shade.verbatim.style attribute set, so that listings we do not         */
/* highlight keep the appearance they have in a plain build.  Falls back to   */
/* the supplied default if the attribute set or the attribute is not found,   */
/* which keeps hldocprep working against a pdf.xsl it does not recognise.     */
/******************************************************************************/

::Routine ShadeDefault
  Use Strict Arg lines, attrName, fallback

  inSet = .False

  Loop j = 1 To lines~items
    line = lines[j]

    If \inSet Then Do
      If line~pos('name="shade.verbatim.style"') > 0 Then inSet = .True
      Iterate
    End

    If line~pos("</xsl:attribute-set>") > 0 Then Leave

    If line~pos('name="'attrName'"') > 0 Then Do
      -- <xsl:attribute name="background-color">#f5f5f5</xsl:attribute>
      Parse Var line 'name="'attrName'"' . ">" value "</xsl:attribute>"
      value = Strip(value)
      -- A value built from nested elements (an xsl:value-of, say) is not
      -- something we can lift into a literal, so we leave it alone.
      If value \== "", value~pos("<") == 0 Then Return value
      Leave
    End
  End

  Return fallback

/******************************************************************************/
/* RoleTest - XPath test for one blank-delimited role token                   */
/******************************************************************************/

::Routine RoleTest
  Use Strict Arg style

  q = "'"
  Return "contains(concat("q" "q",@role,"q" "q")," || -
         q" highlight-rexx-"style" "q")"

/******************************************************************************/
/* HexColour - Turn an RRGGBBaa colour into #RRGGBB                           */
/* ================================================                           */
/*                                                                            */
/* GetHighlight returns colours as 8 hex digits, alpha included; XSL-FO       */
/* wants 6.  Anything that does not look like a colour falls back, so a       */
/* style with no explicit block colour inherits the stock value instead of    */
/* producing invalid FO.                                                      */
/******************************************************************************/

::Routine HexColour
  Use Strict Arg colour, fallback

  hex = Left(Strip(colour), 6)
  If hex~length == 6, hex~dataType("X") Then Return "#"hex

  Return fallback

/******************************************************************************/
/* AvailableStyles - The highlighting styles shipped with the Parser          */
/* =================================================================          */
/*                                                                            */
/* Returns a sorted array of style names, taken from the rexx-<style>.css     */
/* sheets that actually sit in the Parser's css/ directory, so that adding    */
/* a style is a matter of dropping in a file.  rexx-test<N>.css sheets are    */
/* development-only and excluded.                                             */
/*                                                                            */
/* The directory is found relative to Rexx.Parser.cls, wherever the Parser    */
/* happens to be installed, not relative to the current directory.            */
/******************************************************************************/

::Routine AvailableStyles

  sep = .File~separator

  loc = .Context~package~findProgram( "Rexx.Parser.cls" )
  If loc == .Nil Then Return .Array~new

  binDir = FileSpec("Location", loc)
  cssDir = .File~new(binDir || ".." || sep || "css")~absolutePath

  If \.File~new(cssDir)~exists Then Return .Array~new

  Call SysFileTree cssDir || sep || "rexx-*.css", "sheets.", "FO"

  names = .Array~new
  Do i = 1 To sheets.0
    base = .File~new(sheets.i)~name              -- "rexx-<style>.css"
    If base~caselessStartsWith("rexx-test") Then Iterate   -- dev-only
    style = base~substr(6)                       -- drop leading "rexx-"
    style = style~left(style~length - 4)         -- drop trailing ".css"
    names~append(style)
  End

  names~sort

  Return names

/******************************************************************************/
/* CollectXmlFiles - Recursively collect .xml files under a work folder       */
/* ====================================================================       */
/*                                                                            */
/* docprep lays the work folder out with the book components at the top       */
/* level and the Common_Content in a subdirectory.  A flat scan with          */
/* listFiles never descends into that subdirectory, so its listings (e.g.     */
/* Common_Content's Conventions.xml) are never highlighted, however they      */
/* are marked.  This routine walks the tree depth-first and returns an        */
/* array of .File objects for every .xml file found, at any depth.            */
/******************************************************************************/

::Routine CollectXmlFiles
  Use Strict Arg aDir

  collected = .Array~new

  Loop entry Over aDir~listFiles
    If entry~isDirectory Then Do
      -- Recurse into subdirectories and append their .xml files
      subFiles = CollectXmlFiles(entry)
      Loop subFile Over subFiles
        collected~append(subFile)
      End
    End
    Else If entry~extension~upper == "XML" Then
      collected~append(entry)
  End

Return collected

/******************************************************************************/
/* AddLocalParser - Put a locally unpacked Rexx Parser on the search path     */
/* ======================================================================     */
/*                                                                            */
/* setup.rex unpacks the Rexx Parser into .\rexx-parser (relative to the      */
/* tools/bldoc_orx/ directory), so that bin\Rexx.Parser.cls sits at           */
/* .\rexx-parser\bin\Rexx.Parser.cls.  When the Parser has not been           */
/* installed system-wide, that copy is the one we want findProgram and        */
/* loadPackage to see.                                                        */
/*                                                                            */
/* ooRexx consults REXX_PATH at the time of each program lookup, so           */
/* prepending the local bin\ directory to this process's REXX_PATH is         */
/* enough to make the subsequent findProgram( "Rexx.Parser.cls" ) resolve     */
/* it.  The change is deliberately process-local: it is not meant to          */
/* persist between runs, and each hl* script that needs the Parser calls      */
/* this routine for itself at start-up.                                       */
/*                                                                            */
/* If the local copy is absent the routine does nothing and leaves the        */
/* normal PATH / REXX_PATH search untouched, so a system-wide install still   */
/* works exactly as before.  It is idempotent: a bin\ directory already on    */
/* REXX_PATH is not added a second time, which matters because hldoc2HTML     */
/* may invoke hldocprep in the same process.                                  */
/******************************************************************************/

::Routine AddLocalParser Public

  sep = .File~separator                          -- "\" on Windows
  pathSep = .File~pathSeparator                  -- ";" on Windows

  -- Resolve .\rexx-parser\bin to an absolute path.
  binDir = .File~new("rexx-parser" || sep || "bin")

  -- Nothing unpacked locally: leave the search path as it is.
  If \.File~new(binDir~absolutePath || sep || "Rexx.Parser.cls")~exists Then
    Return .False

  absBin = binDir~absolutePath

  -- Read this process's REXX_PATH (empty if unset).
  rexxPath = Value("REXX_PATH", , "ENVIRONMENT")

  -- Only prepend if it is not already present, so repeated calls within the
  -- same process (e.g. hldoc2HTML -> hldocprep) do not stack duplicates.
  If rexxPath == "" Then
    Call Value "REXX_PATH", absBin, "ENVIRONMENT"
  Else If \CaselessPathHas(rexxPath, absBin, pathSep) Then
    Call Value "REXX_PATH", absBin || pathSep || rexxPath, "ENVIRONMENT"

  Return .True

/******************************************************************************/
/* CaselessPathHas - Is dir already one of the entries in a path string?      */
/* =====================================================================      */
/*                                                                            */
/* Splits a REXX_PATH-style string on the platform path separator and         */
/* compares each entry to dir without regard to case, so a Parser bin\        */
/* directory already on the path is recognised however it was capitalised.    */
/******************************************************************************/

::Routine CaselessPathHas
  Use Strict Arg pathString, dir, pathSep

  Loop entry Over pathString~makeArray(pathSep)
    If entry~strip~caselessEquals(dir) Then Return .True
  End

  Return .False

::requires "doc_props.rex"