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
/* 20251226    0.4a Send error messages to .error, not .output                */
/* 20251227         Use .SysCArgs when available                              */
/* 20260102         Standardize help options to -h and --help                 */
/*                                                                            */
/******************************************************************************/

  package =  .context~package

  myName  =   package~name
  Parse Caseless Value FileSpec( "Name", myName ) With myName".rex"
  myHelp  = ChangeStr(                                         -
   "myName",                                                   -
   "https://rexx.epbcn.com/rexx-parser/doc/utilities/myName/", -
    myName)
  Parse Source . how .
  If how == "COMMAND", .SysCArgs \== .Nil
    Then args = .SysCArgs
    Else args = ArgArray(Arg(1))

  If args~items == 0 Then Signal Help

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

  Loop While args~items > 0, "+-"~contains(Left(args[1],1))
    option = args[1]
    args~delete(1)
    Select Case Lower(option)
      When "-h", "--help" Then Signal Help
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
      When "-emptyassignments", -
        "+emptyassignments" Then emptyassignments = 1
      When "-e", "+e"      Then Do
        code   = args~makeString("L", " ")
        source = .Array~of( code )
        fullPath = "INSTORE"
        Signal code
      End
      When "-extraletters", "+extraletters" Then Do
        If args~size ==  0 Then
          Call "Missing set of letters after '"option"' option."
        extraletters = args[1]
        args~delete(1)
      End
      Otherwise Call Error "Invalid option '"option"'."
    End
  End

  Select Case args~items
    When 0 Then Signal Help
    When 1 Then file = args[1]
    Otherwise Call Error "Unexpected argument '"args[2]"'."
  End

  fullPath = .context~package~findProgram(file)

  If fullPath == .Nil Then
    Call Error "File '"file"' does not exist."

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
   .Error~Say( "Error" co~code "in" co~program", line" co~position":" )
    Raise Propagate
  End
  Exit ErrorHandler( fullPath, source, co, itrace)

--------------------------------------------------------------------------------

Error:
 .Error~Say(Arg(1))
  Exit 1

--------------------------------------------------------------------------------

Help:
  Say .Resources[Help]~makeString        -
    ~caselessChangeStr("myName", myName) -
    ~caselessChangeStr("myHelp", myHelp)
  Exit 1

--------------------------------------------------------------------------------

::Requires "Rexx.Parser.cls"
::Requires "ErrorHandler.cls"
::Requires "modules/print/print.cls"

::Resource help
myname -- Parse a program or a short code fragment

Usage:
  myname [OPTIONS] FILE
  myname [OPTIONS] -e "REXX CODE"

Runs the Rexx Parser against FILE or the supplied REXX CODE.
By default, the parser perform a series of early checks,
without needing to execute the program. Checks are performed
syntactically, and therefore they reach dead branches,
uncalled procedures and routines, etc.

If the only option is -h or --help, or if no arguments are present,
then display this help and exit.

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

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::END
