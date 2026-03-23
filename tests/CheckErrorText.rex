/******************************************************************************/
/*                                                                            */
/* CheckErrorText.rex - Verify ANSI.ErrorText.cls is up to date              */
/* ==========================================================                */
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
/* 20260317    0.5  First version                                             */
/*                                                                            */
/******************************************************************************/

/* Callable as: Call "CheckErrorText.rex" binDir, resourcesDir, fix          */
/*                                                                            */
/* binDir       — path to bin/ (where ANSI.ErrorText.cls lives)               */
/* resourcesDir — path to bin/resources/ (where rexxmsg.xml lives)            */
/* fix          — .true to regenerate if out of date, .false to just check    */
/*                                                                            */
/* Returns 1 if ANSI.ErrorText.cls is up to date (or was fixed).              */
/* Returns 0 if out of date and fix is .false.                                */

  Use Strict Arg binDir, resourcesDir, fix

  sl = .File~separator

  rexxMsg    = resourcesDir || sl"rexxmsg.xml"
  target     = binDir || sl"ANSI.ErrorText.cls"
  genScript  = .context~package~name
  genScript  = genScript~left(genScript~lastPos(sl))"GenErrorText.rex"

  -- Generate to a temporary file
  tmpFile = SysTempFileName(Value("TMP",,"ENVIRONMENT")||sl"ansi-errortext-??????.cls")

  Address SYSTEM "rexx" genScript rexxMsg ">" tmpFile
  If rc \== 0 Then Do
    Say "  ERROR: GenErrorText.rex failed (rc ="rc")."
    Call SysFileDelete tmpFile
    Return 0
  End

  -- Read both files
  generated = CharIn(tmpFile, 1, Chars(tmpFile))
  Call Stream tmpFile, "c", "Close"

  current = CharIn(target, 1, Chars(target))
  Call Stream target, "c", "Close"

  -- Normalize line endings for comparison
  generated = generated~changeStr("0d0a"x, "0a"x)
  current   = current~changeStr("0d0a"x, "0a"x)

  If generated == current Then Do
    Call SysFileDelete tmpFile
    Return 1
  End

  -- Files differ
  If \fix Then Do
    Say "  ANSI.ErrorText.cls is OUT OF DATE."
    Say "  Re-run with --fix to regenerate."
    Call SysFileDelete tmpFile
    Return 0
  End

  -- Fix mode: copy the generated file to bin/
  Call SysFileDelete target
  Call SysFileCopy tmpFile, target
  If result \== 0 Then Do
    Say "  ERROR: could not copy generated file to" target "(rc ="result")."
    Call SysFileDelete tmpFile
    Return 0
  End

  Call SysFileDelete tmpFile
  Say "  ANSI.ErrorText.cls has been regenerated."
  Return 1
