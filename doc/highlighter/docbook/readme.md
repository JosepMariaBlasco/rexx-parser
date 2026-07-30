# Rexx Syntax Highlighting for DocBook / ooRexx Official Books

---

## Overview

The Rexx Parser includes a complete toolchain for adding syntax
highlighting to the official ooRexx documentation books (rexxref,
rexxpg, etc.).  These books are written in DocBook XML and built with
the `tools/bldoc_orx/` scripts on top of DocBook XSL — to PDF through
Apache FOP, and to chunked HTML through the DocBook XHTML stylesheets.

The toolchain covers **both outputs from the same highlighted XML**.
It is a drop-in addition to the existing build process: you mark
`<programlisting>` blocks with `language="rexx"`, then run `hldocprep`
instead of `docprep`, and `hldoc2pdf` or `hldoc2HTML` instead of
`doc2pdf` or `doc2HTML`.  Everything else stays the same, and a plain
unhighlighted build keeps working from the same sources.

In the PDF you get fully highlighted Rexx code — keywords in bold
blue, comments in italic, strings in green — using the same CSS-based
styles the Rexx Highlighter uses everywhere else.  In the HTML you get
the same thing plus a **style chooser**: the reader can switch between
all 25 styles in the browser, with no server involved, and the choice
persists between visits.

Several styles can coexist in one book, and each listing can pin its
own style and granularity.

## Prerequisites

1. **The ooRexx documentation tree** from the SourceForge SVN
   repository.  To download a read-only copy:

   ```
   svn checkout svn://svn.code.sf.net/p/oorexx/code-0/docs/trunk ooRexx-docs
   ```

2. **A working build environment**: the `tools/bldoc_orx/` scripts
   (`docprep`, `doc2fo`, `fo2pdf`, `doc2HTML`, etc.), `xsltproc`, the
   DocBook XSL stylesheets, and Apache FOP for the PDF.  You should be
   able to build a book with `docprep` + `doc2pdf` (or `doc2HTML`)
   before trying the highlighting tools.

   Note that `setup.rex` in the documentation tree is Windows-only; on
   Linux and macOS the toolchain has to be set up by hand.

3. **The Rexx Parser**, with its `bin/` directory on your `PATH` or
   `REXX_PATH` so that `hldocprep` can find the highlighting engine.
   The HTML build additionally reads the Parser's `css/` and `js/`
   directories, which it locates relative to `Rexx.Parser.cls` —
   nothing depends on the current directory.

## Installation

Copy the four scripts from the `bin/docbook/` directory of the Rexx
Parser project to your `tools/bldoc_orx/` directory:

```
cp hldocprep.rex hldoc2fo.rex hldoc2pdf.rex hldoc2HTML.rex \
   /path/to/ooRexx-docs/tools/bldoc_orx/
```

No changes to existing files are required.  The original `docprep`,
`doc2fo`, `doc2pdf` and `doc2HTML` remain untouched and continue to
work as before.

`bin/docbook/` also holds `oorexx-catalog.xml`, which you may need on
Linux — see [The XML catalog] below.

## Quick Start

From your `tools/bldoc_orx/` directory:

```
[rexx] hldocprep bookname
[rexx] hldoc2pdf              -- for the PDF
[rexx] hldoc2HTML             -- for the chunked HTML
```

For example, to build the Rexx Reference with highlighting:

```
[rexx] hldocprep rexxref
[rexx] hldoc2pdf
```

That's it.  `hldocprep` does everything `docprep` does, plus:

1. Scans all `.xml` files in the work folder, recursively, for
   `<programlisting language="rexx">` blocks and highlights them.
2. Generates the XSL files that tell FOP and the XHTML stylesheets how
   to render the highlighted code.

Both `hldoc2pdf` and `hldoc2HTML` accept the book name directly and
will run `hldocprep` for you, so `hldoc2HTML rexxref` is enough on its
own.

You can also run the steps separately:

```
[rexx] hldocprep bookname
[rexx] hldoc2fo
[rexx] fo2pdf
```

