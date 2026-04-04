# DocBook Highlighting Tools

This directory contains tools for adding Rexx syntax highlighting to
the official ooRexx documentation books (DocBook XML + Publican + FOP).

## Files

```
hldocprep.rex    Highlighted document preparation (drop-in companion
                 for docprep).  Runs docprep, then highlights all
                 <programlisting language="rexx"> blocks and generates
                 the XSL templates required by the PDF build.

hldoc2fo.rex     XML-to-FO transformation using pdf-hl.xsl (drop-in
                 companion for doc2fo).

hldoc2pdf.rex    Full PDF build with highlighting (drop-in companion
                 for doc2pdf).  Calls hldoc2fo + fo2pdf.

readme.md        This file.
```

## Prerequisites

1. The ooRexx documentation build environment (`tools/bldoc_orx/`)
   must be set up and working — you should be able to build a book
   with `docprep` + `doc2pdf` before trying `hldocprep`.

2. The **Rexx Parser** must be installed and its `bin/` directory
   must be on your `PATH` or `REXX_PATH` so that `hldocprep` can
   find the highlighting engine.

## Installation

Copy the three `.rex` files to your `tools/bldoc_orx/` directory,
alongside `docprep.rex`, `doc2fo.rex`, etc.:

```
cp hldocprep.rex hldoc2fo.rex hldoc2pdf.rex /path/to/ooRexx-docs/tools/bldoc_orx/
```

No changes to existing files are required.

## Usage

From the `tools/bldoc_orx/` directory:

```
[rexx] hldocprep bookname
[rexx] hldoc2pdf
```

For example: `hldocprep rexxref` then `hldoc2pdf`.

Or, step by step: `hldocprep bookname` then `hldoc2fo` then `fo2pdf`.

## Enabling highlighting

Add `language="rexx"` to any `<programlisting>`:

```xml
<programlisting language="rexx">Say "Hello, world!"
x = 42
If x > 0 Then
  Say "positive"</programlisting>
```

Listings without `language="rexx"` are left untouched.

## Per-listing options

Use `hl-style` to select a different highlighting style per listing:

```xml
<programlisting language="rexx" hl-style="dark">Say "Hello!"</programlisting>
```

Granularity can also be set per listing:

| Attribute      | Values                    | Default     |
|:---------------|:--------------------------|:------------|
| `hl-style`     | any highlighting style    | `print`     |
| `operator`     | `group`, `full`, `detail` | `group`     |
| `special`      | `group`, `full`, `detail` | `group`     |
| `constant`     | `group`, `full`, `detail` | `group`     |
| `assignment`   | `group`, `full`, `detail` | `group`     |
| `doccomments`  | `detailed`, `block`       | `detailed`  |

## Command-line options

- `--style STYLE` — set the default style (default: `print`).
- `--regen` — force regeneration of XSL files.

Example: `hldocprep --style dark --regen rexxref`

## Multi-style support

If a book uses multiple styles (via `hl-style`), `hldocprep`
discovers them automatically and generates the appropriate XSL
files for each one.  No manual configuration is needed.

## Dual-path builds

- `docprep` + `doc2pdf` — traditional build (no highlighting)
- `hldocprep` + `hldoc2pdf` — highlighted build

Both work on the same source files.  The highlighting tools only
modify files in the work folder; the original sources are never
touched.

## See also

- `doc/highlighter/docbook/readme.md` in the Rexx Parser project —
  full documentation including manual workflow, troubleshooting,
  and implementation details.