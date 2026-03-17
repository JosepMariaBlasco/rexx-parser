/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2007-2025 Rexx Language Association. All rights reserved.    */
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

/** ooTest.frm
 * An extension to the ooRexxUnit framework providing function and features
 * specific to testing the ooRexx interpreter and its distribution package.
 *
 * Although others may find this framework useful, its primary design goal is to
 * fit the needs of the ooRexx development team.  Classes in this framework are
 * not guaranteed to be backwards compatible with previous versions of this
 * framework as the ooRexx committers may decide to break compatibility to
 * further the goals of the project.
 */

if \ .local~hasEntry('OOTEST_FRAMEWORK_VERSION') then do
  .local~ooTest_Framework_version = 1.0.1_4.0.0

  -- Replace the default test result class in the environment with the ooRexx
  -- project's default class.
  .local~ooRexxUnit.default.TestResult.Class = .ooTestResult

  -- Capture the ooTest framework directory and ensure it is in the path.
  parse source . . fileSpec
  .local~ooTest.dir = fileSpec~left(fileSpec~caseLessPos("ooTest.frm") - 2 )
  call addToPath .ooTest.dir

  -- If not already in the environment, save the current working directory.
  if \ .local~hasEntry("ooTest.originalWorkingDir"~upper) then
    .local~ooTest.originalWorkingDir = directory()

  -- Set up the external library path.  Although this is a bit of a misnomer,
  -- the external directory may also have regular executables in it.
  call setExternalLibDir

end
-- End of entry point.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Directives, Classes, or Routines.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::requires "OOREXXUNIT.CLS"
::requires "rxregexp.cls"

::routine makeSetOfWords public
  use strict arg wordCollection, upper = .true

  if \ isBoolean(upper) then upper = .true

  s = .set~new
  select
    when wordCollection~isA(.string) then do w over wordCollection~space(1)~makearray(" ")
      if upper then s~put(w~translate)
      else s~put(w)
    end

    when wordCollection~isA(.collection) then do w over wordCollection
      if \ w~isA(.string) then return .nil
      if w~words <> 1 then return .nil
      if upper then s~put(w~translate)
      else s~put(w)
    end

    otherwise return .nil
  end
  -- End select

return s
-- End makeSetOfWords()

::routine makeArrayOfWords public
  use strict arg wordCollection, upper = .true

  if \ upper~isA(.string) then upper = .true
  if \ upper~dataType('O') then upper = .true

  a = .array~new
  select
    when wordCollection~isA(.string) then do w over wordCollection~space(1)~makearray(" ")
      if upper then a~append(w~translate)
      else a~append(w)
    end

    when wordCollection~isA(.collection) then do w over wordCollection~allItems
      if \ w~isA(.string) then return .nil
      if upper then a~append(w~translate)
      else a~append(w)
    end

    otherwise return .nil
  end
  -- End select

return a
-- End makeArrayOfWords()

::routine replaceEnvValue public
  use strict arg name, val
return value(name, val, 'ENVIRONMENT')

::routine getEnvValue public
  use strict arg name
return value(name, , 'ENVIRONMENT')

::routine setExternalLibDir

  os = .ooRexxUnit.osName
  sl = .ooRexxUnit.directory.separator
  sep = .ooRexxUnit.path.separator

  libDir = .ooTest.dir || sl || 'bin' || sl || os

  -- if libdir doesn't exist or is empty, don't bother adding it to PATH, LIBPATH, etc.
  libdirFiles = .File~new(libdir)~list
  if .nil == libdirFiles then
    return
  if libdirFiles~items = 0 then
    return

  -- libDir may / will also contain executables.  So add it to the path for all
  -- OSes.
  call addToPath libDir

  select
    when os == "WINDOWS" then do
      -- Don't currently need to do anything else here.
      nop
    end
    when os == 'AIX' then do
      curLibPath = getEnvValue("LIBPATH")
      libDir = libDir || sep || curLibPath
      call replaceEnvValue "LIBPATH", libDir
    end
    when os == 'LINUX' | os == 'DARWIN' then do
      curLDPath = getEnvValue("LD_LIBRARY_PATH")
      libDir = libDir || sep || curLDPath
      call replaceEnvValue "LD_LIBRARY_PATH", libDir
    end
    otherwise do
      say 'ooTest.frm::routine::setExternalDir() line:' .line
      say '  Need code for operating system:' os
    end
  end
  -- End select

return

/** class:  TestContainer
 * Defines an interface for a test container.  Objects containing tests that
 * implement the TestContainer interface can be 'found' by the ooTestFinder
 * class.
 */
::class 'TestContainer' public mixinclass Object

/** isEmpty() Returns true or false.  True if the container has no tests,
 * otherwise false.
 */
::method isEmpty abstract

/** hasTests() Returns true or false. True if the container contains some
 * executable tests, otherwise false.  Note that containing executable tests is
 * not the same as simply containing tests.
 */
::method hasTests abstract

/** hasTestTypes() Returns true or false.  When passed an object as arg 1, the
 * test container determines if it does or does not have tests under the
 * constraints of the object.
 */
::method hasTestTypes abstract

/** testCount() Returns the number of tests the container has.
 */
::method testCount abstract

/** getNoTestsReason() Returns a descriptive string, presumably explaining why
 * the container has no executable tests.
 */
::method getNoTestsReason abstract


/** class:  ooTestCollectingParameter
  *   Defines an interface extended from TestResult for a collecting parameter
  *   used specifically for testing the ooRexx intepreter and its distribution
  *   packages.
  * DFX TODO finish up doc here.
  */
::class 'ooTestCollectingParameter' public subclass TestResult
::method addNotification    abstract
::method getNotifications   abstract
::method notificationCount  abstract
::method addException       abstract
::method getExceptions      abstract
::method exceptionCount     abstract
::method addEvent           abstract
::method getEvents          abstract
::method eventCount         abstract


