/******************************************************************************/
/*                                                                            */
/* DebugSettings.cls - Global Rexx Parser debug settings                      */
/* =====================================================                      */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx.parser/]                                  */
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
/*                                                                            */
/******************************************************************************/

If Value(rexx.parser.debug,,environment) \== "" Then Do
  .environment~rexx.parser.debug = 1
  End
Else Do
  .environment~rexx.parser.debug = 0
End