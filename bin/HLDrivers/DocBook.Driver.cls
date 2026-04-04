/******************************************************************************/
/*                                                                            */
/* DocBook.Driver.cls - DocBook highlighter driver                            */
/* ===============================================                            */
/*                                                                            */
/* Emits XML elements with rexx_STYLE_* names for use in DocBook             */
/* programlisting blocks. The style name is always included in the element   */
/* name for symmetry:                                                        */
/*                                                                            */
/*   "rx-kw" (style "print")        -> <rexx_print_kw>                       */
/*   "rx-op rx-add" (style "dark")  -> <rexx_dark_op_add>                    */
/*   "rx-const rx-method rx-oquo" (style "print")                            */
/*                                  -> <rexx_print_const_method_oquo>        */
/*                                                                            */
/* The content is XML-escaped. No prolog or epilog is emitted.                */
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
  Expose Options.
  Use Strict Arg category, subCategory, variant, tags, string

  -- Whitespace: emit as-is (XML-escaped, no element wrapper)
  If tags == "rx-ws" Then Do
    self~emit( XMLEscape(string) )
    Return
  End

  -- Derive the element name from CSS classes, including the style
  elementName = Tags2Element(tags, Options.style)

  -- Emit <rexx_XX>escaped content</rexx_XX>
  self~emit( "<"elementName">"XMLEscape(string)"</"elementName">" )

::Method Epilog
  Nop

/******************************************************************************/
/* TAGS2ELEMENT: Convert CSS class string to DocBook element name             */
/******************************************************************************/
/*                                                                            */
/* Converts a CSS class string to a DocBook element name by stripping the     */
/* "rx-" prefix from each class, replacing "-" with "_", and joining them     */
/* with "_" under the "rexx_STYLE" prefix.                                    */
/*                                                                            */
/* The style name is always included in the element name for symmetry:        */
/*   Tags2Element("rx-kw", "print")  -> "rexx_print_kw"                      */
/*   Tags2Element("rx-op rx-add", "dark") -> "rexx_dark_op_add"              */
/*   Tags2Element("rx-const rx-method rx-oquo", "print")                     */
/*                                       -> "rexx_print_const_method_oquo"   */
/*                                                                            */
/******************************************************************************/

::Routine Tags2Element Public
  Use Strict Arg cssTags, style

  words = cssTags~makeArray(" ")
  name  = "rexx_" || style~changeStr("-", "_")
  Do w Over words
    name ||= "_" || StripPrefix(w)~changeStr("-", "_")
  End
  Return name

/******************************************************************************/
/* STRIPPREFIX: Remove the "rx-" prefix from a CSS class name                 */
/******************************************************************************/

::Routine StripPrefix
  Use Strict Arg className
  If className~caselessStartsWith("rx-") Then
    Return className~substr(4)
  Return className

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