/* class: ooTestConstants- - - - - - - - - - - - - - - - - - - - - - - - - - -*\
    A class containing constants used in testing ooRexx.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ooTestConstants' public mixinclass Object

  ::constant TEST_ROOT            "ooRexx"
  ::constant TEST_CONTAINER_EXT   ".testGroup"
  ::constant DEFAULT_OPTIONS_FILE "options.ooTest"

  ::constant TESTOOREXX_REX_VERSION        "1.1.0"

  ::constant SUCCESS_RC                         0
  ::constant TEST_SUCCESS_RC                    0
  ::constant TEST_HELP_RC                       1
  ::constant TEST_FAILURES_RC                   2
  ::constant TEST_ERRORS_RC                     3
  ::constant TEST_NO_TESTS_RC                   4
  ::constant TEST_BADARGS_RC                    5
  ::constant FAILED_PACKAGE_LOAD_RC             6
  ::constant BUILD_FAILED_RC                    7
  ::constant UNEXPECTED_ERR_RC                  8

  -- SL (back SLash or forward SLash) abbreviation for the directory separator.
  ::method SL  class; return .ooRexxUnit.directory.separator
  ::method SL;        return .ooRexxUnit.directory.separator

/* class: ooTestTypes- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
    A class containing the constants for the test types supported by the ooTest
    framework and methods to work with those constants..
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ooTestTypes' public mixinclass Object

  ::constant MIN_TEST_TYPE                1

  ::constant UNIT_TEST                    1

  ::constant UNIT_LONG_TEST               2
  ::constant SAMPLE_TEST                  3
  ::constant GUI_TEST                     4
  ::constant GUI_SAMPLE_TEST              5
  ::constant OLE_TEST                     6
  ::constant DOC_EXAMPLE_TEST             7

  -- A test type that makes noise.  I frequently need to run the test suite in
  -- an environment where I need these types of test cases to be skipped.  This
  -- is a convenience for myself (Mark Miesfeld.)
  ::constant DOC_EXAMPLE_NOISE_TEST       8

  -- A test type for the ooTest framework examples.
  ::constant FRAMEWORK_EXAMPLE_TEST       9

  -- A test type for the ooRexx APIs.
  ::constant NATIVE_API_TEST             10

  -- A test type involving TCPIP, smtp, ftp, for example, where the test might
  -- need some special set up.  Like a ftp server, mail server, etc..
  ::constant TCPIP_TEST                  11

  -- A test type that can only work with an English language version of Windows.
  ::constant ENGLISH_ONLY_TEST           12

  ::constant MAX_TEST_TYPE               12

  -- The default test type is the unit test (see above for value.)
  ::constant DEFAULT_TEST_TYPE            1


  /** defaultTestSet()
   * Returns the set of tests that are always run.  Any test type in this set
   * will execute unless the tester specifically eXcludes it.
   *
   * @param  format  Specifies the format of the returned set.  Can be either
   *                 Constant or String, the default is Constant.  Constant
   *                 returns a set containing the numeric constants of the
   *                 default tests, String returns a set of the names of the
   *                 default tests.  Only the first letter is needed and case
   *                 is not significant.
   *
   * @return A set of the tests that are always executed when the test suite is
   *         run.
   */
  ::method defaultTestSet class
    use strict arg format = 'C'

    tests = .set~of(self~UNIT_TEST, self~UNIT_LONG_TEST, self~SAMPLE_TEST, self~GUI_TEST, self~GUI_SAMPLE_TEST, -
                    self~OLE_TEST, self~DOC_EXAMPLE_TEST, self~NATIVE_API_TEST, self~ENGLISH_ONLY_TEST)

    select
      when format~left(1)~upper == 'C' then return tests
      when format~left(1)~upper == 'S' then return self~namesForTests(tests)
      otherwise do
        raise syntax 88.916 array ("1 'format'", "Constant or String", format)
      end
    end

  ::method defaultTestSet
    forward class (self~class)

  /** all()
   * Returns a set of all the test types possible.
   */
  ::method all class
    all = .set~new
    do i = self~MIN_TEST_TYPE to self~MAX_TEST_TYPE
      all~put(i)
    end
    return all

  ::method all
    return self~class~all

  /** allNames()
   * Returns a string of all the test type names separated by blanks.
   */
  ::method allNames class
    expose names

    if names~UNIT == .nil then self~populate
    return self~namesString

  ::method allNames
    return self~class~allNames

  /** getTestForName()
   * Returns the numeric test type constant for the specified name, or .nil if
   * there is no such test type.
   */
  ::method getTestForName class
    expose names
    use strict arg name

    if names~UNIT == .nil then self~populate
    return names~entry(name~upper)

  ::method getTestForName
    use strict arg name
    return self~class(name)

  /** nameForTest()
   * Returns the string name corresponding to a numeric test type constant, or
   * .nil if there is no such test type.
   */
  ::method nameForTest class
    expose names
    use strict arg test

    if names~UNIT == .nil then self~populate
    return names~entry(test)

  /** namesForTests()
   * Returns a string containing the test names for all the corresponding
   * numeric test type constants in a collection.  Returns .nil if: one of the
   * items in the collection is not a test type, the argument is not a
   * collection.
   */
  ::method namesForTests class
    expose names
    use strict arg tests

    if \ tests~isA(.Collection) then return .nil

    if names~UNIT == .nil then self~populate

    names__ = ""
    do t over tests
      name = names~entry(t)
      if name == .nil then return .nil
      names__ = names__ name
    end

    return names__

  ::method namesForTests
    use strict arg tests
    return self~class~namesForTests(tests)

  ::attribute names get class
  ::attribute names set class private
  ::attribute namesString get class
  ::attribute namesString set class private

  ::method init class
    expose names namesString
    names = .directory~new
    namesString = ""

  ::method populate class private
    expose names namesString
    itr = self~methods(.nil)
    do while itr~available
      name = itr~index
      if name~right(5) == "_TEST" then do
        name = name~left(name~length - 5)
        number = self~send(itr~index)

        n = name~lower(2)
        names~setEntry(name, number)
        names~setEntry(number, n)
        namesString = namesString n
      end
      itr~next
    end

-- End of class ooTestTypes


/* class: ooTestTypes- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
    A class containing the constants for the test types supported by the ooTest
    framework.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

/* class: ooTestCase - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    ooTestCases are used to test the ooRexx interpreter package.  An ooTestCase
    class is a test class where methods of the class define individual test
    cases.  In order to make it easy to construct automated tests with large
    numbers of test cases, a convention is followed:

    Each method of an ooTestCase class that starts with 'test' is considered
    an individual test case.

    Each method of an ooTestCase class that starts with 'data' is considered
    a data collection that can be retrieved as an array inside any test case

    Each ooTestCase has a class attribute defining the test type of the
    individual test cases the class contains.  (This list is still being
    defined)

    UNIT SAMPLE GUI_SAMPLE DOC_EXAMPLE STRESS

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ooTestCase' public subclass TestCase inherit ooTestTypes

-- The ooTestType attribute is the type of test cases contained in this test
-- case class.  The default type is set here.  Test case writers need to
-- over-ride the class init() to provide the the test case type when the
-- default is not appropriate.
::attribute ooTestType get class
::attribute ooTestType set class private

::method init class
  forward class (super) continue

  -- Use the ooTestResult as the default test result.
  self~defaultTestResultClass = .ooTestResult

  -- Set the type of test cases this class contains to the default.
  self~ooTestType = .ooTestTypes~DEFAULT_TEST_TYPE

-- End init( ) class

-- End of class: ooTestCase


/* class: ooTestSuite- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ooTestSuite' public subclass TestSuite

  ::attribute showProgress get
  ::attribute showProgress set
    expose showProgress
    use strict arg show

    if \ isBoolean(show) then
      raise syntax 88.900 array ("showProgess must be set to true or false; found:" show)
    showProgress = show

  ::attribute beVerbose get
  ::attribute beVerbose set
    expose beVerbose
    use strict arg verbose

    if \ isBoolean(verbose) then
      raise syntax 88.900 array ("beVerbose must be set to true or false; found:" verbose)
    beVerbose = verbose

  ::method init
    forward class (super) continue

    self~showProgress = .false
    self~beVerbose = .false
  -- End init( )

  /** execute()
   * Executes the tests in this test suite.  Over-rides the superclass method.
   *
   * @param testResult    OPTIONAL    (ooTestCollectingParameter)
   *   The CollectingParameter object (a test result in plain words) to use for
   *   the execution of the tests.  The default ooTest framework test result is
   *   used if this argument is omitted.  (Which is most likely .ooTestResult)
   *
   * @return  Returns the test result object used for the execution of the
   *          tests.
   */
  ::method execute
    use arg testResult = (self~createResult), verbose = (self~beVerbose)

    if \ isBoolean(verbose) then
      raise syntax 88.916 array ("2 'verbose'", "true or false", verbose)

    if verbose then
      say "Executing" self~getName "with" self~countTestCases "test cases"

    tests = self~testQueue

    -- If we are already verbose, we don't need to show progress.
    show = (self~showProgress & \verbose)

    -- Mark the test starting and invoke the test suite setUp method.
    testResult~startTest(self)
    self~setUp(testResult)

    do test over tests while \ testResult~shouldStop
       if show then say "Executing" pathCompact(test~definedInFile, 69)
       test~execute(testResult, verbose)
    end

    -- Invoke the the test suite tearDown method and mark the test has ended.
    self~tearDown
    testResult~endTest(self)

    return testResult
  -- End run()

-- End of class: ooTestSuite


/* class: ConsoleFormatter - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    A console formatter formats the information from a test result and prints
    it out to the console.

    The format of the information is designed to be "console-friendly."  The
    information is broken up into lines, with an attempt made to keep all lines
    no longer than 80 characers wide.

    ConsoleFormatter works with an ooTestResult and therefore has more
    infomation available to it than SimpleConsoleFormatter.  This allows for
    more comprehensive reporting.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ConsoleFormatter' public subclass SimpleConsoleFormatter inherit NotificationTypes

  ::attribute rexxVersion get
  ::attribute rexxVersion set private
  ::attribute unitVersion get
  ::attribute unitVersion set private
  ::attribute ooTestVersion get
  ::attribute ooTestVersion set private

  ::attribute failTable private
  ::attribute notifications private

  /** init()
   *
   */
  ::method init
    use strict arg testResult, title = ""
    forward class (super) continue

    -- We need an ooTestResult.
    if \ isSubClassOf(testResult~class, "ooTestResult") then
       raise syntax 88.914 array ("1 'testResult'", "ooTestResult")
    self~testResult = testResult

    parse version self~rexxVersion
    self~unitVersion = .ooRexxUnit.version
    self~ooTestVersion = .ooTest_Framework_version

    self~failTable = .nil
    self~notifications = .nil

  /** printBrief()
   * The least possible print out.
   */
  ::method printBrief private
    use arg tResult, fails

    say
    say ' '~copies(20) 'ooTest'
    say '  Tests:   ' tResult~runCount
    say '  Failures:' fails['newCount']
    say '  Errors:  ' tResult~errorCount + tResult~exceptionCount
    say

  /** print()
   *
   * Prints the data collected by this test result in a "console-friendly"
   * manner.
   *
   * @param title    OPTIONAL    (String)
   *   Adds a title to the output.  Resets the default title for this
   *   formatter to that specified.
   *
   * @param level   OPTIONAL    (Whole Number)
   *   Sets the verbosity level of the print out.  Resets the default verbosity
   *   for this fromatter.
   */
  ::method print
    use arg title = (self~title), level = (self~getVerbosity)

    if arg(1, 'E') then self~setTitle(title)
    if arg(2, 'E') then self~setVerbosity(level)

    tResult = self~testResult
    verbose = self~getVerbosity

    if self~failTable == .nil then self~failTable = tResult~getExtendedFailureInfo
    if self~notifications == .nil then self~notifications = tResult~getNotifications

    if verbose == 0 then do
      self~printBrief(tResult, self~failTable)
      return
    end

    if self~title<>"" then do
      say
      say self~title
      say
    end

    stats = self~calcStats
    self~printSummary(stats)

    if tResult~failureCount > 0 then do
      if verbose < 7 then do data over self~failTable['newQ']
        self~printFailureInfo(data)
      end
      else do data over tResult~failures
        self~printFailureInfo(data)
      end
    end

    if tResult~errorCount > 0 then do data over tResult~errors
      self~printErrorInfo(data)
    end

    if tResult~exceptionCount > 0 then do data over tResult~getExceptions
      data~print( , , verbose)
    end

    if verbose > 3 then self~printSkippedFiles

    if verbose > 5 then self~printMessages

    -- If a number of failure or error information lines are printed, re-display
    -- the summary statistics again so that the number of failures is obvious to
    -- the user.
    if stats~totalProblems > 3 | verbose > 3 then
      self~printSummary(stats)

    if tResult~eventCount <> 0 then do
      events = tResult~getEvents
      holder = .array~new
      do e over events
        select
          when e~id == .PhaseReport~AUTOMATED_TEST_PHASE then holder[1] = e
          when e~id == .PhaseReport~FILE_SEARCH_PHASE    then holder[2] = e
          when e~id == .PhaseReport~SUITE_BUILD_PHASE    then holder[3] = e
          when e~id == .PhaseReport~TEST_EXECUTION_PHASE then holder[4] = e
          otherwise nop
        end
        -- End select
      end

      if holder[2] \== .nil then say 'File search:       ' holder[2]~duration~string
      if holder[3] \== .nil then say 'Suite construction:' holder[3]~duration~string
      if holder[4] \== .nil then say 'Test execution:    ' holder[4]~duration~string
      if holder[1] \== .nil then say 'Total time:        ' holder[1]~duration~string

      if holder~items > 0 then say
    end

  -- End print()

  ::method printSummary
    use arg stats

    verbose = self~getVerbosity
    width = 19
    parse source osname .

    say "Interpreter:"~left(width) self~rexxVersion