## Enabling Highlighting for a Listing

Add `language="rexx"` to any `<programlisting>` you want highlighted:

```xml
<programlisting language="rexx">Say "Hello, world!"
x = 42
If x > 0 Then
  Say "positive"</programlisting>
```

Only listings with `language="rexx"` are processed.  All other
listings are left untouched, so you can migrate incrementally — add
`language="rexx"` to a few listings, build, check the result, and
continue.  `language` is a standard DocBook attribute, so adding it
does not disturb a plain build either.

## Per-listing Options

### Highlighting style

By default, all listings are highlighted with the `print` style
(designed for paper and for white backgrounds).  You can choose a
different style for an individual listing with the `hl-style`
attribute:

```xml
<programlisting language="rexx" hl-style="dark">Say "Hello!"</programlisting>
```

The attribute is called `hl-style` and not `style` because DocBook's
DTD silently discards unknown attributes.  `hldocprep` reads it from
the raw XML text before the DTD has a chance to remove it.

A listing that names its own style this way is treated as deliberate:
in the HTML output it is marked so that the style chooser leaves it
alone, on the grounds that the author asked for that style on purpose.
See [The HTML Branch].

### Dialect

The `dialect` attribute selects a Rexx dialect for the parse, which
affects what is recognised as a keyword and what counts as valid:

```xml
<programlisting language="rexx" dialect="cms">...</programlisting>
```

Accepted values are `executor`, `cms`, `rexxvm`, `tutor`, `unicode`
and `experimental`.  The default is none, i.e. plain ooRexx.

### Granularity

Highlighting granularity can be controlled per listing, using the same
option names as in FencedCode for Markdown:

```xml
<programlisting language="rexx" operator="detail" constant="full">
...
</programlisting>
```

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

The granularity modes control how much visual distinction each token
category preserves:

- **`group`** — all elements in a category share the same colour
  (e.g. all operators look the same).
- **`detail`** — each element gets its own specific colour where the
  CSS style defines one.
- **`full`** — elements get both the generic and the specific class,
  which is how the cascade works in HTML, and gives maximum detail.

## Command-line Options

`hldocprep` accepts two options before the book name.

### `--style STYLE`

Sets the default highlighting style for all listings that don't have
an explicit `hl-style` attribute.  The default is `print`.

```
[rexx] hldocprep --style dark rexxref
```

`print` is the sensible default for the PDF, and it is also the
default the HTML build ships with, so that both outputs agree.  In the
HTML the reader can change it anyway.

### `--regen`

Forces regeneration of all XSL files, even if they already exist.  Use
this after updating the Rexx Parser or changing the CSS styles.

```
[rexx] hldocprep --regen rexxref
```

Without `--regen`, the per-style token stylesheets and the `pdf-hl.xsl`
/ `html-hl.xsl` customization layers are generated only the first time;
subsequent runs reuse them.  The glue files are rewritten on every run.

`--regen` cannot be used on its own — it still needs a book name.

## What Gets Emitted

Highlighting rewrites each listing into **standard DocBook**.  The
style goes on the container; the tokens carry only their semantic role,
and that role is the highlighter's CSS class string verbatim — the very
same string the HTML driver puts in `class=`:

```xml
<programlisting language="rexx" role="highlight-rexx-print"><phrase
  role="rx-kw">Say</phrase> <phrase role="rx-str rx-oquo">&quot;</phrase><phrase
  role="rx-str">Hi</phrase><phrase role="rx-str rx-cquo">&quot;</phrase></programlisting>
```

Three things follow from that, and together they are the whole point of
the design:

- **The result is valid DocBook.**  `<phrase role="...">` is the
  standard idiom for a semantically tagged inline, so a highlighted
  book still validates against the DocBook 4.5 DTD and survives any
  validating step in the build.

- **The HTML branch needs almost nothing.**  The stock DocBook XSL
  already turns `<phrase role="X">` into `<span class="X">`, multiple
  classes included, so there are no per-token templates to write — and
  none per style either, because in HTML the style is a matter of CSS
  cascade.

