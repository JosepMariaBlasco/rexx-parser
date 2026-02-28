/******************************************************************************/
/*                                                                            */
/* rexx.epbcn.com.optional.cls -- Additional markdown/CGI routines            */
/* ===============================================================            */
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
/* 20241217    0.1c First public release                                      */
/* 20241229    0.1e Make non-essential parts of the page non-printable.       */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250621    0.2c Partial support for .rex and .cls files                   */
/* 20260228    0.4a Add style chooser support                                 */
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
          <h1 class="pagetitle">%title%</h1>
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

  myDir = FileSpec("Location",.context~package~name)
  Call SysFileTree myDir"../css/*.css",F.,"FO"

  array = .Array~new
  Do i = 1 To F.0
    name = FileSpec("Name", F.i)
    Parse Var name "rexx-"name".css"
    If name == "" | name == "dark" | name == "test1" Then Iterate
    array~append('<option value="'name'">'name'</option>')
  End

  Say pad'<form class="form-inline screenonly">'
  Say pad'  <div class="form-group">'
  Say pad'    <label for="style-chooser" style="margin-right: 10px;">'
  Say pad'      <span class="glyphicon glyphicon-eye-open" aria-hidden="true"></span> Style'
  Say pad'    </label>'
  Say pad'    <select class="form-control" id="style-chooser" style="width: auto; display: inline-block;">'
  Say pad'      <option value="dark">Default (dark)</option>'
  Say array
  Say pad'    </select>'
  Say pad'  </div>'
  Say pad'</form>'


  Exit

