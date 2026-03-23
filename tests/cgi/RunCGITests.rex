#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* RunCGITests.rex - Setup and runner for CGI integration tests               */
/* ============================================================               */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Checks prerequisites (ooRexx, Apache, Pandoc), configures Apache if        */
/* needed, starts it, runs the CGI test suite, and stops Apache.              */
/* This script only works on Linux (including WSL). It uses apt-get for       */
/* package installation and Apache paths specific to Debian/Ubuntu.           */
/*                                                                            */
/* Usage:                                                                     */
/*   rexx tests/cgi/RunCGITests.rex [--setup-only] [--no-stop]                */
/*                                                                            */
/*   --setup-only   Check/install prerequisites and configure Apache,         */
/*                  but do not run the tests.                                 */
/*   --no-stop      Do not stop Apache after running the tests.               */
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
    Say "ERROR: RunCGITests.rex requires Linux (including WSL)."
    Say "Current platform:" .RexxInfo~platform
    Return 1
  End

  myDir = FileSpec("Location", myPath)
  -- myDir is tests/cgi/, so project root is two levels up
  If myDir~right(1) == sep Then myDir = myDir~left(myDir~length - 1)
  testsDir = myDir~left(myDir~lastPos(sep) - 1)
  projectDir = testsDir~left(testsDir~lastPos(sep) - 1)

  setupOnly = 0
  noStop    = 0

  Do i = 1 To Arg(1)~words
    option = Arg(1)~word(i)
    Select Case Lower(option)
      When "--setup-only" Then setupOnly = 1
      When "--no-stop"    Then noStop    = 1
      Otherwise Do
        Say "Unknown option:" option
        Say "Usage: rexx RunCGITests.rex [--setup-only] [--no-stop]"
        Return 1
      End
    End
  End

  confFile    = "/etc/apache2/sites-available/rexx-cgi.conf"
  wrapperFile = projectDir || sep || "cgi" || sep || "cgi-wrapper.sh"
  cgiScript   = projectDir || sep || "cgi" || sep || "CGI.markdown.rex"

  Say
  Say "CGI Integration Tests — Setup and Runner"
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
    Say "  Install it before running the CGI tests."
    Return 1
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 2: Check Apache                                                       --
--------------------------------------------------------------------------------

  Say "Checking Apache..."
  Address System "which apachectl > /dev/null 2>&1"
  If RC \== 0 Then Do
    Say "  Apache is not installed."
    If \Ask("  Install apache2?") Then Return 1
    Say "  Installing apache2..."
    Address System "sudo apt-get update -qq && sudo apt-get install -y -qq apache2 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to install apache2."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 3: Check Pandoc                                                       --
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
-- Step 4: Check Apache modules                                               --
--------------------------------------------------------------------------------

  Say "Checking Apache modules (cgid, actions)..."
  Address System "apachectl -M 2>/dev/null | grep -q cgid_module"
  cgidOK = (RC == 0)
  Address System "apachectl -M 2>/dev/null | grep -q actions_module"
  actionsOK = (RC == 0)

  If \cgidOK | \actionsOK Then Do
    missing = ""
    If \cgidOK    Then missing = missing "cgid"
    If \actionsOK Then missing = missing "actions"
    Say "  Missing modules:" missing~strip
    If \Ask("  Enable them?") Then Return 1
    Address System "sudo a2enmod cgid actions 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to enable modules."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 5: Create cgi-wrapper.sh                                              --
--------------------------------------------------------------------------------

  Say "Checking" wrapperFile"..."
  createdWrapper = 0
  If Stream(wrapperFile, "C", "Q Exists") \== "" Then
    Say "  Already exists."
  Else Do
    Say "  Not found."
    If \Ask("  Create it?") Then Return 1
    Call CreateWrapper wrapperFile, projectDir
    createdWrapper = 1
    Say "  Created."
  End

  -- Ensure executable permissions
  Address System "chmod +x" wrapperFile cgiScript

--------------------------------------------------------------------------------
-- Step 6: Create Apache virtualhost                                          --
--------------------------------------------------------------------------------

  Say "Checking" confFile"..."
  createdConf = 0
  Address System "test -f" confFile
  If RC == 0 Then
    Say "  Already exists."
  Else Do
    Say "  Not found."
    If \Ask("  Create it (requires sudo)?") Then Return 1
    tmpConf = "/tmp/rexx-cgi.conf.tmp"
    Call CreateVirtualHost tmpConf, projectDir
    Address System "sudo cp" tmpConf confFile
    Address System "rm -f" tmpConf
    createdConf = 1
    Say "  Created."
  End

