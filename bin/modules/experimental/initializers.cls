/******************************************************************************/
/*                                                                            */
/* Initializers.cls -- Table initializers inspired by NetRexx and Lua         */
/* ==================================================================         */
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
/* 20251116    0.3a First version                                             */
/*                                                                            */
/******************************************************************************/

  Override = .True
  Call "modules/Load.Parser.Module.rex" ,Override

::Requires "modules/identity/compile.cls"

::Method "Initializer::Compile"
  Use Strict Arg element, stream, context

  fields = self~fields
  end    = self~end

  If fields~isEmpty Then Do
    stream~charOut("Rexx:Table~new()/* ")
    Loop While element \== end
      element = Clone( element, stream, context )
    End
    stream~charOut(" */")
    Return element
  End

  stream~charOut("Rexx:Table~of(/* ")
  -- "["
  element = Clone( element, stream, context )
  stream~charOut(" */")

  n = 0

  nFields = fields~items
  Loop Counter c field Over fields
    If field == .Nil Then n += 1
    Else Do
      lhs   = field[1]
      field = field[2]
      start = field~begin

      If lhs == .Nil Then Do
        n += 1
        stream~charOut("("n", ")
      End
      Else Do
        stream~charOut("(")
        element = Clone( element, stream, context ) -- FIXME
        stream~charOut(", ")
      End

      Loop While element \== start
        element = Clone( element, stream, context )
      End

      element = field~compile( element, stream, context )
      stream~charOut(")")
    End

    If c < nFields Then Do
      -- Look for the next comma
      Loop While element \< .EL.COMMA
        element = Clone( element, stream, context )
      End
      -- Comment it out if it is a double comma:
      -- ooRexx mapCollections don't accept holes.
      If field == .Nil Then stream~charOut("/*")
      element = Clone( element, stream, context )
      If field == .Nil Then stream~charOut("*/")
    End

  End

  Loop While element \< .EL.RIGHT_BRACKET
    element = Clone( element, stream, context )
  End

  stream~charOut("/* ")
  -- "]"
  element = Clone( element, stream, context )
  stream~charOut(" */)")

  Return element
