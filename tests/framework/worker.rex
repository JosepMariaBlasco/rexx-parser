#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2007-2021 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* http://www.oorexx.org/license.html                                         */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/

/** worker.rex
 * This is the program that actually executes the test suite.  It is designed
 * to be invoked from testOORexx.rex, or a similar program.  testOORexx sets
 * the path to the framework files prior to invoking this program.  This allows
 * the test suite to be executed from anywhere on the file system without
 * needing the framework directories in the existing path.
 */
arguments = arg(1)

   parse source . . file
   overallPhase = .PhaseReport~new(file, .PhaseReport~AUTOMATED_TEST_PHASE)

   cl = .CommandLine~new(arguments)
   if cl~needsHelp then return cl~showHelp

   .local~bRunTestsLocally = .false

   testResult = .ooRexxUnit.default.TestResult.Class~new
   testResult~noAutoTiming

   -- Set verbosity.
   testResult~setVerbosity(cl~getVerbosity)

   if cl~noTests then return finishTestRun(cl, testResult, overallPhase)

   searchPhase  = .PhaseReport~new(file, .PhaseReport~FILE_SEARCH_PHASE)
   msg = "Searching for test containers"
   if cl~suppressAllTicks then
     say msg
   else
     searchPhase~tickTock(msg)

   finder = .ooTestFinder~new(cl~root, cl~ext, cl~testTypes)
   select
     when .testOpts~singleFile \== .nil then finder~useFileName(.testOpts~singleFile)
     when .testOpts~fileList \== .nil then finder~useFiles(.testOpts~fileList)
     when .testOpts~excludeFileList \== .nil then finder~excludeFiles(.testOpts~excludeFileList)
     when .testOpts~filesWithPattern \== .nil then finder~usePatterns(.testOpts~filesWithPattern)
     otherwise nop
   end
   -- End select

   containers = finder~seek(testResult)

   -- Building the test suite takes very little time at this point.  No need to
   -- show ticks.
   testResult~addEvent(searchPhase~~done)
   suiteBuildPhase  = .PhaseReport~new(file, .PhaseReport~SUITE_BUILD_PHASE)

   suite = .ooTestSuite~new
   suite~showProgress = cl~showProgress
   suite~beVerbose = cl~showTestCases

   do container over containers
     select
       when .testOpts~testCases \== .nil then container~suiteForTestCases(.testOpts~testCases, cl~testTypes, suite)
       when cl~testTypes == .nil then container~suite(suite)
       otherwise container~suiteForTestTypes(cl~testTypes, suite)
     end
   end

   testResult~addEvent(suiteBuildPhase~~done)

   executionPhase  = .PhaseReport~new(file, .PhaseReport~TEST_EXECUTION_PHASE)
   msg = 'Executing automated test suite'
   if cl~doTestCaseTicks then
     executionPhase~tickTock(msg)
   else
     say msg

   -- This next line is what it is all about.
   suite~execute(testResult)

   executionPhase~done
   testResult~addEvent(executionPhase)

return finishTestRun(cl, testResult, overAllPhase, containers)

::requires "ooTest.frm"

::routine finishTestRun
  use strict arg cl, testResult, overallPhase, containers = .nil

  overallPhase~done
  testResult~addEvent(overallPhase)

  if .testOpts~logFile <> .nil then do
    if .testOpts~logFileAppend then mode = 'append'
    else mode = 'replace'

    currenMonitor = .output~destination(.stream~new(.testOpts~logFile)~~command("open write" mode))

    testResult~print("ooTest Framework - Automated Test of the ooRexx Interpreter")

    if .testOpts~debug then j = printDebug(containers, testResult, cl)
    else if .testOpts~printOptions then j = printOptions(.true)

    .output~destination
  end

  testResult~print("ooTest Framework - Automated Test of the ooRexx Interpreter")

  if .testOpts~debug then j = printDebug(containers, testResult, cl)
  else if .testOpts~printOptions then j = printOptions(.true)

  if cl~waitAtCompletion then do
    say
    say "The automated test run is finished, hit enter to continue"
    pull
  end

return max(testResult~newFailureCount > 0, 2 * (testResult~errorCount > 0), 3 * (testResult~exceptionCount > 0))

return .ooTestConstants~SUCCESS_RC

::class 'CommandLine' public inherit ooTestConstants NoiseAdjustable

::attribute version get
::attribute version set private
::attribute root get
::attribute root set private
::attribute ext get
::attribute ext set private
::attribute testTypes get
::attribute testTypes set private

::attribute needsHelp get
::attribute needsHelp set private
::attribute doLongHelp private
::attribute doSubjectHelp private
::attribute errMsg private
::attribute doVersionOnly private