--  say 'Addressing Mode:' .ooRexxUnit.architecture
    say "OS Name:"~left(width) osname

    versions = .Directory~new
    -- if SysVersion() result is unique, use it
    if \versions~hasItem(SysVersion()) then
      versions["SysVersion"] = SysVersion()
    -- if we've got SysWinVer() and its result is unique, use it
    if rxfuncquery("SysWinVer") = 0, \versions~hasItem(SysWinVer()) then
      versions["SysWinVer"] = SysWinVer()
    -- if we've got SysLinVer() and its result is unique, use it
    if rxfuncquery("SysLinVer") = 0, \versions~hasItem(SysLinVer()) then
      versions["SysLinVer"] = SysLinVer()
    do version over .Array~of("SysVersion", "SysWinVer", "SysLinVer")
      if versions~hasIndex(version) then
        say (version":")~left(width) versions[version]
    end

--  say "ooRexxUnit:     " self~unitVersion  '09'x || "ooTest:" self~ooTestVersion
    say
    say "Tests ran:"~left(width)  stats~tests
    say "Assertions:"~left(width) stats~asserts

    -- show known failure count starting with -V 3
    -- (known failing tests are only printed starting with -V 7)
    if verbose <= 2 then
      say "Failures:"~left(width) stats~newFails
    else do
      say "Failures:"~left(width) stats~newFails
      say "  (Known failures:)"~left(width) stats~knownFails
    end

    if verbose < 3 then say "Errors:"~left(width) stats~totalErrs
    else do
      say "Errors:"~left(width)     stats~errs
      say "Exceptions:"~left(width) stats~exceptions
    end

    if verbose < 3 then do
      say
      return
    end

    say "Skipped files:"~left(width) stats~skippedFiles

    if verbose < 4 then do
      say
      return
    end

    say "Messages:"~left(width) stats~messages
    say "Logs:"~left(width) stats~logs
    say


  /* Over-ride the super-class printFailuerInfo(), even though almost exactly
   * the same, because the super-class is used to print TestCase objects and
   * here we are printing ooTestCase objects.  ooTestCase objects have data not
   * avaiable to TestCase objects.
   */
  ::method printFailureInfo private
    use arg data

    say "[failure]" data~when
    say "  Test:  " data~testName
    say "  Class: " data~className
    say "  File:  " pathCompact(data~where, 70)
    say "  Line:  " data~line
    say "  Failed:" data~type
    say "    Expected:" data~expected
    say "    Actual:  " data~actual

    if data~msg \== "" then
      say "    Message: " data~msg
    say

  /* Over-ride the super-class method for the same reason as printFailureInfo().
   */
  ::method printErrorInfo private
    use arg data

    -- It is possible that the error happened in a file other than the test case
    -- file.  Most often the files are the same.
    different = (data~where~compareTo(data~conditionObject~program) <> 0)

    say "[error]" data~when
    say "  Test:  " data~testName
    say "  Class: " data~className
    say "  File:  " pathCompact(data~where, 70)
    say "  Event: " data~type "raised unexpectedly."
    if data~conditionObject~message \== .nil then
      say "    "data~conditionObject~message
    if different then
      say "    Program:" pathCompact(data~conditionObject~program, 60)
    say "    Line:   " data~line
    if data~conditionObject~traceBack~isA(.list) then do line over data~conditionObject~traceBack
      say line
    end
    say

  ::method calcStats private
    expose failTable notifications

    tResult = self~testResult
    stats = .directory~new

    stats~tests      = tResult~runCount
    stats~asserts    = tResult~assertCount
    stats~totalFails = failTable['totalCount']
    stats~newFails   = failTable['newCount']
    stats~knownFails = failTable['knownCount']
    stats~errs       = tResult~errorCount
    stats~exceptions = tResult~exceptionCount
    stats~totalErrs  = tResult~errorCount + tResult~exceptionCount

    stats~totalProblems = stats~totalFails + stats~totalErrs

    -- Brute force for now.
    skips = 0; msgs = 0; logs = 0
    do n over notifications
      select
        when n~type == self~SKIP_TYPE then skips += 1
        when n~type == self~TEXT_TYPE then msgs += 1
        when n~type == self~LOG_TYPE then logs += 1
        otherwise nop -- For now, please fix.
      end
      -- End select
    end
    stats~skippedFiles = skips
    stats~messages = msgs
    stats~logs = logs

  return stats

  ::method printMessages private       -- DFX TODO fix this rough outline
    expose notifications

    do n over notifications
      select
        when n~type == self~TEXT_TYPE then self~printMsg(n)
        when n~type == self~LOG_TYPE then self~printLog(n)
        otherwise nop
      end
      -- End select
    end

  ::method printMsg private
    use arg n
    say "[Message]" n~when
    say "  File:" pathCompact(n~where, 70)
    say " " n~message
    if n~additional \== .nil then
      say " " n~additional
    if n~additionalObject \== .nil then
      say "  Object involved:" n~additionalObject
    say

  ::method printLog private
    use arg l

    if self~getVerbosity < 7 then return

    say "[Log]" l~when
    say " " l~message
    say "  Command line:" l~additional
    say "  Return code: " l~reason

    if l~where \== "" then say "  Location:" pathCompact(l~where, 70)

    if l~additionalObject \== .nil then do
      log = l~additionalObject
      say
      do line over log
        say line
      end
    end
    say


  ::method printSkippedFiles private       -- DFX TODO fix this rough outline
    expose notifications

    do s over notifications
      if s~type == self~SKIP_TYPE then self~printSkip(s)
    end

  ::method printSkip private
    use arg s

    say "[Skipped test group]" s~when
    say "  File:" pathCompact(s~where, 70)
    say " " s~reason

    if s~additional \== .nil then do
      -- We use insider knowledge here.  The ooTestFinder starts the additional
      -- text with 'Specified Test Types' and adds the test types object.  We
      -- check for that to provide a better output.
      obj = s~additionalObject

      if obj \== .nil, obj~isA(.set), s~additional~abbrev("Specified Test Types") then
        say "  Specified Test Types:" .ooTestTypes~namesForTests(obj)
      else
        say " " s~additional
    end
    say

-- End of class ConsoleFormatter

