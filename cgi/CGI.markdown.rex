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

  Call Requires .."/cls/FencedCode.cls"
  Call Requires mypath"rexx.epbcn.com.optional.cls"

  Signal SkipOverRequiresAndSyntaxHandler

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

--------------------------------------------------------------------------------

SkipOverRequiresAndSyntaxHandler:

--------------------------------------------------------------------------------
-- We will collect all our output in an array. To this effect, we use         --
-- a small class that subclasses .Array and at the same time inherits from    --
-- .OutputStream. Indeed, we only need to implement the SAY method.           --
--                                                                            --
-- We change the destination of the output monitor to point to this           --
-- hybrid array.                                                              --
--------------------------------------------------------------------------------

  arrayOutput = .ArrayOutputStream~new
 .output~destination( arrayOutput )

--------------------------------------------------------------------------------
-- We now create .request and .response objects to encapsulate the            --
-- complexities of the CGI protocol.                                          --
--------------------------------------------------------------------------------

 .environment~request  = .Http.Request~new
 .environment~response = .Http.Response~new

--------------------------------------------------------------------------------
-- PATH_TRANSLATED should point to the markdown file we have to process,      --
-- and REQUEST_URI should contain the request URI.                            --
--------------------------------------------------------------------------------

  file = .request~PATH_TRANSLATED
  url  = .request~REQUEST_URI

--------------------------------------------------------------------------------
-- We need to ensure that the CGI processor has not been called directly;     --
-- if this happens, the environment strings will be empty. In that case,      --
-- we produce a soft 404.                                                     --
--------------------------------------------------------------------------------

  If file == ""         Then Exit .Response~404
  If url  == ""         Then Exit .Response~404

--------------------------------------------------------------------------------
-- We only accept one optional query, of the form style=(light|dark)          --
--------------------------------------------------------------------------------

  style = "dark"
  If url~contains("?")  Then Do
    Parse Var url url"?"query
    ok = 0
    If query~startsWith("style=") Then Do
      Parse Var query "style="style
      If style == "dark" | style == "light" Then ok = 1
    End
    If \ok Then Exit .Response~404
  End

--------------------------------------------------------------------------------
-- We don't want strangely formatted URIs                                     --
--------------------------------------------------------------------------------

  If url~contains("//") Then Exit .Response~404
  If url~contains("/.") Then Exit .Response~404
  If url~contains("..") Then Exit .Response~404

--------------------------------------------------------------------------------
-- We are using "readme.md" as one of the index pages, using the Apache       --
-- DirectoryIndex directive.                                                  --
--------------------------------------------------------------------------------

  -- In case we need to form canonical URLs
  If url~endsWith("readme.md") Then url = Left(url, Length(url) - 9)

--------------------------------------------------------------------------------
-- The file should exist in the filesystem; if not, that's a 404 too.         --
--------------------------------------------------------------------------------

  resolved = Stream(file,"C","Query exists")
  If resolved == ""     Then Exit .Response~404

--------------------------------------------------------------------------------
-- There is a bug in the Linux version of ooRexx by which trailing slashes    --
-- are wrongly accepted at the end of a filename. We don't want that.         --
-- See https://sourceforge.net/p/oorexx/bugs/1940/                            --
--------------------------------------------------------------------------------

  If file~endsWith("/") Then Do
    file2 = Strip(file,"T","/")
    resolved2 = Stream(file2,"C","Query exists")
    If resolved2 == resolved Then Exit .Response~404
  End

--------------------------------------------------------------------------------
-- See if an accompanying extra style .css file exists                        --
--   This is is a file with the same name as the cgi, with ".css" added at    --
--   the end. It is useful for specifying variables that are file-dependent,  --
--   like the running header and footer (this should be done with the         --
--   string-set property, but it is not properly implemented in the major     --
--   browsers).
--------------------------------------------------------------------------------

  Select Case FileSpec("Name",file)
    When "slides.md"  Then ownStyle = "slides"
    When "article.md" Then ownStyle = "article"
    Otherwise              ownStyle = ""
  End
  extraStyle = Stream(resolved".css","c","Q exists")
  If extraStyle \== "" Then Do
    p = LastPos(.File~separator,extraStyle)
    extraStyle = SubStr(extraStyle,p+1)
  End

--------------------------------------------------------------------------------
-- Ok, now we have a file to process. Read it into an array                   --
--------------------------------------------------------------------------------

  file = resolved
  source = CharIn( file, 1, Chars(file) )~makeArray
  Call Stream file, "c", "close"

--------------------------------------------------------------------------------
-- We process Rexx fenced code blocks first                                   --
--------------------------------------------------------------------------------

  source = FencedCode( file, source, style )

--------------------------------------------------------------------------------
-- Now call pandoc. It will transform markdown into html by default           --
--------------------------------------------------------------------------------

  contents = .Array~new
  Address COMMAND 'pandoc --from markdown-smart+footnotes' -
    '--reference-location=section' -
    With Input Using (source) Output Using (contents)