::attribute showTestCases get                  -- S
::attribute showTestCases set private
::attribute showProgress get                   -- s
::attribute showProgress set private
::attribute suppressAllTicks get               -- U
::attribute suppressAllTicks set private
::attribute suppressTestcaseTicks get          -- u
::attribute suppressTestcaseTicks set private
::attribute logFile get                        -- l
::attribute logFile set private
::attribute noTests get                        -- n
::attribute noTests set private
::attribute waitAtCompletion get               -- w
::attribute waitAtCompletion set private

::attribute testOpts private

::method init
  expose cmdLine testOpts
  use arg cmdLine

  testOpts = .directory~new
  self~setAllDefaults
  if self~needsHelp then return

  .environment~testOpts = testOpts

  -- Command line options over-ride options in the options file, so the file, if
  -- there is one, must be read before parsing the rest of the command line.
  self~readOptionsFile
  if self~needsHelp then return

  self~parse
  if self~needsHelp then return

  self~resolveTestTypes
  self~resolveOptions

::method showHelp
  expose errMsg

  say "testOORexx version" self~version "ooTest Framework version" .ooTest_Framework_version
  if self~doVersionOnly then return self~TEST_SUCCESS_RC

  say
  if self~doSubjectHelp then return self~subjectHelp
  if self~doLongHelp then return self~longHelp

  if errMsg~items == 0 then do
    ret = self~TEST_HELP_RC
  end
  else do
    ret = self~TEST_BADARGS_RC
    do line over errMsg
      say line
    end
    say
  end

  self~doShortHelp
  return ret

::method getCommandLine
  expose originalCommandLine
  return originalCommandLine

/** doTestCaseTicks()  Convenience method. */
::method doTestCaseTicks
  if \ self~suppressAllTicks,  \ self~suppressTestcaseTicks, \ self~showProgress, \ self~showTestCases then
    return .true
  return .false

::method resolveTestTypes private
  expose testOpts

  tmpSet = testOpts~defaultTestTypes~copy
  includes = testOpts~testTypeIncludes
  excludes = testOpts~testTypeExcludes

  -- If there are includes, add them into the default set.
  if includes \== .nil then tmpSet = tmpSet~union(includes)

  -- Now, if there are excludes subtract them out.
  if  excludes \== .nil then tmpSet = tmpSet~difference(excludes)

  -- A value of .nil is used to signal that all test types are to be used.  This
  -- reduces the processing in parts of the automated running of the test suite.
  -- Determine here if the default set now represents all possible tests.
  if .ooTestTypes~all~difference(tmpSet)~items == 0 then do
    self~testTypes = .nil
    testOpts~testTypes = .nil
  end
  else do
    self~testTypes = tmpSet
    testOpts~testTypes = tmpSet
  end


::method resolveOptions private
  expose testOpts

  self~setVerbosity(testOpts~verbosity)
  self~root      = testOpts~testCaseRoot
  self~ext       = testOpts~testContainerExt

  self~showProgress = testOpts~showProgress
  self~showTestCases = testOpts~showTestCases
  self~suppressTestcaseTicks = testOpts~suppressTestCaseTicks
  self~suppressAllTicks = testOpts~suppressAllTicks
  self~noTests = testOpts~noTests
  self~waitAtCompletion = testOpts~waitAtCompletion

  /*
  if testOpts~singleFile == .nil, testOpts~fileList \== .nil, testOpts~fileList~items == 1 then do
    a = testOpts~fileList~makeArray
    testOpts~singleFile = a[1]
    testOpts~fileList = .nil
  end */

::method readOptionsFile private
  expose cmdLine testOpts originalCommandLine

  -- See if the user specified any options file related flags.
  dashLittle = cmdLine~wordPos("-o")
  dashBig = cmdLine~wordPos("-O")

  -- Can not specifiy both.
  if dashLittle <> 0, dashBig <> 0 then do
    msgs = .list~of("Bad command line",                                                     -
                    "  CommandLine:" originalCommandLine,                                   -
                    "  Error at:   " cmdLine~word(dashLittle) 'and' cmdLine~word(dashBig)  -
                    "The -o and -O flags can not be specified together" )
    self~addErrorMsgAtTop(msg)
    self~needsHelp = .true
    return
  end

  if dashBig <> 0 then do
    testOpts~noOptionsFile = .true
    return
  end

  if dashLittle <> 0 then do
    if \ self~validateAlternateOptionsFile(dashLittle) then return
  end
  else do
    if SysFileExists(self~DEFAULT_OPTIONS_FILE) then testOpts~optionsFile = self~DEFAULT_OPTIONS_FILE
  end

  if testOpts~optionsFile \== .nil then do
    p = .Properties~load(testOpts~optionsFile)
    if p~items == 0 then do
      -- No items found, setting needsHelp will abort the test run.  The user
      -- will have to make sure they don't have an empty options file.
      m = .list~of('Error reading the options file.', '  file:' testOpts~optionsFile, 'No options were found in the file.')
      self~addErrorMsg(m)
      self~needsHelp = .true
      return
    end

    itr = p~supplier
    do while itr~available
      if \ self~validateAndSetOpt(itr~index~upper, itr~item) then do
        m = .list~of('Error reading the options file.', '  file:' testOpts~optionsFile)
        self~addErrorMsgAtTop(m)
        self~needsHelp = .true
        return
      end

      itr~next
    end
  end

