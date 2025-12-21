/******************************************************************************/
/*                                                                            */
/* rxcheck.rex - Run the parser with all the early check activated            */
/* ===============================================================            */
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
/* 20250416    0.2a First release                                             */
/*             0.2a Add "[+|-]debug" option                                   */
/* 20250421    0.2b Add "[+|-]e" option                                       */
/*                  Add "[+|-]extraletters" option                            */
/*                  Add "[+|-]emptyassignments" option                        */
/* 20250426         Add ANSI.ErrorText support, -itrace option                */
/* 20250508         Fix typo (GitHub issue no. 10 - Thanks Geoff!)            */
/* 20250831    0.2e Add support for LEAVE and INTERPRET checks                */
/* 20250929         Add ".rex" to filename when appropriate                   */
/* 20251114    0.3a Add support for Experimental features                     */
/* 20251125         Add support for Executor                                  */
/* 20251129         -e option does not need quotes now                        */
/*                                                                            */
/******************************************************************************/

  Parse Arg file

  If file = "" Then Signal Help

  signal           = 1
  guard            = 1
  leave            = 1
  iterate          = 1
  bifs             = 1
  debug            = 0
  itrace           = 0
  experimental     = 0
  executor         = 0
  extraletters     = ""
  emptyassignments = 0
  Do While "+-"~contains(Left(file,1))
    Parse Var file option file
    Select Case Lower(option)
      When "-?", "-help", "--help" Then Signal Help
      When "-all" Then Do
        signal  = 0
        guard   = 0
        bifs    = 0
        leave   = 0
        iterate = 0
      End
      When "+all" Then Do
        signal  = 1
        guard   = 1
        bifs    = 1
        leave   = 1
        iterate = 1
      End
      When "-signal"       Then signal   = 0
      When "+signal"       Then signal   = 1
      When "-leave"        Then leave    = 0
      When "+leave"        Then leave    = 1
      When "-iterate"      Then iterate  = 0
      When "+iterate"      Then iterate  = 1
      When "-guard"        Then guard    = 0
      When "+guard"        Then guard    = 0
      When "-bifs"         Then bifs     = 0
      When "+bifs"         Then bifs     = 1
      When "-debug"        Then debug    = 0
      When "+debug"        Then debug    = 1
      When "-itrace"       Then itrace   = 0
      When "+itrace"       Then itrace   = 1
      When "-xtr",-
           "-executor"     Then executor = 1
      When "-experimental", -
           "+experimental", -
           "-exp", "+exp"  Then experimental = 1
      When "-emptyassignments", "+emptyassignments" Then emptyassignments = 1
      When "-e", "+e"      Then Do
        code = file
        source = .Array~of( code )
        fullPath = "INSTORE"
        Signal code
      End
      When "-extraletters", "+extraletters" Then Do
        c = file[1]
        If Pos(c,"'""") == 0 Then Do
          Say "The -extraletters option must be immediately followed by a quoted set of letters."
          Exit 1
        End
        Parse Var file (c)extraletters(c)file
        If extraletters == "" Then Do
          Say "No extra letters found found after '-extraletters' option."
        End
      End
      Otherwise
        Say "Invalid option '"option"'."
        Exit 1
    End
  End

  file = Strip(file)

  fullPath = .context~package~findProgram(file)

  If fullPath == .Nil Then Do
    Say "File '"file"' does not exist."
    Exit 1
  End

  source = CharIn(fullPath, 1, Chars(fullPath))~makeArray
  Call Stream fullPath, 'c', 'close'

Code:

  check = .Array~new
  If signal  Then check~append("SIGNAL")
  If guard   Then check~append("GUARD")
  If bifs    Then check~append("BIFS")
  If leave   Then check~append("LEAVE")
  If iterate Then check~append("ITERATE")
  Options = .Array~of( (earlyCheck, check ) )

  If extraletters \== "" Then Options~append(("EXTRALETTERS", extraletters))
  If emptyassignments    Then Options~append(("EMPTYASSIGNMENTS", emptyassignments))
  If experimental        Then Options~append(("EXPERIMENTAL", 1))
  If executor            Then Options~append(("EXECUTOR", 1))

  Signal On Syntax

  If debug Then .environment~rxcheck.debug = 1

  package = .Rexx.Parser~new(fullPath,source,options)~package

  Say "No errors found."

  Exit

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End
  Exit ErrorHandler( fullPath, source, co, itrace)

Help:
  Say .Resources~Help
  Exit 1

::Requires "Rexx.Parser.cls"
::Requires "ErrorHandler.cls"
::Requires "modules/print/print.cls"

::Resource help
rxcheck -- Parse a program or a short code fragment

Usage:
  rxcheck [OPTIONS] FILE
  rxcheck [OPTIONS] -e "REXX CODE"

Runs the Rexx Parser against FILE or the supplied REXX CODE.
By default, the parser perform a series of early checks,
without needing to execute the program. Checks are performed
syntactically, and therefore they reach dead branches,
uncalled procedures and routines, etc.

Options:
  -?, -help, -- help Display this help file.

Toggles:

  +all          Activate all toggles. This is the default.
  -all          Deactivate all toggles.
  [+|-]signal   Toggle detecting SIGNAL to inexistent labels.
  [+|-]guard    Toggle checking that GUARD is in a method body.
  [+|-]bifs     Check BIF arguments.

  [+|-]debug    (De)activate debug mode (not affected by "all").
  [+|-]itrace   Toggle printing internal traceback on error

Other options (all can be prefixed with "+" or "-"):

  -executor     Enable support for Executor
  -xtr          Enable support for Executor
  -experimental Enable experimental features
  -exp          Enable experimental features
  -emptyassignments  Allow assignments like "var =".
  -extraletters "extra"  Allow all the characters in "extra"
                to function as letters.


Executing short code fragments:

  -e code       Immediately parse a string of Rexx code.
                This has to be the last argument.

All toggles except "debug" are active by default
::END
