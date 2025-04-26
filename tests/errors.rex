/******************************************************************************/
/*                                                                            */
/* errors.rex - Compare parser errors and Rexx errors                         */
/* ==================================================                         */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241206    0.1  First public release                                      */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/*                  Binary directory is now "bin" instead of "cls"            */
/* 20250416    0.2a Add BIF early checks                                      */
/*                                                                            */
/******************************************************************************/

Call "earlyChecks.test"

my    = .context~package
myDir = FileSpec("L",my~name)

-- Location of resources directory
resources = myDir"../bin/resources"
-- Location of errors directory
directory = myDir"../tests/errormessages"
-- Location of rexx source files
source    = myDir"../bin"

-- Location of revision file
revision = .File~new(resources"/revision")~absolutePath
-- Location of most current rexxmsg.xml file
rexxMsg  = resources"/rexxmsg.xml"

--------------------------------------------------------------------------------
-- Compare revision levels                                                    --
--------------------------------------------------------------------------------

revision = LineIn(revision)~strip
Call Stream revision,"c","Close"

Say "Processing error messages at Rexx revision" revision"."
If revision \== .RexxInfo~revision Then Do
  Say "-------------------------------------"
  Say "ERROR: revision levels are different!"
  Say "-------------------------------------"
  Say "Resource revision level:"  revision
  Say "Rexx revision          :" .RexxInfo~revision
  Say "-------------------------------------"
  Exit 1
End

--------------------------------------------------------------------------------
-- Fetch all error messages < 100 from rexxmsg.xml                            --
--------------------------------------------------------------------------------

Say
Say "Fetching messages from" rexxMsg"."

messages = CharIn(rexxmsg, 1, Chars(rexxmsg))
Call Stream rexxMsg,"c","Close"

messages = messages~changeStr("0d"x," ")~changeStr("0a"x," ")~space~makeArray("<Message>")

message. = ""
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
      Say "Unexpected '&' in message text" major"."minor":"
      Say text
      Exit
    End
    Do While Pos("<Sub ",Text) >  0
      Parse var text before"<Sub" 'position="'position'"' "/>"after
      If \DataType(position, "W") Then Do
        Say "Position in text of" major"."minor "is not an integer."
        Exit
      End
      text = before"&"position||after
    End
    message.major.minor = text
    nMessages += 1
  End
End

Say nMessages "messages fetched."

--------------------------------------------------------------------------------
-- Inspect all source files and compare with rexxmsg.xml                      --
--------------------------------------------------------------------------------

Say
Say "Processing source files..."

files = .File~new( source )~list~sort

source. = 0

Do i = 1 To files~items
  -- Read each file into an array
  fn = source"/"files[i]
  file = CharIn(fn,1,Chars(fn))~makeArray
  Call Stream fn,"c","Close"

  -- Locate all occurrences of calls to the Syntax() function
  Do j = 1 To file~items
    If file[j]~caselessPos("Syntax(") > 0 Then Do
      Parse Value file[j] With major"."minor": Syntax( "major2"."minor2","
      If major \== major2          Then Say "-- ERROR! -->" file[j]
      Else If minor \== minor2     Then Say "-- ERROR! -->" file[j]
      Else If \DataType(major,"W") Then Say "-- ERROR! -->" file[j]
      Else If \DataType(minor,"W") Then Say "-- ERROR! -->" file[j]
      Else If minor == 900 Then Iterate
      Else If major == 22, minor == "001" Then Iterate -- Unicode
      Else source.[Strip(major),minor] = 1
      major = Strip(major)
      message = ""
      Do k = j - 1 By -1 While file[k][1,3] == "-- "
        Parse Value file[k] With "-- "fragment
        message = Strip(fragment,"T") message
      End
      message = Strip(message,"T")
      If message.major.minor \== message Then Do
        Say "Code" major"."minor":"
        Say "rexxmsg message: '"message.major.minor"'"
        Say "Parser  message: '"message"'"
        Exit
      End
    End
  End

End

--------------------------------------------------------------------------------

Parse Source . . myself
dir =  directory
sep = .File~separator
files = .File~new( directory )~list~sort