/* class: ooTestResult - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\


\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ooTestResult' public subclass ooTestCollectingParameter

  ::attribute notifications  private
  ::attribute exceptions     private
  ::attribute events         private
  ::attribute knownFailures  private
  ::attribute newFailures    private

  ::attribute doAutoTiming   private
  ::attribute executionPhase private

  ::attribute newFailureCount   set private
  ::attribute newFailureCount   get
  ::attribute knownFailureCount set private
  ::attribute knownFailureCount get

  ::method init
    expose newFailureCount knownFailureCount
    use arg verbosity
    self~init:super

    self~notifications = .queue~new
    self~exceptions = .queue~new
    self~events = .queue~new
    self~knownFailures = .queue~new
    self~newFailures = .queue~new
    newFailureCount = 0
    knownFailureCount = 0

    -- If verbosity is specified, use it to over-ride the default.
    if arg(1, 'E') then self~setVerbosity(verbosity)

    -- Over-ride the default formatter
    self~formatter = .ConsoleFormatter

    parse source . . file
    phase = .PhaseReport~new(file, .PhaseReport~TEST_EXECUTION_PHASE)
    phase~description = "Stand alone execution of a TestGroup."
    self~doAutoTiming = .true
    self~executionPhase = phase

  -- End init( )

  /** noAutoTiming()
   * As a convenience when running a stand alone TestGroup, an ooTest result
   * attempts to time the test execution phase.  It does this by creating a
   * PhaseReport when it is initiated, setting the phase as finished when the
   * print method is invoked, and adding the phase report to the event queue.
   *
   * To disable this feature invoke this method.
   *
   */
  ::method noAutoTiming
    use strict arg
    self~doAutoTiming = .false
    self~executionPhase = .nil

  ::method print

    if self~doAutoTiming, self~executionPhase \== .nil then do
      self~executionPhase~done
      self~addEvent(self~executionPhase)
    end
    forward class (super)

  ::method addFailure
    expose newFailureCount knownFailureCount
    use strict arg testCase, failData
    forward class (super) continue

    if failData~msg~abbrev(.ooRexxUnit.knownBugFlag) then do
      self~knownFailures~queue(failData)
      knownFailureCount += 1
    end
    else do
      self~newFailures~queue(failData)
      newFailureCount += 1
    end

  /** getExtendedFailureInfo()
   * Returns a table with the failure objects sorted into known failures and
   * 'new' (i.e. unknown) failures.  The table has the indexes of: 'knowndQ',
   * 'newQ', 'knownCount', 'newCount', and 'totalCount'
   *
   */
  ::method getExtendedFailureInfo
    expose newFailureCount knownFailureCount
    t = .table~new
    t['newQ']       = self~newFailures~copy
    t['newCount']   = newFailureCount
    t['knownQ']     = self~knownFailures~copy
    t['knownCount'] = knownFailureCount
    t['totalCount'] = newFailureCount + knownFailureCount
    return t

  ::method addNotification
    use strict arg notification
    self~notifications~queue(notification)

  /** getNotifications()
   * Return a copy of the notifications queue so the caller can manipulate it
   * however she wants.  Note that all the queue return methods should do this,
   * just not implemented yet.
   */
  ::method getNotifications
    return self~notifications~copy

  ::method notificationCount
    return self~notifications~items

  ::method addException
    use strict arg exception
    self~exceptions~queue(exception)

  ::method getExceptions
    return self~exceptions

  ::method exceptionCount
    return self~exceptions~items

  ::method addEvent
    use strict arg event
    self~events~queue(event)

  ::method getEvents
    return self~events

  ::method eventCount
    return self~events~items

-- End of class: ooTestResult


