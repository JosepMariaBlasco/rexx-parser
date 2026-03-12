#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* CGI.markdown.rex -- Sample Apache CGI markdown processor                   */
/* ========================================================                   */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Requirements:                                                              */
/*                                                                            */
/* + Apache                                                                   */
/* + Pandoc                                                                   */
/* + Use the "Action" directive to define an action pointing to               */
/*   this CGI routine, for example                                            */
/*      Action Markdown /cgi-bin/CGI.markdown.rex                             */
/* + Tell to Apache which files you want to process using the action handler  */
/*   you have defined. For example,                                           */
/*                                                                            */
/*        <Files *.md>                                                        */
/*          SetHandler Markdown                                               */
/*        </Files>                                                            */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241220    0.1c First public release                                      */
/* 20241230    0.1e Switch to a local copy of Bootstrap 3 to allow for colors */
/*                  in code sections to be printed correctly.                 */
/* 20250222    0.2  Add drive to path for requires                            */
/* 20250222         Change Address PATH to Address COMMAND for pandoc         */
/* 20250317         Allow style=(dark|light) query string                     */
/* 20250328         Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250523    0.2b Move HTTP.Request, HTTP.Response and Array.OutputStream   */
/*                  to separate files.                                        */
/* 20250524         Move generic CGI behaviour to Rexx.CGI.cls.               */
/* 20250621    0.2c Add support for .rex and .cls files.                      */
/* 20260101    0.4a Change [*STYLES*] -> %usedStyles%                         */
/* 20260215    0.4a Add support for print=pdf                                 */
/* 20260219    0.4a Add support for generalized style= parameters             */
/* 20260303    0.5  Add support for letter docclass                           */
/* 20260303         Add support for numbered section headers                  */
/* 20260310         Allow arbitrary sizes (thanks, JLF!)                      */
/* 20260310         Add support for figure/listing captions and numbering     */
/* 20260312         Add limited support for YAML front matter blocks          */
/* 20260312         Add YAML support for docclass and language                */
/* 20260312         Add YAML listings: and figures: sub-options               */
/* 20260312         Add YAML highlight-style for Pandoc syntax highlighting  */
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

--------------------------------------------------------------------------------
-- ::REQUIRES does not work well with "../" paths                             --
--------------------------------------------------------------------------------
  package      = .context~package
  local        =  package~local
  mypath       =  FileSpec( "Location", package~name )
  local~mypath = mypath
  local ~ .    = .File~new( mypath"../" )~absolutePath      -- Creates ".."

  Call Requires .."/bin/FencedCode.cls"
  Call Requires .."/bin/YAMLFrontMatter.cls"
  Call Requires mypath"rexx.epbcn.com.optional.cls"

 .MyCGI~new~execute

Exit

Requires:
  package~addPackage( .Package~new( Arg(1) ) )
  Return

--------------------------------------------------------------------------------
-- Error handling in CGIs is complicated, we'd better have a decent handler   --
--------------------------------------------------------------------------------

Syntax:
 .output~destination( .stdOut )
  ConditionObject = Condition("O")
  major     = ConditionObject~rc
  code      = ConditionObject~code
  message1  = ConditionObject~errorText
  message2  = ConditionObject~message
  program   = ConditionObject~program
  line      = ConditionObject~position
  traceBack = ConditionObject~traceBack
  Say "Content-type: text/plain; charset=utf8"
  Say ""
  Say "Syntax error" major "in" program "line" line": " message1
  Say "Error" code":" message2
  Say ""
  Say "Traceback follows:"
  Do line Over traceBack
    Say line
  End
Exit

/******************************************************************************/

::Requires "Rexx.CGI.cls"

/******************************************************************************/
/******************************************************************************/
/* MYCGI                                                                      */
/******************************************************************************/
/******************************************************************************/

-- We subclass Rexx.CGI and implement the abstract PROCESS method,
-- which encapsulates the specificities of our CGIs.

