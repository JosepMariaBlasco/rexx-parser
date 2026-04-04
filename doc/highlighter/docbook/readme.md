# Rexx Syntax Highlighting for DocBook / ooRexx Official Books

---

## Overview

The Rexx Parser includes a complete toolchain for adding syntax
highlighting to the official ooRexx documentation books (rexxref,
rexxpg, etc.).  These books use DocBook XML and are built with
Publican + Apache FOP to produce PDF.

The toolchain is a drop-in addition to the existing build process:
you mark `<programlisting>` blocks with `language="rexx"`, run
`hldocprep` instead of `docprep`, and `hldoc2pdf` instead of
`doc2pdf`.  Everything else stays the same.

The result is fully highlighted Rexx code in the PDF — keywords in
bold blue, comments in italic, strings in green, etc. — using the
same CSS-based themes that the Rexx Highlighter uses elsewhere.
Multiple highlighting styles can coexist in the same book, and each
listing can choose its own style and granularity level.


## Prerequisites

1. **The ooRexx documentation tree** from the SourceForge SVN
   repository.  To download a read-only copy:

   ```
   svn checkout svn://svn.code.sf.net/p/oorexx/code-0/docs/trunk ooRexx-docs
   ```

2. **A working build environment**: Publican with the `oorexx` brand,
   Apache FOP, and the `tools/bldoc_orx/` scripts (docprep, doc2fo,
   fo2pdf, etc.).  You should be able to build a book with `docprep`
   + `doc2pdf` before trying the highlighting tools.

3. **The Rexx Parser**, with its `bin/` directory on your `PATH` or
   `REXX_PATH` so that `hldocprep` can find the highlighting engine.


## Installation

Copy the three scripts from the `bin/docbook/` directory of the Rexx
Parser project to your `tools/bldoc_orx/` directory:

```
cp hldocprep.rex hldoc2fo.rex hldoc2pdf.rex /path/to/ooRexx-docs/tools/bldoc_orx/
```

No changes to existing files are required.  The original `docprep`,
`doc2fo`, and `doc2pdf` remain untouched and continue to work as
before.


## Quick start

From your `tools/bldoc_orx/` directory:

```
[rexx] hldocprep bookname
[rexx] hldoc2pdf
```

For example, to build the Rexx Reference with highlighting:

```
[rexx] hldocprep rexxref
[rexx] hldoc2pdf
```

That's it.  `hldocprep` does everything `docprep` does, plus:

1. Scans all `.xml` files in the work folder for
   `<programlisting language="rexx">` blocks and highlights them.
2. Generates the XSL files that tell FOP how to render the
   highlighted code.

`hldoc2pdf` builds the PDF using those generated XSL files.

You can also run the steps separately if you prefer:

```
[rexx] hldocprep bookname
[rexx] hldoc2fo
[rexx] fo2pdf
```


## Enabling highlighting for a listing

Add `language="rexx"` to any `<programlisting>` you want highlighted:

```xml
<programlisting language="rexx">Say "Hello, world!"
x = 42
If x > 0 Then
  Say "positive"</programlisting>
```

Only listings with `language="rexx"` are processed.  All other
listings are left untouched, so you can migrate incrementally —
add `language="rexx"` to a few listings, build, check the result,
and continue.


## Per-listing options

### Highlighting style

By default, all listings are highlighted with the `print` style
(designed for PDF output on white backgrounds).  You can choose a
different style for individual listings with the `hl-style`
attribute:

```xml
<programlisting language="rexx" hl-style="dark">Say "Hello!"</programlisting>
```

The attribute is called `hl-style` (not `style`) because DocBook's
DTD silently discards unknown attributes.  `hldocprep` reads the
attribute from the raw XML text before the DTD has a chance to
remove it.

When a listing uses a different style, the PDF will show the
appropriate colors and background for that style.  For example,
`hl-style="dark"` produces light text on a dark background.

### Granularity

Highlighting granularity can be controlled per listing with XML
attributes, using the same option names as in FencedCode for
Markdown:

```xml
<programlisting language="rexx" operator="detail" constant="full">
...
</programlisting>
```

| Attribute      | Values                    | Default     |
|:---------------|:--------------------------|:------------|
| `hl-style`     | any highlighting style    | `print`     |
| `operator`     | `group`, `full`, `detail` | `group`     |
| `special`      | `group`, `full`, `detail` | `group`     |
| `constant`     | `group`, `full`, `detail` | `group`     |
| `assignment`   | `group`, `full`, `detail` | `group`     |
| `doccomments`  | `detailed`, `block`       | `detailed`  |

The granularity modes control how much visual distinction each token
category preserves:

