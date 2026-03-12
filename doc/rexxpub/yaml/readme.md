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

| Key                | Values                         | Default   | Pipelines        | Description                        |
|:-------------------|:-------------------------------|:----------|:-----------------|:-----------------------------------|
| `style`            | Any style name                 | `dark`    | All three        | Default Rexx highlighting style    |
| `size`             | Integer (pt)                   | Per class | md2pdf, CGI      | Base font size                     |
| `section-numbers`  | `0`--`4`                       | Per class | All three        | Section numbering depth            |
| `number-figures`   | `0`, `1`, `true`, or `false`   | `true`    | All three        | Automatic figure/listing numbering |
| `docclass`         | `article`, `book`, `letter`, `slides` | Per filename | md2pdf, CGI | Document class              |
| `language`         | Language code (e.g. `en`, `es`)| `en`      | All three        | Document language (`<html lang>`)  |
| `outline`          | `0`--`6`                       | `3`       | md2pdf only      | PDF outline depth (H1..Hn)         |

The `number-figures` option accepts `0`, `1`, `true`, or `false`
(case-insensitive).

The default for `size` is 12 for `article`, `book`, `default`, and
`letter`, and 20 for `slides`.

The default for `section-numbers` depends on the document class:
3 for `article` (and `default`, `letter`), 2 for `book`, and 0
for `slides`.

The `docclass` option overrides both the `--docclass` CLI option
(in `md2pdf`) and the filename-based inference (in the CGI).  For
example, a file named `readme.md` with `docclass: article` in its
YAML front matter will be rendered using the `article` document
class.  In the CGI, this also selects the corresponding CSS
(`print/article.css`) and determines the default section-numbering
depth.  Invalid class names are silently ignored (with a warning
in `md2pdf`).

The `language` option sets the `lang` attribute on the `<html>`
element.  This affects hyphenation, spell-checking, and
accessibility in the browser or PDF viewer.

The `outline` option controls how many heading levels are
included in the PDF document outline (bookmarks).  It is only
used by `md2pdf`, which passes `--outline-tags h1,...,hn` to
`pagedjs-cli`.

### Citation Style Language (`csl`)

The `csl` option is **not** a RexxPub option.  It is a standard
Pandoc metadata field and should be placed at the top level of the
YAML front matter, not under `rexxpub:`:

```
---
bibliography: references.bib
csl: ../../../../csl/rexxpub.csl
rexxpub:
  section-numbers: 3
---
```

Pandoc reads `csl` directly from the YAML front matter and uses it
for citation processing with `--citeproc`.  RexxPub does not need
to duplicate this field.

Note: `md2pdf` also accepts a `--csl` command-line option, which
passes the style name to Pandoc explicitly.  When a `csl` field is
present in the YAML front matter, Pandoc uses it regardless of the
`--csl` command-line option.

### Syntax highlighting style (`highlight-style`)

The `highlight-style` field is a standard Pandoc metadata field
and should be placed at the top level of the YAML front matter,
not under `rexxpub:`:

```
---
highlight-style: kate
rexxpub:
  style: dark
---
```

This option selects the CSS theme used for syntax highlighting
of non-Rexx fenced code blocks (Python, Java, SQL, etc.).  These
blocks are highlighted by Pandoc's built-in skylighting engine;
RexxPub loads the corresponding CSS from the `css/pandoc/`
directory.  The available styles are: `pygments` (the default),
`kate`, `tango`, `espresso`, `zenburn`, `monochrome`,
`breezeDark`, and `haddock`.

This option does not affect Rexx code blocks, which use the
Rexx Highlighter and the `style` option under `rexxpub:`.

Note: `md2pdf` also accepts a `--pandoc-highlighting-style`
command-line option.

### Listing options (`listings:`)

The `listings:` nested group controls the appearance of code
listing captions.  These captions are generated by the
`numberFigures.js` script from the `data-caption` attribute on
Rexx fenced code blocks (set via the `caption="..."` option in
the fenced code block header).

