/******************************************************************************/
/*                                                                            */
/* RexxPubOptions.cls -- Shared option handling for RexxPub pipelines         */
/* =================================================================          */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
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
/* 20260313    0.5   Created: refactor common code from CGI, md2pdf, md2html  */
/*                                                                            */
/******************************************************************************/

::Requires "ANSI.ErrorText.cls"

/******************************************************************************/
/*                                                                            */
/* ParseRexxPubYAML(yaml) -- Extract RexxPub options from parsed YAML         */
/*                                                                            */
/* 'yaml' is the StringTable returned by YAMLFrontMatter(), or .nil.          */
/*                                                                            */
/* Returns a StringTable with normalized option values:                       */
/*                                                                            */
/*   Top-level (from rexxpub: block):                                         */
/*     style              - Rexx highlighting style (or .Nil if not set)      */
/*     size               - base font size (or .Nil if not set)               */
/*     section-numbers    - numbering depth (or .Nil if not set)              */
/*     number-figures     - 0 or 1 (or .Nil if not set)                       */
/*     docclass           - document class name (or .Nil if not set)          */
/*     language           - HTML lang attribute (or .Nil if not set)          */
/*     outline            - PDF bookmark depth (or .Nil if not set)           */
/*                                                                            */
/*   Listing sub-options (from rexxpub: listings:):                           */
/*     listing-caption-position  - "above" or "below"  (default: "above")     */
/*     listing-caption-style     - "normal" or "italic" (default: "normal")   */
/*     listing-label-style       - "bold", "italic", etc. (default: "bold")   */
/*     listing-label             - custom label text (default: "")            */
/*     listing-frame             - "none", "tb", "single", "leftbar"          */
/*                                 (default: "none")                          */
/*                                                                            */
/*   Figure sub-options (from rexxpub: figures:):                             */
/*     figure-caption-position   - "above" or "below" (default: "below")      */
/*     figure-caption-style      - "normal" or "italic" (default: "normal")   */
/*     figure-label-style        - "bold", "italic", etc. (default: "bold")   */
/*     figure-label              - custom label text (default: "")            */
/*                                                                            */
/*   Pandoc metadata (from top-level YAML):                                   */
/*     highlight-style           - Pandoc highlighting theme                  */
/*                                 (or .Nil if not set)                       */
/*                                                                            */
/******************************************************************************/

::Routine ParseRexxPubYAML Public
  Use Strict Arg yaml

  opts = .StringTable~new

  -- Top-level defaults (.Nil = "not set by YAML")
  opts["style"]           = .Nil
  opts["size"]            = .Nil
  opts["section-numbers"] = .Nil
  opts["number-figures"]  = .Nil
  opts["docclass"]        = .Nil
  opts["language"]        = .Nil
  opts["outline"]         = .Nil

  -- Listing sub-option defaults
  opts["listing-caption-position"] = "above"
  opts["listing-caption-style"]    = "normal"
  opts["listing-label-style"]      = "bold"
  opts["listing-label"]            = ""
  opts["listing-frame"]            = "none"

  -- Figure sub-option defaults
  opts["figure-caption-position"]  = "below"
  opts["figure-caption-style"]     = "normal"
  opts["figure-label-style"]       = "bold"
  opts["figure-label"]             = ""

  -- Pandoc metadata (.Nil = "not set by YAML")
  opts["highlight-style"]          = .Nil

  If yaml == .Nil Then Return opts

  -- Process first-level entries

  -- Read highlight-style from top-level YAML (standard Pandoc metadata)
  If yaml~hasIndex("highlight-style")
    Then opts["highlight-style"] = Lower(yaml["highlight-style"])

  -- Process second- and third-level entries

  If yaml~hasIndex("rexxpub") Then Call ReadRexxPubBlock

  Return opts


ConditionalCopyFrom: Procedure Expose opts prefix
  Use Arg table, key, lowerCase = 0, list = ""
  newValue = table[key]
  If newValue == .Nil Then Return
  If lowerCase Then newValue = Lower(newValue)
  If list \== "", WordPos(newValue, list) == 0 Then Return
  newKey = key
  If prefix \== "" Then newKey = prefix"-"key
  If table~hasIndex(key) Then opts[newKey] = newValue