/* class: TestGroup- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    Test Groups are containers of Tests from a single file.  Upon request they
    can provide a Test Suite consisting of all, or part, of the contained Tests.

    When a Test, in the form of the Test class object is added to a Test Group,
    the Test Group handles some of the rote chores used in configuring the Test.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class "TestGroup" public subclass Object inherit TestContainer

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Methods implementating the TestContainer interface.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

  -- True if no tests have been added to this test container, otherwise false.
  ::method isEmpty
    return (self~tests~items == 0)
  -- End isEmpty()

  -- True if this group has any executable tests, otherwise false.
  ::attribute hasTests get
  ::attribute hasTests set private

  /** hasTestTypes()
   *
   * Returns true if this group has any tests matching the types of tests
   * specified, otherwise returns false.
   *
   * @param types REQUIRED
   *   The test type constants to check for.  This can be a blank delimited
   *   string of constants or any .collection object whose items are the
   *   constants.
   *
   * @note  Through out the ooTest framework .nil is used to indicate any and
   *   all tests.
   */
  ::method hasTestTypes
    use strict arg types

    if \ self~hasTests then return .false
    if types == .nil then return .true

    s = makeSetOfWords(types)
    if s == .nil then
       raise syntax 88.917 array ("1 'types'", "must be .nil, a string, or a collection of words")

  return s~intersection(self~currentTypes)~items <> 0
  -- End hasTestTypes()

  -- The number of test case classes this group contains.
  ::attribute testCount get
  ::attribute testCount set private

  /** getNoTestsReason
   *
   * A test group can contain tests, but not have any executable tests.  When
   * this is the case, the getNoTestsReason method returns the reason.
   *
   * Returns the reason why this test container has no executable tests, or the
   * empty string if this container does have executable tests.
   */
  ::method getNoTestsReason
    if self~hasTests then return ""
    else return self~noTests_Reason
  -- End getNoTestReason()

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  End of TestContainer interface implementation.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

  -- The fully qualified path name of the file this test group represents.
  ::attribute pathName get
  ::attribute pathName set private

  -- If an automated test is being run within the process this test group is
  -- instantiated in.  Note that is dependent on a convention establised when
  -- ooRexxUnit was first designed.  The convention is to set a variable in
  -- the .local directory: bRunTestsLocally.  If this variable is set to false,
  -- than an automated test is being run.  If the variable does not exist, or
  -- is set to true, then an automated test is not being run.
  ::attribute isAutomatedTest get
  ::attribute isAutomatedTest set private

  -- A directory object that is used to set the caseInfo class attribute of
  -- each Test class this test group contains.
  ::attribute testInfo get
    expose testInfo
    return testInfo
  ::attribute testInfo set private

  -- A table of Test classes indexed by their category.
  ::attribute tests private

  -- A table of Test classes with their accompanying Suite indexed by their
  -- category.
  ::attribute testsWithSuite private

  -- A table of Test classes, with an accompanying set of individual methods for
  -- that Test class, indexed by their category.  There is a Suite associated
  -- with each Test class, by default ooTestSuite.
  ::attribute testCollections private

  -- A set of the categories of tests this group currently contains.
  ::attribute currentTypes get
  ::attribute currentTypes set private

  -- The operating system this group is executing on.
  ::attribute machineOS get
  ::attribute machineOS set private

  -- A set containing all the possible OSes that ooRexx will run on.  This set
  -- is intended to be immutable.  If / when ooRexx is compilable on additional
  -- operating systems, the set will need to be updated.
  ::attribute knownOSes get
    expose knownOSes
    return knownOSes~copy
  ::attribute knownOSes set private

  -- A set containing the OSes the tests in this group can execute on.  By
  -- default the set contains all known OSes.
  ::attribute allowedOSes get
  ::attribute allowedOSes set private

  -- A string containing an explanation as to why this group has no executable
  -- tests.
  ::attribute noTests_Reason private

  -- Private state variable used to mark that this group has no executable tests
  -- and that should not change.
  ::attribute mustNotExecute private

  ::method readMetadata private
    use arg fsObj

    signal on notready

    lines = .array~new
    do i = 1 until lines[i]~right(2) = "*/"
      lines[i] = fsObj~linein
    end
    fsObj~close
    return lines

    -- Hit the end of file without finding the marker line.  We will return .nil
    -- causing a syntax error to be raised.
    notready:
    fsObj~close
    return .nil

  /** init()
   *
   * Initializes a new test group instance.
   *
   * @param fileSpec  REQUIRED
   *   The path name of the file this test group represents.  The file must
   *   exist.  Relative path names are acceptable, if they will resolve from the
   *   current working directory.  This is UNLIKELY to be the case in an
   *   automated test run, so the fully qualified path name is usually needed.
   */
  ::method init
    use strict arg fileSpec

    fObj = .stream~new(fileSpec)
    self~pathName = fObj~query("EXISTS")
    if self~pathName == "" then
      raise syntax 88.917 array ("1 'fileSpec'", "must be an existing file path name.  File:" fileSpec)

    if fObj~open("SHAREREAD") \== "READY:" then
      raise syntax 88.917 array ("1 'fileSpec'", "must be a readable file.  File:" fileSpec)

    data = self~readMetadata(fObj)
    if data == .nil then
      raise syntax 88.917 array ("1 'fileSpec'", "TestGroup metadata format invalid. File:" fileSpec)

    self~tests = .relation~new
    self~testsWithSuite = .relation~new
    self~testCollections = .relation~new
    self~hasTests = .false
    self~testCount = 0
    self~mustNotExecute = .false
    self~noTests_Reason = "No tests have been added to this container."
    self~currentTypes = .set~new

    -- All possible OS words are put into the allowed OSes set
    self~knownOSes = .set~of('WINDOWS', 'LINUX', 'DARWIN', 'AIX', 'SUNOS', 'MACOSX', 'CYGNUS', 'FREEBSD', 'NETBSD', 'OPENBSD')
    self~allowedOSes = self~knownOSes~copy
    self~machineOS = .ooRexxUnit.OSName

    -- Determine if an automated test run is taking place.
    if isBoolean(.bRunTestsLocally) then self~isAutomatedTest = (\ .bRunTestsLocally)
    else self~isAutomatedTest = .false

    -- Create the metadata directory for this group.
    self~createMetaData(data)

  -- End init( )

  /** hasTestType()
   *
   * Returns true if this group has a test for the type of test specified,
   * otherwise returns false.
   *
   * @param type REQUIRED
   *   The test type keyword to check for.  This must be a string containing a
   *   single word.  Case is not significant.
   *
   */
  ::method hasTestType
    use strict arg type

    if \ type~isA(.string) then
      raise syntax 88.914 array ("1 'type'", "String")

    if type~words \== 1 then
       raise syntax 88.917 array ("1 'type'", "must be a single test type keyword")

  return self~currentTypes~hasIndex(type)
  -- End hasTestType()

  /** restrictOS()
   *
   * Alerts this test group that the tests it contains are operating system
   * specific.  By default tests in a test group are expected to execute on the
   * set of all OSes that ooRexx runs on.  However, test groups can be
   * restricted to only produce test suites for a subset of those OSes.
   *
   * @param acceptable
   *   A set of OS words that this test group should be restricted to.  This can
   *   be either a string of blank separated OS words, or a collection of the OS
   *   words. Case is not significant.  The collection must be a subset of the
   *   known OS words, or the string "UNIX", in which case it translates to
   *   anything except Windows.
   *
   */
  ::method restrictOS
    expose knownOSes
    use strict arg acceptable

    -- special case "UNIX"
    if acceptable = "UNIX" then
      acceptable = knownOSes~copy~~removeItem("WINDOWS")

    s = makeSetOfWords(acceptable)
    if s == .nil then
       raise syntax 88.917 array ("1 'acceptable'", "must be a string or a collection of words")

    if \ s~subset(knownOSes) then
      raise syntax 88.917 array ("1 'acceptable'", "is not a subset of the known operating systems. Found:" acceptable)

    self~allowedOSes = s

    if \ s~hasIndex(self~machineOS) then do
      self~hasTests = .false
      self~mustNotExecute = .true
      self~noTests_Reason = "Test is a" self~wordSetToString(s) "specific test. Current OS is:" self~machineOS
    end

  -- End restrictOS()

  /** markNoTests()
   *
   * Informs this group that there is some reason why any tests the group
   * contains should not be executed.
   *
   * @param reason REQUIRED  (String)
   *   The reason why the tests should not be executed.
   */
  ::method markNoTests
    use strict arg reason

    if \ reason~isA(.string) then
      raise syntax 88.914 array ("1 'reason'", "String")

    if reason == "" then
      raise syntax 88.917 array  ("1 'reason'", "A reason must be supplied to mark a test group as having no tests")

    self~hasTests = .false
    self~noTests_Reason = reason
    self~mustNotExecute = .true
  -- End markNoTests()

  /** wordSetToString()
   *
   * Takes a set of words and turns it into a blank delimited string of words.
   * Note that this is a private method and no error checking is done.
   *
   * @param wordSet REQUIRED  (Set)
   *   The set to work with.
   */
  ::method wordSetToString private
    use arg wordSet
    s = .mutableBuffer~new
    do w over wordSet
      s~append(w" ")
    end
  return s~string~strip
  -- End wordSetToString()


  /** add()
   *
   * Adds a test class object to this group.
   *
   * @param test   REQUIRED  (subclass of ooTestCase)
   *
   */
  ::method add
    expose tests
    use strict arg test

    if \ isSubClassOf(test, "ooTestCase") then
      raise syntax 88.917 array ("1 'test'", "must be a subclass of the ooTestCase class. Found:" test)

    test~caseInfo = self~testInfo
    tests[test~ooTestType] = test
    self~currentTypes~put(test~ooTestType)
    self~testCount += 1

    if \ self~mustNotExecute then self~hasTests = .true
  -- End add()

  /** addWithSuite()
   *
   * Adds a test class object, and the test suite class to use with it, to this
   * group.
   *
   * When this group is asked to return a suite of its executable tests, for
   * the test class specified here, the accompanying test suite class will be
   * used in its construction.
   *
   * @param test   REQUIRED  (subclass of ooTestCase)
   *
   * @param suite  REQUIRED  (subclass of TestSuite)
   *
   */
  ::method addWithSuite
    expose testsWithSuite
    use strict arg test, suite

    if \ isSubClassOf(test, "ooTestCase") then
      raise syntax 88.917 array ("1 'test'", "must be a subclass of the ooTestCase class. Found:" test)

    if \ isSubClassOf(suite, "ooTestSuite") then
      raise syntax 88.917 array ("2 'suite'", "must be a subclass of the ooTestSuite class. Found:" suite)

    test~caseInfo = self~testInfo
    testsWithSuite[test~ooTestType] = .TestWithSuite~new(test, suite)
    self~currentTypes~put(test~ooTestType)
    self~testCount += 1

    if \ self~mustNotExecute then self~hasTests = .true
  -- End addWithSuite()

  /** addWithCollection()
   *
   * Adds a test class object and a collection of the individual test method
   * names to this group.  Optionally a test suite class can be specified to use
   * in the construction of a suite of these tests.
   *
   * When this group is asked to return a suite of its executable tests, a suite
   * will be constructed using the test class and the method names.  If the
   * optional test suite is specified, that suite will be used for the
   * construction, otherwise the default ooTestSuite will be used.
   *
   * @param test   REQUIRED  (subclass of ooTestCase)
   *   The test case class object to be added to this group of test classes.
   *
   * @param names  REQUIRED  (String or Collection)
   *   The names of the individual test case methods to executed with the test
   *   class.  This can be a string of blank delimited method names or any
   *   Collection object whose items are the method names.  If this is an
   *   ordered collection, then the individual test case objects will be added
   *   to the resulting test suite in the same order as they are in the
   *   collection.
   *
   * @param suite  OPTIONAL  (subclass of ooTestSuite)
   *   Specifies the test suite class to use in the construction of a test suite
   *   containing these test cases.  This defaults to the ooTestSuite class.
   *
   */
  ::method addWithCollection
    expose testCollections
    use strict arg test, names, suite = .ooTestSuite

    if \ isSubClassOf(test, "ooTestCase") then
      raise syntax 88.917 array ("1 'test'", "must be a subclass of the ooTestCase class. Found:" test)

    -- Use makeArrayOfWords to preserve the order of the names, if an ordered
    -- collection is passed to us.
    methods = makeArrayOfWords(names)
    if methods == .nil then
       raise syntax 88.917 array ("2 'names'", "must be a string or collection of method names")

    if \ isSubClassOf(suite, "ooTestSuite") then
      raise syntax 88.917 array ("3 'suite'", "if used, must be a subclass of the ooTestSuite class. Found:" suite)

    test~caseInfo = self~testInfo
    testCollections[test~ooTestType] = .TestWithSuiteAndNames~new(test, methods, suite)
    self~currentTypes~put(test~ooTestType)
    self~testCount += 1

    if \ self~mustNotExecute then self~hasTests = .true
  -- End addWithCollection()


  /** suite()
   *
   * Returns a test suite containing all the executable tests, of any test type,
   * to the caller.
   *
   * @param testSuite  OPTIONAL  (subclass of ooTestSuite)
   *   If a test suite object is passed in, the tests will be added to that test
   *   suite.  Otherwise a new test suite is constructed and returned.
   */
  ::method suite
    expose tests testsWithSuite testCollections
    use arg testSuite = (.ooTestSuite~new)

    if \ isSubClassOf(testSuite~class, "ooTestSuite") then
      raise syntax 88.917 array ("1 'testSuite'", "if used, must be a subclass of the ooTestSuite class. Found:" testSuite)

    if \ self~hasTests then return testSuite

    do tClass over tests~allItems
      suite = .ooTestSuite~new(tClass)
      suite~definedInFile = self~pathName
      testSuite~addTest(suite)
    end

    do obj over testsWithSuite~allItems
      suite = obj~getSuite
      suite~definedInFile = self~pathName
      testSuite~addTest(suite)
    end

    do obj over testCollections~allItems
      suite = obj~getSuite
      suite~definedInFile = self~pathName
      testSuite~addTest(suite)
    end

  return testSuite

  /** suiteForTestTypes()
   *
   * Returns a test suite containing all the executable tests, of the specified
   * test type(s), to the caller.
   *
   * @param types  REQUIRED  (String or Collection)
   *   The test type keyword or keywords whose tests should be returned. This
   *   can be a single keyword, a string of blank delimited keywords, or any
   *   Collection object whose items are the keywords.
   *
   * @param testSuite  OPTIONAL  (subclass of ooTestSuite)
   *   If a test suite object is passed in, the tests will be added to that test
   *   suite.  Otherwise a new test suite is constructed and returned.
   */
  ::method suiteForTestTypes
    expose tests testsWithSuite testCollections
    use strict arg types, testSuite = (.ooTestSuite~new)

    testTypes = makeSetOfWords(types)
    if testTypes == .nil then
       raise syntax 88.917 array ("1 'types'", "must be a string or a collection of words")

    if \ isSubClassOf(testSuite~class, "ooTestSuite") then
      raise syntax 88.917 array ("2 'testSuite'", "if used, must be a subclass of the ooTestSuite class. Found:" testSuite)

    if \ self~hasTests then return testSuite

    testTypes = self~currentTypes~intersection(testTypes)
    if testTypes~items == 0 then return testSuite

    do t over testTypes
      testClasses = tests~allAt(t)
      if testClasses <> .nil then do testClass over testClasses
        suite = .ooTestSuite~new(testClass)
        suite~definedInFile = self~pathName
        testSuite~addTest(suite)
      end

      objects = testsWithSuite~allAt(t)
      if objects <> .nil then do obj over objects
        suite = obj~getSuite
        suite~definedInFile = self~pathName
        testSuite~addTest(suite)
      end

      objects = testCollections~allAt(t)
      if objects <> .nil then do obj over objects
        suite = obj~getSuite
        suite~definedInFile = self~pathName
        testSuite~addTest(suite)
      end
    end

  return testSuite
  -- End suiteForTestTypes()

  /** suiteForTestCases
   */
  ::method suiteForTestCases
    expose tests testsWithSuite testCollections
    use strict arg testCases, testTypes, testSuite = (.ooTestSuite~new)

    if \ isSubClassOf(testSuite~class, "ooTestSuite") then
      raise syntax 88.917 array ("3 'testSuite'", "if used, must be a subclass of the ooTestSuite class. Found:" testSuite)

    if \ self~hasTests then return testSuite

    if \ testCases~isA(.set) then
      raise syntax 88.914 array ("1 'testCases'", "Set")

    if \ (testTypes~isA(.set) | testTypes == .nil) then
      raise syntax 88.916 array ("2 'testTypes'", ".nil, or a .Set", testTypes)

    if testTypes == .nil then do
      do tClass over tests~allItems
        suite = self~constructSuiteWithTestCases(tClass, testCases)
        if suite == .nil then iterate

        suite~definedInFile = self~pathName
        testSuite~addTest(suite)
      end

      do obj over testsWithSuite~allItems
        suite = obj~getSuiteForTestCases(testCases)
        if suite == .nil then iterate

        suite~definedInFile = self~pathName
        testSuite~addTest(suite)
      end

      do obj over testCollections~allItems
        suite = obj~getSuiteForTestCases(testCases)
        if suite == .nil then iterate

        suite~definedInFile = self~pathName
        testSuite~addTest(suite)
      end
    end
    else do
      do t over testTypes
        testClasses = tests~allAt(t)
        if testClasses <> .nil then do testClass over testClasses
          suite = self~constructSuiteWithTestCases(testClass, testCases)
          if suite == .nil then iterate

          suite~definedInFile = self~pathName
          testSuite~addTest(suite)
        end

        objects = testsWithSuite~allAt(t)
        if objects <> .nil then do obj over objects
          suite = obj~getSuiteForTestCases(testCases)
          if suite == .nil then iterate

          suite~definedInFile = self~pathName
          testSuite~addTest(suite)
        end

        objects = testCollections~allAt(t)
        if objects <> .nil then do obj over objects
          suite = obj~getSuiteForTestCases(testCases)
          if suite == .nil then iterate

          suite~definedInFile = self~pathName
          testSuite~addTest(suite)
        end
      end
    end

  return testSuite
  -- End suiteForTestCases()

  /** constructSuiteWithTestCases()
   *
   * Determines if the test case class has any of the test cases specified.  If
   * so, constructs a test suite object containing only those test cases
   * specified.
   *
   * @param testCaseClass  The test case class to look at.
   * @param testCases      A set of test case names.
   *
   * return  A test suite object containing all of the matched test cases.  If
   *         there are no matches, .nil is returned.
   */
  ::method constructSuiteWithTestCases private
    use strict arg testCaseClass, testCases

    founds = .array~new

    itr = testCaseClass~methods(testCaseClass)
    do while itr~available
      name = itr~index
      if testCases~hasIndex(name) then founds~append(name)
      itr~next
    end

    if founds~items <> 0 then do
      suite = .ooTestSuite~new
      do t over founds
        suite~addTest(testCaseClass~new(t))
      end
      return suite
    end

    return .nil

  /** createMetaData()
   *
   * Creates a directory object with the metadata from the header of the test
   * group file.  The directory object is used to set the TestInfo class
   * attribute of any Test classes this group contains.
   *
   */
  ::method createMetaData private
    use strict arg src

    data = .directory~new
    data~setentry("test_Case-source", self~pathName)

    self~testInfo = data
  -- End createMetaData()