Crumb:

  tutor        = "/TUTOR"
  tutordocs    = "/TUTOR/doc"

  publications = "/publications"

  parser       = "/rexx-parser"
  print        = "/rexx-parser/doc/print"
  doc          = "/rexx-parser/doc"
  exp          = "/rexx-parser/doc/experimental"
  exe          = "/rexx-parser/doc/executor"
  bin          = "/rexx-parser/bin"
  guide        = doc"/guide"
  ref          = doc"/ref"
  dochl        = doc"/highlighter"
  docrexxpub   = doc"/rexxpub"
  dochlhtml    = dochl"/html"
  dochlfeat    = dochl"/features"
  docpub       = doc"/publications"

  Select Case Arg(1)

    -- Tools

    When "/tools"                  Then Return "Tools and utilities"

    -- Tokenizer

    When "/tokenizer"              Then Return "Tokenizer"

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
    When tutordocs"/publications"  Then Return "Publications"
    When tutordocs"/publications/36" Then Return "36<sup>th</sup> Symposium"
    When tutordocs"/publications/36/2025-05-04-Unicode-and-Rexx"
                                   Then Return "Unicode and Rexx"

    When tutordocs"/properties"    Then Return "Unicode properties"
    When tutordocs"/properties/normalization"
                                   Then Return "The Unicode.Normalization class"
    When tutordocs"/multi-stage-table"
                                   Then Return "The MultiStageTable class"
    When tutordocs"/persistent-string-table"
                                   Then Return "The PersistentStringTable class"
    When tutordocs"/using-tutor-from-classic-rexx"
                                   Then Return "Using TUTOR from Classic Rexx"
    When tutordocs"/0.6-release-notes.md"  Then Return "Release notes for version 0.6"
    When tutordocs"/0.5-release-notes.md"  Then Return "Release notes for version 0.5"
    When tutordocs"/0.4a-release-notes.md" Then Return "Release notes for version 0.4a"
    When tutordocs"/0.4-release-notes.md"  Then Return "Release notes for version 0.4"
    When tutordocs"/0.3b-release-notes.md" Then Return "Release notes for version 0.3b"
    When tutordocs"/0.3-release-notes.md"  Then Return "Release notes for version 0.3"
    When tutordocs"/0.2-release-notes.md"  Then Return "Release notes for version 0.2"
    When tutordocs"/0.1d-release-notes.md" Then Return "Release notes for version 0.1d"
    When tutordocs"/0.1-release-notes.md"  Then Return "Release notes for version 0.1"
    When tutordocs"/pre-0.1-release-notes.md"  Then Return "Release notes for the first version"

    -- "/"
    When ""                        Then Return "Home"
    When "/epbcn"                  Then Return "EPBCN"

    -- "/rexx-parser"
    When parser                    Then Return "Parser"
    When parser"/highlighter"      Then Return "Highlighter"
    When parser"/tests"            Then Return "Tests"

    -- "/rexx-parser/bin"

    When bin                       Then Return "bin"
    When bin"/tools"               Then Return "Tools"

    -- "/rexx-parser/doc/guide"

    When guide                     Then Return "User Guide"
    When guide"/errors"            Then Return "Error handling"
    When guide"/first-steps"       Then Return "First steps"
    When guide"/install"           Then Return "Installation"
    When guide"/elementapi"        Then Return "Element API"
    When guide"/treeapi"           Then Return "Tree API"

    -- "/rexx-parser/doc/ref"

    When ref                       Then Return "Reference"
    When ref"/classes"             Then Return "Classes"
    When ref"/classes/driver"      Then Return "Driver"
    When ref"/classes/highlighter" Then Return "Highlighter"
    When ref"/classes/rexx.clause" Then Return "Rexx.Clause"
    When ref"/classes/rexx.clause/rexx.directive" Then Return "Rexx.Directive"
    When ref"/classes/rexx.clause/rexx.directive/method.directive" Then
      Return "Method.Directive"
    When ref"/classes/rexx.parser" Then Return "Rexx.Parser"
    When ref"/classes/rexx.parser/early-check" Then Return "Early checks"
    When ref"/classes/stylepatch"  Then Return "StylePatch"
    When ref"/classes/element"     Then Return "Element"
    When ref"/categories"          Then Return "Element categories"

    -- "/rexx-parser/doc"
    When doc                       Then Return "Docs"
    When doc"/history"             Then Return "Version history"
    When doc"/glossary"            Then Return "Glossary"
    When doc"/todo"                Then Return "To-do list"
    When doc"/treeapi"             Then Return "Tree API"
    When doc"/elementapi"          Then Return "Element API"
    When doc"/samples"             Then Return "Samples"
    When doc"/oorexx-bugs"         Then Return "Related ooRexx bugs"
    When doc"/utilities"           Then Return "Utilities"
    When doc"/utilities/rxcheck"   Then Return "RxCheck"
    When doc"/utilities/rxcomp"    Then Return "RxComp"
    When doc"/utilities/erexx"     Then Return "ERexx"
    When doc"/utilities/highlight" Then Return "Highlight"
    When doc"/utilities/elements"  Then Return "Elements"
    When doc"/utilities/elident"   Then Return "Elident"
    When doc"/utilities/md2html"   Then Return "Md2html"
    When doc"/utilities/md2pdf"    Then Return "Md2pdf"
    When doc"/utilities/trident"   Then Return "Trident"
    When doc"/utilities/identtest" Then Return "Identtest"
    When doc"/unicode"             Then Return "Unicode"

    -- "/rexx-parser/doc/experimental"

    When exp                       Then Return "Experimental"
    When exp"/classextensions"     Then Return "Class extensions"

    -- "/rexx-parser/doc/executor"

    When exe                       Then Return "Executor"

    -- "/rexx-parser/doc/rexxpub"

    When docrexxpub                Then Return "RexxPub"
    When docrexxpub"/article"      Then Return "Writing articles"

    -- "/rexx-parser/doc/highlighter"

    When dochl                     Then Return "Highlighter"
    When dochl"/predefined-styles" Then Return "Predefined styles"
    When dochl"/cgi"               Then Return "CGI"
    When dochl"/css"               Then Return "CSS support"
    When dochl"/paged-media"       Then Return "CSS Paged Media"
    When dochl"/ansi"              Then Return "ANSI"
    When dochl"/latex"             Then Return "(Lua)LaTeX"
    When dochl"/examples"          Then Return "Highlighting examples"
    When dochl"/htmlclasses"       Then Return "HTMLClasses"
    When dochl"/fencedcode"        Then Return "Fenced Code Blocks"

    -- "/rexx-parser/doc/highlighter/features"

    When dochlfeat                 Then Return "Features"
    When dochlfeat"/var-symbol"    Then Return "Variable symbols"
    When dochlfeat"/compound-variable" Then Return "Compound variables"
    When dochlfeat"/calls"         Then Return "Function and subroutine calls"
    When dochlfeat"/taken-constant" Then Return "Taken constants"
    When dochlfeat"/doc-comments"  Then Return "Doc-comments"
    When dochlfeat"/patches"       Then Return "Style patches"
    When dochlfeat"/numbers"       Then Return "Detailed highlighting of numbers"
    When dochlfeat"/strings"       Then Return "Detailed string highlighting"

    -- "/rexx-parser/doc/highlighter/html"

    When dochlhtml                 Then Return "HTML"
    When dochlhtml"/instructions"  Then Return "Instruction tests"
    When dochlhtml"/directives"    Then Return "Directive tests"
    When dochlhtml"/classes"       Then Return "Element-class-to-HTML mappings"
    When dochlhtml"/all"           Then Return "General tests"

    -- "/rexx-parser/doc/publications"

    When docpub                    Then Return "Publications"
    When docpub"/36"               Then Return "36<sup>th</sup> Symposium"
    When docpub"/37"               Then Return "37<sup>th</sup> Symposium"
    When docpub"/37/2026-05-04-The-Rexx-Parser-Revisited"
                                   Then Return "The Rexx Parser Revisited"
    When docpub"/37/2026-05-05-RexxPub-A-Rexx-Publishing-Framework"
                                   Then Return "RexxPub: A Rexx Publishing Framework"
    When docpub"/36/2025-05-05-The-Rexx-Parser"
                                   Then Return "The Rexx Parser"
    When docpub"/36/2025-05-06-The-Rexx-Highlighter"
                                   Then Return "The Rexx Highlighter"

    Otherwise
      If Arg(1)~startsWith("/rexx-parser/bin/tools/") Then Do
        Parse Value Reverse(Arg(1)) With fn"/"
        Return Reverse(fn)
      End
      Return "XXX"
  End

