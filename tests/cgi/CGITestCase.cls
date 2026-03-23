/******************************************************************************/
/*                                                                            */
/* CGITestCase.cls - ooTestCase subclass for CGI integration tests            */
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
/* 20260323    0.5  First version                                             */
/*                                                                            */
/******************************************************************************/

::Requires "ooTest.frm"

::Class CGITestCase Subclass ooTestCase Public

/******************************************************************************/
/* httpGet: perform an HTTP GET request via curl and return a directory with  */
/* "status" (HTTP status code) and "body" (response body).                   */
/******************************************************************************/

::Method httpGet
  Use Strict Arg url

  response = .Directory~new
  tmpStatus = "/tmp/cgi-test-status.tmp"
  tmpBody   = "/tmp/cgi-test-body.tmp"

  -- Step 1: get HTTP status code (write to temp file)
  Address System "curl -s --noproxy 127.0.0.1 -o /dev/null" -
    "-w %{http_code}" url ">" tmpStatus
  statusCode = LineIn(tmpStatus)
  Call Stream tmpStatus, "C", "Close"
  response~setEntry("status", statusCode~strip)

  -- Step 2: get response body (write to temp file)
  Address System "curl -s --noproxy 127.0.0.1" url ">" tmpBody
  body = .Array~new
  Call Stream tmpBody, "C", "Open Read"
  Loop While Lines(tmpBody) > 0
    body~append(LineIn(tmpBody))
  End
  Call Stream tmpBody, "C", "Close"
  response~setEntry("body", body~makeString("L", "0A"x))

  -- Clean up
  Address System "rm -f" tmpStatus tmpBody

  Return response

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
