# DocBook Highlighting Tools

This directory contains tools for adding Rexx syntax highlighting to
the official ooRexx documentation books (DocBook XML + Publican + FOP
for PDF, DocBook XSL for HTML).

## Files

```
hldocprep.rex    Highlighted document preparation (drop-in companion
                 for docprep).  Runs docprep, then highlights all
                 <programlisting language="rexx"> blocks and generates
                 the XSL files required by the PDF and HTML builds.

hldoc2fo.rex     XML-to-FO transformation using pdf-hl.xsl (drop-in
                 companion for doc2fo).

hldoc2pdf.rex    Full PDF build with highlighting (drop-in companion
                 for doc2pdf).  Calls hldoc2fo + fo2pdf.

hldoc2HTML.rex   Full chunked-HTML build with highlighting (drop-in
                 companion for doc2HTML).  Transforms with html-hl.xsl
                 and ships the highlighting stylesheets and the style
                 chooser alongside the pages.

readme.md        This file.
```

## Prerequisites

1. The ooRexx documentation build environment (`tools/bldoc_orx/`)
   must be set up and working — you should be able to build a book
   with `docprep` + `doc2pdf` (or `doc2HTML`) before trying the
   highlighted equivalents.

2. The **Rexx Parser** must be installed and its `bin/` directory
   must be on your `PATH` or `REXX_PATH`, so that `hldocprep` can
   find the highlighting engine.  The HTML build additionally reads
   the Parser's `css/` and `js/` directories, which it locates
   relative to `Rexx.Parser.cls` — nothing depends on the current
   directory.

## Installation

Copy the four `.rex` files to your `tools/bldoc_orx/` directory,
alongside `docprep.rex`, `doc2fo.rex`, `doc2HTML.rex`, etc.:

```
cp hldocprep.rex hldoc2fo.rex hldoc2pdf.rex hldoc2HTML.rex \
   /path/to/ooRexx-docs/tools/bldoc_orx/
```

No changes to existing files are required.  The generated
`pdf-hl.xsl` and `html-hl.xsl` are copies of `pdf.xsl` and `html.xsl`
with one `<xsl:include>` added; the originals are left alone, so a
plain build keeps working exactly as before.

## Usage

From the `tools/bldoc_orx/` directory:

```
[rexx] hldocprep bookname
[rexx] hldoc2pdf              -- for the PDF
[rexx] hldoc2HTML             -- for the chunked HTML
```

For example: `hldocprep rexxref` then `hldoc2pdf`.

Or, step by step: `hldocprep bookname` then `hldoc2fo` then `fo2pdf`.

Both `hldoc2pdf` and `hldoc2HTML` accept the book name directly and
will run `hldocprep` for you: `hldoc2HTML rexxref`.

## Enabling Highlighting

Add `language="rexx"` to any `<programlisting>`:

```xml
<programlisting language="rexx">Say "Hello, world!"
x = 42
If x > 0 Then
  Say "positive"</programlisting>
```

Listings without `language="rexx"` are left untouched, which is why a
highlighted build and a plain build can share the same sources.

## Per-listing Options

Use `hl-style` to select a different highlighting style per listing:

```xml
<programlisting language="rexx" hl-style="dark">Say "Hello!"</programlisting>
```

Granularity and dialect can also be set per listing:

| Attribute      | Values                             | Default    |
|:---------------|:-----------------------------------|:-----------|
| `hl-style`     | any highlighting style             | `print`    |
| `operator`     | `group`, `full`, `detail`          | `group`    |
| `special`      | `group`, `full`, `detail`          | `group`    |
| `constant`     | `group`, `full`, `detail`          | `group`    |
| `assignment`   | `group`, `full`, `detail`          | `group`    |
| `doccomments`  | `detailed`, `block`                | `detailed` |
| `dialect`      | `executor`, `cms`, `rexxvm`,       | none       |
|                | `tutor`, `unicode`, `experimental` |            |

## Command-line Options

- `--style STYLE` — set the default style (default: `print`).
- `--regen` — force regeneration of the XSL files.

Example: `hldocprep --style dark --regen rexxref`

## What Gets Emitted

Highlighting rewrites each listing into standard DocBook.  The style
goes on the container; the tokens carry only their semantic role,
which is the highlighter's CSS class string verbatim — the very same
string the HTML driver puts in `class=`:

```xml
<programlisting language="rexx" role="highlight-rexx-print"><phrase
  role="rx-kw">Say</phrase> <phrase role="rx-str">"Hi"</phrase></programlisting>
```

Three things follow from that, and they are the whole point of the
design:

- **The result is valid DocBook.** `<phrase role="...">` is the
  standard idiom for a semantically tagged inline, so a highlighted
  book still validates against the DocBook 4.5 DTD and survives any
  validating step of the build.

