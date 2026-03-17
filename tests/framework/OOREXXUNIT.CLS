#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2005-2022 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
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
/*
   name:             ooRexxUnit.cls

   purpose:          Supply the base classes for a JUnit compliant testing framework for ooRexx

   remark:           The original design tried, wherever possible, to use the JUnit class and
                     method names in an effort to make ooRexxUnit easier to understand.  However,
                     this lead to some poor design choices in spots and this design goal no
                     longer has a high priority in ooRexxUnit 2.0.0.

                     Nevetheless, ooRexxUnitstill sticks closely to the design of JUnit 3.8.x
                     and persons familiar with JUnit should have no trouble in understanding
                     ooRexxUnit.  For an excellent overview of this design read the cookstour
                     document, the link to which is provided below.

   link:             http://www.junit.org
                     http://junit.sourceforge.net/doc/cookbook/cookbook.htm
                     http://junit.sourceforge.net/doc/cookstour/cookstour.htm

   category0:        ooRexxUnit
   category1:        framework
*/

  -- Define the version number with: x.x.x_y.y.y  Where x is the ooRexxUnit.cls
  -- version, and y is the minimum ooRexx interpreter level required.
  .local~ooRexxUnit.version=2.0.0_3.2.0

  .local~chars.NonPrintable=xrange("00"x, "1F"x) || "FF"x  -- define non-printable chars

  parse version interpreterName languageLevel interpreterDate
  .local~ooRexxUnit.interpreterName=interpreterName
  .local~ooRexxUnit.languageLevel=languageLevel
  .local~ooRexxUnit.interpreterDate=interpreterDate

  .local~ooRexxUnit.shellName=ooRexxUnit.getShellName()
  .local~ooRexxUnit.OSName   =ooRexxUnit.getOSName()


  -- define end-of-line chars
  .local~ooRexxUnit.line.separator=.endOfLine

  -- Set the path and directory separator characters for the current OS. A select
  -- is used so that if the test suite needs to be run on an OS with different
  -- characters, it can easily be added here.
  select
    when .ooRexxUnit.OSName == "WINDOWS" then do
      .local~ooRexxUnit.directory.separator = '\'
      .local~ooRexxUnit.path.separator=";"
    end
    otherwise do
      .local~ooRexxUnit.directory.separator = '/'
      .local~ooRexxUnit.path.separator=":"
    end
  end
  -- End select

  -- Put the default test result class into the environment.
  .local~ooRexxUnit.default.TestResult.Class = .TestResult

  -- Define a 'marker' that can be used to flag a known test case failure.
  .local~ooRexxUnit.knownBugFlag = "tracker bug #"

  -- Capture the ooRexxUnit framework directory and ensure it is in the path.
  -- Also capture the original path in case someone needs it.
  parse source . . fileSpec
  .local~ooRexxUnit.dir = fileSpec~left(fileSpec~caseLessPos("OOREXXUNIT.CLS") - 2 )
  .local~ooRexxUnit.originalPath = addToPath(.ooRexxUnit.dir)

  -- Add the test utility class to the local environment so that it is available
  -- to anyone running in this process.
  .local~put(.TESTUTIL, 'TESTUTIL')

  .local~ooRexxUnit.architecture = getAddressingMode()

-- End of entry point.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\
  Directives, Classes, or Routines.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

/** isSubClassOf()
 *
 * Tests if an object is a class object that is a subclass of the specified
 * class.  (Note that this is different then testing that an object is an
 * instance of a class.)
 *
 * During the execution of an automated test suite, many of the framework's
 * class objects can be created by different requires directives.  This prevents
 * the use of a simple comparison to test if an object is a specific class
 * object.  This public routine provides a way to test the class of a class
 * object for this situation.
 *
 * @param cObj            REQUIRED  The object to test.
 * @param superClassName  REQUIRED  A string, the name of the class to test for.
 *
 * Return true if the object is a subclass of the specified class, otherwise
 * false.
 *
 */
::routine isSubClassOf public
  use strict arg cObj, superClassName

  -- This is a recursive function and these are the base cases.
  if \ cObj~isA(.class) then return .false

  if cObj~id~caselessEquals(superClassName) then return .true

  supers = cObj~superClasses
  if supers~items == 0 then return .false

  -- Do a breadth-first search
  do cObj over supers
    if cObj~id~caselessEquals(superClassName) then return .true
  end

  -- The recursive part.
  do cObj over supers
    if isSubClassOf(cObj, superClassName) then return .true
  end
  return .false
-- End isSubClassOf()

::routine querySuperClasses public
  use arg classObj
  classes = classObj~superClasses
  do c over classes
    say c
  end
return 0

/** isBoolean()
 *
 * Tests if an object is a boolean (.true or .false.)
 *
 * Note that this function will always return true or false so that it is always
 * safe to use in an logical expression.  If no argument is supplied (which of
 * course makes no sense) then false is returned.
 *
 * @param obj   The object to test.
 *
 * Returns true if the object is strictly true, otherwise false.
 */
::routine isBoolean public
  use arg obj
  if arg(1, 'E') then do
    if obj~isA(.string) then do
      if obj~datatype('O') then return .true
    end
  end
return .false
-- End isBoolean()

/** isPositive()
 * Tests if an object is a positive, whole number.
 *
 * @param number  REQUIRED  The object to test.
 *
 * Returns true if the object is strictly a whole number greater than zero.
 */
::routine isPositive public
  use strict arg number
  if number~isA(.String) then do
    if number~dataType('W') then do
      if number > 0 then return .true
    end
  end
return .false
-- End isBoolean()

/** isWholeRange()
 * Tests if an object is a whole number within the range of min and max.
 *
 * @param number  REQUIRED  The object to test.
 * @param min     REQUIRED  The minimal value of the range.
 * @param max     REQURIED  The maximal value of the range.
 */
::routine isWholeRange public
  use strict arg number, min, max

  if number~isA(.String) then do
    if number~dataType('W') then do
      if number >= min, number <= max then return .true
    end
  end
return .false
-- End isWholeRange()

/* pathCompact( path, len )- - - - - - - - - - - - - - - - - - - - - - - - - -*\

  Takes a path name and compacts it to a shorter path name by removing some
  path components as required.

  Input:
    path REQUIRED
      The path name to compact.

    len  REQUIRED
      used as an indication for the maximum path length to be returned.

  Returns:
    A compacted path.
\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::routine pathCompact public
  use strict arg path, len

  -- best readability is achieved by always starting with /ooRexx directory
  -- in this case we simply ignore any supplied 'len' value
  p = path~caselessPos(.File~separator || "ooRexx" || .File~separator)
  if p > 0 then
    return "..." || path~subStr(p)

  -- return path as-is if it fits the supplied 'len'
  if path~length <= len then
    return path

  -- try to cut path short
  head = "..."
  tail = path~right(len - head~length)
  p = tail~pos(.File~separator)
  if p > 0 then
    return head || tail~subStr(p)
  else
    return head || tail


/** addToPath()
 * Adds the specified directory to the path only if it is not already in the
 * path.  By default the directory is added to the beginning of the path.
 *
 * @param  dir  REQUIRED
 *   The directory to add to the path
 * @param  at   OPTIONAL
 *   Where to add the directory, beginning or end. Only the first letter is
 *   needed.  Specifying anything other than "E"nd results in the beginning.
 * @return  Returns the old path, the current path at time of invocation.
 */
::routine addToPath public
  use strict arg dir, at = 'B'

  at = at~left(1)~upper
  if at \== 'E' then at = 'B'

  curPath = value("PATH", , 'ENVIRONMENT')
  if \ isInPath(dir) then do
    if at == 'B' then
      j = value("PATH", dir || .ooRexxUnit.path.separator || curPath, 'ENVIRONMENT')
    else
      j = value("PATH", curPath || .ooRexxUnit.path.separator || dir, 'ENVIRONMENT')
  end

