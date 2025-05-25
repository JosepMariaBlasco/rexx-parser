/******************************************************************************/
/*                                                                            */
/* Rexx.CGI.cls -- Abstract generic Rexx CGI class                            */
/* ===============================================                            */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20250524    0.2b First separate implementation.                            */
/*                                                                            */
/******************************************************************************/

::Requires "Http.Request.cls"
::Requires "Http.Response.cls"
::Requires "Array.OutputStream.cls"

/******************************************************************************/
/******************************************************************************/
/* CLASS REXX.CGI                                                             */
/******************************************************************************/
/******************************************************************************/

::Class Rexx.CGI Public

::Constant  OK   1
::Constant  FAIL 0

::Attribute Content_Type                -- Defaults to "text/html"
::Attribute file         Get            -- Based on PATH_TRANSLATED
::Attribute URI          Get            -- Based on REQUEST_URI

::Method init
  self~init:super
  self~Content_Type = "text/html"


/******************************************************************************/
/* EXECUTE                                                                    */
/******************************************************************************/

::Method Execute

  If \ self~Setup   Then Return self~FAIL
  If \ self~Process Then Return self~FAIL
  If \ self~Done    Then Return self~FAIL

  Return self~OK

/******************************************************************************/
/* SETUP                                                                      */
/******************************************************************************/

--
-- Creates .Request, .Response and .Array.Output, performs various checks.
--
-- If errors are found, emits an error page and returns 0.
-- In such cases, the caller can simply exit, without doing anything.
--
-- Otherwise it returns 1.
--

::Method Setup

  Expose file URI

  ------------------------------------------------------------------------------
  -- We will collect all our output in an array. To this effect, we use       --
  -- a small class that subclasses .Array and at the same time inherits from  --
  -- .OutputStream. Indeed, we only need to implement the SAY method.         --
  --                                                                          --
  -- We change the destination of the output monitor to point to this         --
  -- hybrid array.                                                            --
  ------------------------------------------------------------------------------

 .environment~Array.Output = .Array.OutputStream~new
 .output~destination( .Array.Output )

  ------------------------------------------------------------------------------
  -- We now create .request and .response objects to encapsulate the          --
  -- complexities of the CGI protocol.                                        --
  ------------------------------------------------------------------------------

 .environment~request  = .Http.Request~new
 .environment~response = .Http.Response~new

  ------------------------------------------------------------------------------
  -- If for whatever reason the request creation process failed,              --
  -- we produce an error page and return with a failure code.                 --
  ------------------------------------------------------------------------------

  If .Request~error \== "" Then Call 404 .Request~error

  ------------------------------------------------------------------------------
  -- PATH_TRANSLATED should point to the file we are requested to process,    --
  -- and REQUEST_URI should contain the request URI.                          --
  ------------------------------------------------------------------------------

  file = .request~PATH_TRANSLATED
  URI  = .request~REQUEST_URI

  ------------------------------------------------------------------------------
  -- We need to ensure that the CGI processor has not been called directly;   --
  -- if this happens, the environment strings will be empty. In that case,    --
  -- we produce a soft 404.                                                   --
  ------------------------------------------------------------------------------

  If file == ""         Then Call 404
  If URI  == ""         Then Call 404

  ------------------------------------------------------------------------------
  -- We don't want strangely formatted URIs                                   --
  ------------------------------------------------------------------------------

  If URI~contains("//") Then Call 404
  If URI~contains("/.") Then Call 404
  If URI~contains("..") Then Call 404

  ------------------------------------------------------------------------------
  -- The file should exist in the filesystem; if not, that's a 404 too.       --
  ------------------------------------------------------------------------------

  resolved = Stream(file,"C","Query exists")
  If resolved == ""     Then Call 404

  ------------------------------------------------------------------------------
  -- There is a bug in the Linux version of ooRexx by which trailing slashes  --
  -- are wrongly accepted at the end of a filename. We don't want that.       --
  -- See https://sourceforge.net/p/oorexx/bugs/1940/                          --
  ------------------------------------------------------------------------------

  If file~endsWith("/") Then Do
    file2 = Strip(file,"T","/")
    resolved2 = Stream(file2,"C","Query exists")
    If resolved2 == resolved Then Call 404
  End

  ------------------------------------------------------------------------------
  -- All OK. Set 'file' to the fully resolved filespec and return.            --
  ------------------------------------------------------------------------------

  file = resolved

  Return self~OK

  ------------------------------------------------------------------------------
  -- Emit a 404 error page with an optional status code                       --
  -- and exit returning FAILURE.                                              --
  ------------------------------------------------------------------------------

404:
  Use Arg code = ""
 .Response~404( code )
  Exit self~FAIL

/******************************************************************************/
/* PROCESS                                                                    */
/******************************************************************************/

--
-- This is an ABTRACT method.
--

::Method Process  Abstract

/******************************************************************************/
/* DONE                                                                       */
/******************************************************************************/

::Method Done

  ------------------------------------------------------------------------------
  -- Set the response content type                                            --
  ------------------------------------------------------------------------------

  -- Both headers and body are cached, which allows to modify the
  -- headers up to the last minute.

 .Response~"Content-Type" = self~Content_Type

  ------------------------------------------------------------------------------
  -- We are now done. We only have to revert to normal .stdout, ...           --
  ------------------------------------------------------------------------------

 .Output~destination

  ------------------------------------------------------------------------------
  -- ... emit the stored HTTP headers ...                                     --
  ------------------------------------------------------------------------------

 .Response~printHeaders

  ------------------------------------------------------------------------------
  -- ... and an empty line to separate HTTP headers and HTML body ...         --
  ------------------------------------------------------------------------------

  Say ""

  ------------------------------------------------------------------------------
  -- ... so that we can finally emit the body itself, by dumping              --
  --     the whole .Array.Output array                                        --
  ------------------------------------------------------------------------------

  Do line Over .Array.Output
    Say line
  End

  ------------------------------------------------------------------------------
  -- Now we are really done!                                                  --
  ------------------------------------------------------------------------------

  Return self~OK