/** validateAlternateOptionsFile()
 *
 * Checks that the -o option is valid.  If it is not valid, an error message is
 * added.
 *
 * @param pos  The word position of the -o token in the command line.
 *
 * @return  True if the -o option names an exsiting file, otherwise false.
 */
::method validateAlternateOptionsFile private
  expose cmdLine testOpts
  use strict arg pos

  extra = ""
  optFile = cmdLine~word(pos + 1)

  if optFile == "" then do
    extra = 'Command line:' cmdLine
  end
  else if \ SysFileExists(optFile) then do
    extra = 'The file:' optFile 'does not exist'
  end

  if extra \== "" then do
    m = .list~of('Error:', '  The -o option must be followed by a valid file name', extra)
    self~addErrorMsg(m)
    self~needsHelp = .true
    return .false
  end

  testOpts~optionsFile = optFile
  return .true

::method parse private
  expose cmdLine testOpts tokenCount errMsg originalCommandLine

  cmdLine = cmdLine~space(1)
  tokenCount = cmdLine~words

  if tokenCount > 0 then do
    done = self~checkFormat
    if done then return
  end

  do i = 1 to tokenCount
    token = cmdLine~word(i)

    if token~abbrev("-") then do
      j = self~parseShortOpt(token, i)
    end
    else do
      errMsg~insert("Command line arguments must start with '-'")
      errMsg~insert("  Error at:" cmdLine~word(i))
      self~needsHelp = .true
      return
    end

    if j < 0 then do
      self~needsHelp = .true

      -- It's not an error to request the version only (-v option.)
      if self~doVersionOnly then return

      -- The error message list *may* already have some messages.  We want these
      -- messages to be first in the print out so they are inserted at the front
      -- of the list.
      msgs = .list~of("Bad command line", "  CommandLine:" originalCommandLine, "  Error at:   " cmdLine~word(i))
      self~addErrorMsgAtTop(msgs)
      return
    end
    i = j
  end
  -- End do

  if testOpts~logFileAppend, testOpts~logFile == .nil then do
    self~needsHelp = .true

    msgs = .list~of("Bad command line", "  CommandLine:" originalCommandLine, -
                    "  The -L option can not be used without the -l option")
    self~addErrorMsgAtTop(msgs)
    return
  end

::method lastToken private
  expose tokenCount
  use strict arg index, msg

  if index == tokenCount then do
    self~addErrorMsg(msg)
    return .true
  end
  return .false

::method isSingleValueToken private
  expose tokenCount
  use strict arg index, msg

  if (index + 2) < tokenCount, \ self~isOptionToken(index + 2) then do
    self~addErrorMsg(msg)
    return .false
  end
  return .true

::method checkPattern private
  use strict arg pattern

  if .ooTestConstants~SL == '\' then wrongSlash = '/'; else wrongSlash = '\'
  invalid = '*|[]:"<>?{}()+ ' || "'" || wrongSlash

  pos = verify(pattern, invalid, 'M')
  if pos <> 0 then do
    char = pattern~substr(pos, 1)
    self~addErrorMsg("The file pattern:" pattern "contains an invalid character ("char")")
    self~addErrorMsg("  File patterns can not contain invalid file name characters")
    self~addErrorMsg("  or regular expression characters.")
    return .false
  end
  return .true

::method checkFileName private
  use strict arg name

  if .ooTestConstants~SL == '\' then wrongSlash = '/'; else wrongSlash = '\'
  invalid = '*|:"<>?;= ' || "'" || wrongSlash

  pos = verify(name, invalid, 'M')
  if pos <> 0 then do
    char = name~substr(pos, 1)
    self~addErrorMsg("The file name:" name "contains an invalid character ("char")")
    self~addErrorMsg("  File patterns can not contain invalid file name characters")
    self~addErrorMsg("  or characters that require special quoting.")
    return .false
  end
  return .true

