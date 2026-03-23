#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* RunTests.rex - Run all .testGroup suites and summarize results            */
/* ==============================================================            */
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
/* 20260316    0.5  First version                                             */
/*                                                                            */
/******************************************************************************/

  Parse Source . . myPath
  sl = .File~separator
  myDir = myPath~left(myPath~lastPos(sl))

  -- Parse arguments: --fix enables auto-regeneration of generated files
  fix = .false
  Do i = 1 To Arg()
    If Arg(i)~caselessEquals("--fix") Then fix = .true
  End

  -- Path separator: ";" on Windows, ":" elsewhere
  If sl == "\" Then pathSep = ";"
                Else pathSep = ":"

  -- Build PATH: framework (for ooTest.frm) + suites (for ParserTestCase.cls)
  --           + bin (for parser classes)
  curPath = Value("PATH", , "ENVIRONMENT")
  newPath = myDir"framework"pathSep || -
            myDir"suites"pathSep || -
            myDir".."sl"bin"pathSep || curPath
  Call Value "PATH", newPath, "ENVIRONMENT"

  -- Tell ooTest.frm that this is an automated run, so .testGroup
  -- files return their TestGroup object instead of executing.
  .local~bRunTestsLocally = .false

  -- Sanity check: verify parser source comments match rexxmsg.xml
  binDir       = myDir".."sl"bin"sl
  resourcesDir = binDir"resources"
  Say "Checking error messages vs rexxmsg.xml..."
  Call (myDir"CheckMessages.rex") binDir, resourcesDir
  If result Then
    Say "Message consistency check passed."
  Else Do
    Say "Message consistency check FAILED — aborting."
    Exit 1
  End

  -- Sanity check: verify ANSI.ErrorText.cls is up to date
  Say "Checking ANSI.ErrorText.cls..."
  Call (myDir"CheckErrorText.rex") binDir, resourcesDir, fix
  If result Then
    Say "ANSI.ErrorText.cls check passed."
  Else Do
    Say "ANSI.ErrorText.cls check FAILED — aborting."
    Exit 1
  End
  Say

  -- Find all .testGroup files in suites/
  suitesDir = myDir"suites"
  Call SysFileTree suitesDir || sl"*.testGroup", "files.", "FO"

  If files.0 == 0 Then Do
    Say "No .testGroup files found in" suitesDir
    Exit 1
  End

  -- Sort alphabetically
  names = .Array~new
  Do i = 1 To files.0
    names~append(files.i)
  End
  names~sortWith(.CaselessComparator~new)

  -- Run each suite and accumulate
  totalTests  = 0
  totalFails  = 0
  totalErrors = 0
  failed      = .Array~new

  Do file Over names
    shortName = file~substr(file~lastPos(sl) + 1)
    Call RunOneSuite file, shortName
  End

  -- Summary
  Say
  Say Copies("=", 60)
  Say "Total tests: " totalTests
  Say "Total failures:" totalFails
  Say "Total errors:  " totalErrors

  If failed~items > 0 Then Do
    Say
    Say "FAILED suites:"
    Do name Over failed
      Say "  -" name
    End
    Exit 1
  End

  Say
  Say "All suites passed."
  Exit 0

/******************************************************************************/
/* RunOneSuite: execute one .testGroup and accumulate results                 */
/******************************************************************************/

RunOneSuite:
  Signal On Syntax Name SuiteCrashed
  Parse Arg suiteFile, suiteName

  Call (suiteFile)
  group = Result

  suite  = group~suite
  result = suite~execute
  tests  = result~runCount
  errs   = result~errorCount
  fails  = result~failureCount

  Say suiteName~left(35) "Tests:" tests~right(4),
    " Failures:" fails~right(3),
    " Errors:" errs~right(3)

  totalTests  += tests
  totalFails  += fails
  totalErrors += errs

  If fails > 0 | errs > 0 Then
    failed~append(suiteName)
  Return

SuiteCrashed:
  co = Condition("O")
  Say suiteName~left(35) "*** CRASHED:" co~message
  totalErrors += 1
  failed~append(suiteName "— CRASHED")
  Return