- **One highlighted document can be restyled without parsing the
  source again**, because the token markup is identical whatever style
  is in effect.  In HTML that is what makes a client-side style chooser
  possible; in the PDF it is what lets one book mix several styles.

Whitespace between tokens is emitted as plain XML-escaped text, with no
`<phrase>` around it: a wrapper there would carry no information.

A listing that names its own style with `hl-style=` is additionally
marked `rexx-style-locked` in its container role, so that a style
chooser can recognise it and leave it alone.  Any `role=` the author
already put on the listing is preserved ahead of ours.

> **If you have older output lying around.** Before July 2026 the
> DocBook driver emitted invented elements with the style baked into
> the name — `<rexx_print_kw>`, `<rexx_dark_op_add>` — wrapped in a
> `rexx_style_<style>` element.  That markup did not validate: rexxpg
> reported 4291 DTD errors, the great majority of them from the
> highlighting elements, and reports none after the migration.  It also
> tied each document to a single style, and it was the one place in the
> Highlighter where the token markup was not style-independent.  It is
> gone.  Re-highlight any old XML and regenerate any old XSL.

## Multi-style Support

A book can use several highlighting styles at once — most listings on
the default `print`, say, and a few on `dark` to demonstrate dark-theme
rendering.  This works automatically: `hldocprep` discovers which
styles are actually used and generates what each branch needs.  No
manual configuration.

Example output from `hldocprep`:

```
15:45:32 2 style(s) found: dark, print.
15:45:32 - Generating hl-styles/rexx-highlight-print.xsl ...
15:45:32 - Generating hl-styles/rexx-highlight-dark.xsl ...
```

The two branches solve multi-style differently, because their media
differ:

- **HTML solves it by cascade.**  Each listing is wrapped in a
  `<div class="highlight-rexx-<style>">` — exactly the shape the HTML
  driver emits elsewhere — and the Parser's existing `rexx-<style>.css`
  files do the rest.  This is the same mechanism that lets the Parser's
  own documentation show 25 styles on a single page.

- **The PDF has no cascade**, so `css2xsl` generates one template per
  token per style, each one restricted to listings that carry that
  style on their container.  This is why the PDF cost grows with the
  number of styles in the book and the HTML cost does not.

## The HTML Branch

`hldoc2HTML` is a drop-in companion for `doc2HTML`: it transforms the
book with `html-hl.xsl` and ships the highlighting assets alongside the
pages.  It also works around a bug in `doc2HTML` that breaks the plain
HTML build on Linux — see [Known Issues in the Surrounding Toolchain].

### What ships with the pages

Into the book's `Common_Content/`, next to the sheets `doc2HTML`
already puts there:

- the Parser's 25 `rexx-<style>.css` sheets, into `Common_Content/css/`
- `style-chooser.js`, into `Common_Content/js/`

Every generated page links all 25 sheets, but every sheet except the
active one is linked with `media="not all"`, so a reader's browser only
fetches the one it is actually being asked to display.

`rexx-test<N>.css` sheets are development-only and are excluded from
both the copy and the links.

### The style chooser

The pages carry a small control in the banner that switches the
highlighting style for the whole book.  It is the same
`style-chooser.js` the Parser uses elsewhere, shipped unmodified —
literally the file the CGI toolbar loads, which is why it also
carries print-button code that a generated book never exercises.

- It ships hidden and reveals itself only on pages that actually
  contain highlighted blocks, so a page with no code shows no stray
  control.
- It skips any block the author pinned with `hl-style=`, which
  `hldocprep` marks with a `data-rexx-style-locked` attribute.
- The choice is remembered in `localStorage`, so it survives navigation
  between chunks and between visits.
- Changing the style also records it in the URL as `?style=<style>`,
  so a link to a chunk arrives showing what its sender was looking
  at.  A style named that way wins over the stored preference for
  that page, but does not overwrite it: a link is a view, not a new
  setting.  Nothing on the receiving end has to understand the
  parameter — the pages are static and the script reads it back
  itself.  On a book opened straight from disk the browser refuses
  the URL rewrite; the style still applies.

