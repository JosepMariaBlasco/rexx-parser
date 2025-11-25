/******************************************************************************/
/*                                                                            */
/* elident.rex - Check that a program is equal to its Element API parsing     */
/* ======================================================================     */
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
/* 20241206    0.1  First public release                                      */
/* 20241208    0.1a c/CLASSIC_COMMENT/STANDARD_COMMENT/                       */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20251110    0.23 Change the name to elident.rex                            */
/*                                                                            */
/******************************************************************************/

Signal On Syntax

Parse Arg args
args = Strip( args )

If args == "" | args == "--help" | args == "-?" Then Do
  Say .Resources["HELP"]
  Exit 1
End

Call RetrieveFilename

-- Read the whole file into an array
chunk = CharIn(file,1,Chars(file))
Call Stream file,"c","close"
source = chunk~makeArray
-- Makearray has a funny definition that ignores a possible
-- last empty line.
If Right(chunk,1) = "0a"X Then source~append("")

parser = .Rexx.Parser~new( file, source )

currentLineNo = 1
currentLine   = ""

element = parser~firstElement -- Same as parser~package~prolog~body~begin
Do Counter elements Until element == .Nil
  If element~from \== element~to Then Do
    category = element~category
    elementLine  = element~from~word(1)
    If      elementLine > currentLineNo          Then Call ChangeLine
    If      category == .EL.STANDARD_COMMENT     Then Call StandardComment
    Else If category == .EL.DOC_COMMENT          Then Call StandardComment
    Else If category == .EL.DOC_COMMENT_MARKDOWN Then Call StandardComment
    Else If category == .EL.RESOURCE_DATA        Then Call ResourceData
    Else    currentLine ||= element~source
  End
  element = element~next
End

Exit 0

StandardComment:
  lastLine = element~to~word(1)
  start = element~from~word(2)
  end   = element~  to~word(2)
  If elementLine == lastLine Then Do
    currentLine ||= source[currentLineNo][ start, end-start ]
    Return
  End
  elementLine += 1
  currentLine ||= SubStr( source[currentLineNo], start )
  Call ChangeLine
  currentLineNo = lastLine
  currentLine   = source[currentLineNo]
Return

ResourceData:
  lastLine = element~to~word(1)
  currentLineNo = lastLine + 1
  currentLine   = ""
Return

ChangeLine:
  Do While elementLine > currentLineNo
    If source[currentLineNo] \== currentLine Then Do
      Say "Difference found in line number" currentLineNo":"
      Say "Source line is '"source[currentLineNo]"',"
      Say "Parsed line is '"currentLine"'."
      Exit 1
    End
    currentLineNo += 1
    currentLine    = ""
  End
Return

RetrieveFilename:
  c = args[1]
  -- Quoted filenames
  If ( '"' || "'" )~contains( c ) Then Do
    Parse Var args +1 fileName (c) extra
    extra = Strip( extra )
    If extra \== "" Then Do
      Say "Unrecognized parameter '"extra"'."
      Exit 1
    End
  End
  Else fileName = args

  -- Try the file name as-is first, then add ".rex" at the end
  file = Stream(fileName,"c","query exists")
  If file = "" Then Do
    If \ fileName~caselessEndsWith(".rex") Then
      file = Stream(fileName".rex","c","query exists")
    If file = "" Then Do
      Say "File '"fileName"' not found."
      Exit 1
    End
  End

Return

-- This is the standard condition handler for the Rexx parser

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End
  br = (.Parser.options~hasIndex( html ) == "1")~?("<br>",.endOfLine)

  additional = Condition("A")
  Say additional[1]":"
  line = Additional~lastItem~position
  Say Right(line,6) "*-*" source[line]
  Say Copies("-",80)
  Say co~stackFrames~makeArray~makeString("L",br)
  additional = additional~lastItem

  Raise Syntax (additional~code) Additional (additional~additional)

  Exit

::Resource HELP
Usage: ident [OPTION]... [FILE]
Check that the Rexx Parser returns a stream of elements identical to a FILE.

If the only option is --help or -?, or if no arguments are present,
then display this help and exit.
::END

::Requires "Rexx.Parser.cls"