::::: title-page

The `article` Document Class <small>A Self-Referencing Guide</small>
====================================================================

::: author
[Josep Maria Blasco](https://www.epbcn.com/equipo/josep-maria-blasco/)
:::

::: affiliation
Espacio Psicoanalítico de Barcelona
:::

::: address
Balmes, 32, 2º 1ª &mdash; 08007 Barcelona
:::

::: email
jose.maria.blasco@gmail.com
:::

::: date
May the 5<sup>th</sup>, 2026
:::

:::::

Notice
======

*This document describes the* `article` *document class for
RexxPub.*[^thisDoc]  *It is itself an* `article.md` *file, rendered
by the same class it documents --- so everything you see on the page
is a live example of the features being described.*

[^thisDoc]: <small>HTML</small> version:
<https://rexx.epbcn.com/rexx-parser/doc/rexxpub/article/>;
<small>HTML</small> <small>PDF</small>-ready printable version:
<https://rexx.epbcn.com/rexx-parser/doc/rexxpub/article/?print=pdf>.

Introduction
============

The `article` document class produces paginated output that closely
follows the conventions of the LaTeX `article` documentclass: DIN A4
portrait pages, Times New Roman typography, justified text with
automatic hyphenation, numbered headings, and footnotes at the bottom
of each page.  It is designed to work with paged.js (in the browser
via `?print=pdf`) and with pagedjs-cli (via `md2pdf` on the command
line).

This document covers the Markdown structure expected by the class,
the typographic choices it makes, the parametric sizing system, and
the CSS architecture that makes it all work.

Markdown structure
==================

The source of an article is a file named `article.md`.  It is
ordinary Pandoc Markdown, with a few conventions enforced by CSS
rather than by code.

The title page
--------------

The title page is built using Pandoc fenced divs.  The outermost div
has the class `title-page`, and it contains nested divs for each
element:

```
::::: title-page

Title of the Article <small>Optional Subtitle</small>
=====================================================

::: author
Author Name
:::

::: affiliation
Institution or Organisation
:::

::: address
Street Address — City, Country
:::

::: email
author@example.com
:::

::: phone
+00 123 456 789
:::

::: date
Month Day, Year
:::

:::::
```

The title itself is an `<h1>` inside the `title-page` div.  It is
centred, set in a larger font (1.7em), with normal weight.  The optional
`<small>` element provides a subtitle in italic.  All other elements
are centred as well, with sizes and spacing designed to resemble
LaTeX's `\maketitle` output.

All elements inside the title page are optional: a minimal title page
needs only the title itself.

Section headings
----------------

Headings follow the LaTeX hierarchy:

- `<h1>` corresponds to `\section` --- bold, 1.4em.
- `<h2>` corresponds to `\subsection` --- bold, 1.2em.
- `<h3>` corresponds to `\subsubsection` --- bold, 1em.
- `<h4>` corresponds to `\paragraph` --- bold italic, 1em.

Both Setext-style headings (underlined with `===` or `---`) and
ATX-style headings (prefixed with `#`) work.  Setext style is
preferred for `<h1>` and `<h2>` in the RexxPub articles because it
is easier to read in the Markdown source.

Consecutive headings (for example, an `<h2>` immediately following an
`<h1>`) collapse their top margin to zero, avoiding the excessive
whitespace that would result from stacking two vertical spaces.

All headings inside `div.content` carry `break-after: avoid`, so
paged.js will not leave a heading stranded at the bottom of a page
without any following text.

### Page breaks

Any heading can force a page break by adding the `{.newpage}`
attribute:

```
Introduction {.newpage}
============
```

This is useful for starting major sections on a new page.  The CSS
class `.newpage` applies `break-before: page`, and the heading's
top margin is suppressed in print mode so that the section begins
flush at the top of the page.

Paragraphs and text-indent
--------------------------

The `article` class uses the LaTeX convention for paragraph
separation: a 1.5em first-line indent, with no vertical space
between paragraphs.

This paragraph, for example, has a first-line indent because it
follows another paragraph.  But the first paragraph after a heading
never has an indent --- the heading already signals the start of a
new section, making the indent redundant.[^noindent]

[^noindent]: This is a typographic convention followed by LaTeX, the
Chicago Manual of Style, and most European book publishers.

The `.noindent` class can be used on a Pandoc div to suppress
indentation for all paragraphs inside it:

```
::: noindent
This paragraph will have no indent.
:::
```

And paragraphs inside list items never have an indent, regardless
of context.

Lists
-----

Lists are scoped to the content area (to avoid interfering with
Bootstrap's navigation elements) and follow LaTeX's spacing
conventions:

- First-level lists use a left margin of 2.5em, matching LaTeX's
  `\leftmargin`.
- Nested lists use 2.2em, matching LaTeX's second-level margin.
- Item separation is 0.2em, and list top/bottom margins are 0.4em
  --- tighter than Bootstrap's defaults, matching LaTeX's `\itemsep`
  and `\topsep`.

This is a nested list example:

1. First item
   - Nested item A
   - Nested item B
2. Second item
3. Third item

Typography
==========

Font and line spacing
---------------------

The body text is set in Times New Roman at the base size defined by
the `--doc-font-size` CSS custom property (12pt by default).  The
line-height is controlled by `--doc-line-height` (1.25 by default),
which is a compromise between LaTeX's exact ratio of 14.5/12 = 1.208
and the slightly more generous spacing that Times New Roman needs due
to its larger x-height compared to Computer Modern.

Text is justified with automatic hyphenation (`hyphens: auto`), and
the CSS properties `widows: 2` and `orphans: 2` prevent single lines
from being stranded at the top or bottom of a page.

Inline code
-----------

Inline `code` elements are styled with a subtle grey background
(`#f0f0f0`), dark text (`#222`), and minimal padding --- replacing
Bootstrap's bright pink (`#c7254e`) default.  The font size is 0.9em,
slightly smaller than the body text.

Inside `<pre>` blocks, the inline code styling is reset to inherit
from the parent, so it does not interfere with Rexx Highlighter
output.

Code blocks
-----------

There are two categories of `<pre>` blocks, and the CSS treats them
differently:

1. **Generic `<pre>` blocks** --- direct children of `div.content`.
   These are plain code listings, command output, or configuration
   examples.  They receive a very subtle background (`#f8f8f8`), no
   border, and a thin left rule (`2pt solid #ccc`) as a visual anchor.

2. **Rexx-highlighted blocks** --- inside `div.highlight-rexx-*`
   wrappers.  These are styled entirely by the Highlighter CSS and
   are not touched by `article.css`.

The selector `div.content > pre` (with the child combinator) ensures
that only generic blocks are affected.  All `<pre>` blocks share the
`break-inside: avoid` property to prevent code listings from being
split across pages.

For example, this is a generic `<pre>` block:

```
@page {
  margin: 3cm;
  size: A4 portrait;
}
```

And this is a Rexx-highlighted block:

~~~rexx
/* A simple Rexx program */
Parse Arg name
If name = "" Then name = "world"
Say "Hello," name"!"
~~~

Links
-----

Links inside the content area use a darker, more academic blue
(`#00529B`), similar to the default of LaTeX's `hyperref` package
with `colorlinks=true`.  This replaces Bootstrap's lighter blue
(`#337ab7`).

Blockquotes
-----------

Blockquotes follow the LaTeX `quote` environment: equal left and
right margins of 1.5em, no style change, no border.  Bootstrap's
default left blue bar and larger font size are both removed.

> This is a blockquote.  It has symmetric margins, no border, and the
> same font size as the body text --- exactly like LaTeX's `quote`
> environment.

Tables
------

Tables follow the `booktabs` convention from LaTeX: horizontal rules
only (no vertical rules), with a thicker rule at the top and bottom
of the table (1.5pt) and a thinner rule below the header (0.75pt).
Tables are centred on the page and use `width: auto` instead of
Bootstrap's default 100%.

Page layout
===========

Page geometry
-------------

The default page geometry is DIN A4 portrait with 3cm margins on all
sides.  This produces a text block of approximately 15cm wide, which
accommodates about 66 characters per line at 12pt Times New Roman ---
the optimal line length for comfortable reading.

Page numbers
------------

Page numbers are centred at the bottom of each page, in the same
font, size, and style as the body text (upright, not italic).  The
first page (the title page) has no page number, following the LaTeX
`\maketitle` convention.  Blank pages also suppress the page number.

Footnotes
---------

Footnotes are placed at the bottom of the page where they are
referenced, using paged.js's implementation of the CSS `float:
footnote` mechanism.  The footnote area is separated from the body
text by a thin rule (0.5pt), with appropriate spacing above and
below.[^fnexample]

[^fnexample]: This is an example footnote, demonstrating the styling:
smaller font (controlled by `--doc-footnote-size`), slightly more
generous line-height (1.4), and left-aligned text.

Footnote markers in the body text use a superscript style at 60% of
the body font size.  Inside footnotes, inline `code` elements are
styled consistently with the body text, even though paged.js moves
the footnote content outside `div.content` in the DOM --- a subtlety
that required a dedicated `.footnote code` rule.

Parametric sizing {.newpage}
=================

The `article` class supports three base sizes --- 10pt, 12pt, and
14pt --- through CSS custom properties.  The default is 12pt; the
other sizes are activated by loading a small override stylesheet
(`article-10pt.css` or `article-14pt.css`) that redefines the
variables.

The following table summarises the values at each size:

| Property               |  10pt   |  12pt   |  14pt   | LaTeX source     |
|:-----------------------|--------:|--------:|--------:|:-----------------|
| `--doc-font-size`      |   10pt  |   12pt  |   14pt  | `\normalsize`    |
| `--doc-line-height`    |   1.20  |   1.25  |   1.29  | `\baselineskip`  |
| `--doc-footnote-size`  |    8pt  |   10pt  |   12pt  | `\footnotesize`  |
| `--doc-fn-marker-size` |    6pt  |    7pt  |    8pt  | ~`\scriptsize`   |
| `--doc-pre-size`       |  7.2pt  |  8.6pt  |   10pt  | ~0.72 x base     |
| Page margin            |  3.5cm  |   3cm   |  2.5cm  | `geometry` pkg   |
| Page number size       |   10pt  |   12pt  |   14pt  | = `\normalsize`  |

All values that can be expressed as CSS custom properties use `var()`
references in the main stylesheet.  The `@page` rules (margin, page
number size) use literal values because `var()` is not reliably
supported inside `@page` in all paged.js versions; the size-specific
stylesheets override these rules directly.

Usage
-----

In the browser (Serve and Print pipelines), the size is selected via the `size`
query string parameter:

```
?print=pdf&size=10
```

From the command line (md2pdf), the size is passed as an option:

```
[rexx] md2pdf --size 10 article.md
```

The default is 12.  When no size parameter is specified, no override
stylesheet is loaded and the 12pt defaults in `article.css` are
used.

The page margins vary with the base size to maintain approximately
66 characters per line: 10pt uses wider margins (3.5cm), 14pt uses
narrower ones (2.5cm).

CSS architecture {.newpage}
================

Relationship with Bootstrap
----------------------------

The `article` class is designed to coexist with Bootstrap 3, which
provides the responsive layout for the web view (navigation bar,
breadcrumbs, sidebar, grid system).  When paged.js activates for
printing, `@media print` rules hide all Bootstrap chrome, leaving
only the article content.

All typographic rules are scoped to `div.content` to avoid
interfering with Bootstrap's UI elements.  For example, list rules
use `div.content ul` and `div.content ol` instead of bare `ul` and
`ol`, which would break Bootstrap's breadcrumb navigation
(`ol.breadcrumb`).

Bootstrap overrides
-------------------

Several Bootstrap defaults are explicitly overridden inside
`div.content`:

- **Headings:** Bootstrap sets `font-weight: 500` and
  `line-height: 1.1` on all headings.  The article class overrides
  these with `font-weight: bold` (via individual heading rules) and
  `line-height: 1.2`.
- **Inline code:** Bootstrap's `code` rule uses `color: #c7254e`
  (pink) and `background-color: #f9f2f4`.  The article class
  overrides both with neutral colours.
- **`<pre>` blocks:** Bootstrap sets `border: 1px solid #ccc`,
  `border-radius: 4px`, and `word-break: break-all`.  The article
  class removes the border and radius for generic blocks, and
  restores `word-break: normal`.
- **Blockquotes:** Bootstrap's `border-left: 5px solid #eee` and
  enlarged font size are both removed.

Protecting the Rexx Highlighter
-------------------------------

The Rexx Highlighter generates `<pre>` blocks inside
`div.highlight-rexx-*` wrappers, with richly annotated `<span>`
elements carrying `rx-*` CSS classes.  The article class must not
interfere with this styling.

The strategy is twofold:

1. **Generic `<pre>` rules** use the child combinator
   (`div.content > pre`) to target only direct children of the
   content area --- never the `<pre>` blocks inside Highlighter
   wrappers.
2. **Inline `code` rules** are scoped to `div.content code`, which
   has lower specificity than the Highlighter's class-based selectors
   (`rx-*`), so the Highlighter styles always win inside highlighted
   blocks.

YAML front matter {.newpage}
=================

RexxPub options can be specified directly in the Markdown source,
inside the YAML front matter block at the beginning of the file.
This allows the author to fix structural options --- such as section
numbering depth, font size, or figure numbering --- as part of the
document itself, rather than relying on command-line options or URL
parameters.

```
---
bibliography: references.bib
rexxpub:
  section-numbers: 3
  number-figures: true
  size: 12
---
```

Options specified in the YAML front matter take precedence over
command-line and URL parameters for structural settings, ensuring
that the author's intent is always respected.  The highlighting
style is an exception: it can always be overridden by the reader
via the style chooser or the `?style=` parameter.

See the [YAML front matter documentation](../yaml/) for the full
list of supported options and the precedence rules.

Acknowledgements {.newpage}
================

The design of `article.css` was developed in collaboration between
the author and Claude (Anthropic), through a detailed comparative
analysis of LaTeX `article` 12pt defaults, Bootstrap 3 base styles,
and the specific requirements of the Rexx Highlighter output.

The CSS for the Rexx Highlighter predefined styles has benefited
greatly from the contributions of Rony G. Flatscher, who developed
the `rgfdark`, `rgflight`, and Vim-derived colour schemes.

Thanks are due to Jean Louis Faucher for his contribution of the
horizontal scrollbar mechanism for wide images.

Special thanks go to the
[Espacio Psicoanalítico de Barcelona (EPBCN)](https://www.epbcn.com/)
for its extraordinarily generous support.