No server is involved: the pages are static files, and switching style
comes down to relabelling the wrapper `<div>` on each block and
activating a different sheet — both things the browser can do on its
own.  That works only because the token markup does not depend on the
style, which is exactly the invariant described in
[What Gets Emitted].

## Dual-path Builds

The traditional and highlighted build paths coexist without conflict:

- `docprep` + `doc2pdf` / `doc2HTML` — traditional build, no
  highlighting.
- `hldocprep` + `hldoc2pdf` / `hldoc2HTML` — build with syntax
  highlighting.

Both paths use the same SVN sources and the same `fo2pdf` step.  The
highlighting tools only modify files in the work folder; the original
sources are never touched.  The generated `pdf-hl.xsl` and
`html-hl.xsl` are copies of `pdf.xsl` and `html.xsl` with a single
`<xsl:include>` added, so the originals are left alone too.

## Generated Files

`hldocprep` writes these into `tools/bldoc_orx/`.  All of them are
generated — do not edit them by hand, they will be overwritten:

```
hl-styles/rexx-highlight-<style>.xsl   FO token templates, one file
                                       per style in use
rexx-highlights.xsl                    PDF glue: the includes above,
                                       plus the per-style block shading
rexx-highlights-html.xsl               HTML glue: the container
                                       template, the stylesheet links
                                       and the chooser bar
pdf-hl.xsl                             pdf.xsl + one xsl:include
html-hl.xsl                            html.xsl + one xsl:include
```

Use `--regen` to force them to be rebuilt.

> **A note for anyone maintaining this.**  The `<xsl:include>` added to
> `pdf.xsl` and `html.xsl` goes **last**, just before the closing
> `</xsl:stylesheet>`, and it has to stay there.  When an attribute set
> is defined more than once at the same import precedence, XSLT merges
> the definitions and, for any attribute defined twice, the last one in
> document order wins.  The glue redefines `shade.verbatim.style`; move
> the include earlier and `pdf.xsl`'s own definition takes the shading
> back, silently and with no error message.

## Manual Workflow

The automated workflow above is the recommended way to use the
toolchain.  The manual workflow below is documented for understanding
each step, and for troubleshooting.

### Step 1: generate the token XSL

From the `bin/` directory of the Rexx Parser:

```
[rexx] css2xsl rexx-highlight.xsl
```

This generates `rexx-highlight.xsl` for the `print` style.  The
`--style` option selects a different one:

```
[rexx] css2xsl --style dark rexx-highlight.xsl
```

Granularity options control how much detail each token category
preserves:

```
[rexx] css2xsl --operator detail --constant full rexx-highlight.xsl
```

See `doc/utilities/css2xsl/` for the full option reference.

### Step 2: install the XSL in the build system

Copy the generated file to the `tools/bldoc_orx/` directory:

```
cp rexx-highlight.xsl /path/to/ooRexx-docs/tools/bldoc_orx/
```

Then edit `tools/bldoc_orx/pdf.xsl` and add an `xsl:include` for it
**at the very end of the file**, immediately before the closing
`</xsl:stylesheet>` tag:

```xml
<!-- Rexx syntax highlighting templates (generated by css2xsl.rex) -->
<xsl:include href="rexx-highlight.xsl"/>
```

The position is not cosmetic.  See the note under
[Generated Files] for why it has to be last.

### Step 3: highlight a Rexx file

Use `highlight --docbook` to convert a `.rex` file to DocBook markup:

```
[rexx] highlight --docbook myprogram.rex
```

The output goes to standard output.  Given this input:

```rexx
/* A simple Rexx program */
Say "Hello, world!"
x = 42
If x > 0 Then
  Say "positive"
```

the output is a run of `<phrase>` elements:

```xml
<phrase role="rx-cm">/* A simple Rexx program */</phrase>
<phrase role="rx-kw">Say</phrase> <phrase role="rx-str rx-oquo">&quot;</phrase><phrase role="rx-str">Hello, world!</phrase><phrase role="rx-str rx-cquo">&quot;</phrase>
<phrase role="rx-var">x</phrase> <phrase role="rx-asg">=</phrase> <phrase role="rx-int rx-ipart">42</phrase>
<phrase role="rx-kw">If</phrase> <phrase role="rx-var">x</phrase> <phrase role="rx-op">&gt;</phrase> <phrase role="rx-int rx-ipart">0</phrase> <phrase role="rx-kw">Then</phrase>
  <phrase role="rx-kw">Say</phrase> <phrase role="rx-str rx-oquo">&quot;</phrase><phrase role="rx-str">positive</phrase><phrase role="rx-str rx-cquo">&quot;</phrase>
```

Note that `--style` has **no effect** in DocBook mode, and that is not
an oversight: the style is not a property of the token markup at all.
It is named on the container, which you supply in the next step.

### Step 4: insert into DocBook

Paste the highlighted output directly inside a `<programlisting>`
element — no extra whitespace before the first element or after the
last — and give the listing the container role naming your style:

```xml
<programlisting role="highlight-rexx-print"><phrase role="rx-cm">/* A simple Rexx program */</phrase>
<phrase role="rx-kw">Say</phrase> ...</programlisting>
```

The `highlight-rexx-<style>` role must name the same style the XSL of
step 1 was generated for.  If it doesn't, the templates simply never
match and the code comes out unstyled, with no error.

### Step 5: build the PDF

```
[rexx] docprep rexxref
[rexx] doc2pdf
```

## Troubleshooting

**Code comes out with no colour at all, and no error message.**  The
most likely cause is a mismatch between the container role and the
generated XSL: every token template is restricted to listings carrying
its own style, so a listing marked `highlight-rexx-dark` gets nothing
from a stylesheet generated for `print`.  Check that the style names
agree, and regenerate with `--regen` if in doubt.

**The block background is wrong, or reverted to DocBook's grey.**  The
`<xsl:include>` is probably not last in `pdf-hl.xsl`.  See the note
under [Generated Files].

**The HTML has no styling whatsoever** (not just the code — the whole
book).  This is a bug in the stock `doc2HTML.rex` on case-sensitive
file systems, not in the highlighting.  Use `hldoc2HTML`, which works
around it.  See [Known Issues in the Surrounding Toolchain].

**`ReferenceError: $ is not defined` in the browser console.**  A
pre-existing bug in the ooRexx XHTML stylesheets, present in a plain
build too.  Harmless.  See
[Known Issues in the Surrounding Toolchain].

**Namespace-stripping warnings, and a very slow HTML build.**  Your XML
catalog is resolving the DocBook stylesheet URI to the namespaced
stylesheets.  See [The XML catalog].

**XML parsing errors.**  Ensure the `<programlisting>` content is valid
XML.  Common causes: unescaped `&` or `<` in Rexx source (the DocBook
driver handles this for you, so this points at hand-written markup), or
unclosed tags.

**`Warning: highlighting failed for block at line N`.**  The Rexx code
in that listing could not be parsed — typically a syntax error, or an
incomplete fragment such as an `Expose` instruction shown outside its
`::Method` context.  The block is left unchanged and the build carries
on.  Check the log for the file and line.  Sometimes the right fix is a
`dialect` attribute rather than a change to the code.

**The style chooser doesn't appear.**  It reveals itself only on pages
that contain highlighted blocks; on a page with no Rexx code, that is
the intended behaviour.

**A listing ignores the style chooser.**  It was pinned by the author
with `hl-style=`, which marks it `rexx-style-locked`.  That is
deliberate.

**Close the PDF reader before regenerating** — FOP cannot overwrite an
open file.

## Implementation Details

This section documents the internal architecture.  It is not needed in
order to use the toolchain, but it may help with understanding,
troubleshooting, or extending the system.

### Architecture overview

The toolchain has a content side and a rendering side, and they meet at
one convention: the `role` strings.