--------------------------------------------------------------------------------
-- Side bar                                                                   --
--------------------------------------------------------------------------------

::Routine MarkDown.SideBar Public

  Parse Arg url

  If url~startsWith("/rexx-parser") Then
    Say .resources~SideBar.Rexx.Parser
  Else
    Say .resources~SideBar.Default

::Resource SideBar.Rexx.Parser
          <div class='panel panel-default sidebar'>
            <div class='panel-heading'>
               <b><a href="/rexx-parser/">The Rexx Parser</a></b>
            </div>
            <div class='panel-body text-left'>
                  <a href="/rexx-parser/#download">Download</a>
              <br><a href="/rexx-parser/doc/">Documentation</a>
              <br><a href="/rexx-parser/doc/glossary/">Glossary</a>
              <br><a href="/rexx-parser/doc/highlighter/">Highlighter</a>
              <br><a href="/rexx-parser/doc/rexxpub/">RexxPub</a>
              <br><a href="/rexx-parser/doc/history/">History</a>
              <br><a href="/rexx-parser/tests/">Tests</a>
              <br><a href="/rexx-parser/doc/todo/">To-do</a>
              <br><a href="/rexx-parser/doc/utilities/">Utilities</a>
              <br><a href="/rexx-parser/doc/samples/">Samples</a>
              <br><a href="/rexx-parser/doc/executor/">Executor support</a>
              <br><a href="/rexx-parser/doc/experimental/">Experimental</a>
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