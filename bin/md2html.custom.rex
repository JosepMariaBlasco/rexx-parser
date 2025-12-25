/******************************************************************************/
/*                                                                            */
/* md2html.custom.rex -- SAMPLE customization layer for md2html               */
/* ============================================================               */
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
/* 20241223    0.4a First version, based cgi/on rexx.epbcn.com.optional.cls   */
/*                                                                            */
/******************************************************************************/

pkgLocal = .Context~package~local
pkgLocal~Exception = .Stem~new     -- Will be used by md2html.Exception below
.Exception[] = 0
.Exception["test_fenced_code_blocks.md"] = 1

-- This set of routines is provided AS A SAMPLE ONLY.

--------------------------------------------------------------------------------
-- Page header -- Displays a top menu, a logo, and the page title             --
--------------------------------------------------------------------------------

::Routine md2html.Header Public

  Use Arg array, title

  Do line Over .resources~Header~makeString~changeStr("%title%",title)
    array~append( line )
  End

::Resource Header
      <nav class="navbar navbar-inverse x-header">
        <div class='navbar-header'>
          <button type='button' class='navbar-toggle' data-toggle='collapse' data-target='#menuREXX'>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
            <span class="icon-bar"></span>
          </button>
          <a class="navbar-brand" href="https://rexx.epbcn.com/" aria-label="REXX">
            <span class="micrologo"><b style="color:#ad564a">EP<span style="color:#f57a69">BCN / Rexx</span></b></span>
          </a>
        </div>
        <div class="collapse navbar-collapse" id="menuREXX">
          <ul class="nav navbar-nav navbar-right">
            <li><a href="https://rexx.epbcn.com/software/">SOFTWARE</a></li>
            <li><a href="https://rexx.epbcn.com/publications/">PUBLICATIONS</a></li>
            <li><a href="https://rexx.epbcn.com/symposium/">SYMPOSIA</a></li>
            <li><a href="https://rexx.epbcn.com/epbcn/">EPBCN</a></li>
            <li><a href="https://rexx.epbcn.com/josep-maria-blasco/">ABOUT ME</a></li>
          </ul>
        </div>
      </nav>
      <div class="row">
        <div>
          <h1>The Rexx-Parser</h1>
        </div>
      </div>
      <br>
::END

--------------------------------------------------------------------------------
-- Content header                                                             --                                    --
--------------------------------------------------------------------------------

::Routine md2html.ContentHeader Public

  Use Arg filename

  -- You might generate a breadcrumb from parts of the filename here

--------------------------------------------------------------------------------
-- Side bar                                                                   --
--------------------------------------------------------------------------------

::Routine md2html.SideBar Public

  Use Arg array

  Loop line Over .resources~SideBar
    array~append( line )
  End

::Resource SideBar
          <div class='panel panel-default sidebar'>
            <div class='panel-heading'>
               <b>The Rexx Parser</b>
            </div>
            <div class='panel-body text-left'>
                  <a href="https://rexx.epbcn.com/rexx-parser/#download">Download</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/">Documentation</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/glossary/">Glossary</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/highlighter/">Highlighter</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/history/">History</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/tests/">Tests</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/todo/">To-do</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/utilities/">Utilities</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/samples/">Samples</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/executor/">Executor support</a>
              <br><a href="https://rexx.epbcn.com/rexx-parser/doc/experimental/">Experimental</a>
            </div>
          </div>
::END

--------------------------------------------------------------------------------
-- Page footer                                                                --
--------------------------------------------------------------------------------

::Routine md2html.Footer Public

  Use Arg array

  year = Date("S")[1,4]

  Loop line Over .resources~PageFooter~makeString~changeStr("%year%",year)
    array~append( line )
  End

::Resource PageFooter
      <hr class="before-footer">
      <div class="panel panel-default footer">
        <div class="panel-heading text-center">
          <small>Copyright &copy; 1992&ndash;%year%,
             <a href="https://www.epbcn.com/">EPBCN</a> &amp; <a href="https://rexx.epbcn.com/josep-maria-blasco/">Josep Maria Blasco</a>.
             This site is powered by <a href="https://sourceforge.net/projects/oorexx/">ooRexx</a> and
             <a href="https://rexx.epbcn.com/software/rexxhttp/">RexxHttp</a>.
          </small>
        </div>
      </div>
::END

--------------------------------------------------------------------------------
-- Exceptions (files that should not be processed)                            --
--------------------------------------------------------------------------------

::Routine md2html.Exception Public

  Return .Exception[Arg(1)]