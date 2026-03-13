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
/*     style              - Rexx highlighting style (or "" if not set)        */
/*     size               - base font size (or "" if not set)                 */
/*     section-numbers    - numbering depth (or "" if not set)                */
/*     number-figures     - 0 or 1 (or "" if not set)                         */
/*     docclass           - document class name (or "" if not set)            */
/*     language           - HTML lang attribute (or "" if not set)            */
/*     outline            - PDF bookmark depth (or "" if not set)             */
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
/*                                 (default: "pygments")                      */
/*                                                                            */
/******************************************************************************/

::Routine ParseRexxPubYAML Public
  Use Strict Arg yaml

  opts = .StringTable~new

  -- Top-level defaults (empty string = "not set by YAML")
  opts["style"]           = ""
  opts["size"]            = ""
  opts["section-numbers"] = ""
  opts["number-figures"]  = ""
  opts["docclass"]        = ""
  opts["language"]        = ""
  opts["outline"]         = ""

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

  -- Pandoc metadata default
  opts["highlight-style"]          = "pygments"

  If yaml == .Nil Then Return opts

  -- Read rexxpub: block
  If yaml~hasIndex("rexxpub") Then Do
    rp = yaml["rexxpub"]
    If rp~isA(.StringTable) Then Do

      If rp~hasIndex("style") Then
        opts["style"] = rp["style"]

      If rp~hasIndex("size") Then
        opts["size"] = rp["size"]

      If rp~hasIndex("section-numbers") Then
        opts["section-numbers"] = rp["section-numbers"]

      If rp~hasIndex("number-figures") Then Do
        nf = Lower(rp["number-figures"])
        Select Case nf
          When "0", "false" Then opts["number-figures"] = 0
          When "1", "true"  Then opts["number-figures"] = 1
          Otherwise Nop                    -- Ignore invalid values
        End
      End

      If rp~hasIndex("docclass") Then
        opts["docclass"] = Lower(rp["docclass"])

      If rp~hasIndex("language") Then
        opts["language"] = rp["language"]

      If rp~hasIndex("outline") Then Do
        yamlOutline = rp["outline"]
        If DataType(yamlOutline,"W"), yamlOutline >= 0, yamlOutline <= 6 Then
          opts["outline"] = yamlOutline
      End

      -- listings: sub-table
      If rp~hasIndex("listings") Then Do
        lst = rp["listings"]
        If lst~isA(.StringTable) Then Do
          If lst~hasIndex("caption-position") Then Do
            cp = Lower(lst["caption-position"])
            If cp == "above" | cp == "below" Then
              opts["listing-caption-position"] = cp
          End
          If lst~hasIndex("caption-style") Then Do
            cs = Lower(lst["caption-style"])
            If cs == "normal" | cs == "italic" Then
              opts["listing-caption-style"] = cs
          End
          If lst~hasIndex("label-style") Then Do
            ls = Lower(lst["label-style"])
            If "normal bold italic bold-italic"~wordPos(ls) > 0 Then
              opts["listing-label-style"] = ls
          End
          If lst~hasIndex("label") Then
            opts["listing-label"] = lst["label"]
          If lst~hasIndex("frame") Then Do
            lf = Lower(lst["frame"])
            If "none tb single leftbar"~wordPos(lf) > 0 Then
              opts["listing-frame"] = lf
          End
        End
      End

      -- figures: sub-table
      If rp~hasIndex("figures") Then Do
        fig = rp["figures"]
        If fig~isA(.StringTable) Then Do
          If fig~hasIndex("caption-position") Then Do
            cp = Lower(fig["caption-position"])
            If cp == "above" | cp == "below" Then
              opts["figure-caption-position"] = cp
          End
          If fig~hasIndex("caption-style") Then Do
            cs = Lower(fig["caption-style"])
            If cs == "normal" | cs == "italic" Then
              opts["figure-caption-style"] = cs
          End
          If fig~hasIndex("label-style") Then Do
            ls = Lower(fig["label-style"])
            If "normal bold italic bold-italic"~wordPos(ls) > 0 Then
              opts["figure-label-style"] = ls
          End
          If fig~hasIndex("label") Then
            opts["figure-label"] = fig["label"]
        End
      End

    End
  End

  -- Read highlight-style from top-level YAML (standard Pandoc metadata)
  If yaml~hasIndex("highlight-style") Then
    opts["highlight-style"] = Lower(yaml["highlight-style"])

  Return opts


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

  result = .StringTable~new
  result["overrideCSS"]   = overrideCSS
  result["listingsAttrs"] = listingsAttrs
  result["figuresAttrs"]  = figuresAttrs

  Return result


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
    When "book"   Then Return 2
    When "slides" Then Return 0
    Otherwise          Return 3
  End