return curPath
-- End addToPath()


/** isInPath()
 * Returns true if the specified directory is in the current PATH, otherwise
 * returns false.
 */
::routine isInPath public
  use strict arg dir

  path = value("PATH", , 'ENVIRONMENT')
  sl   = .ooRexxUnit.directory.separator
  sep  = .ooRexxUnit.path.separator

  if .ooRexxUnit.OSName == "WINDOWS" then do
    if path~caseLessPos(dir || sep) <> 0 then return .true
    if path~caseLessPos(dir || sl || Sep) <> 0 then return .true
    if path~right(dir~length)~caselessCompare(dir) == 0 then return .true
  end
  else do
    if path~pos(dir || sep) <> 0 then return .true
    if path~pos(dir || sl || Sep) <> 0 then return .true
    if path~right(dir~length)~compare(dir) == 0 then return .true
  end

return .false
--End isInPath()


/** pp()
 * Enclose a string value in square brackets "pretty print."
 */
::routine pp public
  return "[" || arg(1)~string || "]"

/** ppp()
 * Enclose a string value in square brackets if escaping non-printable chars as
 * Rexx concatenated Rexx hex strings.
*/
::routine ppp public
  use arg string

  if verify(string, .chars.NonPrintable, "Match")>0 then
     return "[" || escapeString(string) || "]" -- escape non-printable characters

  return (string~length = 0)~?("[]", string)

/** addN
 * If name starts with a vowel, then "n" is returned, "" else
 */
::routine addN public
  parse arg name

  if "aeiou"~caselessPos(name~left(1))>0 then return "n"
  return ""

/** escapeString()
 * Escape non-printable characters in string.
 */
::routine escapeString public
  use arg str
  tmpStr=.mutableBuffer~new

  do forever while str<>""
     start=verify(str, .chars.nonPrintable, "Match")
     if start>0 then    -- non-printing char found, look for printable char after it
     do
            -- find non-matching position, deduct one to point to last non-printable chars in string
        end=verify(str, .chars.nonPrintable, "Nomatch", start)-1
        if end=-1 then   -- no non-matching (=ending) position found: rest is non-printable
           end=length(str)

        if start>1 then -- printable chars before section with non-printable chars ?
        do
           chunk = .TestUtil~enQuote(substr(str, 1, start-1))
           if tmpStr~length<>0 then tmpStr~~append(" || ")~~append(chunk)
                               else tmpStr~append(chunk)
        end

            -- extract non-printable chars, encode them as a Rexx hex string
        chunk = .TestUtil~enQuote(substr(str, start, end-start+1)~c2x) || "x"

        if tmpStr~length<>0 then tmpStr~~append(" || ")~~append(chunk)
                            else tmpStr~append(chunk)

            -- extract non-processed part of string
        str=substr(str, end+1)   -- get remaining string
     end
     else   -- only printable chars available respectively left
     do
        if tmpStr~length<>0 then tmpStr~~append(" || ")~~append(.TestUtil~enquote(str))
                            else tmpStr~append(str)
        leave         -- str=""
     end
  end
  return tmpStr~string


/** timeStamp()
 * Return a date / time string.  This allows a consistent format of time stamps
 * throughout the test framework.
 */
::routine timeStamp public
  return date("S") time("L")

/** isConditionObj()
 * Tests if an object is likely to be a condition object returned from the
 * condition('O') BIF.  This is not a foolproof test.
 */
::routine isConditionObj public
  use strict arg cObj
  if cObj~isA(.directory), cObj~hasEntry("CONDITION"), cObj~hasEntry("INSTRUCTION") then return .true
  return .false

/** conditionObjLineNumber()
 * Given an object, will return the line number of a syntax exception, if the
 * object is a condition object for a syntax exception.  Othewise returns -1.
 */
::routine conditionObjLineNumber public
  use strict arg obj

  lineNumber = -1

  if isConditionObj(obj) then do
    if obj~traceBack~isA(.list) then do
      parse value obj~traceBack~lastItem with number "*-*" .
      lineNumber = number~strip
      if \ isPositive(lineNumber) then lineNumber = -1
    end
    else if obj~condition == "SYNTAX" then do
      lineNumber = obj~position
    end
  end

  return lineNumber

/** getAddressingMode()
 * Determine if this is a 32-bit or 64-bit interpreter.
 */
::routine getAddressingMode

return .Rexxinfo~architecture


/* class: TestUtil - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    A class with static (class) utility methods that can be used anywhere.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class "TestUtil" public

/** enQuote()
 * Enclose a string in double quotes.
 */
::method enQuote class
  return '"' || arg(1)~string || '"'


/* class: NoiseAdjustable- - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    A class that allows adjusting the level of ouput ("noise") produced.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class "NoiseAdjustable" public mixinclass Object

  ::constant MAX_VERBOSITY      10
  ::constant MIN_VERBOSITY       0
  ::constant DEFAULT_VERBOSITY   2

  ::attribute verbose private

  ::method setVerbosity
    use strict arg level

    if \ isWholeRange(level, self~MIN_VERBOSITY, self~MAX_VERBOSITY) then
      raise syntax 88.907 array("1 'level'", self~MIN_VERBOSITY, self~MAX_VERBOSITY, level)
    self~verbose = level

  ::method getVerbosity
    return self~verbose

-- End of class: NoiseAdjustable


/** class:  TestCollectingParameter
  *   Defines an interface for a test data collecting parameter.  The TestResult
  *   class and subclasses apply the 'Collecting Parameter' design pattern.
  *   This object is used to collect data throughout the execution of a test.
  */
::class 'TestCollectingParameter' public inherit NoiseAdjustable

/** Ouputs in some manner the formatted data of this collecting parameter.    */
::method print          abstract

/** Sets the default formatter class to use when print() is invoked.          */
::method setFormatter   abstract

/** Returns the current default formatter class of this collecting parameter  */
::method getFormatter   abstract

-- End of class TestCollectingParameter


::class "TestResult" public subclass TestCollectingParameter

-- The default formatter class for this test result.
::attribute formatter private

::method init
  expose fErrors fFailures fRunTests fStop fTestRuns fAssertions

  fErrors=.queue~new
  fFailures=.queue~new

  fAssertions=0
  fRunTests=0
  fStop=.false

  self~setVerbosity(self~DEFAULT_VERBOSITY)
  self~formatter = .SimpleFormatter

::method addError
  expose fErrors
  use arg aTestCase, errData

  fErrors~queue(errData)

::method addFailure unguarded
  expose fFailures
  use arg aTestCase, failData

  fFailures~queue(failData)

::method assertCount    -- ooRexxUnit only
  expose fAssertions
  return fAssertions

::method endTest        -- informs that the supplied test was completed
  expose fStop fAssertions
  use arg aTestCase

  fAssertions=fAssertions+aTestCase~assertCount
  fStop=.false          -- reset indicator


::method errorCount     -- return # of errors
  expose fErrors
  return fErrors~items

::method errors         -- return error queue
  expose fErrors
  return fErrors


::method failureCount   -- return # of failures
  expose fFailures
  return fFailures~items

::method failures       -- return failure queue
  expose fFailures
  return fFailures


::method execute            -- convenience method to run given TestCase
  use arg aTestCase
  return aTestCase~execute(self)

::method runCount       -- gets the number of run tests
  expose fRunTests
  return fRunTests

::method shouldStop     -- return value
  expose fStop
  return fStop

::method startTest
  expose fStop fRunTests
  use arg aTestCase

  fStop=.false          -- reset indicator
if \aTestCase~isA(.TestSuite) then
  fRunTests=fRunTests+1 -- increase run counter
--say "startTest" fRunTests aTestCase~getName aTestCase~class~id

::method stop           --  mark that the test run should stop
  expose fStop
  fStop=.true

::method wasSuccessful  -- returns whether the entire test was successful or not
  expose fErrors fFailures

  return (fErrors~items+fFailures~items)=0