Return


ReadRexxPubBlock: -- Read rexxpub: block

  rp = yaml["rexxpub"]
  If \rp~isA(.StringTable) Then Return

  lowerCase = 1
  prefix    = ""

  -- Process second-level entries

  Call ConditionalCopyFrom rp, "style"
  Call ConditionalCopyFrom rp, "size"
  Call ConditionalCopyFrom rp, "section-numbers"
  Call ConditionalCopyFrom rp, "number-figures" , lowerCase
  Call ConditionalCopyFrom rp, "docclass"       , lowerCase
  Call ConditionalCopyFrom rp, "language"
  Call ConditionalCopyFrom rp, "outline"

  -- Sanitize values

  opt = opts["number-figures"]
  If opt \== .Nil Then Do
    Select Case opt
      When 0, 1    Then Nop
      When "true"  Then opts["number-figures"] = 1
      When "false" Then opts["number-figures"] = 0
      Otherwise opts~remove("number-figures")
    End
  End

  outline = opts["outline"]
  If DataType(outline,"W"), outline >= 0, outline <= 6 Then Nop
  Else opts~remove("outline")

  -- Process third-level entries

  -- listings: sub-table
  If rp~hasIndex("listings") Then Call ProcessListings

  -- figures: sub-table
  If rp~hasIndex("figures")  Then Call ProcessFigures

Return

ProcessListings:
  lst = rp["listings"]
  If \lst~isA(.StringTable) Then Return

  prefix = "listing"

  Call ConditionalCopyFrom lst, "caption-position", lowerCase, "above below"
  Call ConditionalCopyFrom lst, "caption-style",    lowerCase, "normal italic"
  Call ConditionalCopyFrom lst, "label-style",      lowerCase, -
    "normal bold italic bold-italic"
  Call ConditionalCopyFrom lst, "frame",           lowerCase, -
    "none tb single leftbar"
  Call ConditionalCopyFrom lst, "label"
Return

ProcessFigures:
  fig = rp["figures"]
  If \fig~isA(.StringTable) Then Return

  prefix = "figure"

  Call ConditionalCopyFrom fig, "caption-position", lowerCase, "above below"
  Call ConditionalCopyFrom fig, "caption-style",    lowerCase, "normal italic"
  Call ConditionalCopyFrom fig, "label-style",      lowerCase, -
    "normal bold italic bold-italic"
  Call ConditionalCopyFrom fig, "label"
Return


/******************************************************************************/
/*                                                                            */
/* BuildCaptionOverrides(opts) -- Generate CSS override string                */
/*                                                                            */
/* 'opts' is the StringTable returned by ParseRexxPubYAML().                  */
/*                                                                            */
/* Returns a StringTable with three keys:                                     */
/*   "overrideCSS"   - CSS rules to inject as a <style> block                 */
/*   "listingsAttrs" - data-* attributes for the content div (listings)       */
/*   "figuresAttrs"  - data-* attributes for the content div (figures)        */
/*                                                                            */
/******************************************************************************/