- **The HTML branch needs almost nothing.** The stock DocBook XSL
  already turns `<phrase role="X">` into `<span class="X">`, so there
  are no per-token templates to write — and none per style either,
  because in HTML the style is a matter of CSS cascade.  The whole
  HTML glue is three templates.

- **One highlighted document can be restyled without parsing the
  source again**, because the token markup is identical whatever style
  is in effect.  In HTML that is what makes a client-side style
  chooser possible; in FO it is what lets one book mix several styles.

A listing that names its own style with `hl-style=` is additionally
marked `rexx-style-locked`, so a style chooser leaves it alone: the
author asked for that style on purpose.  Any `role=` the author
already put on the listing is preserved ahead of ours.

## Multi-style Support

If a book uses several styles, `hldocprep` discovers them
automatically and generates what each branch needs.  No manual
configuration.

The two branches solve it differently, because their media differ:

- **HTML** solves it by cascade.  Each listing is wrapped in a
  `<div class="highlight-rexx-<style>">`, exactly the shape the HTML
  driver emits, and the Parser's existing `rexx-<style>.css` files do
  the rest.  This is the same mechanism that lets the Parser's own
  documentation show 25 styles on a single page.

- **PDF** has no cascade, so `css2xsl` generates one template per
  token per style, each restricted to listings carrying that style on
  their container.  The block background is handled once for all
  styles in the glue file, by redefining DocBook's
  `shade.verbatim.style`; listings that are not highlighted keep the
  stock shading, whose values are read out of `pdf.xsl` rather than
  hardcoded.

## The Style Chooser (HTML only)

`hldoc2HTML` ships the Parser's `rexx-*.css` sheets and
`js/style-chooser.js` into the book's `Common_Content/`, and the
generated pages link every sheet and carry a chooser in the header.
Every sheet but the default is linked with `media="not all"`, so a
reader's browser only fetches the one it is actually asked to show.
The chooser ships hidden and reveals itself only on pages that have
highlighted blocks, so a page with no code shows no stray control.

Switching style in the browser works precisely because the token
markup does not depend on the style: it comes down to relabelling the
wrapper `<div>` on each block and activating another sheet, both of
which the browser can do on its own.

## Dual-path Builds

- `docprep` + `doc2pdf` / `doc2HTML` — traditional build, no
  highlighting.
- `hldocprep` + `hldoc2pdf` / `hldoc2HTML` — highlighted build.

Both work on the same source files.  The highlighting tools only
modify files in the work folder; the original sources are never
touched.

## Generated Files

`hldocprep` writes these into `tools/bldoc_orx/`.  All of them are
generated — do not edit them by hand, they are overwritten:

```
hl-styles/rexx-highlight-<style>.xsl   FO token templates, one file
                                       per style in use
rexx-highlights.xsl                    PDF glue: the includes above,
                                       plus the per-style block shading
rexx-highlights-html.xsl               HTML glue: the container
                                       template, the stylesheet links
                                       and the chooser
pdf-hl.xsl                             pdf.xsl + one xsl:include
html-hl.xsl                            html.xsl + one xsl:include
```

Use `--regen` to force them to be rebuilt.

> **A note for anyone maintaining this.** The `<xsl:include>` added to
> `pdf.xsl` and `html.xsl` goes **last**, just before the closing
> `</xsl:stylesheet>`, and it has to stay there.  When an attribute
> set is defined more than once at the same import precedence, XSLT
> merges the definitions and the last one in document order wins for
> any attribute defined twice.  The glue redefines
> `shade.verbatim.style`; move the include earlier and `pdf.xsl`'s own
> definition takes the shading back, silently.

## Known Issues in the Surrounding Toolchain

These are not highlighting bugs — they reproduce in a plain build —
but they will bite anyone building on Linux:

- **`doc2HTML.rex` looks for the common content in `ooRexx`**, while
  the directory is checked out as `oorexx`.  Case-insensitive file
  systems hide this; on Linux the copy step reports "0 files copied"
  and carries on, and the book ends up with no stylesheet at all.
  `hldoc2HTML.rex` resolves the name case-insensitively instead.

- **`xhtml-common.xsl` duplicates class names.** Its `class.attribute`
  mode appends `@role` to whatever class it was handed, so elements
  come out as `class="italic italic"`, `class="rx-kw rx-kw"`.
  Harmless to CSS, untidy in the source.

- **`xhtml-common.xsl` emits a jQuery call on every page**
  (`$("#site_footer").load(...)`) without any page loading jQuery, so
  every page logs `ReferenceError: $ is not defined`.

## See Also

- `doc/highlighter/docbook/readme.md` in the Rexx Parser project —
  full documentation including manual workflow, troubleshooting,
  and implementation details.