-- End of class: TestGroup


/* class: TestWithSuite- - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

  Simple helper class to store a test case class and a test suite class.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'TestWithSuite' public
::attribute testClass
::attribute suiteClass

::method init
  expose testClass suiteClass
  use arg testClass, suiteClass

::method getSuite
  expose testClass suiteClass
  return suiteClass~new(testClass)

::method getSuiteForTestCases
  expose testClass suiteClass
  use strict arg testCases

  founds = .array~new

  itr = testClass~methods(testClass)
  do while itr~available
    methodName = itr~index
    if testCases~hasIndex(methodName) then founds~append(methodName)
    itr~next
  end

  if founds~items <> 0 then do
    suite = suiteClass~new
    do t over founds
      suite~addTest(testClass~new(t))
    end
    return suite
  end

  return .nil

-- End of class: TestWithSuite


/* class: TestWithSuiteAndNames- - - - - - - - - - - - - - - - - - - - - - - -*\

  Simple helper class to store a test case class, a collection of test case
  names, and a test suite class.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'TestWithSuiteAndNames' public
::attribute testClass private
::attribute names private
::attribute suiteClass private

::method init
  expose testClass names suiteClass
  use arg testClass, names, suiteClass

::method getSuite
  expose testClass names suiteClass

  if suiteClass == .nil then suiteClass = .ooTestSuite
  suite = suiteClass~new
  do methodName over names
    suite~addTest(testClass~new(methodName))
  end

  return suite

::method getSuiteForTestCases
  expose testClass names suiteClass
  use strict arg testCases

  founds = .array~new
  do methodName over names
    if testCases~hasIndex(methodName) then founds~append(methodName)
  end

  if founds~items <> 0 then do
    if suiteClass == .nil then suiteClass = .ooTestSuite
    suite = suiteClass~new

    do t over founds
      suite~addTest(testClass~new(t))
    end
    return suite
  end

  return .nil

-- End of class: TestWithSuiteAndNames


/* class: ooTestFinder - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    ooTest Finders search a directory tree for test containers with the desired
    type of tests.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ooTestFinder' public

  ::constant ALL         1
  ::constant FILES       2
  ::constant PATTERN     3
  ::constant SINGLEFILE  4

  ::attribute testTypes private
  ::attribute root private
  ::attribute extension private
  ::attribute simpleFileSpec private
  ::attribute searchType private

  ::attribute file private
  ::attribute filePatterns private
  ::attribute fileNames private
  ::attribute excludeFileNames private

  ::attribute totalFound get
  ::attribute totalFound set private

  /** init()
   * Initializes this test finder.
   *
   * @param  root         REQUIRED
   *   The root of the directory tree to search for test containers.
   * @param  extension  REQUIRED
   *   The extension for test container files, such as .testGroup
   * @param  types      OPTIONAL
   *   The test types to search for.  A value of nil indicates all tests and is
   *   the default.
   */
  ::method init
    expose root extension simpleFileSpec sl
    use strict arg root, extension, types = .nil

    sl = .ooRexxUnit.directory.separator
    if root~right(1) \== sl then root = root || sl
    if extension~left(1) \== '.' then extension = '.' || extension

    simpleFileSpec = root || "*" || extension

    self~testTypes = types
    self~totalFound = 0
    self~filePatterns = .nil
    self~fileNames = .nil
    self~excludeFileNames = .array~new
    self~file = .nil
    self~searchType = self~ALL

  -- End init()

  /** useFileName()
   * Sets this test finder to locate a single file specified by fileName.
   *
   */
  ::method useFileName
    use strict arg fileName
    self~file = fileName
    self~searchType = self~SINGLEFILE

  -- End useFileName()

  /** useFiles()
   *
   * Sets this test finder to searches only for the files listed in names.
   */
  ::method useFiles
    expose fileNames
    use strict arg names

    if \ names~isA(.string), \ names~isA(.collection) then
      raise syntax 88.916 array ("1 'names'", "a string or a collection" names)

    if fileNames == .nil then fileNames = .array~new
    if names~isA(.string) then do
      name = self~getCorrectFileName(names)
      fileNames~append(name)
    end
    else do n over names
      if \ n~isA(.string) then
        raise syntax 88.900 array("The file name must be a string object; found" n)

      name = self~getCorrectFileName(n)
      fileNames~append(name)
    end
    self~searchType = self~FILES

  -- End useFiles()

  /** excludeFiles()
   *
   * Sets this test finder to exclude any files listed in names from the found
   * files list.
   */
  ::method excludeFiles
    expose excludeFileNames
    use strict arg names

    if \ names~isA(.string), \ names~isA(.collection) then
      raise syntax 88.916 array ("1 'names'", "a string or a collection" names)

    if excludeFileNames == .nil then excludeFileNames = .array~new
    if names~isA(.string) then do
      name = self~getCorrectFileName(names)
      excludeFileNames~append(name)
    end
    else do n over names
      if \ n~isA(.string) then
        raise syntax 88.900 array("The file name must be a string object; found" n)

      name = self~getCorrectFileName(n)
      excludeFileNames~append(name)
    end

  -- End excludeFiles()

  ::method getCorrectFileName private
    expose extension sl
    use strict arg name

    correctName = name

    p = name~lastPos(sl)
    if p <> 0 then do
      correctName = name~right(name~length - p)
      if correctName == "" then
        raise syntax 88.900 array('The file name "'name'" is improper')
    end

    if correctName~right(extension~length) \== extension then correctName = correctName || extension

    if correctName~countStr('.') > 1  then
      raise syntax 88.900 array('The file name "'name'" is improper')

    return correctName
  -- End getCorrectFileName()

  /** usePatterns()
   * Add the file pattern or patterns to the file patterns array.  The patterns
   * are stored as regular expressions with the following conventions:
   *
   * If the pattern ends in the extension specified in init(), and no directory
   * slashes are in the pattern, then it will be considered a complete file
   * name.  The regular expression will be: any series of characters, the
   * directory slash, the specified pattern.
   *
   * If there are no slashes and the pattern does not end in the extension the
   * pattern will be considered a segment of a file name.  The regular
   * expression  will be any series of characters, the slash, any series of
   * characters not a slash, the pattern, any series of characters not a slash,
   * the extension.
   *
   * If the pattern ends in the slash, it will be considered a directory speci-
   * fication and all files in the directory will be matched.  The regular ex-
   * pression will be any series of characters, the pattern, any series of
   * characters not the slash, and the extension.
   *
   * If the pattern does contain a slash, but does not end in a slash, the reqular
   * expression will be any series of characters, and the pattern.
   */
  ::method usePatterns
    expose filePatterns
    use strict arg patterns

    if \ patterns~isA(.string), \ patterns~isA(.collection) then
      raise syntax 88.916 array ("1 'patterns'", "a string or a collection" patterns)

    if filePatterns == .nil then filePatterns = .array~new
    if patterns~isA(.string) then do
      regularExpression = self~buildRegEx(patterns)
      filePatterns~append(regularExpression)
    end
    else do pattern over patterns
      if \ pattern~isA(.string) then
        raise syntax 88.900 array("The file pattern must be a string object; found" pattern)

      regularExpression = self~buildRegEx(pattern)
      filePatterns~append(regularExpression)
    end
    self~searchType = self~PATTERN
  -- End usePatterns()

  ::method buildRegEx private
    expose extension sl
    use strict arg pattern

    endsInSlash = (pattern~right(1) == sl)
    hasExt = (pattern~right(extension~length)~upper == extension~upper)
    hasSlash = (pattern~pos(sl) <> 0 )

    notSlash = '[^' || sl || ']*'
    select
      when endsInSlash then do
        reg = '?*' || pattern~upper || notSlash || '(' || extension~upper || ')'
        reg = self~maybeEscapeSlashes(reg)
      end

      when hasExt, \ hasSlash then do
        reg = '?*' || sl || pattern~upper
        reg = self~maybeEscapeSlashes(reg)
      end

      when \ hasExt, \ hasSlash then do
        reg = '?+' || sl || notSlash || '(' || pattern~upper || ')' || notSlash || '(' || extension~upper || ')'
        reg = self~maybeEscapeSlashes(reg)
      end

      when hasExt, hasSlash then do
        reg = '?*' || pattern~upper
        reg = self~maybeEscapeSlashes(reg)
      end

      otherwise do
        -- \ hasExt, hasSlash
        p = pattern~lastPos(sl)
        parse var pattern lead =(p + 1) segment
        reg = '?*' || lead~upper || notSlash || '(' || segment~upper || ')' || notSlash || '(' || extension~upper || ')'
        reg = self~maybeEscapeSlashes(reg)
      end

    end
    -- End select

    return .RegularExpression~new(reg)


  ::method maybeEscapeSlashes private
    use strict arg exp

    if .ooRexxUnit.OSName \== "WINDOWS"then return exp

    escaped = ""
    do while exp~pos('\') <> 0
      parse var exp seg'\'exp
      escaped = escaped || seg || '\\'
    end
    escaped = escaped || exp

    return escaped


  ::method seek
    expose testTypes simpleFileSpec
    use strict arg testResult

    if \ isSubClassOf(testResult~class, "ooTestCollectingParameter") then
      raise syntax 88.917 array ("1 'testResult'", "must be a subclass of the ooTestCollectingParameter class. Found:" testResult)

    q = .queue~new
    files = self~findFiles

    if files~items == 0 then do
      err = .ExceptionData~new(timeStamp(), simpleFileSpec, .ExceptionData~ANOMALY)
      err~severity = "Warning"
      err~msg = "No test containers found matching search parameters."
      testResult~addException(err)
      return q
    end


    do fileName over files
      container = self~getContainer(fileName)

      select
        when isSubClassOf(container~class, "ExceptionData") then do
          testResult~addException(container)
          iterate
        end

        when \ isSubClassOf(container~class, "TestContainer") then do
          n = .Notification~new(timeStamp(), fileName, .Notification~SKIP_TYPE)
          n~reason = "Invocation of test container file did not produce the expected result."
          n~additional = "Returned object is not a test container, object is:" container
          rn~additionalObject = container
          testResult~addNotification(n)
          iterate
        end

        when \ container~hasTests then do
          n = .Notification~new(timeStamp(), fileName, .Notification~SKIP_TYPE)
          n~reason = "The test container has no executable tests"
          n~additional = container~getNoTestsReason
          testResult~addNotification(n)
          iterate
        end

        -- If testTypes are .nil then the caller wants any executable tests from
        -- the container.  We know the container has tests.
        when testTypes == .nil then q~queue(container)

        -- Caller wants a certain type of tests.
        when \ container~hasTestTypes(testTypes) then do
          n = .Notification~new(timeStamp(), fileName, .Notification~SKIP_TYPE)
          n~reason = "The test container has none of the specified test types"
          n~additional = "Specified Test Types:" testTypes
          n~additionalObject = testTypes
          testResult~addNotification(n)
          iterate
        end

        otherwise q~queue(container)
      end
      -- End select
    end
    -- End do fileName over files

  return q
  -- End seek()

  ::method getContainer private
    use arg file

    signal on any name callError
    call (file) self~testTypes
    container = RESULT
    return container

    callError:
      err = .ExceptionData~new(timeStamp(), file, .ExceptionData~TRAP)
      err~setLine(sigl)
      err~conditionObject = condition('O')
      err~msg = "Initial call of test container failed"

  return err
  -- End getContainer()

  /** findFiles()
   *
   */
  ::method findFiles private
    expose simpleFileSpec searchType fileNames excludeFileNames

    f = .array~new

    if searchType == self~SINGLEFILE then do
      j = SysFileTree(self~file, files., "FOS")
      -- if we found exactly 1 file and it is not excluded, then use it.
      if j = 0, files.0 == 1, \ self~isExcludedFile(files.1) then f[1] = files.1
    end
    else do
      j = SysFileTree(simpleFileSpec, files., "FOS")

      select
        when searchType == self~ALL then do i = 1 to files.0
          -- If the file is not excluded then use it.
          if \ self~isExcludedFile(files.i) then f~append(files.i)
        end

        when searchType == self~PATTERN then do i = 1 to files.0
          -- If the file natches our pattern, and not in the excluded file name list, use it
          if self~matchFile(files.i), \ self~isExcludedFile(files.i) then f~append(files.i)
        end

        otherwise do i = 1 to files.0
          n = filespec("NAME", files.i)
          do fn over fileNames
            -- If the file is in our file name list, and not in the excluded file name list, use it
            if fn~caselessCompare(n) == 0, \ self~isExcludedFile(files.i) then f~append(files.i)
          end
        end
      end
      -- End select
    end

    self~totalFound = f~items

  return f~sort
  -- End findFiles()

  /** isExcludedFile()
   *
   * Checks if the specified file is in our excluded file list.
   */
  ::method isExcludedFile private
    expose excludeFileNames
    use strict arg fileName

    n = filespec("NAME", fileName)
    do fn over excludeFileNames
      if fn~caselessCompare(n) == 0 then return .true
    end
    return .false
  -- End isExcludedFile()


  ::method matchFile
    expose filePatterns
    use arg file

    do re over filePatterns
      if re~match(file~upper) then return .true
    end
  return .false
  -- End matchFiles()

-- End of class: ooTestFinder


::class 'ExceptionTypes' public mixinclass Object

  ::constant TRAP        1
  ::constant ANOMALY     2
  ::constant UNEXPECTED  3
  ::constant EXTERNAL    4

/* class: ExceptionData- - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    A data object containing information concerning an unrecoverable error that
    occurred during the execution of an automated group of tests.

    Errors that occur during the invocation a test case method are trapped by
    the exception handle.  However, it is also possible for errors to occur
    during other phases of an an automated test.  For example, errors that
    happen during some set up prior to actually invoking a test case method.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ExceptionData' public subclass TestProblem inherit ExceptionTypes

  ::attribute severity
  ::attribute msg

  ::attribute typeName get
  ::attribute typeName set private

  ::method init
    forward class (super) continue

    self~severity = "Fatal"
    self~msg = ""

    select
      when self~type == self~TRAP then self~typeName = "Trap"
      when self~type == self~ANOMALY then self~typeName = "Anomaly"
      when self~type == self~UNEXPECTED then self~typeName = "Unexpected Error"
      when self~type == self~EXTERNAL then self~typeName = "External Command Failure"
      otherwise self~typeName = "Unexpected Error"
    end
    -- End select

  ::method getMessage

    if self~msg \== "" then return self~msg
    else return "(none)"

  /** print()
   * Prints to the console the information this object contains.
   *
   * @param  title    A name / title for the data print out
   * @parar  compact  If true compact the file path name(s).
   */
  ::method print
    use strict arg title = "Framework exception", compact = .true,  -
                   verbose = (.NoiseAdjustable~DEFAULT_VERBOSITY)

    say "["title"]" self~when
    say "  Type:" self~typeName "Severity:" self~severity

    if compact then say "  File:" pathCompact(self~where, 70)
    else say "  File:" self~where

    if self~line <> -1 then say "  Line:" self~line
    if self~msg \== "" then say " " self~getMessage

    if self~type == self~EXTERNAL then do
      self~printExternalException(compact, verbose)
      say
      return
    end

    if self~conditionObject <> .nil then do
      self~printConditionInfo(compact)
      say
      return
    end

    if self~additional~isA(.string) then say " " self~additional
    say

  ::method printConditionInfo private
    use strict arg compact

    obj = self~conditionObject

    sameFiles = (self~where~caselessCompare(obj~program) == 0 & self~line == obj~position)

    say "  Condition:" obj~condition

    if obj~condition == "SYNTAX" then do
      say "   " obj~message
      if \ sameFiles then do
        if compact then say "    File:" pathCompact(obj~program, 70)
        else say "    File:" obj~program
        say "    Line:" obj~position
      end
    end
    else do
      say "   " obj~description
    end

    if obj~traceBack~isA(.list) then do line over obj~traceBack
      say " " line
    end

  ::method printExternalException private
    use strict arg compact, verbose

    n = self~additionalObject

    say " " n~message
    say "  Command line:" n~additional
    say "  Return code: " n~reason

    if n~where \== "" then do
      l = "  Location:"
      if compact then say l pathCompact(n~where, 70)
      else say l n~where
    end

    if verbose >= 5, n~additionalObject \== .nil then do
      log = n~additionalObject
      say
      do line over log
        say line
      end
    end

-- End of class: ExceptionData


::class 'NotificationTypes' public mixinclass Object

  ::constant MIN_TYPE    1

  ::constant SKIP_TYPE   1
  ::constant WARN_TYPE   2
  ::constant TEXT_TYPE   3
  ::constant STEP_TYPE   4
  ::constant STATS_TYPE  5
  ::constant LOG_TYPE    6

  ::constant MAX_TYPE    6

/* Notes on LOG_TYPE notification

     notification~reason == return code
     notification~additional == command line
     notification~message == some message
     notification~additionObject == .array of lines of captured output
*/

/* class: Notification - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    A data object containing information concerning status, events, or other
    things that might need to be logged during the execution of a test, usually
    the execution of an automated suite of tests.

    At a minimum the object contains a time stamp, the name of the relevant
    file, and the notification type.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'Notification' public subclass ReportData inherit NotificationTypes

  ::attribute reason
  ::attribute message
  ::attribute warning

  ::attribute originatorsID

  ::method init
    use strict arg dateTime, file, type
    forward class (super) continue

    if \ isWholeRange(type, self~MIN_TYPE, self~MAX_TYPE) then
      raise syntax 88.907 array("3 'type'", self~MIN_TYPE, self~MAX_TYPE, type)

    select
      when type == self~SKIP_TYPE then do
        self~reason = "Reason is unknown"
        self~warning = .nil
        self~message = .nil
      end
      when type == self~WARN_TYPE then do
        self~reason = .nil
        self~warning = "Warning is unknown"
        self~message = .nil
      end
      otherwise do
        self~reason = .nil
        self~warning = .nil
        self~message = "Message is unknown"
      end
    end
    -- End select

    self~originatorsID = .nil

-- End of class: Notification

/* class: PhaseReport- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

  A type of a notification containging data concerning a phase of the overall
  execution of a group of tests.  By definition, a phase covers some period of
  time and phase reports contain a begin and end time and can produce the
  duration of the phase.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'PhaseReport' public subclass Notification

  ::constant MIN_PHASE            1

  ::constant AUTOMATED_TEST_PHASE 1
  ::constant FILE_SEARCH_PHASE    2
  ::constant SUITE_BUILD_PHASE    3
  ::constant TEST_EXECUTION_PHASE 4

  ::constant MAX_PHASE            4

  ::attribute begin get
  ::attribute begin set private

  ::attribute finish get
  ::attribute finish set private

  ::attribute isFinished get
  ::attribute isFinished set private

  ::attribute id get
  ::attribute id set private

  ::attribute isTicking private unguarded
  ::attribute endTicking private unguarded

  ::method init
    use strict arg file, id

   	self~begin = .TimeSpan~new(time('F'))
    if \ isWholeRange(id, self~MIN_PHASE, self~MAX_PHASE) then
      raise syntax 88.907 array("2 'id'", self~MIN_PHASE, self~MAX_PHASE, type)

    self~init:super(timeStamp(), file, self~STEP_TYPE)

    self~id = id
    self~finish = .nil
    self~isFinished = .false
    self~isTicking = .false
    self~endTicking = .true

  /** tickTock()
   * Outputs dots to the screen in a separate thread.
   */
  ::method tickTock unguarded
    expose isTicking
    use arg msg

    .stdout~charout(msg)
    isTicking = .true
    self~endTicking = .false

    reply
    dots = msg~length

    do while \ self~endTicking
      do i = 1 to 2
        if self~endTicking then leave
        j = SysSleep(.5)
      end
      if dots == 75 then do
        .stdout~lineout(".")
        dots = 0
      end
      else do
        .stdout~charout(".")
      end
      dots += 1
    end
    .stdout~lineout(".")
    isTicking = .false

  /** stopTicking()
   * Provides a way to turn off the tick tock before the duration of this phase
   * is over.
   */
  ::method stopTicking unguarded
    expose isTicking
    self~endTicking = .true
    guard on when \ isTicking

  /** done()
   * Tells this phase that the phase is over.  Sets the finish time.  After this
   * message, the phase duration will always be the same.
   */
  ::method done
    use strict arg
    self~finish = .TimeSpan~new(time('F'))
    self~isFinished = .true

    if self~isTicking then self~stopTicking

  /** duration()
   * The time spanned by this phase.  If the phase is not done, is not finished,
   * then this will be the time elapsed up to this point.  When the phase is
   * done, it will be the total time elapsed for the phase.  Once the phase is
   * finished, duration will not change.
   */
  ::method duration
    if \ self~isFinished then return (self~finish - .TimeSpan~new(time('F')))
    else return (self~finish - self~begin)

  ::method 'description='
    use strict arg description
    self~message = description

  ::method 'description'
    return self~message

-- End of class: PhaseReport


::options novalue syntax
