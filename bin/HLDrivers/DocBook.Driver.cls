/******************************************************************************/
/*                                                                            */
/* DocBook.Driver.cls - DocBook highlighter driver                            */
/* ===============================================                            */
/*                                                                            */
/* Emits XML elements with rexx_* names for use in DocBook programlisting     */
/* blocks. The element names are derived from CSS class strings using the     */
/* same convention as css2xsl.rex (Tags2Element):                             */
/*                                                                            */
/*   "rx-kw"                      -> <rexx_kw>...</rexx_kw>                   */
/*   "rx-op rx-add"               -> <rexx_op_add>...</rexx_op_add>           */
/*   "rx-const rx-method rx-oquo" -> <rexx_const_method_oquo>                 */
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
  Use Strict Arg category, subCategory, variant, tags, string

  -- Whitespace: emit as-is (XML-escaped, no element wrapper)
  If tags == "rx-ws" Then Do
    self~emit( XMLEscape(string) )
    Return
  End

  -- Derive the element name from CSS classes
  elementName = Tags2Element(tags)

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
/* with "_" under the "rexx_" prefix.                                         */
/*                                                                            */
/* Examples:                                                                  */
/*   "rx-kw"                          -> "rexx_kw"                            */
/*   "rx-op rx-add"                   -> "rexx_op_add"                        */
/*   "rx-const rx-method rx-oquo"     -> "rexx_const_method_oquo"             */
/*                                                                            */
/******************************************************************************/

::Routine Tags2Element
  Use Strict Arg cssTags

  words = cssTags~makeArray(" ")
  name  = "rexx"
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
