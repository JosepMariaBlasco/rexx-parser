/******************************************************************************/
/*                                                                            */
/* Array.OutputStream.cls -- An array that works as an output stream          */
/* =================================================================          */
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
/* 20250523    0.2b First separate implementation.                            */
/*                                                                            */
/******************************************************************************/

::Class Array.OutputStream Public SubClass Array Inherit OutputStream

::Method Say
  Use Strict Arg string -- We make string not optional
  self~append(string)
  Return 0