--------------------------------------------------------------------------------
-- Step 7: Enable site                                                        --
--------------------------------------------------------------------------------

  Say "Enabling rexx-cgi site..."
  Address System "sudo a2dissite 000-default 2>/dev/null"
  Address System "sudo a2ensite rexx-cgi 2>/dev/null"
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 8: Start Apache                                                       --
--------------------------------------------------------------------------------

  Say "Starting Apache..."
  Address System "sudo apachectl start 2>/dev/null"
  -- Give it a moment to start
  Call SysSleep 0.5
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 9: Smoke test                                                         --
--------------------------------------------------------------------------------

  Say "Smoke test (curl http://127.0.0.1/)..."
  Address System "curl -s -o /dev/null -w '%{http_code}'" ,
    "--noproxy 127.0.0.1 http://127.0.0.1/ > /tmp/cgi-smoke.tmp 2>&1"
  smoke = LineIn("/tmp/cgi-smoke.tmp")
  Call Stream "/tmp/cgi-smoke.tmp", "C", "Close"
  Address System "rm -f /tmp/cgi-smoke.tmp"
  If smoke~strip~left(1) \== "2" & smoke~strip \== "403" Then Do
    Say "  WARNING: Apache responded with" smoke~strip
    Say "  The tests may not work. Check the Apache configuration."
  End
  Else
    Say "  OK (HTTP" smoke~strip")."

  Say
  If setupOnly Then Do
    Say "Setup complete. Apache is running."
    Say "Run the tests manually with:"
    Say '  cd tests && PATH="framework:cgi:../bin:$PATH" rexx cgi/CGI.testGroup'
    Return 0
  End

--------------------------------------------------------------------------------
-- Step 10: Run the tests                                                     --
--------------------------------------------------------------------------------

  Say "Running CGI tests..."
  Say "===================="
  Say

  savedDir = Directory()
  Call Directory testsDir

  Address System 'PATH="framework:cgi:../bin:$PATH" rexx cgi/CGI.testGroup'

  testRC = RC

  Call Directory savedDir

  Say

--------------------------------------------------------------------------------
-- Step 11: Stop Apache (unless --no-stop)                                    --
--------------------------------------------------------------------------------

  If \noStop Then Do
    Say "Stopping Apache..."
    Address System "sudo apachectl stop 2>/dev/null"
    Say "  OK."
  End
  Else
    Say "Apache left running (--no-stop)."

--------------------------------------------------------------------------------
-- Step 12: Clean up files we created                                         --
--------------------------------------------------------------------------------

  If createdWrapper Then Do
    Say "Removing" wrapperFile "(created by this script)..."
    Address System "rm -f" '"'wrapperFile'"'
    Say "  OK."
  End

  If createdConf Then Do
    Say "Removing" confFile "(created by this script)..."
    Address System "sudo rm -f" confFile
    Say "  OK."
  End

  Return testRC

/******************************************************************************/
/* Ask: prompt the user for a yes/no answer. Returns 1 for yes, 0 for no.    */
/******************************************************************************/

Ask:
  Use Strict Arg prompt
  Call CharOut , prompt "(y/n) "
  Parse Pull answer
  Return Lower(answer~strip)~abbrev("y")

/******************************************************************************/
/* CreateWrapper: generate cgi-wrapper.sh                                     */
/******************************************************************************/

CreateWrapper:
  Use Strict Arg filePath, projDir
  template = .Resources~Wrapper~makeString("L", "0A"x)
  template = template~changeStr("%projectDir%", projDir)
  Call Stream filePath, "C", "Open Write Replace"
  Call CharOut filePath, template
  Call Stream filePath, "C", "Close"
  Return

/******************************************************************************/
/* CreateVirtualHost: generate Apache virtualhost config                      */
/******************************************************************************/

CreateVirtualHost:
  Use Strict Arg filePath, projDir
  template = .Resources~VirtualHost~makeString("L", "0A"x)
  template = template~changeStr("%projectDir%", projDir)
  Call Stream filePath, "C", "Open Write Replace"
  Call CharOut filePath, template
  Call Stream filePath, "C", "Close"
  Return

::Resource Wrapper
#!/bin/bash
export REXX_PATH="%projectDir%/cgi:%projectDir%/bin"
exec rexx %projectDir%/cgi/CGI.markdown.rex "$@"
::END

::Resource VirtualHost
<VirtualHost *:80>
    DocumentRoot %projectDir%
    <Directory %projectDir%>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ScriptAlias /cgi-bin/ %projectDir%/cgi/
    <Directory %projectDir%/cgi>
        Options +ExecCGI
        AllowOverride None
        Require all granted
        SetHandler cgi-script
    </Directory>
    Action Markdown /cgi-bin/cgi-wrapper.sh
    <FilesMatch "\.(md|rex|cls)$">
        SetHandler Markdown
    </FilesMatch>
</VirtualHost>
::END