/** print()
 * Output the result data using our assigned formatter.
 *
 * @param title    OPTIONAL    (String)
 *   Passes a title on to the formatter.
 *
 * @param level   OPTIONAL    (Whole Number)
 *   Sets the verbosity level of the print out by over-riding the verbosity
 *   level of this test result.  By default the verbosity of the print out will
 *   be that of this test result.
 */
::method print
  use arg title = "", level = (self~getVerbosity)

  if \ title~isA(.string) then
    raise syntax 88.914 array ("1 'title'", "String")

  formatter = self~formatter~new(self, title)

  if arg(2, 'E') then formatter~setVerbosity(level)
  else formatter~setVerbosity(self~getVerbosity)

  formatter~print

/** setFormatter()
 * Change the current default formatter class for this test result to that
 * specified.
 *
 * @param formatterClass  REQUIRED  (ResultFormatter)
 *   The new default formatter class for this test result.
 */
::method setFormatter
  use strict arg formatterClass

  if \ isSubclassOf(formatterClass, "ResultFormatter") then
     raise syntax 88.914 array ("1 'formatterClass'", "ResultFormatter")
  self~formatter = formatterClass

/** getFormatter()
 * Returns the current default formatter class for this test result.
 */
::method getFormatter
  return self~formatter

-- End of class TestResult


/* class: ResultFormatter- - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    An interface for an object that can format, and then output, the data
    contained in a test collecting parameter.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ResultFormatter' public inherit NoiseAdjustable

::attribute testResult private
::attribute title private

::method init
  use strict arg testResult, title = ""

  if \ isSubClassOf(testResult~class, "TestCollectingParameter") then
     raise syntax 88.914 array ("1 'testResult'", "TestCollectingParameter")

  if \ title~isA(.string) then
    raise syntax 88.914 array ("2 'title'", "String")


  self~testResult = testResult
  self~title = title
  self~setVerbosity(self~DEFAULT_VERBOSITY)

/** print()  Format and output the data of this formatter's test result. */
::method print abstract

/** setTitle()  Set a title for this formatter's output. */
::method setTitle abstract

-- End of class ResultFormatter


/* class: SimpleFormatter- - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    Formats and prints to the console a simple rendition of a test result's
    data.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'SimpleFormatter' public subclass ResultFormatter

::method setTitle
  use strict arg title

  if \ title~isA(.string) then
    raise syntax 88.914 array ("1 'title'", "String")

  self~title = title

::method print
  aTestResult = self~testResult

  if self~title <> "" then do
    say self~title
    say
  end

  say "nr of test runs:            " aTestResult~runCount
  say "nr of successful assertions:" aTestResult~assertCount

  say "nr of failures:             " aTestResult~failureCount
  if aTestResult~failureCount > 0 then do data over aTestResult~failures
    say "  " self~failureToString(data)
  end

  say "nr of errors:               " aTestResult~errorCount
  if aTestResult~errorCount > 0 then do err over aTestResult~errors
    say "  " self~errorToString(err)
  end

::method failureToString private
  use arg data

  str = data~when":" "failure" data~testString "---> @assertFailure" -
        data~type": expected="data~expected", actual="data~actual"."

  if data~msg <> "" then str = str ||"09"x || data~msg

return str

::method errorToString private
  use arg data

  str = data~when':' "error" data~testString '---> condition' -
        pp(data~type) 'raised unexpectedly.'

  if data~conditionObject~message <> .nil then str = str || '09'x || data~conditionObject~message

return str

-- End of class SimpleFormatter


/* class: SimpleConsoleFormatter - - - - - - - - - - - - - - - - - - - - - - -*\

    Formats a test result's data and prints it in a console friendly manner.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'SimpleConsoleFormatter' public subclass ResultFormatter

::method setTitle
  use strict arg title
  if \ title~isA(.String) then
    raise syntax 88.914 array ("1 'title'", .string~id)

  self~title = title

::method print
  aTestResult = self~testResult

  if self~title <> "" then do
    say self~title
    say
  end

   versionStr = .ooRexxUnit.interpreterName .ooRexxUnit.languageLevel .ooRexxUnit.interpreterDate
   say "Interpreter:" versionStr
   say "ooRexxUnit: " .ooRexxUnit.version
   say
   say "Count of tests ran:            " aTestResult~runCount
   say "Count of successful assertions:" aTestResult~assertCount
   say "Count of failures:             " aTestResult~failureCount
   say "Count of errors:               " aTestResult~errorCount
   say

   if aTestResult~failureCount > 0 then do data over aTestResult~failures
      self~printFailureInfo(data)
   end

   if aTestResult~errorCount > 0 then do data over aTestResult~errors
      self~printErrorInfo(data)
   end

   -- If a number of failure or error information lines are printed, re-display
   -- the summary statistics again so that the number of failures is obvious to
   -- the user.
   if (aTestResult~failureCount + aTestResult~errorCount) > 3 then do
     say "Interpreter:" versionStr
     say "ooRexxUnit: " .ooRexxUnit.version
     say
     say "Count of tests ran:            " aTestResult~runCount
     say "Count of successful assertions:" aTestResult~assertCount
     say "Count of failures:             " aTestResult~failureCount
     say "Count of errors:               " aTestResult~errorCount
     say
   end


::method printFailureInfo private
  use arg data

  say "failure" data~when
  say "  Test:  " data~testname
  say "  Class: " data~className
  say "  File:  " pathCompact(data~where, 70)
  say "  Line:  " data~line
  say "  Failed:" data~type
  say "    Expected:" data~expected
  say "    Actual:  " data~actual

  if data~msg \== "" then
    say "    Message: " data~msg
  say

::method printErrorInfo private
  use arg data

  -- It is possible that the error happened in a file other than the test case
  -- file.  Most often the files are the same.
  different = (data~where~compareTo(data~conditionObject~program) <> 0)

  say "error" data~when
  say "  Test: " data~testName
  say "  Class:" data~className
  say "  File: " pathCompact(data~where, 70)
  say "  Event:" pp(data~type) "raised unexpectedly."
  if data~conditionObject~message \== .nil then
    say "    "data~conditionObject~message
  if different then
    say "    Program:" pathCompact(data~conditionObject~program, 60)
  say "    Line:   " data~line
  if data~conditionObject~traceBack~isA(.list) then do line over data~conditionObject~traceBack
    say line
  end
  say

-- End of class SimpleFormatter


/* class: ReportData - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    A base class for data objects reporting problems, events, or infomation
    during the execution of tests using the ooRexxUnit framework.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ReportData' public

::attribute when get
::attribute when set private

::attribute where get
::attribute where set private

::attribute type get
::attribute type set private

::attribute additionalObject
::attribute additional

::method init
  expose when where type
  use strict arg when, where, type, ...

  self~additionalObject = .nil
  self~additional = .nil


/* class: TestProblem- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    The superclass for reporting problems during the execution of tests.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'TestProblem' public subclass ReportData

::attribute className
::attribute testName
::attribute testString

::attribute conditionObject get
::attribute conditionObject set
  expose conditionObject
  use strict arg cObj
  if \ isConditionObj(cObj) then
    raise syntax 88.900 array ("conditionObject must be set to the object returned from CONDITION('O')")
  conditionObject = cObj

::method init
  expose conditionObject lineNumber
  forward class (super) continue

  conditionObject = .nil
  lineNumber = .nil

  self~className = .nil
  self~testName = .nil
  self~testString = .nil

::method setLine
  expose lineNumber
  use strict arg number
  if \ isPositive(number) then
    raise syntax 88.905 array ("1 'number'", number)
  lineNumber = number

::method line
  expose lineNumber conditionObject

  if lineNumber \== .nil then return lineNumber
  else return self~conditionObjLineNumber

/** conditionObjLineNumber()
 * Given an object, will return the line number of a syntax exception, if the
 * object is a condition object for a syntax exception.  Othewise returns -1.
 */