::method parseShortOpt private
  expose cmdLine tokenCount testOpts
  use arg word, i

  j = i

  select
    when word == '-v' then do
      -- Return -1 to stop parsing the command line.
      self~doVersionOnly = .true
      j = -1
    end

    when word == '-a' then do
      testOpts~allTestTypes = .true
      testOpts~defaultTestTypes = .ooTestTypes~all
    end

    when word == '-d' then do
      j = self~addMultiWordOpt(i, '-d')
    end

    when word~abbrev("-D")  then do
      j = self~addOption(i)
    end

    when word == '-e' then do
      value = self~getValueSegment(i)

      if \ self~validateAndSetOpt("testContainerExt"~upper, value, "-e") then j = -1
      else j+=1
    end

    when word == '-f' then do
      value = self~getValueSegment(i)

      if \ self~validateAndSetOpt("singleFile"~upper, value, "-f") then j = -1
      else j+=1
    end

    when word == '-F' then do
      j = self~addMultiWordOpt(i, "-F")
    end

    when word == '-I' then do
      j = self~addMultiWordOpt(i, '-I')
    end

    when word == '-l' then do
      value = self~getValueSegment(i)

      if \ self~validateAndSetOpt("logFile"~upper, value, "-l") then j = -1
      else j+=1
    end

    when word == '-L' then do
      testOpts~logFileAppend = .true
    end

    when word == '-n' then do
      testOpts~noTests = .true
    end

    -- The -o and -O (options file related) are processed already, so they are
    -- just ignored here.
    when word == '-o' then j += 1
    when word == '-O' then nop

    when word == '-p' then do
      j = self~addMultiWordOpt(i, "-p")
    end

    when word == '-R' then do
      value = self~getValueSegment(i)

      if \ self~validateAndSetOpt("testCaseRoot"~upper, value, "-R") then j = -1
      else j+=1
    end

    when word == '-s' then do
      testOpts~showProgress = .true
    end

    when word == '-S' then do
      testOpts~showTestCases = .true
    end

    when word == '-t' then do
      j = self~addMultiWordOpt(i, "-t")
    end

    when word == '-u' then do
      testOpts~suppressTestCaseTicks = .true
    end

    when word == '-U' then do
      testOpts~suppressAllTicks = .true
    end

    when word == '-V' then do
      value = self~getValueSegment(i)

      if \ self~validateAndSetOpt("verbosity"~upper, value, "-V") then j = -1
      else j+=1
    end

    when word == '-w' then do
      testOpts~waitAtCompletion = .true
    end

    when word == '-x' then do
      j = self~addMultiWordOpt(i, '-x')
    end

    when word == '-X' then do
      j = self~addMultiWordOpt(i, '-X')
    end

    otherwise do
      self~addErrorMsg( '"'cmdLine~word(i)'"' "is not a valid option")
      j = -1
    end
  end
  -- End select

  return j

::method getValueSegment private
  expose cmdLine tokenCount
  use strict arg switchPos

  start = switchPos + 1
  if start > tokenCount then return ""

  nextSwitch = self~nextOptionIndex(start)
  select
    when nextSwitch == start then ret = ""
    when nextSwitch == 0 then ret = cmdLine~subword(start)
    otherwise ret = cmdLine~subword(start, (nextSwitch - start))
  end
  -- End select

  return ret

::method nextOptionIndex private
  expose cmdLine tokenCount
  use strict arg start

  do i = start to tokenCount
    if cmdLine~word(i)~abbrev("-") then return i
  end
  return 0

::method notImplemented private
  use strict arg opt
  self~addErrorMsg("The" opt "argument option is not implemented yet.")
  return -1

::method addFiles private
  expose cmdLine tokenCount testOpts
  use strict arg i, opt

  displayName = opt

  if i == tokenCount | self~isOptionToken(i + 1) then do
    files = ""
    j = -1
  end
  else do
    j = i + 1
    nextOpt = self~nextOptionIndex(j)

    if nextOpt == 0 then do
      files = cmdLine~subWord(j)
      j = tokenCount
    end
    else do
      files = cmdLine~subWord(j, (nextOpt - j))
      j = nextOpt - 1
    end
  end

  if \ self~validateAndSetOpt(optName, types, displayName) then j = -1

  return j


::method addMultiWordOpt private
  expose cmdLine tokenCount testOpts
  use strict arg i, opt

  displayName = opt
  select
    when opt == '-d' then optName = 'DEFAULTTESTTYPES'
    when opt == '-F' then optName = 'FILELIST'
    when opt == '-I' then optName = 'TESTTYPEINCLUDES'
    when opt == '-p' then optName = 'FILESWITHPATTERN'
    when opt == '-t' then optName = 'TESTCASES'
    when opt == '-x' then optName = 'EXCLUDEFILELIST'
    when opt == '-X' then optName = 'TESTTYPEEXCLUDES'
  end
  -- End select

  if i == tokenCount | self~isOptionToken(i + 1) then do
    optWords = ""
    j = -1
  end
  else do
    j = i + 1
    nextOpt = self~nextOptionIndex(j)

    if nextOpt == 0 then do
      optWords = cmdLine~subWord(j)
      j = tokenCount
    end
    else do
      optWords = cmdLine~subWord(j, (nextOpt - j))
      j = nextOpt - 1
    end
  end

  if \ self~validateAndSetOpt(optName, optWords, displayName) then j = -1

  return j

::method addOption private
  expose cmdLine tokenCount testOpts
  use strict arg i

  token = cmdLine~subword(i, 1)
  if token~pos("=") == 0 then do
      self~addErrorMsg("The -D option must be in the following format:")
      self~addErrorMsg("  -Dname=value")
      self~addErrorMsg(" " token "is not valid.")
      return -1
  end

  nextOpt = self~nextOptionIndex(i + 1)

  if nextOpt == 0 then do
    define = cmdLine~subWord(i)
    i = tokenCount
  end
  else do
    define = cmdLine~subWord(i, (nextOpt - i))
    i = nextOpt - 1
  end

  parse var define "-D" name "=" value
  if \ self~validateAndSetOpt(name~upper, value) then return -1

  return i