- **Content side**: `Parser.DocBook.cls` provides the
  `ProcessProgramListings` routine, which scans DocBook XML for
  `<programlisting language="rexx">` blocks, highlights their plain-text
  content through the DocBook driver
  (`HLDrivers/DocBook.Driver.cls`), and puts the style on the container
  as `role="highlight-rexx-<style>"`.

- **Rendering side**: for the PDF, `css2xsl.rex` reads a Rexx CSS style
  and generates XSL templates that map each token role to `fo:inline`
  formatting attributes.  For the HTML, nothing per token is generated
  at all — the stock DocBook XSL already does the mapping.

### The invariant

The Highlighter has one rule that all its drivers obey: **the token
markup is identical for every style; only the container and the linked
stylesheet differ.**  The HTML driver has always worked this way, and
the LaTeX design assumes it.  Everything in this document that looks
like a convenience — the HTML branch costing three templates, the
client-side chooser, one book mixing styles — is a consequence of it.

`DocBook.Driver.cls` is consequently almost identical to the HTML
driver, which is the sign that the design is right rather than a
duplication to be factored out.

### Style discovery

After highlighting, `hldocprep` scans the processed XML files to find
out which styles are actually in use, so that nothing has to be
configured by hand.  It reads each file in a single `charIn` call and
looks for the `highlight-rexx-` marker in container roles, taking the
style name from each one.

A container role can hold more than one token — `"highlight-rexx-dark
rexx-style-locked"`, or an author's own role ahead of ours — so the
scan takes the marker's own token rather than the whole attribute.

The list of *available* styles (as opposed to used ones) comes from the
`rexx-<style>.css` files that actually sit in the Parser's `css/`
directory, so adding a style is a matter of dropping in a file.  That
directory is found relative to `Rexx.Parser.cls`, wherever the Parser
happens to be installed — never relative to the current directory.

### The PDF branch

`css2xsl` generates one `fo:inline` template per token role per style.
For the `print` style in the default `group` granularity that is 153
templates, about 940 lines.  Each is restricted to its own style
through a predicate on the ancestor listing:

```
match="phrase[@role='rx-kw'][ancestor::programlisting[
         contains(concat(' ',@role,' '),' highlight-rexx-print ')]]"
```

The `concat`/`contains` idiom tests for a **blank-delimited token**,
not a substring.  This matters: `vim-dark-blue` is a prefix of
`vim-dark-blue2`, and a plain `contains` would style listings with the
wrong sheet.

The **block background** is not part of the token templates.  It is
handled once for all styles in the glue file, which redefines DocBook's
`shade.verbatim.style` attribute set so that it consults the `@role` of
the listing currently being formatted.  XSLT instantiates attribute
sets against the current node, which is what makes this possible.

That mechanism replaced an earlier wrapper element, and with it a hack
of negative margins (−6pt on three sides) with matching padding, whose
job was to stretch the wrapper's background over the padding of
DocBook's own shaded block.  The hack left a one-pixel column
uncovered on the right-hand edge; consulting the role instead removed
both the hack and the artefact.

Listings that are **not** highlighted keep DocBook's stock shading.
Its value is read out of `pdf.xsl` at generation time rather than
hardcoded, so a book that customises the stock shading keeps its
customisation.

### The HTML glue

The whole HTML glue is three templates, none of them per token or per
style:

1. the **container** template, which wraps the listing in
   `<div class="highlight-rexx-<style>">`.  It extracts the style from
   the container role with `substring-after` / `substring-before`, so it
   does not depend on which styles exist, and it copies the locked
   marker through as `data-rexx-style-locked`.
2. `user.head.content`, which emits the `<link>` elements for the
   sheets, plus a little CSS to place the chooser bar.
3. `user.header.content`, which emits the chooser bar itself.

The chooser's own layout CSS is emitted by the glue rather than added
to the book's `common.css`.  The reason is ownership: those class names
arrive with the chooser and the book's stylesheet knows nothing about
them, so putting them in the book would mean patching a file that
belongs to the ooRexx documentation.  The bar is positioned against
`body`, not the viewport, because the ooRexx content is centred with a
`max-width`.

