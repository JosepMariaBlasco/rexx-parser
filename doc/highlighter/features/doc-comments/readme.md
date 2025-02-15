Documentation comments
======================

----------------------------------------

**Documentation comments** or **doc-comments** are a special
form of comment, similar to JavaDoc comments.

Doc-comments can be placed before a directive, or before a callable label.

**Standard doc-comments** start with `"/**` and end
with `"*/"`.

~~~rexx {pad=80 patch="element el.doc_comment #000/#c4c"}
/******************************************************************************/
/* This is a set of three classic comments, forming a box.                    */
/******************************************************************************/

/**
 *  This is a doc-comment. It Starts with "/**" and it ends with "*/", and it
 *  is placed immediately before a directive. A style patch has been applied
 *  to highlight the doc-comment in reverse fuchsia, and a pad of 80 has been
 *  specified as a fenced code block attribute, to embelish the display.
 */
::Routine R
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
--- This is a markdown doc-comment. It Starts with "---", and it is placed
--- immediately before a callable label. A style patch has been applied
--- to highlight the doc-comment in yellow over dark blue, and a pad
--- of 80 has been specified as a fenced code block attribute,
--- to embelish the display.
---
Proc: Procedure Expose a b c
~~~

Documentation comments are always returned as *a single element*.

- In the case of standard doc-comments, the Rexx Parser
  adds to the element all the whitespace which can
  be found, if any, in the first comment line,
  before the first `"/"` character, and in the last
  line, after the last `"/"` character. The returned
  element has an element category of `.EL.DOC_COMMENT`.
- In the case of Markdown doc-comments,
  the Rexx Parser combines all the line comments,
  and preceding whitespace, if present, into a single element.
  The returned element has an element category of
  `.EL.DOC_COMMENT_MARKDOWN`.