::method validateAndSetOpt private
  expose testOpts optsTable
  use strict arg name, value, displayName = (arg(1))

  optType = optsTable[name]

  -- First deal with specific option keywords that require special handling.
  -- Then deal with option keywords that have a generic handling.  Everything
  -- else is user defined options where the value could be whatever the user
  -- wants.
  select
    when name == 'ALLTESTTYPES' then do
      tmpVal = value
      if value == 'true' then value = 1
      else if value == 'false' then value = 0

      if \ isBoolean(value) then do
        self~addErrorMsg("The value for the" displayName "option must be true or false, found:" tmpVal)
        return .false
      end

      testOpts~allTestTypes = value
      if testOpts~allTestTypes then testOpts~defaultTestTypes = .ooTestTypes~all
    end

    -- If the file name ends in the test container extension, we treat it as an
    -- absolute path name, otherwise it is treated as a file name.
    when name == 'SINGLEFILE' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by a file name.")
        return .false
      end

      if value~words > 1 then do
        self~addErrorMsg("The" displayName "option must be followed by a single file name.")
        return .false
      end

      if value~right(self~TEST_CONTAINER_EXT~length) == self~TEST_CONTAINER_EXT then do
        testOpts~singleFile = value
        return .true
      end

      if \ self~checkFileName(value) then do
        self~addErrorMsgAtTop("The" displayName "option must be followed by a valid file name.")
        return .false
      end

      if testOpts~fileList == .nil then testOpts~fileList = .set~new
      testOpts~fileList~put(value)
      return .true
    end

    when name == 'FILELIST' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by at least 1 file name.")
        return .false
      end

      -- Don't uppercase words in set.
      files = makeSetOfWords(value, .false)
      if testOpts~fileList == .nil then testOpts~fileList = .set~new
      do f over files
        if \ self~checkFileName(f) then do
          self~addErrorMsgAtTop("The" displayName "option only accepts valid file names that do not require quoting.")
          return .false
        end
        testOpts~fileList~put(f)
      end

      return .true
    end

    when name == 'EXCLUDEFILELIST' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by at least 1 file name.")
        return .false
      end

      -- Don't uppercase words in set.
      files = makeSetOfWords(value, .false)
      if testOpts~excludeFileList == .nil then testOpts~excludeFileList = .set~new
      do f over files
        if \ self~checkFileName(f) then do
          self~addErrorMsgAtTop("The" displayName "option only accepts valid file names that do not require quoting.")
          return .false
        end
        testOpts~excludeFileList~put(f)
      end

      return .true
    end

    when name == 'FILESWITHPATTERN' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by at least 1 file pattern.")
        return .false
      end

      patterns = makeSetOfWords(value)
      if testOpts~filesWithPattern == .nil then testOpts~filesWithPattern = .set~new
      do p over patterns
        if \ self~checkPattern(p) then do
          self~addErrorMsgAtTop("The" displayName "option only accepts valid patterns.")
          return .false
        end
        testOpts~filesWithPattern~put(p)
      end

      return .true
    end

    when name == 'LOGFILE' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by a file name.")
        return .false
      end

      if value~words > 1 then do
        self~addErrorMsg("The" displayName "option must be followed by a single file name.")
        return .false
      end

      if \ self~checkFileName(value) then do
        self~addErrorMsgAtTop("The" displayName "option must be followed by a valid file name.")
        return .false
      end

      testOpts~logFile = .File~new(value)~absolutePath
      return .true
    end

    when name == 'TESTCASES' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by at least 1 test case name.")
        return .false
      end

      tests = makeSetOfWords(value)

      do t over tests
        if \ t~abbrev("TEST") then do
          self~addErrorMsg("The" displayName "option requires test case method names.")
          self~addErrorMsg("  All test case method names start with 'test'; found" t)
          return .false
        end
      end
      testOpts~testCases = tests
      return .true
    end

    when name == 'TESTCASEROOT' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by a directory name.")
        return .false
      end

      if value~words > 1 then do
        self~addErrorMsg("The" displayName "option must be followed by a single directory name.")
        return .false
      end

      if value~right(1) \== self~SL then value = value || self~SL
      testOpts~testCaseRoot = value
    end

    when name == 'VERBOSITY' then do
      if value == "" then do
        self~addErrorMsg("The" displayName "option must be followed by the verbosity level.")
        return .false
      end

      if value~words > 1 then do
        self~addErrorMsg("The" displayName "option must be followed by only 1 verbosity level.")
        return .false
      end

      if \ isWholeRange(value, self~MIN_VERBOSITY, self~MAX_VERBOSITY) then do
        self~addErrorMsg("The" displayName "option must be followed by a valid verbosity level; found" value)
        self~addErrorMsg("  Valid levels are in the range of" self~MIN_VERBOSITY "to" self~MAX_VERBOSITY)
        return .false
      end

      testOpts~verbosity = value
    end

    when optType == 'testtypes' then do
      if value = "" then do
        self~addErrorMsg("The" displayName "option must be followed by at least 1 test type, or the word all.")
        return .false
      end

      testTypes = makeSetOfWords(value)
      tmpSet = .set~new

      do t over testTypes
        if t~caselessCompare('all') == 0 then do
          tmpSet = .ooTestTypes~all
          leave
        end

        testType = .ooTestTypes~getTestForName(t)
        if testType == .nil then do
          self~addErrorMsg("The" displayName "option must be followed by valid test types")
          self~addErrorMsg(" " t "is not a valid test type.")
          self~addErrorMsg("  Valid types are:" .ooTestTypes~allNames)
          self~addErrorMsg("  In addition, the keyword 'all' can be used to indicate every test type.")
          return .false
        end

        tmpSet~put(testType)
      end
      testOpts[name] = tmpSet
    end

    when optType == 'boolean' then do
      if value == 'true' then value = 1
      else if value == 'false' then value = 0

      if \ isBoolean(value) then do
        self~addErrorMsg("The value for the" displayName "option must be true or false, found:" value)
        return .false
      end
      testOpts[name] = value
    end

    when optType == 'notimplemented' then do
      self~notImplemented(displayName)
      return .false
    end

    when optType == 'invalid' then do
        self~addErrorMsg("The" displayName "option is not valid in an options file.")
        return .false
    end

    otherwise do
      testOpts[name] = value
    end
  end
  -- End select

  return .true


