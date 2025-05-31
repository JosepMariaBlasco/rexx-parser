/******************************************************************************/
/*                                                                            */
/* SecondPass.cls                                                             */
/* ==============                                                             */
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
/* 20241209    0.1b New call system                                           */
/* 20241225    0.1d Add support for doc-comments                              */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250414         Move BIF info to BIFs.cls                                 */
/* 20250414         Add argument info to called routine chain                 */
/* 20250418    0.2a Support for BIF early checking                            */
/* 20250418         Fix SIGNAL early checking                                 */
/* 20250531    0.2c Move support for doc-comments to Tokenizer.cls            */
/*                                                                            */
/******************************************************************************/

::Requires "BaseClassesAndRoutines.cls"
::Requires "BIFs.cls"

/******************************************************************************/
--
-- * Label and ::Routine collection
-- * Determination of the call types: internal, BIF, ::Routine, external
--
/******************************************************************************/

::Routine SecondPass Public

  Use Strict Arg package

  Call LoadBIFInfo -- Defined in BIFs.cls

  Call ProcessBody package, package~prolog, package~prolog~body

  Do Counter n fragment Over package~directives
    body = fragment~body
    If \ body~isEmpty Then Call ProcessBody package, fragment, body
  End

--------------------------------------------------------------------------------

::Routine ProcessBody

  Use Strict Arg package, fragment, body

  Call CheckCallTypes package, body

  -- Check all SIGNAL and SIGNAL ON instructions.

  bodyLabels    = body~labels

  checkSignal   = 0
  If .Parser.Options~hasIndex( earlyCheck ) Then
    checkSignal = .Parser.Options~earlyCheck~hasItem( signal )

  Do clause Over body~clauses
    Select Case clause~class
      When .Signal.Instruction, .Signal.On.Instruction Then
        If checkSignal Then Call CheckSignal clause, bodyLabels
      Otherwise Nop
    End
  End

  Exit

--------------------------------------------------------------------------------

::Routine CheckSignal

If .rxcheck.debug = 1 Then Trace ?a

  Use Strict Arg clause, bodyLabels

  label = clause~label
  If label == .Nil Then Do -- SIGNAL ON only
    label = clause~condition
    If label~value == "USER" Then label = clause~userCondition
  End
  If \bodyLabels~hasItem( label~value ) Then Signal 16.001

  Return

-- Label "&1" not found.
16.001: Syntax( 16.001, TheElementAfter( clause~begin ), label )

--------------------------------------------------------------------------------

-- Determine the nature of all (non namespace qualified) function
-- and procedure calls, and perform additional checks for BIFs (only
-- if the earlyCheck option is present and contains a BIFs item).

::Routine CheckCallTypes

  Use Strict Arg package, body

  If .Parser.Options~hasIndex( earlyCheck ) Then
    checkBIFs = .Parser.Options~earlyCheck~hasItem( BIFs )
  Else checkBIFs = .False

  bodyLabels = body~labels
  routines   = package~routines

  Do routine Over body~calledRoutineNames
    name = routine[1]
    label = name~value
    type  = name~invocationType
    Select
      When name < .ALL.SYMBOLS, bodyLabels~hasItem(label) Then Do
        Select Case type
          When "FUNCTION" Then subCategory = .INTERNAL.FUNCTION.NAME
          When "CALL"     Then subCategory = .INTERNAL.SUBROUTINE.NAME
        End
      End
      When .Parser.BIF[ label ] \== .Nil     Then Do
        Select Case type
          When "FUNCTION" Then subCategory = .BUILTIN.FUNCTION.NAME
          When "CALL"     Then subCategory = .BUILTIN.SUBROUTINE.NAME
        End
        If checkBIFs Then Call CheckBIFArgs name, routine[2]
      End
      When routines[ label ] \== .Nil Then Do
        Select Case type
          When "FUNCTION" Then subCategory = .PACKAGE.FUNCTION.NAME
          When "CALL"     Then subCategory = .PACKAGE.SUBROUTINE.NAME
        End
      End
      Otherwise Do
        Select Case type
          When "FUNCTION" Then subCategory = .EXTERNAL.FUNCTION.NAME
          When "CALL"     Then subCategory = .EXTERNAL.SUBROUTINE.NAME
        End
      End
    End
    Call SetConstantName name, subCategory
  End