::method conditionObjLineNumber
  expose conditionObject testName

  lineNumber = -1

  if isConditionObj(conditionObject) then do
    if conditionObject~stackFrames~isA(.list) then do
      do frame over conditionObject~stackFrames
          if frame~name~caselessEquals(testName) then do
               return frame~line
          end
      end
      return -1
    end
    else if conditionObject~condition == "SYNTAX" then do
      lineNumber = conditionObject~position
    end
  end

  return lineNumber


/* class: AssertFailure- - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    AssertFailure is a report of a test case failure.  A test case fails when an
    assertion does not hold.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'AssertFailure' public subclass TestProblem

::attribute expected
::attribute actual
::attribute msg

::method init
  forward class (super) continue

  self~expected = .nil
  self~actual = .nil
  self~msg = .nil


/* class: ErrorReport- - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    ErrorReports are used for unexpected errors during the execution of a test
    case.

    When an unexpected error happens during the execution of a test case, there
    is always a condition object at the time the error is trapped.  So, unlike
    AssertFailures, the condition object is required to instantiate an error
    report.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class 'ErrorReport' public subclass TestProblem

::method init
  use strict arg dateTime, file, type, cObj
  forward class (super) continue

  self~conditionObject = cObj


/* class: Assert - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*\

    Assertions will raise a user error, if they do not hold.

\* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
::class "Assert" public mixinclass Object

::attribute fAssertions private
::attribute definedInFile    -- allows to quickly get filename from which test case is taken

::method init
  self~fAssertions = 0
  self~clearCondition

::method assertCount
  return self~fAssertions     -- count assertions, ooRexxUnit only


/** assertEquals()
 * Checks if two collection objects are equal, or, if two objects are equal
 */
::method assertEquals
  use strict arg expected, actual, msg = ""

  if expected~isA(.Collection), actual~isA(.Collection) then do
    if \isCollectionEqual(expected, actual) then
      self~fail(self~makeFailure(expected, actual, msg, "assertEquals"))
  end
  else if expected \= actual then
    self~fail(self~makeFailure(expected, actual, msg, "assertEquals"))

  -- Assertion holds
  self~fAssertions += 1


/** assertFuzzyEquals()
 * Checks if two objects are equal using fuzzy math
 */
::method assertFuzzyEquals
  use strict arg expected, actual, digits = (digits()), msg = ""

  numeric digits digits
  numeric fuzz 1

  if \ (expected = actual) then do
      self~fail(self~makeFailure(expected, actual, msg, "assertFuzzyEquals"))
  end

  -- Assertion holds
  self~fAssertions += 1

/** assertNotEquals()
 * Checks if two collection objects are not equal, or, if two objects are not equal
 */
::method assertNotEquals
  use strict arg expected, actual, msg = ""

  if expected~isA(.Collection), actual~isA(.Collection) then do
    if isCollectionEqual(expected, actual) then
      self~fail(self~makeFailure(expected, actual, msg, "assertNotEquals"))
  end
  else if expected = actual then
    self~fail(self~makeFailure(expected, actual, msg, "assertNotEquals"))

  -- Assertion holds
  self~fAssertions += 1


::method assertNull -- deprecated, use assertNil instead
  use strict arg actual, msg = ""

  if \ (.nil = actual) then do
    self~fail(self~makeFailure(".nil", actual, msg, "assertNull"))
  end

  -- Assertion holds.
  self~fAssertions += 1


::method assertNotNull -- deprecated, use assertNotNil instead
  use strict arg actual, msg = ""

  if (.nil = actual) then do
    self~fail(self~makeFailure("not .nil", ".nil", msg, "assertNotNull"))
  end

  -- Assertion holds.
  self~fAssertions += 1

::method assertNil
  use strict arg actual, msg = ""

  if .nil \== actual then
    self~fail(self~makeFailure(".nil", actual, msg, "assertNil"))
  self~fAssertions += 1


::method assertNotNil
  use strict arg actual, msg = ""

  if .nil == actual then
    self~fail(self~makeFailure("not .nil", ".nil", msg, "assertNotNil"))
  self~fAssertions += 1

::method assertIsA
  use strict arg target, class, msg = ""

  if \target~isA(class) then
    self~fail(self~makeFailure(class~id, target~class~id, msg, "assertIsA"))

  -- Assertion holds.
  self~fAssertions += 1

-- compare two Collections for equality
::method assertSameList
  use strict arg expected, actual, msg = "assertSameList"

  if \isCollectionEqual(expected, actual) then
    self~fail(self~makeFailure(expected, actual, msg, "assertSameList"))

  -- Assertion holds.
  self~fAssertions += 1

-- compare two Collections for equivalence
::method assertEquivalentList
  use strict arg expected, actual, msg = "assertEquivalentList"

  -- same items, but in a potentially different order
  if \isCollectionEquivalent(expected, actual) then
    self~fail(self~makeFailure(expected, actual, msg, "assertEquivalentList"))

  -- Assertion holds.
  self~fAssertions += 1


::method assertSame
  use strict arg expected, actual, msg = ""

  if \ (expected == actual) then do
    self~fail(self~makeFailure(expected, actual, msg, "assertSame"))
  end

  -- Assertion holds.
  self~fAssertions += 1


::method assertNotSame
  use strict arg expected, actual, msg = ""

  if (expected == actual) then do
    expected = self~formatObjectInfo(expected)
    actual   = self~formatObjectInfo(actual)

    self~fail(self~makeFailure(expected '\==' actual, expected ' ==' actual, msg, "assertNotSame"))
  end

  -- Assertion holds.
  self~fAssertions += 1

-- Check if an object is EXACTLY the same object instance
::method assertIdentical
  use strict arg expected, actual, msg = ""

  if (expected~identityHash \== actual~identityHash) then do
    self~fail(self~makeFailure(expected, actual, msg, "assertIdentical"))
  end

  -- Assertion holds.
  self~fAssertions += 1

-- Check if an object is NOT EXACTLY the same object instance
::method assertNotIdentical
  use strict arg expected, actual, msg = ""

  if (expected~identityHash == actual~identityHash) then do
    self~fail(self~makeFailure(expected, actual, msg, "assertNotIdentical"))
  end

  -- Assertion holds.
  self~fAssertions += 1


/** assertEitherOr()
 * Exclusive or, either arg 1 is true or arg 2 is true, but not both.
 */
::method assertEitherOr
  use strict arg truthOne, truthTwo, msg = ""

  if \ self~exclusiveOr(truthOne, truthTwo) then do
    expected = '[ one .true and one .false ]'
    actual   = '['self~formatObjectInfo(truthOne) self~formatObjectInfo(truthTwo)']'
    self~fail(self~makeFailure(expected, actual, msg, "assertEitherOr"))
  end

  -- Assertion holds.
  self~fAssertions += 1


/** assertOneOrAnother()
 * Exclusive or for objects.  The actual object is expected to equal either one
 * object, or another object, but not both.
 */
::method assertOneOrAnother
  use strict arg one, other, actual, msg = ""

  if \ self~exclusiveOrObject(one, other, actual) then do
    expected = '['self~formatObjectInfo(one) 'or' self~formatObjectInfo(other)']'
    actual   = self~formatObjectInfo(actual)
    self~fail(self~makeFailure(expected, actual, msg, "assertOneOrAnother"))
  end

  -- Assertion holds.
  self~fAssertions += 1


::method assertTrue
  use strict arg actual, msg = ""

  if \ (actual = .true) then do
    self~fail(self~makeFailure("1", actual, msg, "assertTrue"))
  end

  -- Assertion holds.
  self~fAssertions += 1


::method assertFalse
  use strict arg actual, msg = ""

  if \ (actual = .false) then do
    self~fail(self~makeFailure("0", actual, msg, "assertFalse"))
  end

  -- Assertion holds.
  self~fAssertions += 1