```
---
rexxpub:
  listings:
    caption-position: below
    caption-style: italic
    label-style: bold-italic
    label: Example
---
```

| Key                | Values                                | Default      | Description                       |
|:-------------------|:--------------------------------------|:-------------|:----------------------------------|
| `caption-position` | `above`, `below`                      | `above`      | Caption placement relative to code |
| `caption-style`    | `normal`, `italic`                    | `normal`     | Font style of the caption text     |
| `label-style`      | `bold`, `italic`, `bold-italic`, `normal` | `bold`   | Font style of the "Listing N:" label |
| `label`            | Any text                              | Per language  | Custom label (overrides localization) |

The `caption-position` option changes both the DOM order
(semantic) and the visual position of the `<figcaption>` element.
When set to `below`, the script places the caption after the code
block instead of before it, and the CSS `break` rules are adjusted
so that the caption stays attached to the code.

The `label` option overrides the localized label ("Listing" in
English, "Listado" in Spanish, etc.) for all listings in the
document.  This is useful for tutorials that prefer "Example" or
documents mixing code and pseudocode that want "Code".

Listing options only affect code listings.  Image figure captions
are controlled separately by the `figures:` group described below.

### Figure options (`figures:`)

The `figures:` nested group controls the appearance of image
figure captions.  These are the `<figcaption>` elements that
Pandoc generates inside `<figure>` elements for images with alt
text.

```
---
rexxpub:
  figures:
    caption-position: above
    caption-style: italic
    label-style: bold
    label: Illustration
---
```

| Key                | Values                                | Default      | Description                       |
|:-------------------|:--------------------------------------|:-------------|:----------------------------------|
| `caption-position` | `above`, `below`                      | `below`      | Caption placement relative to image |
| `caption-style`    | `normal`, `italic`                    | `normal`     | Font style of the caption text     |
| `label-style`      | `bold`, `italic`, `bold-italic`, `normal` | `bold`   | Font style of the "Figure N:" label |
| `label`            | Any text                              | Per language  | Custom label (overrides localization) |

Note that the default for `caption-position` is `below` (the
standard HTML/Pandoc convention), whereas for listings it is
`above` (the LaTeX convention).

The `caption-position` option changes both the DOM order and the
visual position of the `<figcaption>` element.  When set to
`above`, the script moves the caption before the `<img>` element,
and the CSS `break` rules are adjusted so that the caption stays
attached to the image.

The `label` option overrides the localized label ("Figure" in
English, "Figura" in Spanish, etc.) for all figures in the
document.

Figure options only affect image figures.  Code listing captions
are controlled separately by the `listings:` group described
above.

### Other nested groups

The `rexxpub:` key may contain additional nested groups for
future expansion.  These are parsed and stored as sub-tables
but are not currently acted upon by the pipelines.

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

### All other options

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

| Option             | 1st (wins)  | 2nd            | 3rd (default) |
|:-------------------|:------------|:---------------|:---------------|
| `style`            | URL/CLI     | YAML           | `dark`         |
| `size`             | YAML        | URL/CLI        | Per class      |
| `section-numbers`  | YAML        | URL/CLI        | Per class      |
| `number-figures`   | YAML        | URL/CLI        | `true`         |
| `docclass`         | YAML        | CLI / filename | Per filename   |
| `language`         | YAML        | CLI            | `en`           |
| `outline`          | YAML        | CLI            | `3`            |

Example
-------

A typical article with RexxPub options in the YAML front matter:

```
---
bibliography: references.bib
csl: ../../../../csl/rexxpub.csl
rexxpub:
  docclass: article
  language: en
  section-numbers: 3
  number-figures: true
  outline: 4
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
automatic figure numbering, using the `article` document class
(regardless of the filename).  The highlighting style will default
to `dark`, but the reader can override it with `?style=light` or
the style chooser dropdown.  The section numbering, figure
numbering, document class, and language cannot be overridden from
the URL --- they are fixed by the author.

When rendered with `md2pdf`, the PDF will include an outline
(bookmarks) for headings H1 through H4, and the `<html lang>`
attribute will be set to `en`.