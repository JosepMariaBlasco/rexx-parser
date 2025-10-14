#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* CGI.markdown.rex -- Sample Apache CGI markdown processor                   */
/* ========================================================                   */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
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
/*                                                                            */
/******************************************************************************/

  Signal On Syntax

--------------------------------------------------------------------------------
-- ::REQUIRES does not work well with "../" paths                             --
--------------------------------------------------------------------------------
  package   = .context~package
  local     =  package~local
  mypath    =  FileSpec( "Drive", package~name )FileSpec( "Path", package~name )
  local ~ . = .File~new( mypath"../" )~absolutePath      -- Creates ".."

  Call Requires .."/bin/FencedCode.cls"
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
  -- We only accept one optional query, of the form "style=(light|dark)"      --
  -- or "view=highlight" (only for .rex and .cls files)                       --
  ------------------------------------------------------------------------------

  style = "dark"
  view  = "text"
  If uri~contains("?")  Then Do
    Parse Var uri uri"?"query
    ok = 0
    If query~startsWith("view="), -
      (uri~endsWith(".cls") | uri~endsWith(".rex")) Then Do
      Parse Var query "view="view
      If view == "highlight" Then ok = 1
    End
    Else If query~startsWith("style=") Then Do
      Parse Var query "style="style
      If style == "dark" | style == "light" Then ok = 1
    End
    If \ok              Then Do
     .Response~404
     Return self~FAIL
    End
  End

  ------------------------------------------------------------------------------
  -- We are using "readme.md", "slides.md" and "article.md" as index pages,   --
  -- using the Apache DirectoryIndex directive.                               --
  ------------------------------------------------------------------------------

  -- In case we need to form canonical URLs
  If      URI~endsWith(  "readme.md" ) Then URI = Left(URI, Length(URI) -  9)
  Else If URI~endsWith(  "slides.md" ) Then URI = Left(URI, Length(URI) -  9)
  Else If URI~endsWith( "article.md" ) Then URI = Left(URI, Length(URI) - 10)

  ------------------------------------------------------------------------------
  -- See if an accompanying extra style .css file exists                      --
  --   This is is a file with the same name as the cgi, with ".css" added at  --
  --   the end. It is useful for specifying variables that are file-dependent,--
  --   like the running header and footer (this should be done with the       --
  --   string-set property, but it is not properly implemented in the major   --
  --   browsers).                                                             --
  ------------------------------------------------------------------------------

  Select Case FileSpec("Name",file)
    When "slides.md"  Then ownStyle = "slides"
    When "article.md" Then ownStyle = "article"
    Otherwise              ownStyle = ""
  End
  extraStyle = Stream(file".css","c","Q exists")
  If extraStyle \== "" Then Do
    p = LastPos(.File~separator,extraStyle)
    extraStyle = SubStr(extraStyle,p+1)
  End

  ------------------------------------------------------------------------------
  -- Ok, now we have a file to process. Read it into an array                 --
  ------------------------------------------------------------------------------

  source = CharIn( file, 1, Chars(file) )~makeArray
  Call Stream file, "c", "close"

  ------------------------------------------------------------------------------
  -- Special case for .rex or .cls files                                      --
  ------------------------------------------------------------------------------

  If URI~endsWith( ".rex") Then Signal View
  If URI~endsWith( ".cls") Then Signal View

  ------------------------------------------------------------------------------
  -- We process Rexx fenced code blocks first                                 --
  ------------------------------------------------------------------------------

  source = FencedCode( file, source, style )

  ------------------------------------------------------------------------------
  -- We now call pandoc. It will transform markdown into html by default      --
  ------------------------------------------------------------------------------

  contents = .Array~new
  Address COMMAND 'pandoc --from markdown-smart+footnotes' -
    '--reference-location=section' -
    With Input Using (source) Output Using (contents)

  ------------------------------------------------------------------------------
  -- As the document title, pick the contents of the first h1 header          --
  ------------------------------------------------------------------------------

  title = "Missing title"
  chunk = contents~makeString("L"," ")
  If chunk~contains("<h1") Then
    Parse Var chunk "<h1" ">"title"</h1>"

  ------------------------------------------------------------------------------
  -- Copy the HTML resource, with some substitutions                          --
  ------------------------------------------------------------------------------

  template = .Resources~HTML

  Do line Over template
    Select
      When line = "%title%"         Then Say  title
      When line = "%header%"        Then Call OptionalCall PageHeader, title
      When line = "%contents%"      Then Do line Over contents; Say line; End
      When line = "%footer%"        Then Call OptionalCall PageFooter
      When line = "%sidebar%"       Then Call OptionalCall Sidebar, uri
      When line = "%contentheader%" Then Call OptionalCall ContentHeader, uri
      When line = "%extrastyle%"    Then
        If extraStyle \== "" Then
          Say "    <link rel='stylesheet' media='print' href='"extraStyle"'>"
      When line = "%ownstyle%"      Then
        If ownStyle \== ""   Then
          Say "    <link rel='stylesheet'" -
              "href='/rexx-parser/css/print/"ownstyle".css'>"
      Otherwise Say line
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
  Do i = 1 To lines Until out[i] = "</head>"
    If out[i] == "[*STYLES*]" Then subs = i
  End

  If i > items Then Raise Halt Array("No '</head>' line found.")
  If subs == 0 Then Raise Halt Array("No '[*STYLES*]' line found.")

  allowed = XRange(AlNum)".-_"
  styles = .Array~new
  Do i = i + 1 To out~items
    Parse Value out[i] With ' class="highlight-rexx-'style'">'
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
  Call (routineName) Arg(2)
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
    Select
      When line = "%title%"         Then Say  URI
      When line = "%header%"        Then Call OptionalCall PageHeader, URI
      When line = "%contents%"      Then Do line Over contents; Say line; End
      When line = "%footer%"        Then Call OptionalCall PageFooter
      When line = "%sidebar%"       Then Call OptionalCall Sidebar, uri
      When line = "%contentheader%" Then Call OptionalCall ContentHeader, uri
      When line = "%extrastyle%"    Then Nop
      When line = "%ownstyle%"      Then Nop
      Otherwise Say line
    End
  End

  Signal Hack


-- We are loading a local copy of Bootstrap 3, customized to eliminate
-- print media styles, and then we add our own media styles css.

::Resource DisplayRexx
<!doctype html>
<html lang='en'>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>
      %title%
    </title>
    <link rel="stylesheet" href="/css/bootstrap.min.css">
[*STYLES*]
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Questrial&display=swap" rel="stylesheet">
    %extrastyle%
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
<html lang='en'>
  <head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>
      %title%
    </title>
    <link rel="stylesheet" href="/css/bootstrap.min.css">
[*STYLES*]
    <link rel='stylesheet' href='/rexx-parser/css/markdown.css'>
    %ownstyle%
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Questrial&display=swap" rel="stylesheet">
    %extrastyle%
    <!--[if lt IE 9]>
      <script src="https://cdn.jsdelivr.net/npm/html5shiv@3.7.3/dist/html5shiv.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/respond.js@1.4.2/dest/respond.min.js"></script>
    <![endif]-->
  </head>
  <body>
    <div class='container bg-white' lang='en'>
      %header%
      <div class='row'>
        <div class='col-md-9'>
          %contentheader%
          <div class='content'>
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
  </body>
</html>
::END