/** assertFail()
 * Assert a failure explicitly.  Useful for situations where control is not expected
 * to reach a particular point.
 */
::method assertFail
  use strict arg msg = ""
  self~assertTrue(.false, msg) -- just do this as a true assertion


-- create a package from an array of lines with the intent of checking
-- errors raised at translate time rather than runtime.
::method assertSyntaxError
  use strict arg error, code, parentPackage = (self~class~package)

  self~expectSyntax(error)
  -- this will translate this code and nothing else.
  r = .package~new("test", code, parentPackage)


-- create a routine and call from an array of lines with the intent of checking
-- errors raised at run time rather than during translation.
::method assertRuntimeError
  use strict arg error, code, parentPackage = (self~class~package)

  self~expectSyntax(error)
  -- this will create a routine and then we invoke it, returning the
  -- code result.
  r = .routine~new("test", code, parentPackage)
  return r[]

-- run some dynamically created source code that will return a result.
::method runDynamicSource
  use strict arg code, parentPackage = (self~class~package)

  -- this will create a routine object and return the result.
  -- use the parent package name as the routine name to allow external
  -- files to resolve with correct extension
  r = .routine~new(parentPackage~name, code, parentPackage)
  return r[]


-- assert an external command return code
-- on Windows, return codes in the range -32768 to 32767 are valid
-- on Unix-like systems, return codes use just the 8 least significant bits
-- of the returned value giving a range of 0 to 255
::method assertRc
  use strict arg expected, actual, msg = ""

  -- if the expected rc is -1, the assert will pass
  -- on Windows if actual rc is -1
  -- on a Unix-like system if actual rc is 255

  -- we pass if
  -- * expected and actual match, or if
  -- * on Unix, LSB of expected and actual match
  if expected = actual |,
     .ooRexxUnit.OSName \= "WINDOWS" & expected~d2c(2)~right(1)~c2d = actual then
    self~fAssertions += 1
  else
    self~fail(self~makeFailure(expected, actual, msg, "assertRc"))


/** fail()
 * Raise an application definable syntax condition with code 93.964.  The
 * exception handler for the test case method execution will check for this
 * specific code and know that the 'syntax' condition is actually a condition
 * raised by the framework for a test case failure.
 *
 * The data failure object is passed through to the exception handler in index
 * 2 of the additional array.  Index 1 of the array contains a distinctive
 * message to further ensure that the exception handler will know that the
 * condition is raised by the framework.
 *
 * We raise a syntax condition because syntax conditions are propagated from
 * an active message invocation (the test case method invocation) to the clause
 * containing the message invocation.  This allows the exception handler to trap
 * the failed test case.
 *
 * @param data  REQUIRED (AssertFailure or String)  Data concerning the failure.
 */
::method fail
  use strict arg data

  if data~isA(.String) then data = self~makeFailure("n/a", "n/a", data, "fail")

  -- Tests which run assertXxxx() method calls in threads spawned by the REPLY
  -- instruction require special handling.  As REPLY threads run at the base
  -- base of the stack, we cannot raise SYNTAX.  Instead, we directly modify
  -- our test result instance.  For this to work, a test result must have been
  -- provided as an argument to the test method call.  This will have happened
  -- when the test method is named with a trailing "replyAssert" marker.  Also
  -- note that for these types of failure the test method will continue to run
  -- as it is not being stopped by a raised SNYTAX.  To further support this,
  -- the framework makes method addFailure UNGUARDED.
  frames = .context~stackframes
  bottom = frames[frames~last]
  -- is this a REPLY thread to which we provided  a test result argument?
  if bottom~type == "METHOD", bottom~name~caselessEndsWith("replyAssert") then do
    data~className = self~class~id
    data~testName = bottom~name
    data~setLine(bottom~line)
    result = bottom~arguments[1] -- retrieve our test result object
    result~addFailure(self, data)
  end
  else do
    msg = "ooRexxUnit.cls - source of syntax exception 'FAIL' method invocation in class 'ASSERT'."
    RAISE syntax 93.964 array (msg, data)
  end


::attribute conditionExpected private
::attribute conditionName private
::attribute conditionCode private
::attribute conditionMsg private
::attribute conditionAdditional private


::method clearCondition
  self~conditionExpected = .false
  self~conditionName = .nil
  self~conditionCode = .nil
  self~conditionMsg = .nil
  self~conditionAdditional = .nil

/** expectSyntax()
 * The syntax error code to expect is required.
   We allow both a String specifying the error code or an Array with
   the first item being the error code and any following items the
   message inserts.
 */
::method expectSyntax
  use strict arg errorCode, msg = .nil

  self~conditionExpected = .true
  self~conditionName = "SYNTAX"
  if errorCode~isA(.String) then       -- error code only
    self~conditionCode = errorCode
  else do                              -- error code plus message inserts
    self~conditionCode = errorCode[1]
    self~conditionAdditional = errorCode~section(2)
  end
  self~conditionMsg = msg


/** expectCondition()
 * Only the name of the condition is required, and it can be two words.  E.g.
 * "USER SOMETHING"
 */
::method expectCondition
  use strict arg name, msg = .nil

  self~conditionExpected = .true
  self~conditionName = name
  self~conditionMsg = msg


/** checkCondition()
 * Return true if the condition raised matches the condition expected, otherwise
 * return false.
 */
::method checkCondition

  use arg receivedCondition

  if self~conditionExpected, self~conditionName == receivedCondition~condition then do
     -- For a syntax error, the actual error code has to match the expected error code.
     -- We also check if any given message inserts match the returned additional object.
     if self~conditionName == "SYNTAX", -
      self~conditionCode \= receivedCondition~code | -
      \self~checkAdditional(receivedCondition, self~conditionAdditional) then
         return .false
      self~fAssertions += 1
      return .true
  end
  return .false


/** checkAdditional()
 * Returns true if expected additional info matches received additional info.
 */
::method checkAdditional
  use strict arg conditionReceived, additionalExpected

  if additionalExpected~isNil then -- no message inserts were supplied
     return .true
  additionalReceived = conditionReceived["ADDITIONAL"]
  if \additionalReceived~isA(.Array) then
     return .false -- a SYNTAX error should always supply an ADDITIONAL Array

  -- only check expected message inserts
  -- no ned for the assert call to specify all received inserts
  do i = 1 to additionalExpected~items
     if additionalReceived[i] \== additionalExpected[i] then
        return .false
  end
  return .true

/** check4ConditionFailure()
 * Forces an assert failure if a condition is expected to be raised.  The
 * assumption is that this method is invoked when a condition has not been
 * raised.
 */
::method check4ConditionFailure

  if self~conditionExpected then do
     expected = self~conditionName
     type = 'expectCondition'

     if expected == "SYNTAX", self~conditionCode <> .nil then do
        expected = expected self~conditionCode
        type = 'expectSyntax'
     end

    data = .AssertFailure~new(timeStamp(), self~definedInFile, type)

    data~expected = expected
    data~actual = "Not raised"
    if self~conditionMsg <> .nil then data~msg = self~conditionMsg
    else data~msg = ""

    self~fail(data)
  end


::method makeFailure private
  use strict arg expected, actual, msg, type

  data = .AssertFailure~new(timeStamp(), self~definedInFile, type)

  if expected~isA(.string), expected~left(1) == "[", expected~right(1) == "]" then
    data~expected = expected
  else
    data~expected = self~formatObjectInfo(expected)

  if actual~isA(.string), actual~left(1) == "[", actual~right(1) == "]" then
    data~actual = actual
  else
    data~actual = self~formatObjectInfo(actual)

  data~msg = msg

  return data


::method formatObjectInfo private
  use arg o, hint = ""

  if o~isA(.Array) then do
    string = o~makeString(, ", ")
    if string~length < 200 then
      string = "an Array (" || ppp(string) || ")"
    else
      string = "an Array with" o~items "items"
  end
  else
    string = ppp(o~string)
  return hint || string