Do i = 1 To files~items
  file = files[i]
  Parse value files[i] With major"."minor"."
  major = major + 0
  Drop source.major.minor
Say "Processing" file"..."
-- Second pass not implemented yet & some interpreter bugs
If file~startsWith("99.913") Then Iterate
If file~startsWith("47.003.else.clause.rex")   Then Iterate -- BUG
If file~startsWith("47.003.then.clause.rex")   Then Iterate -- BUG
If file~startsWith("47.004.then.clause.1.rex") Then Iterate -- BUG
If file~startsWith("47.004.then.clause.n.rex") Then Iterate -- BUG
  file = dir || sep || files[i]
  If \ file~caselessEndsWith(".rex") Then Iterate
  Call ProcessFile file, files[i]
  If result == -1 Then Exit
End
Say files~items "error conditions checked."

If source.~allIndexes~items > 0 Then Do
  Say "Syntax calls present in the parser source and not checked:"
  Do code over source.~allIndexes
    If code == "49.900" Then Iterate
    Say "  "code
  End
End

::Routine ProcessFile


  Use Arg file

  file = Translate(file, .File~separator||.File~separator, "\/")

  source = CharIn(file,1,Chars(file))~makeArray
  Call Stream file,'c','close'

  Parse Arg , major"."minor"."

  Options = .Array~of( (earlyCheck, (signal, guard, bifs) ) )

Parser:
  Signal On Syntax Name Syntax1

  -- Should produce a syntax error
  package = .Rexx.Parser~new(file,source,options)~package
  Say
  Say "Expected syntax error on file" file", but parser returned normally."
  Say "File content follows:"
  Say "----------"
  Say CharIn(file,1,Chars(file))~makeArray
  Say "----------"
  Say "Aborting."
  Exit -1

Rexx:
  Signal On Syntax Name Syntax2
  Call (file)

  Say
  Say "Expected syntax error on file" file", but Rexx returned normally."
  Say "File content follows:"
  Say "----------"
  Say CharIn(file,1,Chars(file))~makeArray
  Say "----------"
  Say "Aborting."
  Exit -1

Syntax1:
  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End

  additional = condition("A")

  line1 = additional~lastItem~position
  code1 = additional~lastItem~code

  Signal Rexx

Syntax2:
  co = Condition("O")
  line2 = co~position

  -- line2 may be .Nil in certain circumstances, like when calling
  -- BEEP, DIRECTORY or FILESPEC.
  -- In some other cases, we may encounter intermediate frames. Skip them too.
  If line2 == .Nil Then Do
    line2      = co~stackFrames[1]~line
    traceLine2 = co~stackFrames[1]~traceLine
    Do i = 2 To co~stackFrames~items While traceLine2~contains("(no source available)")
      line2      = co~stackFrames[i]~line
      traceLine2 = co~stackFrames[i]~traceLine
    End
  End

  code2 = co~code

  If line1 == line2, code1 == code2 Then Do
    If additional~items > 2 Then Do
      Do i = 1 To co~additional~items
        If co~additional[i] \== additional[i+1] Then Do
          Say "Processing file" file "failed!"
          Say "Parser additional" i": '"additional[i+1]"'"
          Say "Rexx   additional" i": '"co~additional[i]"'"
          Return -1
        End
      End
    End
    Parse Var code1 cmajor"."cminor
    If major \= cmajor Then Do
      Say "Processing file" file "failed!"
      Say "File name   (major):" major
      Say "Parse error (major):" cmajor
      Return -1
    End
    If minor \= cminor Then Do
      Say "Processing file" file "failed!"
      Say "File name   (minor):" minor
      Say "Parse error (minor):" cminor
      Return -1
    End
    Return 0
  End
  Say "Processing file" file "failed!"
  If line1 \== line2 Then Do
    Say "Parser line:" line1
    Say "Rexx   line:" line2
  End
  If code1 \= code2 Then Do
    Say "Parser code:" code1
    Say "Rexx   code:" code2
  End
  Return -1

  ::Requires "Rexx.Parser.cls"
