/******************************************************************************/
/*                                                                            */
/* Test.Parser.cls                                                            */
/* ===============                                                            */
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
/* 20251226    0.4a Send error messages to .error, not .output                */
/*                                                                            */
/******************************************************************************/

  If .environment~Parser.Test.SimpleErrors == .Nil Then
     .environment~Parser.Test.SimpleErrors = 0
  If .environment~Parser.Test.Fast.OK      == .Nil Then
     .environment~Parser.Test.Fast.OK      = 0

  myDir =  FileSpec("Location",.context~name)
  sep   = .File~separator
  rexxMsg = myDir".."sep"bin"sep"resources"sep"rexxmsg.xml"
  file = Stream(rexxMsg,"c","Query exists")
  If file == "" Then Do
   .Error~Say( "Internal error: file '"rexxMsg"' does not exist." )
    Raise Halt
  End

  messages = CharIn(rexxmsg, 1, Chars(rexxmsg))
  Call Stream rexxMsg,"c","Close"

  messages = messages~changeStr("0d"x," ")~changeStr("0a"x," ")~space~makeArray("<Message>")

 .environment~errorMessages = .Array~new(1,1)
  nMessages = 0

  Do i = 2 To messages~items
    Parse Value messages[i] With "<Code>"major"</Code>" "<Subcodes>"subCodes"</Subcodes>"
  If major > 99 Then Leave
    subMessages = subCodes~makeArray("<SubMessage>")
    Do j = 2 To subMessages~items
      Parse Value subMessages[j] With "<Subcode>"minor"</Subcode>" "<Text>"text"</Text>"
      text = text~changeStr("<q>",'"')~changeStr("</q>",'"')~changeStr("<sq/>","'") -
        ~changeStr("<dq/>",'"')~changeStr("&gt;",'>')~changeStr("&lt;",'<')         -
        ~changeStr("&apos;","'")
      If Pos("&",text) > 0 Then Do
       .Error~Say( "Unexpected '&' in message text" major"."minor":" )
       .Error~Say( text )
        Exit 1
      End
      Do While Pos("<Sub ",Text) >  0
        Parse var text before"<Sub" 'position="'position'"' "/>"after
        If \DataType(position, "W") Then Do
         .Error~Say( "Position in text of" major"."minor "is not an integer." )
          Exit 1
        End
        text = before"&"position||after
      End
     .errorMessages[major,minor] = text
      -- Say major"."minor": "text
      nMessages += 1
    End
  End

  -- Say nMessages "messages fetched."

----------------------------------------------------------------------------
-- .ERRORTEXT                                                             --
----------------------------------------------------------------------------

::Routine .ErrorText Public
  Parse Arg major"."minor
  message = .errorMessages[major, minor]
  pos = 1
  n = 0
  Loop
    pos = Pos("&", message, pos)
  If pos == 0 Then Leave
    n += 1
    message = Left(message, pos - 1)Arg(2)[n]SubStr(message,pos+2)
  End
  Return message

----------------------------------------------------------------------------
-- Test.Error                                                             --
--   Checks that a certain program, consisting of a single line, produces --
--   a certain error, and that the error produced by the ooRexx           --
--   interpreter and the Parser is the same.                              --
--                                                                        --
--   This is a quick check. The interpreter test is done using INTERPRET, --
--   which means that a number of features cannot be tested using this    --
--   test (for example, INTERPRET does not allow directives, etc.).       --
--                                                                        --
--   Parameters:                                                          --
--     code: a Rexx code, in the format major.minor. Both numbers may     --
--        have extra zeros to the left, for example for prettyprinting    --
--        reasons; these are removed before execution.                    --
--     string: a single line of Rexx code.                                --
----------------------------------------------------------------------------

::Routine Test.Error Public

  .environment~Parser.Test.SimpleErrors += 1

  -- In some cases, we will need an existing file
  myself = .context~package~name

  Use Strict Arg code, string

  Parse Var code major"."minor
  major = major + 0
  minor = minor + 0

  -- Step 1: Check the ooRexx interpreter

  Signal On Syntax Name PackageCreationTrapped

  package = .Package~new("Compiled", string) -- Should trap

 .Error~Say(                                                             -
    "A SYNTAX error" code "was expected when interpreting"               -
    "the following code line, but the ooRexx interpreter produced none:" -
  )
 .Error~Say( "     1 *-* "string )

  caller = .context~stackFrames[2]

 .Error~Say( "This test originated from" caller~name "at line" caller~line":" )
 .Error~Say( caller~traceLine )

  Raise Halt

