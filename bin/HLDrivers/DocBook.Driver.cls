/******************************************************************************/
/*                                                                            */
/* DocBook.Driver.cls - DocBook highlighter driver                            */
/* ===============================================                            */
/*                                                                            */
/* Emits a DocBook <phrase role="..."> element around every highlighted       */
/* token.  The role attribute carries the highlighter's CSS class string      */
/* verbatim -- exactly what the HTML driver puts in class=:                   */
/*                                                                            */
/*   "rx-kw"                       -> <phrase role="rx-kw">                   */
/*   "rx-op rx-add"                -> <phrase role="rx-op rx-add">            */
/*   "rx-const rx-method rx-oquo"  -> <phrase role="rx-const rx-method        */
/*                                       rx-oquo">                            */
/*                                                                            */
/* Two properties of this markup matter, and both are deliberate:             */
/*                                                                            */
/*   1. It is valid DocBook.  <phrase role="..."> is the standard idiom for   */
/*      a semantically tagged inline, so the emitted XML validates against    */
/*      the DocBook 4.5 DTD and survives any validating step of the build.    */
/*      It also means the stock DocBook XSL already knows what to do with     */
/*      it: the XHTML stylesheets turn <phrase role="X"> into <span           */
/*      class="X"> unaided, so the HTML branch needs no per-token templates   */
/*      at all.                                                               */
/*                                                                            */
/*   2. It is style-independent.  The markup emitted for a given token is     */
/*      identical whatever style is in effect; the style is carried by the    */
/*      container element, not by the tokens.  This is the same invariant     */
/*      the HTML driver relies on, and it is what allows one highlighted      */
/*      document to be restyled -- by CSS in HTML, by the generated           */
/*      templates in FO -- without parsing the source again.                  */
/*                                                                            */
/* Whitespace is emitted as bare escaped text, with no wrapping element.      */
/* The content is XML-escaped.  No prolog or epilog is emitted; the           */
/* container is supplied by Parser.DocBook.cls, which owns the enclosing      */
/* <programlisting>.                                                          */
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
/* 20260403    0.5  First version                                             */
/* 20260729    0.6  Emit <phrase role="..."> instead of <rexx_STYLE_*>        */
/*                  elements.  The style no longer appears in the token       */
/*                  markup; Tags2Element and StripPrefix are gone.            */
/*                                                                            */
/******************************************************************************/


If \.environment~hasIndex( DocBook.Highlighter ) Then Do
  .environment~DocBook.Highlighter = .DocBook.Highlighter
End

::Class DocBook.Highlighter SubClass Highlighter.Driver Public

::Method Init
  Expose Options. output
  Use Strict Arg Options., output
  self~init:super(Options., output)

::Method Prolog
  Nop

::Method startLine
  Use Strict Arg lineNo
  self~say("")

::Method Highlight
  Use Strict Arg category, subCategory, variant, tags, string

  -- Whitespace: emit as-is (XML-escaped, no element wrapper).  A
  -- <phrase> around a run of spaces would carry no information and
  -- would bloat the document for no gain.
  If tags == "rx-ws" Then Do
    self~emit( XMLEscape(string) )
    Return
  End

  -- An untagged token is emitted bare as well: an empty role would be
  -- meaningless in DocBook and would produce <span class=""> in HTML.
  If tags == "" Then Do
    self~emit( XMLEscape(string) )
    Return
  End

  self~emit( '<phrase role="'tags'">'XMLEscape(string)'</phrase>' )

::Method Epilog
  Nop

/******************************************************************************/
/* XMLESCAPE: Escape XML special characters in content                        */
/******************************************************************************/

::Routine XMLEscape

  Use Strict Arg text

  text = text~changeStr("&",  "&amp;")
  text = text~changeStr("<",  "&lt;")
  text = text~changeStr(">",  "&gt;")
  text = text~changeStr('"',  "&quot;")
  text = text~changeStr("'",  "&apos;")

  Return text
