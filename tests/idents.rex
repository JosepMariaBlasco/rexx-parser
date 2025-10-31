/******************************************************************************/
/*                                                                            */
/* idents.rex - Rexx Parser integrity self-test                               */
/* ============================================                               */
/*                                                                            */
/* This program uses the ident.rex tool to check that all the major           */
/* components of the Rexx parser are identical to their own parsing.          */
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
/* 20241206    0.1  First public release                                      */
/* 20241228    0.1d Test all .cls and .rex files in utils/ too                */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/*                  Binary directory is now "bin" instead of "cls"            */
/*                                                                            */
/******************************************************************************/

mypath      =  FileSpec("Location",.context~package~name)
parent      = .File~new(mypath"..")      ~absolutePath
cls         = .File~new(mypath"../bin")  ~absolutePath
HLDrivers   = .File~new(mypath"../bin/HLDrivers")  ~absolutePath
utils       = .File~new(mypath"../utils")~absolutePath

files = .Array~of( )

Do file Over .File~new(cls)~list
  file = .File~new( cls"/"file )
  If file~isDirectory Then Iterate
  file = file~absolutePath
  files~append( file )
End

Do file Over .File~new(samples)~list
  file = .File~new( samples"/"file )
  If file~isDirectory Then Iterate
  file = file~absolutePath
  If file~endsWith(".rex") | file~endsWith(".cls") Then files~append( file )
End

Do file Over .File~new(HLDrivers)~list
  file = .File~new( HLDrivers"/"file )
  If file~isDirectory Then Iterate
  file = file~absolutePath
  If file~endsWith(".rex") | file~endsWith(".cls") Then files~append( file )
End

Do file Over files
  Say "Checking '"file"'..."
  Call Ident file
  If result \== 0 Then Exit 1
End

Exit 0