--------------------------------------------------------------------------------
-- As the document title, pick the contents of the first h1 header            --
--------------------------------------------------------------------------------

  title = "Missing title"
  chunk = contents~makeString("L"," ")
  If chunk~contains("<h1") Then
    Parse Var chunk "<h1" ">"title"</h1>"

--------------------------------------------------------------------------------
-- Our output will be html                                                    --
--------------------------------------------------------------------------------

 .response~"Content-Type" = "text/html"

--------------------------------------------------------------------------------
-- Copy the HTML resource, with some substitutions                            --
--------------------------------------------------------------------------------

  template = .Resources~HTML

  Do line Over template
    Select
      When line = "%title%"         Then Say  title
      When line = "%header%"        Then Call OptionalCall PageHeader, title
      When line = "%contents%"      Then Say  contents
      When line = "%footer%"        Then Call OptionalCall PageFooter
      When line = "%sidebar%"       Then Call OptionalCall Sidebar, url
      When line = "%contentheader%" Then Call OptionalCall ContentHeader, url
      When line = "%extrastyle%"    Then
        If extraStyle \== "" Then
          Say "    <link rel='stylesheet' media='print' href='"extraStyle"'>"
      When line = "%ownstyle%"    Then
        If ownStyle \== "" Then
          Say "    <link rel='stylesheet'" -
              "href='/rexx-parser/css/print/"ownstyle".css'>"
      Otherwise Say line
    End
  End

--------------------------------------------------------------------------------
-- We are done. We only have to revert to normal .stdout, ...                 --
--------------------------------------------------------------------------------

 .output~destination

--------------------------------------------------------------------------------
-- ... emit the stored HTTP headers ...                                       --
--------------------------------------------------------------------------------

 .response~printHeaders

--------------------------------------------------------------------------------
-- ... and an empty line to separate http headers and html body ...           --
--------------------------------------------------------------------------------

  Say ""

--------------------------------------------------------------------------------
-- ...and we can finally emit the body, by dumping the whole array at once    --
--------------------------------------------------------------------------------

  Say arrayOutput

Exit 0

--------------------------------------------------------------------------------
-- This allows us to optionally implement headers, footers, breadcrumbs and   --
-- sidebars.                                                                  --
--------------------------------------------------------------------------------

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

::Class Http.Request
::Method unknown
  Return Value(Arg(1),,"ENVIRONMENT")

--------------------------------------------------------------------------------

::Class Http.Response
::Method 404
 .output~destination( .stdOut )
  Say 'Content-Type: text/html; charset=iso-8859-1'
  Say 'Status: 404 Not Found'
  Say ""
  Say '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">'
  Say '<html><head>'
  Say '<title>404 Not Found</title>'
  Say '</head><body>'
  Say '<h1>Not Found</h1>'
  Say '<p>The requested URL was not found on this server.</p>'
  Say '<hr>'
  Say Value('SERVER_SIGNATURE',,"ENVIRONMENT")'</body></html>'
  Return 0 -- Necessary to allow EXIT syntax
::Method init
  Expose headers order
  order   = .Array~new
  headers = .Directory~new
::Method printHeaders
  Expose headers order
  Do header Over order
    Say header":" headers[header]
  End
::Method unknown
  Expose headers order
  messageName = Arg(1)
  If messageName~endsWith("=") Then Do
    messageName = messageName[1, Length(messageName) - 1]
    messageName = Process(messageName)
    order~append( messageName )
    headers[ messageName ] = Arg(2)
    Return
  End
  messageName = Process(messageName)
  If \headers~hasIndex(messageName) Then Return ""
  Return headers[messageName]

Process:
  array = messageName~translate("  ","-_")~space~makeArray(" ")
  Do i = 1 To array~items
    array[i] = Upper( array[i][1] )Lower( SubStr(array[i],2) )
  End
  Return array~makeString("Line","-")

--------------------------------------------------------------------------------

::Class ArrayOutputStream SubClass Array Inherit OutputStream
::Method say
  Use Strict Arg string -- We make string not optional
  self~append(string)
  Return 0

--------------------------------------------------------------------------------
--  Structure of a page:
--
--  +------------------------------------------+
--  |         page header, inc. title          |
--  +------------------------------------------+
--  |       content header      |   side bar   |
--  +---------------------------+              |
--  |                           |              |
--  |          contents         |              |
--  |                           |              |
--  |        [9 columns]        |  [3 columns] |
--  +------------------------------------------+
--  |              page footer                 |
--  +------------------------------------------+
--
--------------------------------------------------------------------------------

-- We are loading a local copy of Bootstrap 3, customized to eliminate
-- print media styles, and then we add our own media styles css.

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
    <link rel='stylesheet' href='/rexx-parser/css/rexx-light.css'>
    <link rel='stylesheet' href='/rexx-parser/css/rexx-dark.css'>
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
