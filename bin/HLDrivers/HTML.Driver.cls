/******************************************************************************/
/*                                                                            */
/* HTML.Highlighter.Driver.cls - LaTeX highlighter driver                     */
/* ======================================================                     */
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
/* 20250101    0.1e First version                                             */
/* 20250120    0.1f Add size option                                           */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/*                                                                            */
/******************************************************************************/

If \.environment~hasIndex( HTML.Highlighter ) Then
 .environment~HTML.Highlighter = .HTML.Highlighter

::Class HTML.Highlighter SubClass Highlighter.Driver Public

-- We store Options. and source too

::Method Init
  Expose Options. output
  Use Strict Arg Options., output
  self~init:super(Options., output)

-- What to print at the beginning

::Method Prolog
  Expose Options.

  patch     = Options.!Patch
  HTMLClass = Options.!HTMLClass
  style     = Options.style

  -- No patch? A simple div will do.
  If patch == .Nil Then Do
    self~Say( '<div class="highlight-rexx-'style'">' )
  End
  Else If patch~getpatch[!Tag2Attr]~isEmpty Then Do
    self~Say( '<div class="highlight-rexx-'style'">' )
  End
  -- We have a patch. We will emit an inline style, indexed to our
  -- unique ID. This does not validate, but it works with all major
  -- browsers. A validating alternative would be to generate
  -- inline styles for all the affected spans.
  Else Do

    id = Options.!UniqueID
    self~Say( '<div id="rx'id'" class="highlight-rexx-'style'">' )
    patch.    = patch~getpatch
    Tag2Attr. = patch.!Tag2Attr
    constant  = .EL.TAKEN_CONSTANT

    self~say( "<style>" )
    Do tail Over Tag2Attr.~allIndexes
      Select Case tail~length
        When 3 Then classes = HTMLClass[ constant, tail[3] ]
        When 5 Then classes = HTMLClass[ constant, tail[3], tail[5] ]
        Otherwise   classes = HTMLClass[ tail ]
      End
      lastClass = Word( classes, Words( classes ) )
      Parse Value Tag2Attr.tail With b i u  color":"background
      style = ""
      Do c Over (b i u)~makeArray(" ")
        Select Case c
          When "b" Then style ||= "font-weight:normal; "
          When "B" Then style ||= "font-weight:bold; "
          When "i" Then style ||= "font-style:normal; "
          When "I" Then style ||= "font-style:italic; "
          When "u" Then style ||= "text-decoration:none; "
          When "U" Then style ||= "text-decoration:underline; "
          Otherwise Nop
        End
      End
      If color      \== "" Then style ||= "color:#"color"; "
      If background \== "" Then style ||= "background-color:#"background"; "

      self~say( "#rx"id "."lastClass "{"style"}" )

    End
    self~say( "</style>" )
  End

  options.!inc = 1

  If options.size == 0 Then size = ""
  Else size = ' style="font-size:'options.size'"'
  If Options.numberLines Then Do
    self~emit( '<pre'size' class="number-lines w'Options.!numberWidth'">' )
  End
  Else
    self~emit( '<pre'size'>' )

  self~emit( '<code lineNo="'Options.startFrom'">' )

-- At the beginning of every line of code...

::Method startLine
  Use Strict Arg lineNo

  self~say(  '</code>' )
  self~emit( '<code lineno="'lineNo'">' )

-- Print a highlighted element value

::Method Highlight
  Use Strict Arg category, subCategory, variant, tags, string
  self~emit( '<span class="'tags'">'Escape(string)'</span>' )
  Exit

Escape:
  Return Arg(1)~changeStr( "&", "&amp;" ) -
               ~changeStr( ">", "&gt;"  ) -
               ~changeStr( "<", "&lt;"  )

-- What to print at the end

::Method Epilog
  self~Say( "" )               -- End last line
  self~Say( "</code></pre>" )  -- Close <code> and <pre>
  self~Say( "</div>" )         -- Close <div>