::method exclusiveOr private
  use strict arg t1, t2

  if \ t1~isA(.string) | \ t2~isA(.string) then return .false
  if \ t1~datatype('O') | \ t2~datatype('O') then return .false

  -- t1 and t2 are both logicals, for exclusive or they must be different
  -- logicals.
  return (t1 \== t2)


::method exclusiveOrObject private
  use strict arg one, other, actual

  if one == actual, other == actual then return .false
  if one \== actual, other \== actual then return .false
  return .true



/* *********************************************************************************** */
/* *********************************************************************************** */
::class "TestCase" public inherit "Assert"

::attribute defaultTestResultClass class
::attribute caseInfo class

::method init class
  self~defaultTestResultClass=.TestResult -- set default: use TestResult class
  self~caseInfo=.directory~new
  forward class (super)


::method init        -- constructor
  expose fName fCountTestCases    -- name of Testcase (method) to carry out
  use strict arg fName = ""
  fName = fName~string

  fCountTestCases=0  -- default: no test cases counted yet
  self~caseInfo=.directory~new -- directory to contain information on test

  clzTCI=self~class~caseInfo    -- get access to clz' 'caseInfo' dir
  s=clzTCI~entry("test_Case-source")
  if .nil<>s then                   -- if source available, memorize fully qualified file name
     self~definedInFile=s
  else
    self~definedInFile="n/a_"self~identityHash -- indicate that no file name available

  self~init:super   -- let superclass initialize


::method caseInfo attribute                 -- ooRexxUnit only


::method createResult      -- creates a default TestResult object
  -- Use the default class in the environment, if it exists, before using the
  -- self~class~defaultTestResultClass.
  if .local~hasEntry("ooRexxUnit.default.TestResult.Class"~upper) then do
    if .ooRexxUnit.default.TestResult.Class~isA(.class) then
      return .ooRexxUnit.default.TestResult.Class~new
  end
  return self~class~defaultTestResultClass~new

::method "countTestCases=" private  -- set method
  expose  fCountTestCases
  use arg fCountTestCases


::method countTestCases -- return nr. of test cases (methods) in this class
  expose fCountTestCases
  return fCountTestCases


::method execute            -- will get implemented in subclasses
  expose fName
  use arg aTestResult, bGiveFeedback=.false

  if \datatype(bGiveFeedback,"O") then
     raise syntax 93.903 array (bGiveFeedback) -- raise error

   -- make sure an instance of .TestResult is used
  if arg(1, 'O') then aTestResult=self~createResult
  else aTestResult=arg(1)

  aTestResult~startTest(self)       -- remember test started
  self~setUp                        -- make sure setup is invoked before test
  if bGiveFeedback then
     .error~say(".. Executing" self~string)

 -- make sure the output streams are in default state
 .output~destination(.stdout)
 .error~destination(.stderr)
 .traceoutput~destination(.error)

 -- save the current directory in case the test cases change it
  currentDirectory = directory()

  self~doTheTest(fName, aTestResult)  -- carry out the testmethod

  -- restore the current directory
  call directory currentDirectory

 -- make sure the output streams are in default state
 .output~destination(.stdout)
 .error~destination(.stderr)
 .traceoutput~destination(.error)

  self~tearDown                       -- make sure tearDown is invoked after test
  aTestResult~endTest(self)           -- remember test ended

  return aTestResult

::method doTheTest private
   use arg methodName, aTestResult

   -- Trap all conditions propagated from the invocation of the test case
   -- method, or from the check4ConditionFailure method.
   signal on any name exceptionHandler


   -- The test case method itself is invoked by creating a message object and
   -- sending it to ourself.

   -- Tests which run assertXxxx() method calls in threads spawned by the REPLY
   -- instruction require special handling.  As REPLY threads run at the base
   -- base of the stack, we cannot raise SYNTAX.  Instead, we directly modify
   -- our test result instance.  For this to work, we have to supply the test
   -- result as an argument to the test method call.  But as existing test
   -- groups like USE.testGroup rely on the fact that test methods have no
   -- arguments, we only supply this argument if the test method is named with
   -- a trailing "replyAssert" marker.
   if methodName~caselessEndsWith("replyAssert") then
     .message~new(self, methodName)~send(, aTestResult)
  else
     .message~new(self, methodName)~send

   -- The test case method completed without raising a condition.  The last step
   -- is to check if the test case *exepected* a condition to be raised.
   self~check4ConditionFailure
   return aTestResult

exceptionHandler:

  -- Get the condition object.  (The condition object is a Directory object.)
  cObj = condition("O")

  -- If a condition was expected to be raised AND this condition matches the
  -- expected condition, then the test passed so just return.
  if self~conditionExpected, self~checkCondition(cObj) then return aTestResult

  -- If the condition code is 93.964 then this condition was raised by the
  -- framework to signal a test case failure.  The assert failue object is at
  -- index 2 of the additional array.
  if cObj~code = 93.964 then do
    data = cObj~additional[2]

    -- It does not seem conceivable that data is not the object I think it is.
    -- The best thing to do would be to check if it is an AssertFailure object
    -- and, if not, create an ErrorReport object and do aTestResult~addError()
    -- Skipping that for now.

    data~className = self~class~id
    data~testName = self~getName
    data~testString = self~string
    data~conditionObject = cObj
    data~additionalObject = self
    aTestResult~addFailure(self, data)
  end
  else do
    -- This is an unexpected, unanticipated error.
    type = cObj~condition
    if cObj~hasentry("CODE") then type = type cObj~code

    err = .ErrorReport~new(timeStamp(), self~definedInFile, type, cObj)
    err~className = self~class~id
    err~testName = self~getName
    err~testString = self~string
    err~additionalObject = self
    aTestResult~addError(self, err)
  end

  return aTestResult

::method disableOutput
  .output~destination(.NullOutput~new)

::method disableError
  .error~destination(.NullOutput~new)

::method disableTraceOutput
  .traceOutput~destination(.NullOutput~new)

::method enableOutput
  .output~destination(.stdout)

::method enableError
  .error~destination(.stderr)

::method enableTraceOutput
  .traceOutput~destination(.error)


::method getName     -- returns the name for this TestCase
  expose fName
  return fName

::method setName     -- set the name for this TestCase
  expose fName
  parse arg fName

/** Create a string representation of this test case, a counterpart to Java's
 *  toString()
 */
::method string
  className=self~class~id   -- get class name
  return filespec("name", self~definedInFile) "test case" self~getName


/** setUp()
 * setUp is invoked immediately prior the invocation of *each* individual test
 * case method.  If needed, subclasses of TestCase can implement this method to
 * provide some type of pre-test set up.  Normally this is not needed.
 *
 * NOP is used to indicate that this method body is empty on purpose.
 */
::method setUp
  NOP

/** tearDown()
 * tearDown is the counter-point to setUp.  It is invoked immediately after the
 * invocation of *each* individual test case method.  If needed, subclasses of
 * TestCase can implement this method to provide some type of post-test clean
 * up.  Normally this is not needed.
 *
 * NOP is used to indicate that this method body is empty on purpose.
 */
::method tearDown
  NOP

/** dataItem
 * dataItem extracts an embedded set of data from the test classes.  The data
 * is in the form of a method that embeds the data as comment in the method code.
 * The first line of the method must be the line "return /*".  The last line must
 * be the line "*/ return".  All lines between the two delimiters are returned as
 * an array of data.
 *
 * The target method must begin with the characters "data" and is requested using
 * the name without the modifier.  For example, a dataitem named "xml1" would be
 * contained in an instance method named "dataxml1" and would be requested using
 * lines = self~dataitem("xml1")
 */
::method dataItem -- deprecated, use ::RESOURCE directive instead
  use strict arg name

  method = self~instanceMethod("DATA"||name~upper)
  self~assertNotNull(method, "Method DATA"||name~upper "not found")
  source = method~source
  self~assertTrue(source~size > 2, "Data item method does not contain correct data")
  -- extract the middle section of the data and return as an array
  return source~section(2, source~size - 2)

