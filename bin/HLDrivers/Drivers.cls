/******************************************************************************/
/*                                                                            */
/* Highlighter.Drivers.cls - Rexx highlighter driver system                   */
/* ========================================================                   */
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
/* 20241231    0.1e First version                                             */
/* 20250222    0.2  Add drive to path for requires                            */
/* 20250328         Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/*                                                                            */
/******************************************************************************/

-- We call all the drivers (the .cls files) in our own directory,
-- except ourselves.

If .environment~Highlighter.Driver == .Nil Then Do
   .environment~Highlighter.Driver =  .Highlighter.Driver
  package    = .context~package
  local      =  package~local
  mypath     =  FileSpec( "Location", package~name )
  myName     =  FileSpec( "Name", package~name )
  drivers    = .File~new(mypath)~list
  Do driver Over drivers
    If driver == myName Then Iterate    -- Don't call ourselves
    If driver~endsWith(".cls") Then     -- Call every driver in turn
      Call (mypath||driver)
  End

  stem. = ""
 .environment~CSS.Cache = stem.

End

::Requires "StyleSheet.cls"

/******************************************************************************/
/* Base class, should be subclassed by actual drivers                         */
/******************************************************************************/

::Class Highlighter.Driver Public Abstract

-- These two methods are driver-specific, and should be implemented
-- by all subclasses.

::Method Prolog    Abstract
::Method Epilog    Abstract

-- Emit a simple newline by default

::Method startLine
  Use Strict Arg lineNo
  self~say("")

-- Store options. and output

::Method Init
  Expose Options. output

  Use Strict Arg Options., output

  source = Options.!Source

  -- If we are going to print line numbers, we need to compute
  -- the width of the line number area. We use a minimum of
  -- two columns, even in the case that a single digit is enough.
  -- If the user has specified the "numberWidth" option, we use that
  -- value, unless it's incapable to accomodate our numbers.
  -- Otherwise, we use the width of the maximum line number, plus one.

  If options.numberLines Then Do
    nWidth = Max( Length(options.startFrom + source~items - 1), 2) + 1
    If options.numberWidth > nWidth Then nWidth = options.numberWidth
    Options.!numberWidth = nWidth       -- Store in options.
  End

--------------------------------------------------------------------------
-- CachedCSS                                                            --
--------------------------------------------------------------------------

---
--- Return a version of the CSS associated with some tags.
---
--- @param style A style, like "dark" or "light".
--- @parem tags  A list of CSS classes.
---
--- @return A string, "b i u fg':'bg".
---

::Method CachedCSS Public

  Use Strict Arg style, tags

  -- Was "tags" already normalized?
  newTags = .CSS.Cache[style,tags]

  -- It was: return it
  If newTags \== "" Then Return newTags

  -- It was not: normalize it, cache and return the results

  newTags = GetHighlight(style, tags )

 .CSS.Cache[style,tags] = newTags

  Return newTags

--------------------------------------------------------------------------
-- Conceptually, EMIT Arg(1) is CHAROUT , Arg(1)                        --
--------------------------------------------------------------------------

::Method Emit
  Expose output
  output[ output~last ] ||= Arg(1)      -- Append to the current line

--------------------------------------------------------------------------
-- Conceptually, this is SAY Arg(1)                                     --
--------------------------------------------------------------------------

::Method Say
  Expose output
  self~emit( Arg(1) )
  output~append("")                     -- Start a new, empty line

-- Used by the ANSI and LaTeX highlighter.
-- The HTML Highlighter uses inline <style>s.

::Method tags2highlight
  Expose Options.

  Use Strict Arg tags, extra

  style      = Options.Style

  Parse Value self~CachedCSS(style, tags) With x y z fg":"bg
  attrs = x y z
  color      = ""
  background = ""
  If fg \== "" Then color      = fg
  If bg \== "" Then background = bg

  If extra \== "" Then Do
    Parse Value extra With x y z fg":"bg
    attrs ||= x y z
    If fg \== "" Then color      = fg
    If bg \== "" Then background = bg
  End

  If background = "" Then
    Parse Value self~CachedCSS(style, "rexx") With ":"background

  bold      = .False
  italic    = .False
  underline = .False

  Do attr Over attrs~makeArray("")
    Select Case attr
      When "B" Then bold      = .True
      When "b" Then bold      = .False
      When "I" Then italic    = .True
      When "i" Then italic    = .False
      When "U" Then underline = .True
      When "u" Then underline = .False
      Otherwise Nop
    End
  End

  Return bold italic underline color":"background