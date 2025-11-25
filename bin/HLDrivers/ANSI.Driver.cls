/******************************************************************************/
/*                                                                            */
/* ANSI.Highlighter.Driver.cls - LaTeX highlighter driver                     */
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
/* 20250105    0.1f Support style patches                                     */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/*                                                                            */
/******************************************************************************/


If \.environment~hasIndex( ANSI.Highlighter ) Then Do
  .environment~ANSI.Highlighter = .ANSI.Highlighter
End

::Class ANSI.Highlighter SubClass Highlighter.Driver Public

::Method Init
  Expose Options. output
  Use Strict Arg Options., output
  self~init:super(Options., output)

::Method Prolog
  Expose Options. linenoHL linebarHL
  self~emit( "1B"x"[0m" )

  If Options.numberLines Then Do
    linenoHL  = self~hl2SGR("rx-lineno")
    linebarHL = self~hl2SGR("rx-linebar")
    lineno    = Right(options.startFrom, Options.!numberWidth)
    self~emit( ANSI(linenoHL,  lineno) )
    self~emit( ANSI(linebarHL, " | " ) )
  End

::Method startLine
  Expose Options. linenoHL linebarHL
  Use Strict Arg lineNo

  self~EnsureWidth

  self~say( "" )

  If Options.numberLines Then Do
    lineno = Right(lineNo, options.!numberWidth)
    self~emit( ANSI(linenoHL,  lineno) )
    self~emit( ANSI(linebarHL, " | " ) )
  End

::Method Highlight
  Expose Options.

  Use Strict Arg category, subCategory, variant, tags, string

  patch = Options.!Patch
  If patch == .Nil Then extra = ""
  Else Do
    patch. = patch~getPatch
    Tag2Attr. = patch.!Tag2Attr
    Select
      When variant     \== "" Then extra = Tag2Attr.category.subCategory.variant
      When subCategory \== "" Then extra = Tag2Attr.category.subCategory
      Otherwise                    extra = Tag2Attr.category
    End
  End

  self~emit( ANSI(self~hl2SGR(tags,extra), string) )

::Method hl2SGR
  Use Strict Arg tags, extra = ""

  Parse Value self~tags2highlight(tags, extra) -
    With bold italic underline color":"background

  command = ""
  If bold              Then command ||= "1;"
  If italic            Then command ||= "3;"
  If underline         Then command ||= "4;"
  If color      \== "" Then command ||= "38;2;"color2SGR(color)
  If background \== "" Then command ||= "48;2;"color2SGR(background)

  Return command

::Method Epilog
  self~EnsureWidth

::Method EnsureWidth
  Expose Options. output
  style = Options.style
  Parse Value self~CachedCSS(style, "rexx") With ":"background
  If background = "" Then Return
  background = color2SGR(background)
  len = Columns( output[ output~last ] ) - options.!numberWidth - 1
  If len >= Options.width Then Return
  self~emit( ANSI( "48;2;"background, Copies(" ",Options.width-len)) )
Return

Columns: Procedure
  Use Strict Arg string
  len = 0
  esc = "1B"x
  Do While string~contains(esc)
    Parse Var string before(esc)"m"string
    len += Length(before)
  End
  Return len+Length(string)

----------

::Routine color2SGR -- hhhhhh --> r;g;b;
  Parse Arg aa +2 bb +2 cc +2
  Return aa~x2d";"bb~x2d";"cc~x2d";"

----------

::Routine ANSI
  ESC = "1B"x

  Parse Arg SGR, string
  If SGR~endsWith(";") Then SGR = Left(SGR,Length(SGR)-1)

  Return ESC"["SGR"m"Arg(2)ESC"[0m"