- **`group`** — all elements in a category share the same color
  (e.g. all operators look the same).
- **`detail`** — each element gets its own specific color where the
  CSS style defines one.
- **`full`** — elements get both the generic and specific classes,
  resulting in maximum detail.


## Command-line options

`hldocprep` accepts two options before the book name:

### `--style STYLE`

Sets the default highlighting style for all listings that don't have
an explicit `hl-style` attribute.  The default is `print`.

```
[rexx] hldocprep --style dark rexxref
```

### `--regen`

Forces regeneration of all XSL files, even if they already exist.
Use this after updating the Rexx Parser or changing CSS themes.

```
[rexx] hldocprep --regen rexxref
```

Without `--regen`, XSL files are only generated the first time.
Subsequent runs reuse the existing files.


## Multi-style support

A book can use multiple highlighting styles.  For example, most
listings might use the default `print` style, while a few use
`dark` to demonstrate dark-theme rendering.

This works automatically — `hldocprep` discovers which styles are
used in the highlighted XML and generates an XSL file for each one.
No manual configuration is needed.

Example output from `hldocprep`:

```
15:45:32 2 style(s) found: dark, print.
15:45:32 - Generating hl-styles/rexx-highlight-print.xsl ...
15:45:32 - Generating hl-styles/rexx-highlight-dark.xsl ...
```


## Dual-path builds

The traditional and highlighted build paths coexist without conflict:

- `docprep` + `doc2pdf` — traditional build (no highlighting)
- `hldocprep` + `hldoc2pdf` — build with syntax highlighting

Both paths use the same SVN sources and the same `fo2pdf` step.
The highlighting tools only modify files in the work folder; the
original SVN sources are never touched.


## Manual workflow

The automated workflow described above is the recommended way to
use the toolchain.  The manual workflow below is documented for
understanding each step or for troubleshooting.

### Step 1: Generate XSL templates

From the `bin/` directory of the Rexx Parser:

```
[rexx] css2xsl rexx-highlight.xsl
```

This generates `rexx-highlight.xsl` using the `print` style.  The
`--style` option selects a different CSS style:

```
[rexx] css2xsl --style dark rexx-highlight.xsl
```

Granularity options control how much detail each token category
preserves:

```
[rexx] css2xsl --operator detail --constant full rexx-highlight.xsl
```

See `doc/utilities/css2xsl/` for the full option reference.

### Step 2: Install the XSL in the build system

Copy the generated file to the `tools/bldoc_orx/` directory:

```
cp rexx-highlight.xsl /path/to/ooRexx-docs/tools/bldoc_orx/
```

Then edit `tools/bldoc_orx/pdf.xsl` and add an `xsl:include` for it.
Look for the section with the `perl_*` templates (around line 1922)
and add just before them:

```xml
<!-- Rexx syntax highlighting templates (generated by css2xsl.rex) -->
<xsl:include href="rexx-highlight.xsl"/>
```

### Step 3: Highlight a Rexx file

Use `highlight --docbook` to convert a `.rex` file to DocBook XML:

```
[rexx] highlight --docbook myprogram.rex
```

The output goes to stdout.  For example, given this input:

```rexx
/* A simple Rexx program */
Say "Hello, world!"
x = 42
If x > 0 Then
  Say "positive"
```

The output is XML with `rexx_*` elements:

```xml
<rexx_print_cm>/* A simple Rexx program */</rexx_print_cm>
<rexx_print_kw>Say</rexx_print_kw> ...
```

### Step 4: Insert into DocBook

Paste the highlighted output directly inside a `<programlisting>`
element — no extra whitespace before the first element or after the
last:

```xml
<programlisting><rexx_print_cm>/* A simple Rexx program */</rexx_print_cm>
<rexx_print_kw>Say</rexx_print_kw> ...</programlisting>
```

### Step 5: Build the PDF

```
[rexx] docprep rexxref
[rexx] doc2pdf
```


## Troubleshooting

**"Unknown element rexx_kw" or similar in FOP output:**
The XSL templates are not being loaded.  If using the automated
workflow, check that `pdf-hl.xsl` was generated.  If using the
manual workflow, verify the `xsl:include href` path.

**PDF is generated but without colors:**
Publican may be using a different `pdf.xsl` than expected.  Check
which customization layer is active (depends on the `oorexx` brand
configuration).  The automated workflow avoids this by using its own
`pdf-hl.xsl`.

**XML parsing errors:**
Ensure the `<programlisting>` content is valid XML.  Common issues:
unescaped `&` or `<` in Rexx source code (the DocBook driver handles
this automatically), or unclosed tags.