::method isOptionToken private
  expose cmdLine tokenCount
  use strict arg i

  if i > tokenCount then return .false
  else return cmdLine~word(i)~abbrev("-")


/** addErrorMsg()
 *
 * Adds message(s) to the end of the error messages list.
 *
 * @param msg  The message(s) to add.  This can be a single string or a list of
 *             message strings
 */
::method addErrorMsg private
  expose errMsg
  use strict arg msg
  if msg~isA(.list) then do
    do line over msg
      errMsg~insert(line)
    end
  end
  else do
    errMsg~insert(msg)
  end


/** addErrorMsgAtTop()
 *
 * Adds message(s) to the top of the error messages list.
 *
 * @param msg  The message(s) to add.  This can be a single string or a list of
 *             message strings
 */
::method addErrorMsgAtTop private
  expose errMsg
  use strict arg msg
  if msg~isA(.list) then do
    if msg~isEmpty then do
      errMsg~insert("", .nil)
      return
    end

    index = msg~first
    k = errMsg~insert(msg~at(index), .nil)

    index = msg~next(index)
    do while index \== .nil
      k = errMsg~insert(msg~at(index), k)
      index = msg~next(index)
    end
  end
  else do
    errMsg~insert(msg, .nil)
  end


/** checkFormat()
 * Checks that the first command line token starts with "-", or if not, that it
 * is a simple command line with only one token on it.
 *
 * Returns true if command line parsing is done, otherwise false.  Parsing would
 * be done if there is an error, or if there is only a single token on the
 * command line.
 *
 * The single token is treated as a either a complete file specification,  or a
 * file pattern.  If the token ends with the default container extension,  it is
 * considered to be a complete file name, otherwise it is considered a pattern.
 *
 * So, if it is a pattern, for instance, 'char' would execute all test groups
 * with 'char' in their name.  ooRexx\base would execute all test groups in the
 * ooRexx\base directory, but not recurse.  Etc.. Look at the pattern matching
 * doc to see how this works.
 *
 * To execute a single specific test group file, the -f option can also be used.
 */
::method checkFormat private
  expose cmdLine tokenCount testOpts

  if cmdLine~left(1) == "-" then return .false

  if tokenCount > 1 then do
    self~addErrorMsg("Command line arguments must start with '-'")
    self~needsHelp = .true
  end
  else do
    if cmdLine~right(self~TEST_CONTAINER_EXT~length) == self~TEST_CONTAINER_EXT then testOpts~singleFile = cmdLine
    else testOpts~filesWithPattern = cmdLine
  end

  return .true

