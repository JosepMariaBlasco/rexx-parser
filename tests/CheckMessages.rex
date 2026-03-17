/******************************************************************************/
/*                                                                            */
/* CheckMessages.rex - Verify parser error comments vs rexxmsg.xml            */
/* ================================================================           */
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
/* 20260317    0.5  Extracted from errors.rex                                 */
/*                                                                            */
/******************************************************************************/

/* Callable as: Call "CheckMessages.rex" binDir, resourcesDir                 */
/* Returns 1 if all checks pass, raises Syntax if not.                        */

  Use Strict Arg binDir, resourcesDir

  rexxMsg  = resourcesDir"/rexxmsg.xml"
  revision = .File~new(resourcesDir"/revision")~absolutePath

/******************************************************************************/
/* Compare revision levels                                                    */
/******************************************************************************/

  revision = LineIn(revision)~strip
  Call Stream revision, "c", "Close"

  If revision \== .RexxInfo~revision Then Do
    Say "  ERROR: revision levels differ!" -
      "Resource:" revision "Rexx:" .RexxInfo~revision
    Return 0
  End

/******************************************************************************/
/* Fetch all error messages < 100 from rexxmsg.xml                            */
/******************************************************************************/

  messages = CharIn(rexxMsg, 1, Chars(rexxMsg))
  Call Stream rexxMsg, "c", "Close"

  messages = messages                        -
    ~changeStr("0d"x, " ")                   -
    ~changeStr("0a"x, " ")                   -
    ~space                                   -
    ~makeArray("<Message>")

  message. = ""
  nMessages = 0

  Do i = 2 To messages~items
    Parse Value messages[i] With -
      "<Code>"major"</Code>" "<Subcodes>"subCodes"</Subcodes>"
    If major > 99 Then Leave
    subMessages = subCodes~makeArray("<SubMessage>")
    Do j = 2 To subMessages~items
      Parse Value subMessages[j] With -
        "<Subcode>"minor"</Subcode>" "<Text>"text"</Text>"
      text = text                            -
        ~changeStr("<q>",  '"')              -
        ~changeStr("</q>", '"')              -
        ~changeStr("<sq/>", "'")             -
        ~changeStr("<dq/>", '"')             -
        ~changeStr("&gt;",  ">")             -
        ~changeStr("&lt;",  "<")             -
        ~changeStr("&apos;", "'")
      If Pos("&", text) > 0 Then Do
        Say "  Unexpected '&' in message text" major"."minor
        Return 0
      End
      Do While Pos("<Sub ", text) > 0
        Parse Var text before "<Sub" 'position="'position'"' "/>" after
        If \DataType(position, "W") Then Do
          Say "  Position in text of" major"."minor "is not an integer."
          Return 0
        End
        text = before"&"position || after
      End
      message.major.minor = text
      nMessages += 1
    End
  End

/******************************************************************************/
/* Inspect all source files and compare with rexxmsg.xml                      */
/******************************************************************************/

  files = .File~new(binDir)~list~sort

  Do i = 1 To files~items
    fn = binDir"/"files[i]
    file = CharIn(fn, 1, Chars(fn))~makeArray
    Call Stream fn, "c", "Close"

    Do j = 1 To file~items
      If file[j]~caselessPos("Syntax(") > 0 Then Do
        Parse Value file[j] With -
          major"."minor": Syntax( "major2"."minor2","
        If major \== major2          Then Iterate
        Else If minor \== minor2     Then Iterate
        Else If \DataType(major,"W") Then Iterate
        Else If \DataType(minor,"W") Then Iterate
        Else If minor == 900         Then Iterate
        Else If major == 22, minor == "001" Then Iterate
        major = Strip(major)
        -- Reconstruct the comment that precedes this Syntax() call
        comment = ""
        Do k = j - 1 By -1 While file[k][1,3] == "-- "
          Parse Value file[k] With "-- "fragment
          comment = Strip(fragment, "T") comment
        End
        comment = Strip(comment, "T")
        If message.major.minor \== comment Then Do
          Say "  Mismatch at" major"."minor "in" files[i]":"
          Say "    rexxmsg: '"message.major.minor"'"
          Say "    source:  '"comment"'"
          Return 0
        End
      End
    End
  End

  Return 1