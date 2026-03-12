YAML Front Matter
=================

RexxPub can read configuration options from the YAML front matter
block of a Markdown document, in addition to (or instead of) command-line
options, URL parameters, or program defaults.

This feature is available in all three RexxPub pipelines: the CGI
(Serve and Print), `md2html` (Build), and `md2pdf` (Render).

Syntax
------

A YAML front matter block is a block of text delimited by `---` lines
at the very beginning of a Markdown file:

```
---
title: My Document
author: Josep Maria Blasco
bibliography: references.bib
rexxpub:
  section-numbers: 3
  size: 12
---
```

The opening `---` must be the first line of the file.  The closing
delimiter may be `---` or `...`.  Lines between the delimiters follow
a subset of YAML syntax: block mappings with scalar values, up to
three levels of nesting.  Lists, anchors, tags, flow style, and
multiline scalars are not supported.

Blank lines and comment lines (starting with `#`) are allowed
anywhere inside the front matter block.

Values may optionally be enclosed in single or double quotes:

```
---
title: "My Document"
author: 'Josep Maria Blasco'
---
```

Quoted values have their quotes stripped; no escape processing is
performed.

Pandoc metadata vs. RexxPub options
------------------------------------

The YAML front matter block serves a dual purpose.  Pandoc reads
it to extract standard metadata fields such as `title`, `author`,
`date`, `bibliography`, and `csl`.  RexxPub reads it to extract
its own options, which live under the `rexxpub:` key to avoid any
conflict with Pandoc's metadata.

Both Pandoc and RexxPub process the same front matter block ---
there is no need to duplicate it:

```
---
bibliography: references.bib
csl: ../../../../csl/rexxpub.csl
rexxpub:
  style: dark
  section-numbers: 3
  number-figures: true
  size: 12
---
```

In this example, Pandoc will use `bibliography` and `csl` for
citation processing, and RexxPub will use the fields under
`rexxpub:` to configure the output.

RexxPub options
---------------

All RexxPub options are placed under the `rexxpub:` key.  The
currently supported options are:

| Key                | Values                         | Default   | Description                        |
|:-------------------|:-------------------------------|:----------|:-----------------------------------|
| `style`            | Any style name                 | `dark`    | Default Rexx highlighting style    |
| `size`             | Integer (pt)                   | Per class | Base font size                     |
| `section-numbers`  | `0`--`4`                       | Per class | Section numbering depth            |
| `number-figures`   | `0`, `1`, `true`, or `false`   | `true`    | Automatic figure/listing numbering |

The `number-figures` option accepts `0`, `1`, `true`, or `false`
(case-insensitive).

The default for `size` is 12 for `article`, `book`, `default`, and
`letter`, and 20 for `slides`.

The default for `section-numbers` depends on the document class:
3 for `article` (and `default`, `letter`), 2 for `book`, and 0
for `slides`.

### Nested groups

The `rexxpub:` key may also contain nested groups for future
expansion:

```
---
rexxpub:
  style: dark
  section-numbers: 3
  figures:
    caption-position: above
    numbering: auto
  listings:
    caption-position: above
    default-style: dark
---
```

Nested groups are parsed and stored as sub-tables, but no nested
options are currently acted upon by the pipelines.  They are
reserved for future use.

Precedence
----------

When the same option is specified in multiple places, the following
precedence rules apply:

### `style` (highlighting style)

URL parameter > YAML > default.

The `style` option follows a **reader-wins** policy.  The URL
parameter (or the style chooser dropdown in the CGI) always takes
precedence over the YAML value, which in turn takes precedence over
the built-in default (`dark`).

This is because the highlighting style is a presentation choice
that depends on context: a document may look best with `dark` on
screen, but the author (or someone else) will need `print` when
producing a PDF for conference proceedings.  The style chooser and
the `?style=` parameter must continue to work even when the YAML
specifies a default.

### All other options (`size`, `section-numbers`, `number-figures`)

YAML > URL/CLI > default.

All structural options follow an **author-wins** policy.  If the
author has specified a value in the YAML front matter, that value
prevails, regardless of what the URL parameter or command-line
option says.

This is because structural options reflect the author's intent
about how the document should be rendered.  If the author writes
`section-numbers: 2`, it is because the document is designed for
exactly two levels of numbering.  A URL parameter should not
silently override that decision --- and, looking ahead, if the
document contains cross-references such as "as explained in
Section 3.1 on page 12", changing the numbering depth from the
URL could render those references meaningless.

When the YAML does not specify a value, the URL parameter (or
command-line option) is used; when neither is specified, the
built-in default applies.

### Summary table

| Option             | 1st (wins)  | 2nd         | 3rd (default) |
|:-------------------|:------------|:------------|:---------------|
| `style`            | URL/CLI     | YAML        | `dark`         |
| `size`             | YAML        | URL/CLI     | Per class      |
| `section-numbers`  | YAML        | URL/CLI     | Per class      |
| `number-figures`   | YAML        | URL/CLI     | `true`         |

Example
-------

A typical article with RexxPub options in the YAML front matter:

```
---
bibliography: references.bib
csl: ../../../../csl/rexxpub.csl
rexxpub:
  section-numbers: 3
  number-figures: true
---

::::: title-page

My Article <small>A Subtitle</small>
=====================================

::: author
Author Name
:::

:::::

Introduction
============

...
```

The CGI will render this with 3 levels of section numbering and
automatic figure numbering.  The highlighting style will default to
`dark`, but the reader can override it with `?style=light` or the
style chooser dropdown.  The section numbering and figure numbering
cannot be overridden from the URL --- they are fixed by the author.