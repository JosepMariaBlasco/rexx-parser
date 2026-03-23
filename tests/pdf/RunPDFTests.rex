#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* RunPDFTests.rex - Setup and runner for PDF integration tests               */
/* ============================================================               */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Checks prerequisites (ooRexx, Pandoc, Node.js, pagedjs-cli,               */
/* poppler-utils), offers to install missing ones, and runs the               */
/* PDF test suite.                                                            */
/* This script only works on Linux (including WSL). It uses apt-get for       */
/* package installation.                                                      */
/*                                                                            */
/* Usage:                                                                     */
/*   rexx tests/pdf/RunPDFTests.rex [--setup-only]                            */
/*                                                                            */
/*   --setup-only   Check/install prerequisites but do not run the tests.     */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260323    0.5  First version                                             */
/*                                                                            */
/******************************************************************************/

  Parse Source . . myPath
  sep = .File~separator

  -- This script only works on Linux (including WSL)
  If .RexxInfo~platform \== "LINUX" Then Do
    Say "ERROR: RunPDFTests.rex requires Linux (including WSL)."
    Say "Current platform:" .RexxInfo~platform
    Return 1
  End

  myDir = FileSpec("Location", myPath)
  -- myDir is tests/pdf/, so project root is two levels up
  If myDir~right(1) == sep Then myDir = myDir~left(myDir~length - 1)
  testsDir = myDir~left(myDir~lastPos(sep) - 1)
  projectDir = testsDir~left(testsDir~lastPos(sep) - 1)

  setupOnly = 0

  Do i = 1 To Arg(1)~words
    option = Arg(1)~word(i)
    Select Case Lower(option)
      When "--setup-only" Then setupOnly = 1
      Otherwise Do
        Say "Unknown option:" option
        Say "Usage: rexx RunPDFTests.rex [--setup-only]"
        Return 1
      End
    End
  End

  Say
  Say "PDF Integration Tests — Setup and Runner"
  Say "========================================="
  Say
  Say "Project directory:" projectDir
  Say

--------------------------------------------------------------------------------
-- Step 1: Check ooRexx                                                       --
--------------------------------------------------------------------------------

  Say "Checking ooRexx..."
  Address System "rexx -v > /dev/null 2>&1"
  If RC \== 0 Then Do
    Say "  ERROR: ooRexx is not installed or not in PATH."
    Say "  Install it before running the PDF tests."
    Return 1
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 2: Check Pandoc                                                       --
--------------------------------------------------------------------------------

  Say "Checking Pandoc..."
  Address System "which pandoc > /dev/null 2>&1"
  If RC \== 0 Then Do
    Say "  Pandoc is not installed."
    If \Ask("  Install pandoc?") Then Return 1
    Say "  Installing pandoc..."
    Address System "sudo apt-get update -qq && sudo apt-get install -y -qq pandoc 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to install pandoc."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 3: Check Node.js and npm                                              --
--------------------------------------------------------------------------------

  Say "Checking Node.js..."
  Address System "which node > /dev/null 2>&1"
  nodeOK = (RC == 0)
  Address System "which npm > /dev/null 2>&1"
  npmOK = (RC == 0)

  If \nodeOK | \npmOK Then Do
    missing = ""
    If \nodeOK Then missing = missing "nodejs"
    If \npmOK  Then missing = missing "npm"
    Say " " missing~strip "not installed."
    If \Ask("  Install" missing~strip"?") Then Return 1
    Say "  Installing..."
    Address System "sudo apt-get update -qq && sudo apt-get install -y -qq" -
      missing~strip "2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to install" missing~strip"."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 4: Check pagedjs-cli                                                  --
--------------------------------------------------------------------------------

  Say "Checking pagedjs-cli..."
  Address System "which pagedjs-cli > /dev/null 2>&1"
  If RC \== 0 Then Do
    Say "  pagedjs-cli is not installed."
    If \Ask("  Install pagedjs-cli (via npm install -g pagedjs-cli)?") -
      Then Return 1
    Say "  Installing pagedjs-cli..."
    Address System "sudo npm install -g pagedjs-cli 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to install pagedjs-cli."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 5: Check poppler-utils (pdfinfo, pdftotext)                           --
--------------------------------------------------------------------------------

  Say "Checking poppler-utils (pdfinfo, pdftotext)..."
  Address System "which pdfinfo > /dev/null 2>&1"
  pdfinfoOK = (RC == 0)
  Address System "which pdftotext > /dev/null 2>&1"
  pdftextOK = (RC == 0)

  If \pdfinfoOK | \pdftextOK Then Do
    Say "  poppler-utils is not installed."
    If \Ask("  Install poppler-utils?") Then Return 1
    Say "  Installing poppler-utils..."
    Address System "sudo apt-get update -qq && sudo apt-get install -y -qq" -
      "poppler-utils 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to install poppler-utils."
      Return 1
    End
  End
  Say "  OK."

  Say
  If setupOnly Then Do
    Say "Setup complete. All prerequisites are installed."
    Say "Run the tests manually with:"
    Say '  cd tests && PATH="framework:pdf:../bin:$PATH"' -
      "rexx pdf/PDF.testGroup"
    Return 0
  End

--------------------------------------------------------------------------------
-- Step 6: Run the tests                                                      --
--------------------------------------------------------------------------------

  Say "Running PDF tests..."
  Say "===================="
  Say "(Each test invokes Pandoc + pagedjs-cli — this may take some time)"
  Say

  savedDir = Directory()
  Call Directory testsDir

  Address System 'PATH="framework:pdf:../bin:$PATH" rexx pdf/PDF.testGroup'

  testRC = RC

  Call Directory savedDir

  Return testRC

/******************************************************************************/
/* Ask: prompt the user for a yes/no answer. Returns 1 for yes, 0 for no.    */
/******************************************************************************/

Ask:
  Use Strict Arg prompt
  Call CharOut , prompt "(y/n) "
  Parse Pull answer
  Return Lower(answer~strip)~abbrev("y")