PackageCreationTrapped:
  -- The interpreted raised an error. Keep the error parameters, to compare
  -- them with the ones produced by the Parser.
  co                    = Condition("O")
  interpreterCode       = co~code
  interpreterErrorText  = co~errorText
  interpreterMessage    = co~message
  interpreterAdditional = co~additional

  -- Now call the Parser

  Options = .Array~of( -
    (earlyCheck, (BIFs, SIGNAL, GUARD, LEAVE, ITERATE) ) -
  )

  Signal On Syntax Name ParserSyntax

  package = .Rexx.Parser~new("",string,options)~package

 .Error~Say(                                                     -
   "A SYNTAX error" code "was expected when parsing"             -
   "the following code line, but the Rexx Parser produced none:" -
  )
 .Error~Say( "     1 *-* "string )

  caller = .context~stackFrames[2]

 .Error~Say( "This test originated from" caller~name "at line" caller~line":" )
 .Error~Say( caller~traceLine )

  Raise Halt

ParserSyntax:
  co = Condition("O")

  If co~code \== 98.900 Then Do
   .Error~Say( "Error" co~code "in" co~program", line" co~position":" )
    Raise Propagate
  End

  theCode = co~additional~lastitem~code
  If theCode \== major"."minor Then Do
    Call Failed 2, "Expected " major"."minor "SYNTAX error but got" theCode "from the Rexx parser instead."
  End

  parserCode       = co~additional~lastitem~code
  parserAdditional = co~additional~lastItem~additional

  If interpreterCode \== parserCode Then
    Call Failed 3, "ooRexx produced a" interpreterCode "error, but the Parser produced" parserCode"."
  If parserAdditional~items \== interpreterAdditional~items Then
    Call DumpAdditional "Additional arrays have different sizes."
  message = .ErrorText(major"."minor, parserAdditional)
  If message \== interpreterMessage Then
    Call Failed 3, ("ooRexx additional message for" interpreterCode "was",-
      "   "interpreterMessage, "but Parser produced", "   "message-
    )

  Return 1

DumpAdditional:
 .Error~Say( Arg(1) )
  Do i = 1 To Max(parserAdditional~items, interpreterAdditional~items)
   .Error~Say( "Parser[     "i"] = '"parserAdditional[i]"'" )
   .Error~Say( "Interpreter["i"] = '"interpreterAdditional[i]"'" )
   .Error~Say
  End
  Call Failed 4, "Additional arrays differ."

Failed:
 .Error~Say( Arg(2)              )
 .Error~Say( "     1 *-* "string )

  caller = .context~stackFrames[Arg(1)]

/*
 .Error~Say(                                                        -
   "This test originated from" caller~name "at line" caller~line":" -
  )
 .Error~Say( caller~traceLine )
*/

  Raise Halt

----------------------------------------------------------------------------
-- Test.OK                                                                --
--   Checks that a certain program, supplied as an array, can be run      --
--   by ooRexx without errors, and that the Rexx Parser parser it         --
--   correctly. If not, an error message is printed, and  the HALT        --
--   condition is raised. Otherwise, the routine returns .True.           --
----------------------------------------------------------------------------

::Routine Test.OK Public

 .environment~Parser.Test.OK += 1

  Use Strict Arg source

  Signal On Syntax Name PackageCreationTrapped

  package = .Package~new("Compiled", source)

  Signal Parse

PackageCreationTrapped:

  co = condition("O")

  caller = .context~stackFrames[2]

  line = co~position
  executing = Right(line,6) "*-*" source[line]

  Parse Value co~code With major"."minor

 .Error~Say( caller~traceLine )
 .Error~Say( "Error" major":" ErrorText(major) )
 .Error~Say( "Error" major"."minor "running" caller~name "line" caller~line":" )
 .Error~Say( co~message )
 .Error~Say( "" )
 .Error~Say( "This error happened when compiling:" )
 .Error~Say( executing )

  Raise HALT


Parse:
  Options = .Array~of( -
    (earlyCheck, (BIFs, SIGNAL, GUARD, LEAVE, ITERATE) ) -
  )

  Signal On Syntax

  package = .Rexx.Parser~new(file,source,options)~package

  Return .True

Syntax:

  co = condition("O")
  If co~code \== 98.900 Then Do
   .Error~Say( "Error" co~code "in" co~program", line" co~position":" )
    Raise Propagate
  End

  additional = Condition("A")
  Parse Value additional~lastItem~code With major"."minor

  caller = .context~stackFrames[2]

  line = Additional~lastItem~position
  executing = Right(line,6) "*-*" string

  additional = additional~lastItem
  Parse Value additional~code With major"."minor

 .Error~Say( caller~traceLine )
 .Error~Say( "Error" major":" ErrorText(major) )
 .Error~Say( "Error" major"."minor "running" caller~name "line" caller~line":" .errorText(major"."minor, additional~additional) )
 .Error~Say( "" )
 .Error~Say( "This error happened when executing:" )
 .Error~Say( executing )

  Raise HALT


::Requires "Rexx.Parser.cls"
::Requires "modules/print/print.cls"