::Routine BuildCaptionOverrides Public
  Use Strict Arg opts

  listingsAttrs = ""
  figuresAttrs  = ""
  overrideCSS   = ""
  NL            = "0a"x

  listingCaptionPosition = opts["listing-caption-position"]
  listingCaptionStyle    = opts["listing-caption-style"]
  listingLabelStyle      = opts["listing-label-style"]
  listingLabel           = opts["listing-label"]
  listingFrame           = opts["listing-frame"]
  figureCaptionPosition  = opts["figure-caption-position"]
  figureCaptionStyle     = opts["figure-caption-style"]
  figureLabelStyle       = opts["figure-label-style"]
  figureLabel            = opts["figure-label"]

  /* --- Listing data-* attributes ---                                        */
  If listingCaptionPosition \== "above" Then
    listingsAttrs ||= ' data-listing-caption-position="'listingCaptionPosition'"'
  If listingLabel \== "" Then
    listingsAttrs ||= ' data-listing-label="'listingLabel'"'

  /* --- Figure data-* attributes ---                                         */
  If figureCaptionPosition \== "below" Then
    figuresAttrs ||= ' data-figure-caption-position="'figureCaptionPosition'"'
  If figureLabel \== "" Then
    figuresAttrs ||= ' data-figure-label="'figureLabel'"'

  /* --- Listing CSS overrides ---                                            */
  If listingCaptionPosition == "below" Then
    overrideCSS ||= "figure.listing figcaption {"            -
      " break-after: auto; break-before: avoid;"             -
      " margin-top: 0.075em; margin-bottom: 0; }" || NL     -
      || "figure.listing pre {"                              -
      " margin-bottom: 0; }" || NL                           -
      || "figure.listing div.sourceCode {"                   -
      " margin-bottom: 0; }" || NL
  If listingCaptionStyle == "italic" Then
    overrideCSS ||= "figure.listing figcaption {"            -
      " font-style: italic; }" || NL
  Select Case listingLabelStyle
    When "normal" Then
      overrideCSS ||= "figure.listing .figure-number {"      -
        " font-weight: normal; font-style: normal; }" || NL
    When "italic" Then
      overrideCSS ||= "figure.listing .figure-number {"      -
        " font-weight: normal; font-style: italic; }" || NL
    When "bold-italic" Then
      overrideCSS ||= "figure.listing .figure-number {"      -
        " font-weight: bold; font-style: italic; }" || NL
    Otherwise
      If listingCaptionStyle == "italic" Then
        overrideCSS ||= "figure.listing .figure-number {"    -
          " font-style: normal; }" || NL
  End

  /* --- Listing frame CSS overrides ---                                      */
  Select Case listingFrame
    When "tb" Then
      overrideCSS ||= "div.sourceCode {"                     -
        " border-top: 0.4pt solid #000;"                     -
        " border-bottom: 0.4pt solid #000;"                  -
        " padding: 0.5em 1em; }" || NL
    When "single" Then
      overrideCSS ||= "div.sourceCode {"                     -
        " border: 0.4pt solid #000;"                         -
        " padding: 0.5em 1em; }" || NL
    When "leftbar" Then
      overrideCSS ||= "div.sourceCode {"                     -
        " border-left: 2pt solid #ccc;"                      -
        " padding: 0.5em 1em; }" || NL
    Otherwise Nop                          -- "none": no frame
  End

  /* --- Figure CSS overrides ---                                             */
  If figureCaptionPosition == "above" Then
    overrideCSS ||= "figure:not(.listing) figcaption {"      -
      " break-before: auto; break-after: avoid;"             -
      " margin-top: 0; margin-bottom: 0.5em; }" || NL       -
      || "figure:not(.listing) img {"                        -
      " margin-top: 0; }" || NL
  If figureCaptionStyle == "italic" Then
    overrideCSS ||= "figure:not(.listing) figcaption {"      -
      " font-style: italic; }" || NL
  Select Case figureLabelStyle
    When "normal" Then
      overrideCSS ||= "figure:not(.listing) .figure-number {" -
        " font-weight: normal; font-style: normal; }" || NL
    When "italic" Then
      overrideCSS ||= "figure:not(.listing) .figure-number {" -
        " font-weight: normal; font-style: italic; }" || NL
    When "bold-italic" Then
      overrideCSS ||= "figure:not(.listing) .figure-number {" -
        " font-weight: bold; font-style: italic; }" || NL
    Otherwise
      If figureCaptionStyle == "italic" Then
        overrideCSS ||= "figure:not(.listing) .figure-number {" -
          " font-style: normal; }" || NL
  End

  res = .StringTable~new
  res["overrideCSS"]   = overrideCSS
  res["listingsAttrs"] = listingsAttrs
  res["figuresAttrs"]  = figuresAttrs

  Return res


/******************************************************************************/
/*                                                                            */
/* DefaultSectionNumbers(docclass) -- Return the default numbering depth      */
/*                                                                            */
/* 'docclass' is the document class name (e.g. "article", "book", "slides").  */
/* Returns the default section numbering depth for that class.                */
/*                                                                            */
/******************************************************************************/

::Routine DefaultSectionNumbers Public
  Use Strict Arg docclass
  Select Case docclass
    When "article" Then Return 3
    When "letter"  Then Return 0
    When "book"    Then Return 2
    When "slides"  Then Return 0
    Otherwise           Return 3
  End