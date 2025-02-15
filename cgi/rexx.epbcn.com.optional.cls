/******************************************************************************/
/*                                                                            */
/* rexx.epbcn.com.optional.cls -- Additional markdown/CGI routines            */
/* ===============================================================            */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx.parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241217    0.1c First public release                                      */
/* 20241229    0.1e Make non-essential parts of the page non-printable.       */
/*                                                                            */
/******************************************************************************/

-- This is the set of routines used in the rexx.epbcn.com web.
-- They are provided AS A SAMPLE ONLY.

--------------------------------------------------------------------------------
-- Page header -- Displays a top menu, a logo, and the page title             --
--------------------------------------------------------------------------------

::Routine MarkDown.PageHeader Public

  Parse Arg title
  Say .resources~Header~makeString~changeStr("%title%",title)

::Resource Header
      <nav class="navbar navbar-inverse x-header">
        <div class='navbar-header'>
          <button type='button' class='navbar-toggle' data-toggle='collapse' data-target='#menuREXX'>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="/" aria-label="REXX">
            <span class="glyphicon glyphicon-home hidden-xs" aria-hidden="true"></span>
            <span class="visible-xs-inline-block micrologo"><b style="color:#ad564a">EP<span style="color:#f57a69">BCN / Rexx</span></b></span>
          </a>
        </div>
        <div class="collapse navbar-collapse" id="menuREXX">
          <ul class="nav navbar-nav navbar-right">
            <li><a href="/software/">SOFTWARE</a></li>
            <li><a href="/publications/">PUBLICATIONS</a></li>
            <li><a href="/symposium/">SYMPOSIA</a></li>
            <li><a href="/epbcn/">EPBCN</a></li>
            <li><a href="/josep-maria-blasco/">ABOUT ME</a></li>
          </ul>
        </div>
      </nav>
      <div class="row logo-and-title">
        <div class="col-lg-3 col-md-4 col-sm-5 hidden-xs">
          <a href="/"><img src="/imagenes/logo.png" class="img-responsive" alt="Rexx Repository -"></a>
        </div>
        <div class="col-lg-9 col-md-8 col-sm-7 col-xs-12">
          <h1 class="websection">%title%</h1>
        </div>
      </div>
      <br>
::END

--------------------------------------------------------------------------------
-- Content header -- Displays a breadcrumb                                    --
--------------------------------------------------------------------------------

::Routine MarkDown.ContentHeader Public

  Parse Arg before"/"after

  pad = "          "

  Say pad'<nav aria-label="breadcrumb" class="x-breadcrumb">'
  Say pad'  <ol class="breadcrumb">'

  Do While after \== ""
    crumb = Crumb( before )
    Say pad'    <li class="breadcrumb-item"><a href="'before'/">'crumb'</a></li>'
    Parse Var after middle"/"after
    before ||= "/"middle
  End

  classes = "breadcrumb-item active"
  Say pad'    <li class="'classes'">'Crumb(before)'</li>'

  Say pad'  </ol>'
  Say pad'</nav>'

  Exit

