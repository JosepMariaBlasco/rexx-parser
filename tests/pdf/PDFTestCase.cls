/******************************************************************************/
/*                                                                            */
/* PDFTestCase.cls - ooTestCase subclass for PDF integration tests            */
/* ===============================================================            */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Provides helper methods for tests that exercise md2pdf.rex:                */
/*                                                                            */
/*   runMd2pdf(fixture)   Run md2pdf.rex on a fixture .md file.               */
/*                        Returns a Directory with entries "rc", "output",    */
/*                        and "pdfFile" (access via ~entry).                  */
/*                                                                            */
/*   pdfInfo(pdfFile)     Run pdfinfo on a PDF file. Returns a Directory      */
/*                        with entries like "pages", "title", "page size".    */
/*                                                                            */
/*   pdfText(pdfFile)     Run pdftotext on a PDF file. Returns the            */
/*                        extracted text as a string.                          */
/*                                                                            */
/*   assertPDF(pdfFile)   Assert that a file is a valid PDF.                  */
/*                                                                            */
/*   assertContains       Assert that text contains a substring.              */
/*   assertNotContains    Assert that text does NOT contain a substring.      */
/*                                                                            */
/* IMPORTANT: Directory~setEntry uppercases keys. Use ~entry() to read        */
/* values back (it is case-insensitive), NOT the [] operator (which           */
/* uses ~at and is case-sensitive).                                           */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260323    0.5  First version                                             */
/* 20260323         Fix: use ~entry() instead of [] for Directory access      */
/*                  Fix: capture output via Stem instead of shell redirect    */
/*                                                                            */
/******************************************************************************/

::Requires "ooTest.frm"

::Class PDFTestCase Subclass ooTestCase Public

/******************************************************************************/
/* Class-level attributes: project directory and fixtures directory.           */
/******************************************************************************/

::Attribute projectDir Class
::Attribute fixturesDir Class

::Method activate Class
  -- Derive project directory from this file's location:
  -- this file is tests/pdf/PDFTestCase.cls, so project root is two up.
  Parse Source . . myPath
  sep = .File~separator
  myDir = .File~new(myPath)~parentFile~absolutePath
  If myDir~right(1) == sep Then myDir = myDir~left(myDir~length - 1)
  testsDir = myDir~left(myDir~lastPos(sep) - 1)
  self~projectDir  = testsDir~left(testsDir~lastPos(sep) - 1)
  self~fixturesDir = myDir || sep || "fixtures"

/******************************************************************************/
/* runMd2pdf: run md2pdf.rex on a fixture and return results.                 */
/*                                                                            */
/* Arguments:                                                                 */
/*   fixture  - filename (e.g. "basic.md") relative to fixtures/              */
/*   options  - optional extra CLI options (default: "")                       */
/*                                                                            */
/* Returns a Directory with entries:                                          */
/*   "rc"      - return code from md2pdf.rex                                  */
/*   "output"  - combined stdout+stderr as a string                           */
/*   "pdfFile" - expected PDF output path                                     */
/******************************************************************************/

::Method runMd2pdf
  Use Strict Arg fixture, options = ""

  sep = .File~separator
  inputFile = self~class~fixturesDir || sep || fixture
  -- md2pdf generates the PDF next to the input file, same name with .pdf
  Parse Var fixture baseName "." .
  pdfFile = self~class~fixturesDir || sep || baseName".pdf"

  -- Remove any leftover PDF from a previous run
  Address System "rm -f" '"'pdfFile'"'

  -- Build the command
  projectDir = self~class~projectDir
  cmd = "rexx" projectDir || sep || "bin" || sep || "md2pdf.rex" -
    '"'inputFile'"' options

  -- Run md2pdf and capture output + return code via shell
  tmpOut = "/tmp/md2pdf-test-output.tmp"
  tmpRC  = "/tmp/md2pdf-test-rc.tmp"
  Address System cmd ">" tmpOut "2>&1; echo $? >" tmpRC
  -- Note: RC from Address System here is the shell's exit code,
  -- not md2pdf's.  We read md2pdf's exit code from tmpRC.

  -- Read md2pdf's return code
  cmdRC = LineIn(tmpRC)~strip
  Call Stream tmpRC, "C", "Close"

  -- Read the output
  output = ""
  Call Stream tmpOut, "C", "Open Read"
  Loop While Lines(tmpOut) > 0
    output ||= LineIn(tmpOut) || "0A"x
  End
  Call Stream tmpOut, "C", "Close"

  Address System "rm -f" tmpOut tmpRC

  response = .Directory~new
  response~setEntry("rc", cmdRC)
  response~setEntry("output", output)
  response~setEntry("pdfFile", pdfFile)

  Return response

/******************************************************************************/
/* pdfInfo: run pdfinfo on a PDF file and return parsed results.              */
/*                                                                            */
/* Returns a Directory with entries using lowercase keys: "title", "pages",   */
/* "page size", "creator", "producer", etc.                                   */
/******************************************************************************/

::Method pdfInfo
  Use Strict Arg pdfFile

  tmpOut = "/tmp/pdfinfo-output.tmp"
  Address System "pdfinfo" '"'pdfFile'"' ">" tmpOut "2>&1"

  info = .Directory~new
  Call Stream tmpOut, "C", "Open Read"
  Loop While Lines(tmpOut) > 0
    line = LineIn(tmpOut)
    Parse Var line key ":" value
    If key \== "" Then
      info~setEntry(key~strip, value~strip)
  End
  Call Stream tmpOut, "C", "Close"
  Address System "rm -f" tmpOut

  Return info

/******************************************************************************/
/* pdfText: run pdftotext on a PDF file and return the extracted text.        */
/******************************************************************************/

::Method pdfText
  Use Strict Arg pdfFile

  tmpOut = "/tmp/pdftotext-output.tmp"
  -- pdftotext with "-" as output sends text to stdout
  Address System "pdftotext" '"'pdfFile'"' "-" ">" tmpOut "2>&1"

  text = ""
  Call Stream tmpOut, "C", "Open Read"
  Loop While Lines(tmpOut) > 0
    text ||= LineIn(tmpOut) || "0A"x
  End
  Call Stream tmpOut, "C", "Close"
  Address System "rm -f" tmpOut

  Return text

/******************************************************************************/
/* assertPDF: assert that a file exists and is a valid PDF.                   */
/******************************************************************************/

::Method assertPDF
  Use Strict Arg pdfFile, label = "File is a valid PDF"

  -- Check file exists
  self~assertTrue(Stream(pdfFile, "C", "Q Exists") \== "", -
    label "— file exists")

  -- Check file type via file command
  tmpOut = "/tmp/file-type-output.tmp"
  Address System "file --brief" '"'pdfFile'"' ">" tmpOut "2>&1"
  fileType = LineIn(tmpOut)
  Call Stream tmpOut, "C", "Close"
  Address System "rm -f" tmpOut

  self~assertTrue(fileType~caselessPos("PDF") > 0, -
    label "— file command reports PDF")

/******************************************************************************/
/* assertContains: assert that text contains a substring.                     */
/******************************************************************************/

::Method assertContains
  Use Strict Arg text, substring, label

  self~assertTrue(text~caselessPos(substring) > 0, label)

/******************************************************************************/
/* assertNotContains: assert that text does NOT contain a substring.          */
/******************************************************************************/

::Method assertNotContains
  Use Strict Arg text, substring, label

  self~assertTrue(text~caselessPos(substring) == 0, label)