::method setAllDefaults private
  expose cmdLine originalCommandLine testOpts optsTable

  originalCommandLine = cmdLine~copy

  self~version = self~TESTOOREXX_REX_VERSION
  self~needsHelp = .false
  self~doLongHelp = .false
  self~doSubjectHelp = .false
  self~errMsg = .list~new
  self~doVersionOnly = .false

  if self~hasHelpArg then return

  -- Set all the known, defined, test options.  In the below, some indexes are
  -- purposively set to .nil even though that is not necessary.  It is done so
  -- that the list of valid option words is in one place.
  testOpts~version = self~version

  testOpts~allTestTypes = .false
  testOpts~debug = .false
  testOpts~defaultTestTypes = .ooTestTypes~defaultTestSet
  testOpts~excludeFileList = .nil
  testOpts~fileList = .nil
  testOpts~filesWithPattern = .nil
  testOpts~logFile = .nil
  testOpts~logFileAppend = .false
  testOpts~noOptionsFile = .false
  testOpts~noTests = .false
  testOpts~optionsFile = .nil
  testOpts~printOptions = .false
  testOpts~showProgress = .false
  testOpts~showTestcases = .false
  testOpts~singleFile = .nil
  testOpts~suppressAllTicks = .false
  testOpts~suppressTestcaseTicks = .false
  testOpts~testCaseRoot= self~TEST_ROOT || self~SL
  testOpts~testCases = .nil
  testOpts~testContainerExt = self~TEST_CONTAINER_EXT
  testOpts~testTypeExcludes = .nil
  testOpts~testTypeIncludes = .nil
  testOpts~verbosity = self~DEFAULT_VERBOSITY
  testOpts~waitAtCompletion = .false

  optsTable = .Directory~new
  optsTable~allTestTypes          = "boolean"
  optsTable~debug                 = "boolean"
  optsTable~defaultTestTypes      = "testtypes"
  optsTable~excludeFileList       = "filelist"
  optsTable~fileList              = "filelist"
  optsTable~filesWithPattern      = "fileswithpattern"
  optsTable~logFile               = "string"
  optsTable~logFileAppend         = "boolean"
  optsTable~noOptionsFile         = "invalid"
  optsTable~noTests               = "boolean"
  optsTable~optionsFile           = "invalid"
  optsTable~printOptions          = "boolean"
  optsTable~showProgress          = "boolean"
  optsTable~showTestcases         = "boolean"
  optsTable~singleFile            = "string"
  optsTable~suppressAllTicks      = "boolean"
  optsTable~suppressTestcaseTicks = "boolean"
  optsTable~testCaseRoot          = "string"
  optsTable~testCases             = "testcases"
  optsTable~testContainerExt      = "string"
  optsTable~testTypeIncludes      = "testtypes"
  optsTable~testTypeExcludes      = "testtypes"
  optsTable~verbosity             = "verbosity"
  optsTable~waitAtCompletion      = "boolean"

  optsTable~h    = "invalid"
  optsTable~help = "invalid"
  optsTable~v    = "invalid"


::method hasHelpArg private
  expose cmdLine helpSubject

  if cmdLine~word(1) == 'help' then do
    helpSubject = cmdLine~word(2)
    self~doSubjectHelp = .true
    self~needsHelp = .true
    return .true
  end

  tokens = makeSetOfWords(cmdLine)
  helpTokens = .set~of("-H", "/H", "--H", "--HELP", "/?", "?", "-?", "--?")
  intersect = helpTokens~intersection(tokens)

  if intersect~isEmpty then return .false

  if intersect~hasIndex("--HELP") then self~doLongHelp = .true
  self~needsHelp = .true
  return .true

::method doShortHelp private
  say "usage: testOORexx [OPTIONS]"
  say "Try 'testOORexx --help' for more information."

::method longHelp private
  say 'Test the ooRexx interpreter using the automated ooTest framework.'
  say "usage: 1.  testOORexx"
  say "       2.  testOORexx fileName"
  say "       3.  testOORexx [OPTIONS]"
  say '       4.  testOORexx help [subject]'
  say
  say '  1. With no options the automated test suite is executed using the default'
  say '     set of test types, the default verbosity, and the default formatter.'
  say
  say '  2. The single test group specified by "fileName" is executed.'
  say
  say '  3. The automated test suite is executed using the specified options.'
  say
  say '  4. Show detailed help on "subject"  Use "help topic" to list valid subjects'
  say
  say '  Options must start with "-", the only exception is the --help option.  Spaces'
  say '  are not tolerated in either file names or directory names.'
  say
  say '  The long name options are specified using the -D (define option) format.  I.e.,'
  say '  the "testContainerExt" option is specified as: -DtestContainerExt=ext.'
  say
  say '  All command line options, except the help and options file options, are valid'
  say '  in the options file, but you must use the long name format.  I.e., the'
  say '  -Dverbosity=NUM option could be: verbosity=5 in the options file.'
  say
  say '  Options below shown as: someOpt=bool are true / false, with the default as'
  say '  false.  The value can be specified as either 1 / 0 or the words true / false.'
  say
  say 'Valid options:'
  say ' Help related:'
  say '  -h                   Show short help'
  say '  --help               Show long help (this help)'
  say '  -v                   Show version and quit'
  say
  say ' Generic option:'
  say '  -D    Define option.  Format must be: -Dname=value'
  say
  say ' Test selection:'
  say '  -a  -DallTestTypes=bool           Include all test types'
  say '  -d  -DdefaultTestTypes=D1 D2 ...  change default test type set to D1 D2 ...'
  say '  -e  -DtestContainerExt=EXT        change default test container ext to EXT'
  say '  -f  -DsingleFile=NAME             Execute the single NAME test group'
  say '  -F  -DfileList=N1 N2 ...          Execute the N1 N2 ... test groups'
  say '  -I, -DtestTypeIncludes=T1 T2 ...  Include test types T1 T2 ... keyword "all"'
  say '                                    indicates all test types'
  say '  -n  -DnoTests=bool                No tests to execute (deliberately)'
  say '  -o  -DoptionsFile=FILE            Use FILE as options file, not default file'
  say '  -O  -DnoOptionsFile=bool          Do not use any options file'
  say '  -p  -DfilesWithPattern=PA         Execute test groups matching PA'
  say '  -R, -DtestCaseRoot=DIR            DIR is root of search tree'
  say '  -x  -DexcludeFileList=N1 N2 ...   Exclude the N1 N2 ... test groups'
  say '  -X  -DtestTypeExcludes=X1 X1 ...  Exclude test types X1 X2 ... keyword "all"'
  say '                                    indicates all test types'
  say
  say ' Output control:'
  say '  -l  -DlogFile=FILE                Put test results in log file FILE'
  say '  -L  -DlogFileAppend=bool          Append test results to log file'
  say '  -s  -DshowProgress=bool           Show test group progress'
  say '  -S  -DshowTestcases=bool          Show test case progress'
  say '  -u  -DsuppressTestcaseTicks=bool  Do not show ticks during test execution'
  say '  -U  -DsuppressAllTicks=bool       Do not show any ticks'
  say '  -V, -Dverbosity=NUM               Set vebosity to NUM'
  say '  -w, -DwaitAtCompletion=bool       At test end, wait for user to hit enter'
  say

  return self~TEST_HELP_RC


