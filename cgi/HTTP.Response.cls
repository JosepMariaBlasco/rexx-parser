/******************************************************************************/
/*                                                                            */
/* HTTP.Response.cls -- Class to encapsulate CGI HTTP responses               */
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
/* 20250523    0.2b First separate implementation.                            */
/*                                                                            */
/******************************************************************************/

-------------------------------------------------------------------------------
--                                                                           --
-- This class is used to encapsulate a CGI HTTP response.                    --
--                                                                           --
-- Recommended use:                                                          --
--   .environment~response = .HTTP.Response~new                              --
--                                                                           --
-------------------------------------------------------------------------------

::Class HTTP.Response Public

--------------------------------------------------------------------------------
-- INIT                                                                       --
--------------------------------------------------------------------------------
--
-- The class defines a series of headers, which will be emitted
-- in a certain order.
--

::Method init
  Expose headers order
  order   = .Array~new
  headers = .Directory~new

--------------------------------------------------------------------------------
-- PRINTHEADERS                                                               --
--------------------------------------------------------------------------------

--
-- This prints the headers in their corresponding order
--

::Method printHeaders
  Expose headers order
  Do header Over order
    Say header":" headers[header]
  End

--------------------------------------------------------------------------------
-- UNKNOWN                                                                    --
--------------------------------------------------------------------------------
--
-- The UNKNOWN method implements the following idioms:
--
--   Setters:
--     .request~header    = expr
--
--   Getters:
--     .request~header
--
--   Words in multi-word headers can be separated by whitespace,
--   dashes ("-") or underscores ("_"). Case is irrelevant.
--   The name is normalized: "-" separators, no leading or trailing.
--   Words are lowercased, and the first letter is uppercased.
--
--   The following are equivalent:
--
--     .response~content_type
--     .response["Content-Type"]
--     .response[Content Type]   -- If "content" and "type" do not have a value
--
--------------------------------------------------------------------------------

::Method Unknown
  Expose headers order
  messageName = Arg(1)
  If messageName~endsWith("=") Then Do
    messageName = messageName[1, Length(messageName) - 1]
    messageName = Process(messageName)
    If \ headers~hasIndex( messageName ) Then
      order~append( messageName )
    headers[ messageName ] = Arg(2)
    Return
  End
  messageName = Process(messageName)
  If \headers~hasIndex(messageName) Then Return ""
  Return headers[messageName]

Process:
  array = messageName~translate("  ","-_")~space~makeArray(" ")
  Do i = 1 To array~items
    array[i] = Upper( array[i][1] )Lower( SubStr(array[i],2) )
  End
  Return array~makeString("Line","-")

--------------------------------------------------------------------------------
-- 404 -- Utility method to generate a software 404 NOT FOUND error           --
--------------------------------------------------------------------------------

::Method 404

  Use Arg code = ""

  -- Restore the output destination to .SdtOut
 .output~destination( .stdout )

  -- Emit an Apache-like soft 404 error
  Say 'Content-Type: text/html; charset=iso-8859-1'
  Say 'Status: 404 Not Found'
  Say ""
  Say '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">'
  Say '<html><head>'
  Say '<title>404 Not Found</title>'
  Say '</head><body>'
  Say '<h1>Not Found</h1>'
  If code == "" Then
    Say '<p>The requested URL was not found on this server.</p>'
  Else
    Say '<p>The requested URL was not found on this server [code:' code'].</p>'
  Say '<hr>'
  Say Value('SERVER_SIGNATURE',,"ENVIRONMENT")'</body></html>'

  -- Return a value so that one can use the "Exit .response~404" idiom
  Return 0