The token CSS is not generated at all — it is the Parser's existing
`css/rexx-*.css`, unmodified, the same files that serve `md2html` and
the paged.js pipeline.

### The `hl-style` attribute

The attribute is called `hl-style` rather than `style` because DocBook
4.5's DTD discards unknown attributes before the XML reaches the
processing pipeline.  `hldocprep` reads it out of the raw XML text,
before any validation, so it survives.

The attribute itself does not appear in the final XML.  Its effect is
carried by the container role — both the style name and, because an
explicit `hl-style=` counts as a deliberate choice by the author, the
`rexx-style-locked` marker.

### Loading the Rexx Parser

`hldocprep` uses `findProgram` + `loadPackage`, not `::Requires`, to
load `Parser.DocBook.cls`.  This allows a clear, actionable error
message when the Rexx Parser is not installed, instead of a cryptic
`::Requires` failure at load time.

### The XML catalog

On Debian and Ubuntu, the system XML catalog maps
`cdn.docbook.org/release/xsl-nons/` to the DocBook stylesheets **with**
the XSL namespace.  That forces `xsltproc` into namespace-stripping,
which is slow and floods the log with warnings.

`bin/docbook/oorexx-catalog.xml` resolves the URI to `docbook-xsl-nons`
instead.  Use it with:

```
export XML_CATALOG_FILES="/path/to/oorexx-catalog.xml /etc/xml/catalog"
```

## Known Issues in the Surrounding Toolchain

These are **not** highlighting bugs.  All four reproduce in a plain
build without any of these tools, and all four are reportable to the
RexxLA.  They are listed here because they will bite anyone building
the official books, especially on Linux.

1. **`doc2HTML.rex` looks for the common content in `ooRexx`**, while
   the directory is checked out as `oorexx`.  Case-insensitive file
   systems hide this; on Linux the copy step reports "0 files copied"
   and carries on, and the book ends up with no stylesheet at all.
   This is the most damaging of the four, because the failure is
   silent and the result looks like a highlighting problem.
   `hldoc2HTML.rex` resolves the name case-insensitively instead.

2. **`xhtml-common.xsl` duplicates class names.**  Its
   `class.attribute` mode appends `@role` to whatever class it was
   handed, so elements come out as `class="italic italic"` and
   `class="rx-kw rx-kw"`.  Harmless to CSS, untidy in the source.

3. **`xhtml-common.xsl` emits a jQuery call on every page**
   (`$("#site_footer").load(...)`) without any page loading jQuery, so
   every page in the manual logs `ReferenceError: $ is not defined`.

4. **`setup.rex` is Windows-only.**  On Linux and macOS the
   documentation toolchain has to be set up by hand.

## Quick Reference

| Task | Command |
|:-----|:--------|
| Build the PDF with highlighting | `hldocprep bookname` then `hldoc2pdf` |
| Build the HTML with highlighting | `hldocprep bookname` then `hldoc2HTML` |
| Either, in one step | `hldoc2pdf bookname` / `hldoc2HTML bookname` |
| Set the default style | `hldocprep --style dark bookname` |
| Force XSL regeneration | `hldocprep --regen bookname` |
| Enable a listing | Add `language="rexx"` to `<programlisting>` |
| Pin a listing's style | Add `hl-style="dark"` to `<programlisting>` |
| Set a dialect | Add `dialect="cms"` to `<programlisting>` |
| Manual XSL generation | `css2xsl rexx-highlight.xsl` |
| Manual highlighting | `highlight --docbook myfile.rex` |

## See Also

- `bin/docbook/readme.md` — the install-and-go card that ships next to
  the scripts themselves.
- `doc/utilities/css2xsl/` — full reference for `css2xsl.rex` options.
- `doc/utilities/highlight/` — full reference for `highlight.rex`.
- `doc/highlighter/predefined-styles/` — the 25 styles, shown together.
