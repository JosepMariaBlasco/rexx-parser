Documentation comments
======================

----------------------------------------

**Documentation comments** or **doc-comments** are a special
form of comment, similar to JavaDoc comments.

Doc-comments can be placed anywhere in the source file.

**Standard doc-comments** start with `"/**` and end with `"*/"`.

~~~rexx
/******************************************************************************/
/* This is a set of three classic comments, forming a box.                    */
/******************************************************************************/

/**
 *  This is a doc-comment. It is highlighed differently, and the initial
 *  statement (the "summary") gets its own style.
 */

--------------------------------------------------------------------------------

/**
    The initial asterisks are optional. But the starting "/**" and
    the ending "*/" are not.
 */

--------------------------------------------------------------------------------

/** A doc-comment. In a single line. */

--------------------------------------------------------------------------------

/** A doc-comment.
    In two lines, that's also possible. */

~~~


**Markdown doc-comments** are contiguous sequences
of line comments starting with exactly three dashes
(that is, with `"---"` but not with `"----"`).

~~~rexx
--------------------------------------------------------------------------------
-- This is a set of five line comments, forming a box. All the lines are      --
-- recognized as line comments, because they start with either less or more   --
-- than three dashes.                                                         --
--------------------------------------------------------------------------------

---
--- This is a markdown doc-comment. It is highlighted differently.
---
~~~

Documentation comments are always returned as *a single element*.

Doc-comments can be highlighted in _detailed_ mode (the default), or
as a _block_:

~~~rexx {doccomments=block}
--
-- This is a set of normal line comments.
--

---
--- This is a markdown doc-comment. It is highlighted as a block,
--- by specifying "doccomments=block" in the fenced code block.
---
~~~

When detailed highlighting is selected, the following parts
of a doc-comment are recognized:

+ The _armature_: the initial `"/**"`, `"*"` or `"---"`, and
  skippable blanks.
+ The _summary_: the first statement, ended by a period
  followed by a blank, a tab, or a line-end.
+ The _main description_: the rest of the description block,
  after the summary.
+ A _tag block_. Each tag is composed of
  + A _tag name_, starting with a `"@"` character.
  + A _tag value_. Some tags, like `@param` or `@author`, should
    be followed by a tag value, and others, like `@deprecated`,
    are directly followed by an optional text which is a description.
  + An optional _tag description_.

```rexx
--
-- This is a small set of standard line comments
--

---
--- This is a markdown-style doc-comment.
---
--- The main description is styled differently from the summary.
---
--- @param     name          The first line starting with "@" starts the block tag
---                          section. Tag descriptions can span several lines.
--- @author    J. M. Blasco
--- @condition Syntax 47.002 Standard Rexx should not produce such an error.
---
```

The highlighter recognizes only the following tags: `@author`, `@condition`,
`@deprecated`, `@param`, `@return`, `@see`, `@since` and `@version`.
Other annotations will have their tag highlighted and all the rest of the text highlighted
in the style assigned to tag descriptions.
