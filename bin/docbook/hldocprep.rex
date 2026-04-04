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
/* and generates the XSL templates required by the PDF build.                 */
/*                                                                            */
/* Usage:                                                                     */
/*   [rexx] hldocprep [options] <bookname>                                    */
/*                                                                            */
/* Options:                                                                   */
/*   --style STYLE   Default highlighting style (default: print).             */
/*                   Individual blocks can override with style="X".           */
/*   --regen         Force regeneration of XSL files even if they exist.      */
/*                                                                            */
/* Then build the PDF as usual:                                               */
/*   [rexx] hldoc2pdf                                                         */
/*                                                                            */
/* Requires the Rexx Parser to be installed (bin/ directory on REXX_PATH      */
/* or system PATH so that Parser.DocBook.cls can be found).                   */
/*                                                                            */

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
  Loop aFile Over wfDir~listFiles
    If aFile~isDirectory Then Iterate
    If aFile~extension~upper \== "XML" Then Iterate

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

  -- The default style is always in the set (for blocks without style=).
  -- We also scan the highlighted XML files for element names of the form
  -- <rexx_STYLE_...> to discover per-block styles.

  usedStyles = .Set~new
  usedStyles~put(defaultStyle)

  Loop aFile Over wfDir~listFiles
    If aFile~isDirectory Then Iterate
    If aFile~extension~upper \== "XML" Then Iterate

    src = .Stream~new(aFile)
    chunk = src~charIn(,src~chars)

    pos = 1
    Loop
      pos = Pos("<rexx_",chunk, pos)
    If pos == 0 Then Leave
      endPos = Pos("_",chunk,pos+6)
      style = chunk[pos+6, endPos-pos-6]
      If style \== "style" Then
        usedStyles[] = style
      pos += 6 + Length(style)
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
/* Generate rexx-highlights.xsl (glue file with xsl:include directives)      */
/******************************************************************************/

  glueFile = "rexx-highlights.xsl"

  Say time() "- Generating" glueFile "..."

  nl = "0A"x

  glue = '<?xml version="1.0" encoding="UTF-8"?>'                      || nl
  glue ||= "<!--"                                                       || nl
  glue ||= "  rexx-highlights.xsl — Glue file for Rexx syntax"         || nl
  glue ||= "  highlighting XSL stylesheets."                            || nl
  glue ||= ""                                                           || nl
  glue ||= "  Generated by hldocprep.  Do not edit manually."          || nl
  glue ||= "-->"                                                        || nl
  glue ||= ""                                                           || nl
  glue ||= '<xsl:stylesheet version="1.0"'                              || nl
  glue ||= '  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"'        || nl
  glue ||= '  xmlns:fo="http://www.w3.org/1999/XSL/Format">'           || nl
  glue ||= ""                                                           || nl

  -- Add an xsl:include for each style, sorted for reproducibility
  sorted = usedStyles~makeArray~sortWith(.CaselessComparator~new)
  Do aStyle Over sorted
    xslFile = hlDir"/"  || "rexx-highlight-"aStyle".xsl"
    glue ||= '  <xsl:include href="'xslFile'"/>'                        || nl
  End

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

    If \.File~new("pdf.xsl")~exists Then Do
      Say "Error: pdf.xsl not found in the current directory."
      Say "Make sure you are running hldocprep from the tools/bldoc_orx/ directory."
      Exit 1
    End

    pdfXsl = .Stream~new("pdf.xsl")
    pdfLines = pdfXsl~arrayIn
    pdfXsl~close

    -- Find the right place to insert the xsl:include.
    -- Look for the perl_* templates section (around line 1922 in the
    -- standard pdf.xsl) and insert just before it.
    insertLine = 0
    Loop j = 1 To pdfLines~items
      If pdfLines[j]~pos("perl_") > 0, -
         pdfLines[j]~pos("template") > 0 Then Do
        insertLine = j
        Leave
      End
    End

    If insertLine == 0 Then Do
      -- Fallback: insert before the closing </xsl:stylesheet>
      Loop j = pdfLines~items To 1 By -1
        If pdfLines[j]~pos("</xsl:stylesheet>") > 0 Then Do
          insertLine = j
          Leave
        End
      End
    End

    If insertLine == 0 Then Do
      Say "Error: could not find insertion point in pdf.xsl."
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

  Say time() whichdoc "source files are ready (with highlighting)."

::requires doc_props.rex