/******************************************************************************/
/*                                                                            */
/* HTTP.Request.cls -- Class to encapsulate CGI HTTP requests                 */
/* ==========================================================                 */
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
-- This class is used to encapsulate a CGI HTTP request.                     --
--                                                                           --
-- Recommended use:                                                          --
--   .environment~request = .HTTP.Request~new                                --
--                                                                           --
-------------------------------------------------------------------------------

::Class HTTP.Request Public

::Method init
  Expose error method query args

  error = ""

  -- Get the request method and store it

  method = self~REQUEST_METHOD
  args   = .Stem~new

  -- Methods: we only support GET and POST.
  --
  -- Parameters: at the moment, we only support GET query strings,
  -- and POST content types of application/x-www-form-urlencoded.
  -- GET parameters are not supported when the request method is POST.
  --
  -- Duplicate parameters are not supported
  --

  Select Case method
    When "GET"  Then query = self~QUERY_STRING
    When "POST" Then Do
      expected = "application/x-www-form-urlencoded"
      type = self~CONTENT_TYPE
      If type \== expected Then Signal BadContentType
      If self~QUERY_STRING \== "" Then Signal NoGetAndPost
      query = CharIn(,,self~CONTENT_LENGTH)
    End
    Otherwise Signal BadMethod
  End

  If query == ""               Then args[0] = 0
  Else If \query~contains("=") Then Signal NoEqSign
  Else Do
    params = query
    names = .Set~new
    Do i = 1 By 1 Until params == ""
      Parse Var params param"&"params
      If \param~contains("=")  Then Signal NoEqSign
      Parse Var param name"="value
      name = Lower(name)
      If names~hasIndex(name)  Then Signal Duplicate
      names[] = name
      args[i,"NAME"]  = Lower(name)
      args[i,"VALUE"] = Decode(value)
      args[name]      = i
      args["0"]       = i
    End
  End

  Return

Duplicate:
  error = "DupParam"
  Return

NoEqSign:
  error = "NoEqSign"
  Return

BadContentType:
  error = "BadContentType"
  Return

BadMethod:
  error = "BadMethod"
  Return

NoGetAndPost:
  error = "GetAndPostParams"
  Return

--------------------------------------------------------------------------------
-- ERROR                                                                      --
--------------------------------------------------------------------------------

::Attribute Error Get

--------------------------------------------------------------------------------
-- ARG                                                                        --
--                                                                            --
--   Syntax:    (n is an integer, s a string)                                 --
--     arg()                  --> Number of arguments                         --
--     arg(n[,Value])         --> value for nth argument                      --
--     arg(s[,Value])         --> value for argname=s, or ""                  --
--     arg(s,Exists)          --> If there is an arg named s then 1 else 0    --
--                            Similarly with Omitted                          --
--     arg(n,Name)            --> name of nth arg                             --
--     arg(n,Value)           --> value of nth arg                            --
--                                                                            --
--   You cannot search by name if the name is a number                        --
--                                                                            --
--------------------------------------------------------------------------------

::Method arg
  Expose args

  If Arg() = 0  Then Return args["0"]

  If Arg(1,'o') Then
    -- Missing argument in method; argument 1 is required
    Raise syntax 93.903 array ( 1 )

  If Arg() > 2  Then
    -- Too many arguments in invocation of method; 2 expected.
    Raise syntax 93.902 array ( 2 )

  n = Arg(1)~request("STRING")
  If n == .nil  Then
    -- Method argument 1 must have a string value.
    Raise syntax 93.938 array ( 1 )

  If Arg(2,'o') Then option = "V"
  Else Do
    option = Arg(2)~request("STRING")
    If option == .nil Then Raise syntax 93.938 array ( 2 )
    option = option~translate~strip~left(1)
    If option = "" Then option = "V"
    If "NVEO"~pos(option) == 0 Then
      -- Method argument 2 must be one of "Name Value Exists Omitted";
      -- found "option"
      Raise syntax 93.914 array ( 2, "Name Value Exists Omitted", option )
  End

  If n~datatype("w") & n > 0 Then Do
    If n > args["0"] Then Do
      If      option == "E" Then Return .false
      Else If option == "O" Then Return .true
      Else                       Return ""
    End
    If option == "E" Then Return .true
    If option == "O" Then Return .false
    If option == "V" Then Return args[n,"VALUE"]
    If option == "N" Then Return args[n,"NAME"]
  End

  If option == "E" Then Return args[n] \== ""
  If option == "O" Then Return args[n]  == ""
  If option == "V" Then
    If args[n] = "" Then Return ""
    Else Return args[args[n],"VALUE"]
  If option == "N" Then
    If args[n] = "" Then Return ""
    Else Return args[args[n],"NAME"]

--------------------------------------------------------------------------------
-- QUERY -- The query string, or the query post data                          --
--------------------------------------------------------------------------------

::Attribute Query Get

--------------------------------------------------------------------------------
-- "[]"                                                                       --
--------------------------------------------------------------------------------
--
-- Allows using ".request[header]" instead of ".request~header"
--

::Method "[]"
  Use Strict Arg message
  Forward Message (UNKNOWN) Array (message, .Array~of() )

--------------------------------------------------------------------------------
-- UNKNOWN                                                                    --
--------------------------------------------------------------------------------
--
-- - The message name is normalized (see the code below)
-- - Headers that begin with "REQUEST_" can omit "REQUEST_", i.e.,
--   .request~uri == .request~URI == .request~REQUEST_URI
--

::Method UNKNOWN
  Use Strict Arg message, args = .Nil

  -- No header setters are allowed
  If message~endsWith("=") Then Raise Syntax 97.001 Additional( self, message )

  -- No additional arguments allowed
  If args~items > 0        Then Raise Syntax 93.902 Additional( 0 )

  -- That's a header getter. Normalize it
  message = message~      -
    translate("  ","-_")~ - -- (1) dashes and underscored -> blanks
    space~                - -- (2) delete leading and trailing, normalize rest
    upper~                - -- (3) uppercase everything
    translate("_"," ")      -- (4) separator is "_"

  -- Prepend "REQUEST_" to some few headers
  Select Case message
    When "METHOD", "URI", "SCHEME" Then message = "REQUEST_"message
    Otherwise Nop
  End

  Return Value(message,,"ENVIRONMENT")

/******************************************************************************/
/* URL-DECODE                                                                 */
/******************************************************************************/

::Routine Decode Private

  Use Arg from

  lFrom = from~length

  to    = .MutableBuffer~new(,lFrom)

  Do i = 1 To lFrom
    c = from~substr(i,1)
    If c == "+" Then c = " "
    If c == "%" & i+2 <= lfrom Then Do
      hex = from~substr(i+1,2)
      If hex~datatype("X") Then Do
        i = i + 2
        c = hex~x2c
      End
    End
    to~append(c)
  End

  Return to~string