/* *********************************************************************************** */
/* *********************************************************************************** */
::class "TestSuite" subclass TestCase public

::attribute testQueue private

::method init

  forward class (super) continue
  self~testQueue = .queue~new

      -- a class object, use reflection and create test cases
  if arg()>0 then       -- args there ?
  do
     use strict arg arg1    -- make sure, only one arg supplied

     if isSubClassOf(arg1~class, "TestSuite") then -- a TestSuite object ?
     do
        self~addTest(arg1)                -- just add it
        return
     end

      -- a TestCase class object in hand?
     else if arg1~isA(.class), isSubClassOf(arg1, "TestCase") then
     do
        testCaseClass=arg1
        testMethods=self~class~getTestMethods(testCaseClass)
        do name over testMethods          -- iterate over all test methods
           self~addTest(testCaseClass~new(name))
        end
        return
     end

      -- a collection of individual TestCase objects to add?
     else if arg1~isA(.Collection) then
     do
        do tc over arg1~makeArray         -- iterate over test cases
           if isSubClassOf(tc~class, "TestCase") then
              self~addTest(tc)
           else
              raise syntax 88.914 array ("'collection item ["tc"]'", "'TestCase' or 'TestSuite'")
        end
        return
     end
     raise syntax 88.914 array ("1", "'TestCase', 'TestSuite' or 'Collection'")
  end
  return


::method getTestMethods class -- use reflection to retrieve testmethods, sort alphabetically
  use strict arg classObj

  if \ classObj~isA(.class) then
    raise syntax 88.914 array ("1 'classObj'", 'Class')

  -- Get the test methods names.  By convention this is all methods starting
  -- with "TEST".  We use a set because there may be duplicates in the
  -- class hierarchy
  testMethodNames = .set~new

 -- Get all methods that start with "TEST", even ones from the superclasses
 -- Some tests might have method overrides that test different variants of
 -- the base test methods
  methSupplier = classObj~methods
  do while methSupplier~available -- iterate over supplied methods
     name = methSupplier~index
     if name~left(4)="TEST" then testMethodNames~put(name)
     methSupplier~next
  end

  return testMethodNames~makearray~sort


::method addTest
  use strict arg aTestCase

  if \isSubClassOf(aTestCase~class, "TestCase") then
     raise syntax 88.914 array ("'aTestCase'", "'TestCase' or 'TestSuite'")

  self~testQueue~queue(aTestCase)
  self~countTestCases += 1


::method execute
  use arg aTestResult = (self~createResult), bGiveFeedback = .false

  if \ isBoolean(bGiveFeedback) then
    raise syntax 88.916 array ("2 'bGiveFeedback'", "true or false", bGivefeedback)

  if bGiveFeedback then
     .error~say( "running testSuite" pp(self~string"@"self~identityHash) "with" pp(self~countTestCases) "test cases ...")

  tests = self~testQueue

  aTestResult~startTest(self)       -- remember test started
  self~setUp                        -- make sure setup is invoked before testSuite runs
  do aTestCase over tests while aTestResult~shouldStop=.false
     aTestCase~execute(aTestResult, bGiveFeedback)
  end
  self~tearDown                     -- make sure tearDown is invoked after testSuite ran
  aTestResult~endTest(self)         -- remember test ended

  return aTestResult


/** setUp()
 * setUp is invoked immediately prior to the invocation of this test suite's
 * execute() method.  That means it will be invoked exactly once prior to the
 * execution of the tests contained in this test suite.
 *
 * Subclass the TestSuite class and implement a setUp method to provide a method
 * that will run prior to the execution of all tests the test suite contains.
 *
 * NOP is used to indicate that this method body is empty on purpose.
 *
 * Note:  When subclassing the TestSuite, do not inovke the superclass setUp()
 * method.  That will invoke the TestCase setUp() method, which is normally not
 * what is desired.
 */
::method setUp
  NOP

/** tearDown()
 * tearDown is the counter-point to setUp.  It is invoked immediately after the
 * execution of all test cases contained by this test suite has finished.
 *
 * Subclasses of TestSuite can implement this method to provide some a clean up
 * method that is invoked after all the test cases have been executed.
 *
 * NOP is used to indicate that this method body is empty on purpose.
 *
 * Note:  When subclassing the TestSuite, do not inovke the superclass
 * tearDown() method.  That will invoke the TestCase tearDown() method, which is
 * normally not what is desired.
 */
::method tearDown
  NOP


/* *********************************************************************************** */
/* *********************************************************************************** */
-- routines

/* *********************************************************************************** */
/* *********************************************************************************** */
::routine iif public -- utility routine
  if arg(1)=.true then return arg(2)
                  else return arg(3)



-- shallow comparison of two Collections, no recursive testing
::routine isCollectionEqual
  use arg expected, actual

  if -
    expected~items == actual~items, -
    expected~allIndexes~makeString == actual~allIndexes~makeString, -
    expected~allItems~makeString == actual~allItems~makeString
    then return .true
    else return .false

-- check if both Collections have the same items, but in a potentially different order
::routine isCollectionEquivalent
  use arg expected, actual

  return actual~equivalent(expected)


/* *********************************************************************************** */
/* *********************************************************************************** */
/* *********************************************************************************** */
/* *********************************************************************************** */
   -- parse file-info into the supplied directory object
   /*
      uses the information about the program in the very first block-comment at the top:

      - keyword":" text
            if keyword starts with "changed", "purpose", "remark", "link", "category" then
            entry is a queue and text will get enqueued at the end it; the first four letters
            are used for matching these words

      - arrLines:

   */
::routine makeDirTestInfo public
   use arg aTestCaseClass, arrLines

   tmpDir=aTestCaseClass~caseInfo   -- get directory object to add infos to

   keyWord=""
   tOut=xrange("A","Z")||xrange("a","z")
   tIn =xrange("A","Z")||xrange("a","z")||xrange()

   do i=1 to arrLines~items while arrLines[i]<>"*/"
      if arrLines[i]~strip~left(2)="--" then iterate    -- ignore comment

         -- a keyWord already set and this line has no new keyword, than append it
      if pos(":", arrLines[i])=0 then
      do
         if keyWord<>"" then  -- alreay a keyWord found, append line to it
         do
            tmpDir~entry(keyWord)~queue(arrLines[i])
         end
         iterate
      end


      parse value arrLines[i] with name ":" rest

      keyWord=name~translate(tOut, tIn)~space(0)   -- a keyWord change ?

      if tmpDir~hasEntry(keyWord)=.false then
         tmpDir~setentry(keyWord, .queue~new)      -- create a new queue for this keyword

      tmpDir~entry(keyWord)~queue(rest~strip)      -- add line
   end



   -- create a testSuite object by calling the supplied testCaseFileList; needs testCase programs
   -- modelled after the example programs
::routine makeTestSuiteFromFileList public
   use arg testCaseFileList, ts

   if arg(2, "Omitted") then  -- no TestSuite object supplied?
      ts=.testSuite~new

      -- make sure, that the tests are not run when CALLing/REQUIRE'ing the testUnit programs
   .local~bRunTestsLocally=.false   -- do not run tests, if calling/requiring the testUnit files

   do fileName over testCaseFileList