Crumb:

  tutor     = "/tutor"
  tutordocs = "/tutor/doc"

  parser    = "/rexx.parser"
  print     = "/rexx.parser/print"
  doc       = "/rexx.parser/doc"
  guide     = doc"/guide"
  ref       = doc"/ref"
  dochl     = doc"/highlighter"
  dochlhtml = dochl"/html"
  dochlfeat = dochl"/features"

  Select Case Arg(1)

    -- TUTOR

    When tutor                     Then Return "TUTOR"
    When tutordocs                 Then Return "Docs"
    When tutordocs"/rxu"           Then Return "RXU"
    When tutordocs"/string-types"  Then Return "New types of strings"
    When tutordocs"/built-in"      Then Return "Revised and enhanced BIFs"
    When tutordocs"/stream"        Then Return "Stream functions"
    When tutordocs"/encodings"     Then Return "Encoding and decoding"
    When tutordocs"/new-functions" Then Return "New functions"
    When tutordocs"/new-classes"   Then Return "New classes"
    When tutordocs"/options"       Then Return "The OPTIONS instruction"
    When tutordocs"/properties"    Then Return "Unicode properties"
    When tutordocs"/properties/normalization"
                                   Then Return "The Unicode.Normalization class"
    When tutordocs"/multi-stage-table"
                                   Then Return "The MultiStageTable class"
    When tutordocs"/persistent-string-table"
                                   Then Return "The PersistentStringTable class"
    When tutordocs"/using-tutor-from-classic-rexx"
                                   Then Return "Using TUTOR from Classic Rexx"

    -- "/"
    When ""                        Then Return "Home"
    When "/epbcn"                  Then Return "EPBCN"

    -- "/rexx.parser"
    When parser                    Then Return "Parser"
    When parser"/cgi"              Then Return "CGI"
    When parser"/download"         Then Return "Download"
    When parser"/highlighter"      Then Return "Highlighter"
    When parser"/tests"            Then Return "Tests"

    -- "/rexx.parser/print"

    When print                     Then Return "Publications"
    When print"/36"                Then Return "36<sup>th</sup> symposium"
    When print"/36/2025-05-04-The-Unicode-Tools-Of-Rexx"
                                   Then Return "The Unicode Tools Of Rexx"
    When print"/36/2025-05-05-The-Rexx-Parser"
                                   Then Return "The Rexx Parser"
    When print"/36/2025-05-05-The-Rexx-Parser-Slides"
                                   Then Return "The Rexx Parser (Slides)"
    When print"/36/2025-05-05-The-Rexx-Highlighter"
                                   Then Return "The Rexx Highlighter (Slides)"

    -- "/rexx.parser/doc/guide"

    When guide                     Then Return "User Guide"
    When guide"/errors"            Then Return "Error handling"
    When guide"/first-steps"       Then Return "First steps"
    When guide"/install"           Then Return "Installation"
    When guide"/elementapi"        Then Return "Element API"
    When guide"/treeapi"           Then Return "Tree API"

    -- "/rexx.parser/doc/ref"

    When ref                       Then Return "Reference"
    When ref"/classes"             Then Return "Classes"
    When ref"/classes/driver"      Then Return "Driver"
    When ref"/classes/highlighter" Then Return "Highlighter"
    When ref"/classes/rexx.parser" Then Return "Rexx.Parser"
    When ref"/classes/stylepatch"  Then Return "StylePatch"
    When ref"/classes/element"     Then Return "Element"
    When ref"/categories"          Then Return "Element categories"

    -- "/rexx.parser/doc"
    When doc                       Then Return "Docs"
    When doc"/history"             Then Return "Version history"
    When doc"/glossary"            Then Return "Glossary"
    When doc"/todo"                Then Return "To-do list"
    When doc"/treeapi"             Then Return "Tree API"
    When doc"/elementapi"          Then Return "Element API"
    When doc"/utils"               Then Return "Utilities"
    When doc"/utils/highlight"     Then Return "Highlight"
    When doc"/utils/elements"      Then Return "Elements"
    When doc"/unicode"             Then Return "Unicode"

    -- "/rexx.parser/doc/highlighter"

    When dochl                     Then Return "Highlighter"
    When dochl"/ansi"              Then Return "ANSI"
    When dochl"/latex"             Then Return "(Lua)LaTeX"
    When dochl"/htmlclasses"       Then Return "HTMLClasses"
    When dochl"/fencedcode"        Then Return "Fenced Code Blocks"

    -- "/rexx.parser/doc/highlighter/features"

    When dochlfeat                 Then Return "Features"
    When dochlfeat"/var-symbol"    Then Return "Variable symbols"
    When dochlfeat"/compound-variable" Then Return "Compound variables"
    When dochlfeat"/calls"         Then Return "Function and subroutine calls"
    When dochlfeat"/taken-constant" Then Return "Taken constants"
    When dochlfeat"/doc-comments"  Then Return "Doc-comments"
    When dochlfeat"/patches"       Then Return "Style patches"

    -- "/rexx.parser/doc/highlighter/html"

    When dochlhtml                 Then Return "HTML"
    When dochlhtml"/instructions"  Then Return "Instruction tests"
    When dochlhtml"/directives"    Then Return "Directive tests"
    When dochlhtml"/classes"       Then Return "Element-class-to-HTML mappings"
    When dochlhtml"/all"           Then Return "General tests"

    Otherwise                           Return "XXX"
  End

--------------------------------------------------------------------------------
-- Side bar                                                                   --
--------------------------------------------------------------------------------

::Routine MarkDown.SideBar Public

  Parse Arg url

  If url~startsWith("/rexx.parser") Then
    Say .resources~SideBar.Rexx.Parser
  Else
    Say .resources~SideBar.Default

::Resource SideBar.Rexx.Parser
          <div class='panel panel-default sidebar'>
            <div class='panel-heading'>
               <b><a href="/rexx.parser/">The Rexx Parser</a></b>
            </div>
            <div class='panel-body text-left'>
                  <a href="/rexx.parser/download/">Download</a>
              <br><a href="/rexx.parser/doc/">Documentation</a>
              <br><a href="/rexx.parser/doc/glossary/">Glossary</a>
              <br><a href="/rexx.parser/doc/highlighter/">Highlighter</a>
              <br><a href="/rexx.parser/doc/history/">History</a>
              <br><a href="/rexx.parser/tests/">Tests</a>
              <br><a href="/rexx.parser/doc/todo/">To-do</a>
              <br><a href="/rexx.parser/doc/utils/">Utilities and Samples</a>
            </div>
          </div>
::END

::Resource SideBar.Default
          <div class='panel panel-default sidebar'>
            <div class='panel-heading'>
               <b>Links</b>
            </div>
            <div class='panel-body text-left'>
                  <a href="/software/">Software</a>
              <br><a href="/publications/">Publications</a>
              <br><a href="/symposium/">Symposia</a>
              <br><a href="/epbcn/">EPBCN</a>
              <br><a href="/josep-maria-blasco/">About me</a>
            </div>
          </div>
::END

--------------------------------------------------------------------------------
-- Page footer                                                                --
--------------------------------------------------------------------------------

::Routine MarkDown.PageFooter Public

  year = Date("S")[1,4]

  Say .resources~PageFooter~makeString~changeStr("%year%",year)

::Resource PageFooter
      <hr class="before-footer">
      <div class="panel panel-default footer">
        <div class="panel-heading text-center">
          <small>Copyright &copy; 1992&ndash;%year%,
             <a href="https://www.epbcn.com/">EPBCN</a> &amp; <a href="/josep-maria-blasco/">Josep Maria Blasco</a>.
             This site is powered by <a href="https://sourceforge.net/projects/oorexx/">ooRexx</a> and
             <a href="/software/rexxhttp/">RexxHttp</a>.
          </small>
        </div>
      </div>
::END