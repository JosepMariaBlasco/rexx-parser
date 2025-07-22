/******************************************************************************/
/* This is a sample Rexx code fragment, numbered, starting at line 93.        */
/* It shows many of the features of the Rexx Parser.                          */
/******************************************************************************/

/**
 * This is a doc-comment, a special form of comment, similar to JavaDoc.
 */
::Method myMethod Package Protected     -- Bold, underline, italic
  Expose x pos stem.

  a   = 12.34e-56 + " -98.76e+123 "     -- Highlighting of numbers
  len = Length( Stem.12.2a.x.y )        -- A built-in function call
  pos = Pos( "S", "String" )            -- An internal function call
  Call External pos, len, .X, 12.34e+5  -- An external function call
  .environment~test.2.x = test.2.x      -- Method call, compound variable

  Exit "नमस्ते"G,  "P ≝ 𝔐 ",  "🦞🍐"      -- Unicode strings

---
--- When a doc-comment starts with "---", it's a _Markdown_ doc-comment.
---
Pos: Procedure                          -- A label
  Return "POS"( Arg(1), Arg(2) ) + 1    -- Built-in function calls