The Rexx Parser
===============

```
/********************************* WARNING ************************************
 * This version of the Rexx Parser is a work-in-progress. In particular, some *
 * parts of the APIs (like the Tree API) are largely undocumented; they will  *
 * be defined at a later stage of the package development.                    *
 ******************************************************************************/
```

The Rexx Parser is hosted on:

- <https://rexx.epbcn.com/rexx-parser/> (daily builds *and* releases,
  full documentation).
- <https://github.com/JosepMariaBlasco/rexx-parser/> (releases only,
  documentation is partial due to the limitations of GitHub highlighting).

The documentation copy at <https://rexx.epbcn.com/rexx-parser/> uses
the Rexx Highlighter to display Rexx programs, and therefore has better
highlihting. On the other hand, the copy at
<https://github.com/JosepMariaBlasco/rexx-parser/>
has version control, bug reporting, and all the features offered by GitHub.

**Beware**: some of the program listings that appear in this documentation
will not display at all in the GitHub version, as GitHub does not implement
the `source` attribute for Rexx fenced code blocks.

~~~rexx {.numberLines startfrom=93 unicode}
/*******************************************************************************/
/* This is a sample Rexx code fragment, numbered, starting at line 93.         */
/* It shows many of the features of the Rexx Parser.                           */
/*******************************************************************************/

/**
 * This is a doc-comment, a special form of comment, similar to JavaDoc.
 * It must appear immediately before a directive or a callable label.
 */
::Method myMethod Package Protected     -- Bold, underline, italic
  Expose x pos stem.

  a   = 12.34e-56 + " -98.76e+123 "     -- Highlighting of numbers
  len = Length( Stem.12.2a.x.y )        -- A built-in function call
  pos = Pos( "S", "String" )            -- An internal function call
  Call External pos, len, .True         -- An external function call
  .environment~test.2.x = test.2.x      -- Method call, compound variable

  Exit "नमस्ते"G,  "P ≝ 𝔐",  "🦞🍐"     -- Unicode strings

---
--- When a doc-comment starts with "---", it's a _Markdown_ doc-comment.
---
Pos: Procedure                          -- A label
  Return "POS"( Arg(1), Arg(2) ) + 1    -- Built-in function calls
~~~

The **Rexx Parser** is a full Abstract Syntax Tree (AST)
parser for Rexx and ooRexx written by Josep Maria Blasco
&lt;<josep.maria.blasco@epbcn.com>&gt; and distributed
under [the Apache 2.0 license](LICENSE). Some files may
contain contributions from other authors, as attributed
in the corresponding copyright notices.

Current version and downloads {#download}
-----------------------------

The current release is beta 0.2c, refresh 20250531.
You can download it <a href="Rexx-Parser-0.2c-20250531.zip">here</a>.
Daily builds can be found at <https://rexx.epbcn.com/rexx-parser/>.

- [Version history](doc/history/).
- [Next releases](doc/todo/).

The Rexx Parser is also distributed as part of **net-oo-rexx**,
a software bundle curated by Rony Flatscher and consisting of
several different Rexx- (and NetRexx-) related packages.
The net-oo-rexx package can be downloaded at
<https://wi.wu.ac.at/rgf/rexx/tmp/net-oo-rexx-packages/>.

Documentation
-------------

You may be interested in browsing our [documentation](doc/).
In particular, you may want to use one the following quick links:

- [Installation and first steps](doc/guide/install/).
- [Utitities](doc/samples/) and [consistency tests](tests/).
- [Error handling](doc/guide/errors/).

Child projects
--------------

### The Rexx Highlighter

The [**Rexx Highlighter**](doc/highlighter/) is a child project
of the Rexx Parser. Developed around a common code base,
it will include output drivers for HTML, ANSI Terminals,
and LaTeX.

- [Features common to all](doc/highlighter/features/) highlighters.
- Variants:
  - [The HTML Highlighter](doc/highlighter/html/).
  - [The ANSI Terminal Highlighter](doc/highlighter/ansi/).
  - [The LaTeX Highlighter](doc/highlighter/latex/).






