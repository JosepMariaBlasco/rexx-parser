Documentation comments
======================

----------------------------------------

**Documentation comments** or **doc-comments** are a special
form of comment, similar to JavaDoc comments.

Doc-comments can be placed anywhere in the source file.

**Standard doc-comments** start with `"/**` and end with `"*/"`.

~~~rexx {pad=80 patch="element el.doc_comment #000/#c4c"}
/******************************************************************************/
/* This is a set of three classic comments, forming a box.                    */
/******************************************************************************/

/**
 *  This is a doc-comment. It Starts with "/**" and it ends with "*/".
 *  A style patch has been applied to highlight the doc-comment in reverse
 *  fuchsia, and a pad of 80 has been specified as a fenced code block
 *  attribute, to embelish the display.
 */
~~~


**Markdown doc-comments** are contiguous sequences
of line comments starting with exactly three dashes
(that is, with `"---"` but not with `"----"`).

~~~rexx {pad=80 patch="element el.doc_comment_markdown #FF0/#22f"}
--------------------------------------------------------------------------------
-- This is a set of five line comments, forming a box. All the lines are      --
-- recognized as line comments, because they start with either less or more   --
-- than three dashes.                                                         --
--------------------------------------------------------------------------------

---
--- This is a markdown doc-comment. It Starts with "---". A style patch
--- has been applied to highlight the doc-comment in yellow over dark blue,
--- and a pad of 80 has been specified as a fenced code block attribute,
--- to embelish the display.
---
~~~

Documentation comments are always returned as *a single element*.