::Class MyCGI SubClass Rexx.CGI

/******************************************************************************/
/* PROCESS                                                                    */
/******************************************************************************/

::Method Process

  file = self~file
  URI  = self~URI

  ------------------------------------------------------------------------------
  -- Accepted parameters are "style=styleName", "print=pdf", "size=n",        --
  -- "sections=n", "figures", and "view=highlight" (only for .rex and .cls    --
  -- files).                                                                  --
  -- When style=styleName is specified, the program will search for a file    --
  -- called rexx-<stylename>.css in the css subdirectory.                     --
  -- For security reasons, only letters, numbers, periods, dashes and         --
  -- underscores are accepted as styleNames.                                  --
  ------------------------------------------------------------------------------

  style          = "dark"
  view           = "text"
  size           = 12
  print          = 0
  language       = "en"
  highlightStyle = "pygments"
  sectionNumbers = -1
  numberFigures  = 1

  -- Track whether style was explicitly set via URL,
  -- so that YAML front matter can provide a default.
  urlStyle = 0

  If uri~contains("?")  Then Do
    Parse Var uri uri"?"parameters
    Loop While parameters \== ""
      Parse Var parameters param"&"parameters
      ok = 1
      Select
        When param == "print=pdf" Then print = 1
        When param == "numberfigures=0" Then numberFigures = 0
        When param == "numberfigures=1" Then numberFigures = 1
        When param~startsWith("view="), -
          (uri~endsWith(".cls") | uri~endsWith(".rex")) Then Do
          Parse Var param "view="view
          If view \== "highlight" Then ok = 0
        End
        When param~startsWith("style=") Then Do
          Parse Var param "style="style
          If style~verify(XRange("ALNUM")"-_.") > 0 Then ok = 0
          Else Do
            cssName = .MyPath"../css/rexx-"style".css"
            If \.File~new(cssName)~exists Then ok = 0
            Else urlStyle = 1
          End
        End
        When param~startsWith("size=") Then Do
          Parse Var param "size="size
          If \DataType(size,"W") | size < 1 Then ok = 0
        End
        When param~startsWith("sections=") Then Do
          Parse Var param "sections="sectionNumbers
          If \DataType(sectionNumbers,"W") | sectionNumbers < 0 | sectionNumbers > 4 Then ok = 0
        End
        Otherwise ok = 0
      End
      If \ok              Then Do
       .Response~404
        Return self~FAIL
      End
    End
  End

  ------------------------------------------------------------------------------
  -- We are using "readme.md", "article.md", "book.md", "letter.md" and       --
  -- "slides.md" as index pages, using the Apache DirectoryIndex directive.   --
  ------------------------------------------------------------------------------

  -- In case we need to form canonical URLs
  If      URI~endsWith(  "readme.md" ) Then URI = Left(URI, Length(URI) -  9)
  Else If URI~endsWith(    "book.md" ) Then URI = Left(URI, Length(URI) -  7)
  Else If URI~endsWith(  "slides.md" ) Then URI = Left(URI, Length(URI) -  9)
  Else If URI~endsWith(  "letter.md" ) Then URI = Left(URI, Length(URI) -  9)
  Else If URI~endsWith( "article.md" ) Then URI = Left(URI, Length(URI) - 10)

  fileLocation = FileSpec("Location",file)
  fileName     = FileSpec("Name",    file)

  ------------------------------------------------------------------------------
  -- See if an accompanying extra style .css file exists                      --
  --   This is is a file with the same name as the cgi, with ".css" added at  --
  --   the end. It is useful for specifying variables that are file-dependent,--
  --   like the running header and footer (this should be done with the       --
  --   string-set property, but it is not properly implemented in the major   --
  --   browsers).                                                             --
  ------------------------------------------------------------------------------

  Select Case FileSpec("Name",file)
    When "book.md"    Then filenameSpecificStyle = "print/book"
    When "slides.md"  Then filenameSpecificStyle = "print/slides"
    When "article.md" Then filenameSpecificStyle = "print/article"
    When "letter.md"  Then filenameSpecificStyle = "print/letter"
    Otherwise              filenameSpecificStyle = "markdown"
  End

  printStyle = Stream(file".css","c","Q exists")
  If printStyle \== "" Then Do
    p = LastPos(.File~separator,printStyle)
    printStyle = SubStr(printStyle,p+1)
  End

  ------------------------------------------------------------------------------
  -- Ok, now we have a file to process. Read it into an array                 --
  ------------------------------------------------------------------------------

  source = CharIn( file, 1, Chars(file) )~makeArray
  Call Stream file, "c", "close"

  ------------------------------------------------------------------------------
  -- Parse YAML front matter for RexxPub options                              --
  -- Precedence:                                                              --
  --   style:          URL > YAML > default  (reader/printer chooses)         --
  --   everything else: YAML > URL > default  (author's intent prevails)      --
  ------------------------------------------------------------------------------

  yaml = YAMLFrontMatter(source)
  -- Listings sub-options (defaults)
  listingCaptionPosition = "above"
  listingCaptionStyle    = "normal"
  listingLabelStyle      = "bold"
  listingLabel           = ""
  -- Figures sub-options (defaults)
  figureCaptionPosition  = "below"
  figureCaptionStyle     = "normal"
  figureLabelStyle       = "bold"
  figureLabel            = ""

  If yaml \== .Nil, yaml~hasIndex("rexxpub") Then Do
    rp = yaml["rexxpub"]
    If rp~isA(.StringTable) Then Do
      -- style: only use YAML when the URL did not specify one
      If \urlStyle, rp~hasIndex("style") Then
        style = rp["style"]
      -- For structural options, YAML always wins
      If rp~hasIndex("size") Then
        size = rp["size"]
      If rp~hasIndex("section-numbers") Then
        sectionNumbers = rp["section-numbers"]
      If rp~hasIndex("number-figures") Then Do
        nf = rp["number-figures"]
        Select Case Lower(nf)
          When "0", "false" Then numberFigures = 0
          When "1", "true"  Then numberFigures = 1
          Otherwise Nop                  -- Ignore invalid values
        End
      End
      -- docclass: YAML overrides filename inference
      If rp~hasIndex("docclass") Then Do
        yamlDocClass = Lower(rp["docclass"])
        validClasses = "article book letter slides"
        If validClasses~caselessWordPos(yamlDocClass) > 0 Then
          filenameSpecificStyle = "print/"yamlDocClass
        -- Otherwise silently ignored
      End
      -- language: YAML always wins
      If rp~hasIndex("language") Then
        language = rp["language"]
      -- listings: sub-table with caption options
      If rp~hasIndex("listings") Then Do
        lst = rp["listings"]
        If lst~isA(.StringTable) Then Do
          If lst~hasIndex("caption-position") Then Do
            cp = Lower(lst["caption-position"])
            If cp == "above" | cp == "below" Then
              listingCaptionPosition = cp
          End
          If lst~hasIndex("caption-style") Then Do
            cs = Lower(lst["caption-style"])
            If cs == "normal" | cs == "italic" Then
              listingCaptionStyle = cs
          End
          If lst~hasIndex("label-style") Then Do
            ls = Lower(lst["label-style"])
            If "normal bold italic bold-italic"~wordPos(ls) > 0 Then
              listingLabelStyle = ls
          End
          If lst~hasIndex("label") Then
            listingLabel = lst["label"]
        End
      End
      -- figures: sub-table with caption options
      If rp~hasIndex("figures") Then Do
        fig = rp["figures"]
        If fig~isA(.StringTable) Then Do
          If fig~hasIndex("caption-position") Then Do
            cp = Lower(fig["caption-position"])
            If cp == "above" | cp == "below" Then
              figureCaptionPosition = cp
          End
          If fig~hasIndex("caption-style") Then Do
            cs = Lower(fig["caption-style"])
            If cs == "normal" | cs == "italic" Then
              figureCaptionStyle = cs
          End
          If fig~hasIndex("label-style") Then Do
            ls = Lower(fig["label-style"])
            If "normal bold italic bold-italic"~wordPos(ls) > 0 Then
              figureLabelStyle = ls
          End
          If fig~hasIndex("label") Then
            figureLabel = fig["label"]
        End
      End
    End
  End

  -- Read highlight-style from top-level YAML (standard Pandoc metadata)
  If yaml \== .Nil, yaml~hasIndex("highlight-style") Then
    highlightStyle = Lower(yaml["highlight-style"])

  -- Resolve sectionNumbers default based on docclass
  -- (uses filenameSpecificStyle which may have been overridden by YAML)
  If sectionNumbers == -1 Then
    Select Case filenameSpecificStyle
      When "print/book"   Then sectionNumbers = 2
      When "print/slides" Then sectionNumbers = 0
      Otherwise                sectionNumbers = 3
    End

  ------------------------------------------------------------------------------
  -- Special case for .rex or .cls files                                      --
  ------------------------------------------------------------------------------

  If URI~endsWith( ".rex" ) Then Signal View
  If URI~endsWith( ".cls" ) Then Signal View

  ------------------------------------------------------------------------------
  -- We process Rexx fenced code blocks first                                 --
  ------------------------------------------------------------------------------

  defaultOptions.         = 0
  defaultOptions.continue = 1
  source = FencedCode( file, source, style, defaultOptions. )

  ------------------------------------------------------------------------------
  -- We now call pandoc. It will transform markdown into html by default      --
  ------------------------------------------------------------------------------

  contents = .Array~new

  -- Needed so that Pandoc finds the files mentioned in the YAML section
  Call Directory fileLocation

  If \print Then command = 'pandoc --citeproc -M link-citations=true' -
    '--from markdown-smart+footnotes' -
    '--reference-location=section'
  Else Do
    command = 'pandoc --citeproc'-
    '-M link-citations=true' -
    '--lua-filter='.myPath || "inline-footnotes.lua"
  End

  Address COMMAND command -
    With Input Using (source) Output Using (contents) Error Using (contents)

  ------------------------------------------------------------------------------
  -- As the document title, pick the contents of the first h1 header          --
  ------------------------------------------------------------------------------

  title = "Missing title"
  chunk = contents~makeString("L"," ")


  Select Case fileName
    When "letter.md" Then Do
      Parse Caseless Var chunk With '<div class="recipient">' '<p>'title'</p>'
      If title \== "" Then title = "Letter to" title
      Else Do
        Parse Caseless Var chunk With '<div class="opening">' '<p>'title'</p>'
        If title \== "" Then Do
          title = "Letter -" title
          If title~endsWith(",") Then title = Left(title, Length(title)-1)
        End
        Else title = "Letter"
      End
      htmlTitle = title
    End
    Otherwise Do
      If chunk~contains("<h1") Then Do
        Parse Var chunk "<h1" ">"title"</h1>"
        If title~caselessPos("<small") > 0 Then
          Parse Caseless Var title title "<small"
        htmlTitle = title
        Do While title~caselessPos("<br>") > 0
          title = title~caselessChangeStr("<br>","")
        End
        Do While title~caselessPos("<br") > 0
          Parse Caseless Var title With before "<br" ">" after
          title = before after
        End
        Do While Pos("<",title) > 0
          Parse Var title before "<" ">" after
          title = before after
        End
      End
    End
  End

  ------------------------------------------------------------------------------
  -- Copy the HTML resource, with some substitutions                          --
  ------------------------------------------------------------------------------

  If sectionNumbers > 0
    Then sectionNumbersClass = "section-numbers-"sectionNumbers
    Else sectionNumbersClass = ""

  If numberFigures
    Then numberFiguresClass = "number-figures"
    Else numberFiguresClass = ""

  /* Build listing and figure data-* attributes and CSS overrides            */
  listingsAttrs = ""
  figuresAttrs  = ""
  overrideCSS   = ""

  If listingCaptionPosition \== "above" Then
    listingsAttrs ||= ' data-listing-caption-position="'listingCaptionPosition'"'
  If listingLabel \== "" Then
    listingsAttrs ||= ' data-listing-label="'listingLabel'"'
  If figureCaptionPosition \== "below" Then
    figuresAttrs ||= ' data-figure-caption-position="'figureCaptionPosition'"'
  If figureLabel \== "" Then
    figuresAttrs ||= ' data-figure-label="'figureLabel'"'

  /* --- Listing CSS overrides ---                                           */
  If listingCaptionPosition == "below" Then
    overrideCSS ||= "figure.listing figcaption {"            -
      " break-after: auto; break-before: avoid;"             -
      " margin-top: 0.075em; margin-bottom: 0; }" || "0a"x  -
      || "figure.listing pre {"                              -
      " margin-bottom: 0; }" || "0a"x                       -
      || "figure.listing div.sourceCode {"                   -
      " margin-bottom: 0; }" || "0a"x
  If listingCaptionStyle == "italic" Then
    overrideCSS ||= "figure.listing figcaption {"            -
      " font-style: italic; }" || "0a"x
  Select Case listingLabelStyle
    When "normal" Then
      overrideCSS ||= "figure.listing .figure-number {"      -
        " font-weight: normal; font-style: normal; }" || "0a"x
    When "italic" Then
      overrideCSS ||= "figure.listing .figure-number {"      -
        " font-weight: normal; font-style: italic; }" || "0a"x
    When "bold-italic" Then
      overrideCSS ||= "figure.listing .figure-number {"      -
        " font-weight: bold; font-style: italic; }" || "0a"x
    Otherwise
      If listingCaptionStyle == "italic" Then
        overrideCSS ||= "figure.listing .figure-number {"    -
          " font-style: normal; }" || "0a"x
  End

  /* --- Figure CSS overrides ---                                            */
  If figureCaptionPosition == "above" Then
    overrideCSS ||= "figure:not(.listing) figcaption {"      -
      " break-before: auto; break-after: avoid;"             -
      " margin-top: 0; margin-bottom: 0.5em; }" || "0a"x    -
      || "figure:not(.listing) img {"                        -
      " margin-top: 0; }" || "0a"x
  If figureCaptionStyle == "italic" Then
    overrideCSS ||= "figure:not(.listing) figcaption {"      -
      " font-style: italic; }" || "0a"x
  Select Case figureLabelStyle
    When "normal" Then
      overrideCSS ||= "figure:not(.listing) .figure-number {" -
        " font-weight: normal; font-style: normal; }" || "0a"x
    When "italic" Then
      overrideCSS ||= "figure:not(.listing) .figure-number {" -
        " font-weight: normal; font-style: italic; }" || "0a"x
    When "bold-italic" Then
      overrideCSS ||= "figure:not(.listing) .figure-number {" -
        " font-weight: bold; font-style: italic; }" || "0a"x
    Otherwise
      If figureCaptionStyle == "italic" Then
        overrideCSS ||= "figure:not(.listing) .figure-number {" -
          " font-style: normal; }" || "0a"x
  End

  template = .Resources~HTML

  Do line Over template
    Select Case Strip(Lower(line))
      When "%title%"         Then Say title
      When "%contentheader%" Then Call OptionalCall ContentHeader, uri, file
      When "%header%"        Then Call OptionalCall PageHeader, HTMLTitle
      When "%contents%"      Then Do line Over contents; Say line; End
      When "%footer%"        Then Call OptionalCall PageFooter
      When "%sidebar%"       Then Call OptionalCall Sidebar, uri
      When "%printjs%"       Then If print Then
        Say "<script src='/js/paged.polyfill.js'></script>"
      When "%printtoc%"      Then
        Say "<script src='/rexx-parser/js/createToc.js'></script>"
      When "%printsections%"  Then
        If print & sectionNumbers > 0 Then
          Say "<script src='/rexx-parser/js/numberSections.js'></script>"
      When "%printfigures%"   Then
        Say "<script src='/rexx-parser/js/numberFigures.js'></script>"
      When "%printstyle%"    Then
        If printStyle \== "" Then
          Say "    <link rel='stylesheet' media='print' href='"printStyle"'>"
      When "%filenamespecificstyle%"    Then Do
        If filenameSpecificStyle == "markdown" Then
          Say "    <link rel='stylesheet' href='/rexx-parser/css/markdown.css'>"
        Else Do
          Say "    <link rel='stylesheet'" -
              "href='/rexx-parser/css/print/rexxpub-base.css'>"
          Say "    <link rel='stylesheet'" -
              "href='/rexx-parser/css/"filenameSpecificStyle".css'>"
        End
      End
      When "%sizespecificstyle%"        Then Do
        If size \== 12 Then Do
          sizeFile = .MyPath"../css/"filenameSpecificStyle"-"size"pt.css"
          If .File~new(sizeFile)~exists Then
            Say "    <link rel='stylesheet'" -
                "href='/rexx-parser/css/"filenameSpecificStyle"-"size"pt.css'>"
        End
      End
      When "%highlightstyle%"            Then Do
        pandocCSSName = highlightStyle".css"
        If .File~new(.MyPath"../css/pandoc/"pandocCSSName)~exists Then
          Say "    <link rel='stylesheet'" -
              "href='/rexx-parser/css/pandoc/"pandocCSSName"'>"
      End
      When "%listingsstyle%"             Then
        If overrideCSS \== "" Then
          Say "    <style>" || overrideCSS || "</style>"
      Otherwise Say line~changeStr("%SectionNumbers%", sectionNumbersClass) -
                        ~changeStr("%NumberFigures%",  numberFiguresClass)  -
                        ~changeStr("%ListingsAttrs%",  listingsAttrs)       -
                        ~changeStr("%FiguresAttrs%",   figuresAttrs)        -
                        ~changeStr("%Language%",       language)
    End
  End

  ------------------------------------------------------------------------------
  -- Hack: Review entire .Array.Output array, detect CSS styles used          --
  -- in fenced code blocks, and dynamically update the array to refer         --
  -- to these CSS files.                                                      --
  ------------------------------------------------------------------------------
Hack:

  out   = .Array.Output
  lines = out~items

  -- We choose "</head>" because it has no attributes.

  subs = 0
  Do i = 1 To lines Until Lower(out[i]) = "</head>"
    If Lower(out[i]) = "%usedstyles%" Then subs = i
  End

  If i > items Then Raise Halt Array("No '</head>' line found.")
  If subs == 0 Then Raise Halt Array("No '%usedStyles%' line found.")

  allowed = XRange(AlNum)".-_"
  styles = .Array~new
  Do i = i + 1 To out~items
    Parse Value out[i] With ' class="highlight-rexx-'style'"'
    If style == "" Then Iterate
    If Verify(style, allowed) > 0 Then Iterate
    If \styles~hasItem(style) Then styles~append(style)
  End

  new = "    "
  Do style Over styles
    new ||= "<link rel='stylesheet' href='/rexx-parser/css/rexx-"style".css'>"
  End

  out[subs] = new

  Return self~OK

  ------------------------------------------------------------------------------

OptionalCall: Procedure
  Signal On Syntax Name OptionalRoutineMissing
  routineName = Markdown"."Arg(1)
  Call (routineName) Arg(2), Arg(3)
  Return
OptionalRoutineMissing:
  code = Condition("O")~code
  If code == 43.1, Condition("A")[1] = routineName Then Return
Raise Propagate

--------------------------------------------------------------------------------

View:

  If view \== "highlight" Then Do
    self~Content_Type = "text/plain"
    Do line Over source
      Say line
    End
    Exit self~OK
  End

  fenced = .Array~of("~~~~~~~~~~~~~~rexx")
  fenced ~ appendAll(source)
  fenced ~ append("~~~~~~~~~~~~~~")

  contents = FencedCode( file, fenced )

  ------------------------------------------------------------------------------
  -- Copy the HTML resource, with some substitutions                          --
  ------------------------------------------------------------------------------

  template = .Resources~DisplayRexx

  Do line Over template
    Select Case Strip(Lower(line))
      When "%title%"                 Then Say  URI
      When "%header%"                Then Call OptionalCall PageHeader, URI
      When "%contents%"              Then Do line Over contents; Say line; End
      When "%footer%"                Then Call OptionalCall PageFooter
      When "%sidebar%"               Then Call OptionalCall Sidebar, uri
      When "%contentheader%"         Then Call OptionalCall ContentHeader, uri
      When "%printstyle%"            Then Nop
      When "%filenamespecificstyle%" Then Nop
      Otherwise Say line~changeStr("%Language%", language)
    End
  End

  Signal Hack

-- We are loading a local copy of Bootstrap 3, customized to eliminate
-- print media styles, and then we add our own media styles css.

::Resource DisplayRexx
<!doctype html>
<html lang='%Language%'>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>
      %title%
    </title>
    <link rel="stylesheet" href="/css/bootstrap.min.css">
%usedStyles%
    %printStyle%
    <!--[if lt IE 9]>
      <script src="https://cdn.jsdelivr.net/npm/html5shiv@3.7.3/dist/html5shiv.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/respond.js@1.4.2/dest/respond.min.js"></script>
    <![endif]-->
  </head>
  <body>
    %contents%
    <script src="/js/bootstrap.min.js"></script>
  </body>
</html>
::END


/******************************************************************************/
/******************************************************************************/
--                         Structure of a page:
--
--      +-------------------------------------------------------------+
--      |              page header, including the title               |
--      +-------------------------------------------------------------+
--      |                content header               |   side bar    |
--      +---------------------------------------------+               |
--      |                                             |               |
--      |                  contents                   |               |
--      |                                             |               |
--      |                 [9 columns]                 |  [3 columns]  |
--      +-------------------------------------------------------------+
--      |                          page footer                        |
--      +-------------------------------------------------------------+
--
/******************************************************************************/
/******************************************************************************/

::Resource HTML
<!doctype html>
<html lang='%Language%'>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>
      %title%
    </title>
    <link rel="stylesheet" href="/css/bootstrap.min.css">
%usedStyles%
    %filenameSpecificStyle%
    %sizeSpecificStyle%
    %highlightStyle%
    %printStyle%
    %printJs%
    %listingsStyle%
    <!--[if lt IE 9]>
      <script src="https://cdn.jsdelivr.net/npm/html5shiv@3.7.3/dist/html5shiv.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/respond.js@1.4.2/dest/respond.min.js"></script>
    <![endif]-->
  </head>
  <body>
    <div class='container bg-white' lang='%Language%'>
      %header%
      <div class='row'>
        <div class='col-md-9'>
          %contentheader%
          <div class='content %SectionNumbers% %NumberFigures%'%ListingsAttrs%%FiguresAttrs%>
            %contents%
          </div>
        </div>
        <div class="col-md-3 text-center text-larger">
          %sidebar%
        </div>
      </div>
      %footer%
    </div>
    <script src="https://code.jquery.com/jquery-1.12.4.min.js" integrity="sha384-nvAa0+6Qg9clwYCGGPpDQLVpLNn0fRaROjHqs13t4Ggj3Ez50XnGQqc/r8MhnRDZ" crossorigin="anonymous"></script>
    <script src="/js/bootstrap.min.js"></script>
    %printFigures%
    %printSections%
    %printTOC%
    <script src="/js/chooser.js"></script>
  </body>
</html>
::END
