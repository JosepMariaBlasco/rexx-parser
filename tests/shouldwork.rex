/******************************************************************************/
/*                                                                            */
/* shouldwork.test - A testfile that should not produce any parsing error     */
/* ======================================================================     */
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
/* 20250419    0.2a First public release                                      */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- .o is a bad target, but .o~m is not.                                       --
--------------------------------------------------------------------------------

Use Arg .o~m

--------------------------------------------------------------------------------
-- Nested expression lists should reset their terminators.                    --
--------------------------------------------------------------------------------

x = (+10)                     -- Fails. Reported by JLF. Fixed on 20250419.

--------------------------------------------------------------------------------
-- Attribute bodies are tricky.                                               --
--------------------------------------------------------------------------------

::Class TestClass
::Attribute Attr Class Set
  Expose v1 v2 v3            -- Reported by JLF. Fixed on 20250419.

::Routine R  -- To end previous CLASS

--------------------------------------------------------------------------------
-- Control variable no accepted in LEAVE and ITERATE.                         --
--------------------------------------------------------------------------------

-- Reported by JLF. Fixed on 20250419.

Do i = 1 To n
  If condition Then Leave   i
  If condition Then Iterate i
End

Do Label i j = 1 To n
  If condition Then Leave   i
  If condition Then Iterate i
End

--------------------------------------------------------------------------------
-- Spurious check for control variables in SELECT blocks.                     --
--------------------------------------------------------------------------------

Do Label out i = 1 By 1
  Select
    When 1 Then Leave   Out  -- Traps. Reported by JLF. Fixed on 20250419.
    When 1 Then Iterate Out  -- Traps. Reported by JLF. Fixed on 20250419.
  End
End

--------------------------------------------------------------------------------
-- Test that SIGNAL to an _existing_ label works.                             --
--------------------------------------------------------------------------------

Signal ExistingLabel -- Was failing. Reported by JLF. Fixed on 20250419.
ExistingLabel: Nop

--------------------------------------------------------------------------------
-- Test that different expressions are correctly checked inside BIFs.         --
--------------------------------------------------------------------------------

Say sign(x - y)      -- Was crashing. Reported by JLF. Fixed on 20250419.
Say sign(x y)

--------------------------------------------------------------------------------
-- TRACE needs special handling because of the "?" prefix.                    --
--------------------------------------------------------------------------------

Call Trace "?a"      -- Was failing. Reported by JLF. Fixed on 20250419.