/*
       call (fileName)        -- call file
       testUnitList=result    -- retrieve result (a list of array objects)
*/
       testUnitList=callTestUnit(fileName)

       do arr over testUnitList  -- loop over array objects
          classObject   =arr[1]  -- a class object
          mandatoryTests=arr[2]  -- a list

          -- check whether mandatory tests are defined
          bMandatoryTests=(.nil<>arr[2])
          if bMandatoryTests=.true then   -- o.k. not .nil in hand
          do
             bMandatoryTests=(.list=mandatoryTests~class)   -- is there a list in hand
             if bMandatoryTests then
             do
                bMandatoryTests=(mandatoryTests~items>0)    -- are there any entries?
             end
          end

          if bMandatoryTests then   -- mandatory tests available, just use them to create testCases
          do
            tsMand=.testSuite~new     -- create a test suite for this test class
            do testMethodName over mandatoryTests
               tsMand~addTest( classObject~new(testMethodName) )   -- create and add testCase
            end
            ts~addTest(tsMand)      -- now add the test suite of mandatory methods to the overall test suite
          end
          else    -- no mandatory tests defined, hence use all testmethods
          do
             ts~addTest(.testSuite~new(classObject))  -- creates testCases from all testmethods
          end
       end
   end
   return ts      -- return the testSuite object


callTestUnit: procedure -- rgf, 2007-04-28: possible, that a ::requires causes program to fail
   parse arg fileName
   signal on syntax
   call (fileName)      -- call file
   return result        -- return its return value

syntax:
   .error~say("ooRexxUnit's routine 'makeTestSuiteFromFileList', 'callTestUnit()':")
   .error~say("    testUnit-file: ["fileName"]")
   .error~say(ooRexxUnit.formatConditionObject(condition("O")))

   return .array~new    -- return empty array so no testsuite gets built for this testUnit



/* Determine and return the shell name to be used in ADDRESS keyword statements. This
   is a central location to make it easy to maintain in the future, in case a non-Windows
   and non-Unix compatible operating systems comes up, or new shell variants develop.
*/
::routine ooRexxUnit.getShellName public

   parse upper source os .

      -- make sure we address the shell
   shell="CMD"          -- default to the Windows shell
   if \os~abbrev("WIN") then    -- if not running under Windows assume Unix
   do
      unixShell=value("SHELL", , "environment")    -- get the fully qualified shell
      shell=substr(unixShell, 1+lastpos("/", unixShell))    -- extract name of shell
   end

   return shell

/* Determine and return the operating system under which the currently executing
   program is running.  Provides an uniform method for test cases to determine
   which operating system they are executing on.
*/
::routine ooRexxUnit.getOSName public

  parse upper source os .
  if os~abbrev("WIN") then os = "WINDOWS"
  return os



/* Returns a string containing the directory entries in sorted order. In case an entry
   is a colleciton itself, its elements will be returned as strings.
*/
::routine ooRexxUnit.formatConditionObject public  /* dump condition object */
   use arg co

   arr=co~allIndexes~~stableSortWith(.CaselessComparator~new)
   len=length(arr~items)
   indent1=12
   sumIndent=len+indent1+2

   blanks=copies(" ", sumIndent) "--> "
   res=.mutableBuffer~new

   NL="0a"x
   TAB1="09"x
   TAB2=TAB1~copies(2)
   TAB3=TAB1~copies(3)
   TAB4=TAB1~copies(4)

   do index over arr
      o=co~entry(index)
      if o~isA(.Collection) then items=o~items
                            else items=""

      tmpString=.MutableBuffer~new

      tmpString~~append(TAB3)~~append(index~left(indent1,"."))~~append(pp(o))
      if items<>"" then tmpString~~append(" containing ")~~append(items)~~append(" item(s)")

      if res~length=0 then    -- first value to assign
      do
         res~~append(tmpString~string)
      end
      else                    -- value already available
      do
         res~~append(NL)~~append(tmpString~string)
      end

      if items<>"" then       -- a collection object in hand?
      do
         nr=0
         do item over o       -- list items
            nr=nr+1
            res~~append(NL)~~append(TAB3)~~append(blanks)~~append(pp(item))
         end

         res~~append(TAB3)
      end
   end
   return res~string


pp: procedure
   use arg a
   if .nil=a then return ".nil"
   return "[" || a~string || "]"


   -- simple dumping of the testResult data
::routine simpleDumpTestResults public
   use arg aTestResult, title = ""

   f = .SimpleFormatter~new(aTestResult, title)
   f~print


/**
 * Public routine simpleFormatTestResults()
 *
 *  Variation on simpleDumpTestResults() that formats the result output in a
 *  more "console-friendly" manner.  The information is broken up into lines,
 *  with an attempt made to keep all lines no longer than 80 characters wide.
 */
::routine simpleFormatTestResults public
   use arg aTestResult, title = ""

   f = .SimpleConsoleFormatter~new(aTestResult, title)
   f~print

return 0

-- a class for creating/deleting temporary test files
::class TemporaryTestFile subclass File public
::method init
  expose package
  use strict arg host = .nil, name

  -- let's see where we create the temporary file
  if host == .nil then do
    -- create the file in the user's temp folder
    package = .nil
    dir = .File~temporaryPath
  end
  else if host~isA(.File) then do
    -- create the file in the given location
    package = .nil
    dir = host
  end
  else do
    -- create the file in the same location as the package
    if host~isA(.Class) then
      package = host~package -- we've been called from a class method
    else
      package = host~class~package
    dir = .File~new(package~name)~parentFile
  end

  self~init:super(name, dir)

-- get the full resolved name of this file
::method fullName
  forward message "absolutePath"

-- get the quoted name of this file
::method quotedName
  return '"' || self~absolutePath || '"'

-- create a file from an array of lines
::method create
  use strict arg lines = ""

  s = .stream~new(self)
  -- allow to create zero-length files
  s~open("write replace")

  if lines~isA(.String) then do
    s~charOut(lines)
  end
  else do
    s~arrayout(lines)
  end
  s~close
  return self

-- append an array of lines to a file
::method append
  use strict arg lines

  s = .stream~new(self)
  s~open('WRITE APPEND')
  if lines~isA(.String) then do
    s~lineout(lines)
  end
  else do
    s~arrayout(lines)
  end
  s~close
  return self

-- read file into array
::method arrayIn
  use strict arg

  s = .stream~new(self)
  s~open("read shared")
  array = s~arrayIn
  s~close
  return array

-- create a file from a package resource
::method createFromResource
  expose package
  use strict arg resourceName

  return self~create(package~resources[resourceName~upper])

-- append a package resource to a file
::method appendFromResource
  expose package
  use strict arg resourceName

  return self~append(package~resources[resourceName~upper])

-- delete the file
::method delete
  use strict arg
  self~setWritable
  forward class (super)

-- clean up the temporary file after termination.
::method uninit
  self~setWritable
  self~delete

-- a class for creating/deleting temporary test directories.
::class TemporaryTestDirectory subclass File public
::method init
  use strict arg host, name

  -- let's see where we create the temporary file
  if host == .nil then do
    -- create the file in the user's temp folder
    package = .nil
    dir = .File~temporaryPath
  end
  else if host~isA(.File) then do
    -- create the file in the given location
    package = .nil
    dir = host
  end
  else do
    -- create the file in the same location as the package
    if host~isA(.Class) then
      package = host~package -- we've been called from a class method
    else
      package = host~class~package
    dir = .File~new(package~name)~parentFile
  end

  self~init:super(name, dir)

-- get the full resolved name of this directory
::method fullName
  forward message "absolutePath"

-- create the directory
::method create
  self~makeDir
  return self

-- delete the directory
::method delete
  use strict arg

--self~deleteDir(self) -- a full tree delete is way too dangerous
  self~setWritable
  forward class (super)

-- delete a directory and all of the files in the directory
::method XXX_deleteDir private
  use arg dir

  files = dir~listFiles
  if files == .nil then do
    return
  end

  do f over files
    -- recursively delete directories
    if f~isDirectory then do
      self~deleteDir(f)
    end
    -- make sure this is a writable file
    if f~isReadOnly then do
      f~setWritable
    end
    -- delete the file now
    f~delete
  end

-- clean up the temporary directory after termination.
::method uninit
  self~delete

-- a dummy class for disabling output to .output, .error. or .traceOutput
::class NullOutput
::method lineout
  return 0
::method say


::options novalue syntax