::method subjectHelp
  expose helpSubject

  if helpSubject == "" then do
    say 'A "subject" keyword must follow the "help" command'
    say 'Use "help topic" to list valid subjects'
    say
    self~doShortHelp
    return self~TEST_BADARGS_RC
  end

  helpSubject = helpSubject~lower
  ret = self~TEST_HELP_RC

  select
    when helpSubject == 'topic' then do
      say 'Detailed help subjects (case insignificant) are:'
      say '  testTypes'
    end

    when helpSubject == 'testtypes' then do
      say 'All test types:'
      say ' ' .ooTestTypes~allNames
      say
      say 'Default test type set:'
      say ' ' .ooTestTypes~defaultTestSet('String')
      say
      say 'Default exclued test type set:'
      xSet = .ooTestTypes~all~difference(.ooTestTypes~defaultTestSet)
      say .ooTestTypes~namesForTests(xSet)
    end

    otherwise do
      say helpSubject 'is not a recognized subject keyword.'
      say 'Use "help topic" to list valid subjects'
      say
      self~doShortHelp
      ret = self~TEST_BADARGS_RC
    end
  end
  -- End select

  return ret

::routine printDebug
  use strict arg containers, testResult, cl

  prefix = "====== Debug output"
  say prefix '='~copies(80 - prefix~length)
  say

  if containers \== .nil then do
    say 'Test groups collected:'
    do c over containers
      say c~pathName
    end
    say
  end

  return printOptions(.false)

::routine printOptions
  use strict arg doHeader

  width = getLongestOpt() + 2
  opts = .array~new
  itr = .testOpts~supplier
  do while itr~available
    opts~append(" " itr~index~left(width) || "=  " || maybeReturnBool(itr~item))
    itr~next
  end
  opts~sort

  if doHeader then do
    prefix = "====== Debug output"
    say prefix '='~copies(80 - prefix~length)
    say
  end

  say "Test options (.testOpts) in effect:"
  do l over opts
    say l
    parse var l name '=' value
    if value~strip == 'a Set' then j = printMultiWordOpt(name~strip)
  end
  say

  return 0

::routine printMultiWordOpt
  use strict arg optName

  s = .testOpts~entry(optName)
  prefix = "    "

  testTypeOpt = (optName == 'DEFAULTTESTTYPES' | optName == 'TESTTYPEEXCLUDES' | optName == 'TESTTYPEINCLUDES' | optName == 'TESTTYPES')

  out = prefix
  currentLen = out~length

  do word over s
    if testTypeOpt then token = ' ' || .ooTestTypes~nameForTest(word)
    else token = ' ' word

    if currentLen + token~length > 80 then do
      out ||= .endOfLine || prefix
      currentLen = prefix~length
    end

    out ||= token
    currentLen += token~length
  end
  say out
  say
  return 0

::routine getLongestOpt

  itr = .testOpts~supplier
  len = 0
  do while itr~available
    l = itr~index~length
    if l > len then len = l
    itr~next
  end
  return len

::routine maybeReturnBool
  use strict arg w
  select
    when w == 1 then return '.true'
    when w == 0 then return '.false'
    otherwise return w
  end


::options novalue error