**Warning: highlighting failed for block at line N:**
The Rexx code in that listing could not be parsed — typically a
syntax error or incomplete code fragment (e.g. an EXPOSE instruction
shown outside its METHOD context).  The block is left unchanged.
Check the log output for the specific file and line.

**Close the PDF reader before regenerating** — FOP cannot overwrite
an open file.


## Implementation details

This section documents the internal architecture.  It is not needed
for using the toolchain, but may help with understanding,
troubleshooting, or extending the system.

### Architecture overview

The toolchain has two independent sides that use the same naming
convention to connect:

- **Content side**: `Parser.DocBook.cls` provides the
  `ProcessProgramListings` routine, which scans DocBook XML for
  `<programlisting language="rexx">` blocks and replaces their
  plain-text content with `rexx_*` elements using the DocBook
  highlighting driver (`HLDrivers/DocBook.Driver.cls`).

- **XSL side**: `css2xsl.rex` reads a Rexx CSS theme and generates
  XSL templates that map each `rexx_*` element to `fo:inline`
  formatting attributes (color, font-weight, font-style).

### Element naming convention

CSS class strings are converted to XML element names by stripping the
`rx-` prefix, replacing hyphens with underscores, and joining under
the `rexx_STYLE_` prefix.  The style name is always included:

| CSS classes (style `print`)      | XML element                    |
|:---------------------------------|:-------------------------------|
| `rx-kw`                         | `rexx_print_kw`                |
| `rx-op rx-add`                  | `rexx_print_op_add`            |
| `rx-const rx-method rx-oquo`    | `rexx_print_const_method_oquo` |

Whitespace is emitted as plain XML-escaped text (no element wrapper).

### Block background and the wrapper element

Each highlighted listing is wrapped in a `rexx_style_STYLE` element
(e.g. `rexx_style_print`, `rexx_style_dark`).  This wrapper carries
the block-level formatting — background color, text color — via an
XSL template that emits an `fo:block`.

DocBook 4.5's DTD silently discards unknown XML attributes but lets
custom elements pass through, which is why a wrapper element is used
instead of an attribute.

The wrapper's `fo:block` uses negative margins and matching padding
to extend the background color over the padding area of DocBook's
`shade.verbatim.style` block, ensuring a clean visual result with no
border artifacts.

### Style discovery

After highlighting, `hldocprep` scans the processed XML files to
discover which styles are actually used.  It reads each file in a
single `charIn` call and searches for `<rexx_STYLE_` patterns,
extracting the style name from each element.  This avoids the need
for manual configuration when multiple styles are in use.

### XSL file structure

`hldocprep` generates the following files in the `tools/bldoc_orx/`
directory:

- `hl-styles/rexx-highlight-STYLE.xsl` — one XSL file per style,
  each containing all the `fo:inline` and `fo:block` templates for
  that style (generated by `css2xsl.rex`).
- `rexx-highlights.xsl` — a glue file with `xsl:include` directives
  for all per-style XSL files.  Regenerated on every run.
- `pdf-hl.xsl` — a copy of `pdf.xsl` with an `xsl:include` for
  `rexx-highlights.xsl` inserted before the `perl_*` templates.
  Generated only once; use `--regen` to force regeneration.

### Loading the Rexx Parser

`hldocprep` uses `findProgram` + `loadPackage` (not `::Requires`)
to load `Parser.DocBook.cls`.  This allows a clear, user-friendly
error message if the Rexx Parser is not installed, instead of a
cryptic `::Requires` failure.

### The `hl-style` attribute

The attribute is called `hl-style` instead of `style` because
DocBook 4.5's DTD discards unknown attributes before the XML reaches
the processing pipeline.  `hldocprep` reads the attribute from the
raw XML text (before DTD validation), so it survives.  The attribute
is not preserved in the final XML, but its effect (the style choice)
is encoded in the element names and wrapper element.


## Quick reference

| Task | Command |
|:-----|:--------|
| Build with highlighting | `hldocprep bookname` then `hldoc2pdf` |
| Set default style | `hldocprep --style dark bookname` |
| Force XSL regeneration | `hldocprep --regen bookname` |
| Enable a listing | Add `language="rexx"` to `<programlisting>` |
| Per-listing style | Add `hl-style="dark"` to `<programlisting>` |
| Manual XSL generation | `css2xsl rexx-highlight.xsl` |
| Manual highlighting | `highlight --docbook myfile.rex` |


## See also

- `doc/utilities/css2xsl/` — full reference for `css2xsl.rex` options
- `doc/utilities/highlight/` — full reference for `highlight.rex`
- `bin/docbook/readme.md` — quick-start guide (subset of this document)