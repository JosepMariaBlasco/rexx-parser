md2html
=======

----------------

MD2Html ("MarkDown to HTML") is a utility
that transforms Markdown files to HTML, after expanding
all Rexx fenced code blocks.

Md2html operates in two modes: when the argument is a file,
it converts that single file to HTML; when the argument is a directory,
it converts all `.md` files in it (and its subdirectories) to HTML.

Usage
-----

<pre>
[rexx] md2html [<em>options</em>] <em>filename</em> [<em>destination</em>]
[rexx] md2html [<em>options</em>] <em>source</em> [<em>destination</em>]
</pre>

In single-file mode, <em>filename</em> is a file containing Markdown.
If the file is not found and does not already have an extension,
`.md` is appended automatically.
The output HTML file is placed in the <em>destination</em> directory,
which defaults to the current directory.

In batch mode, <em>source</em> and <em>destination</em> should be
existing directories.
<em>Destination</em> defaults to the current directory.

When called without arguments, display help information and exit.

Options
-------

\

--------------------------------------------------------------------------------- ------------------------------
`-h`, `--help`                                                                    Display help and exit
<code>-c <em>cssbase</em></code>, <code>--css <em>cssbase</em></code>&nbsp;&nbsp; Where to locate the CSS files
`--continue`                                                                      Continue when a fenced code block is in error
`--default` "attributes"                                                          Default attributes for all code blocks
`-it`, `--itrace`                                                                 Print internal traceback on error
<code>-j <em>jsbase</em></code>, <code>--js  <em>jsbase</em></code>               Where to locate the JavaScript files
<code>-p <em>path</em></code>, <code>--path  <em>path</em></code>                 First path to search for `default.md2html` and `md2html.custom.rex`
--------------------------------------------------------------------------------- ------------------------------

\

When <em>cssbase</em> is not specified, it defaults to the filesystem location
of a first-level `css` subdirectory of the <em>destination</em> directory,
if one exists; the same is true, respectively, of <em>jsbase</em> and
the `js` subdirectory.

Prerequisites
-------------

A working installation of <a href="https://pandoc.org/">Pandoc</a> is required.

YAML front matter
-----------------

Md2html reads RexxPub options from the YAML front matter block of each
Markdown file.  Options are placed under the `rexxpub:` key, separate
from Pandoc's standard metadata:

```
---
bibliography: references.bib
rexxpub:
  section-numbers: 3
  number-figures: true
  language: en
  style: light
---
```

The supported options under `rexxpub:` include `style`, `section-numbers`,
`number-figures` (which accepts `0`, `1`, `true`, or `false`,
case-insensitive), and `language`, as well as `listings:` and `figures:`
sub-tables for caption and frame customization, and the Pandoc top-level
`highlight-style`.

All options are set exclusively in the YAML front matter.  Since md2html
has no `--style` command-line option, the YAML `style` value is always
used when present; otherwise, the default (`dark`) applies.

See the [YAML front matter documentation](../../rexxpub/yaml/) for the
full specification.

Program operation
-----------------

In both modes, the processing of each Markdown file follows the
same pipeline.  The utility first expands all the Rexx fenced code blocks,
using [the Rexx Highlighter](../../highlighter),
then runs <a href="https://pandoc.org/">Pandoc</a> against the result to convert
it to HTML, and finally calls a set of routines
found in `md2html.custom.rex`, which provide the constant or
almost constant parts of an HTML page, like headers, footers,
menus or sidebars.

In single-file mode, md2html changes to the directory containing
the file before processing, so that Pandoc can resolve relative
paths for resources such as bibliographies.

In batch mode, md2html uses `SysFileTree` to recursively list all the
Markdown (`.md`) files found in the source directory and processes
them in turn.

```
                               md2html workflow
                               ────────────────

                        ╔═════════════════════════════╗
                        ║                             ║
                        ║ (1) Markdown source file    ║
                        ║                             ║
                        ╚═════════════════════════════╝
                                       │
                                       │ ◀──── The Rexx Highlighter (FencedCode.cls)
                                       │
                                       ▼
                        ╔═════════════════════════════╗
                        ║                             ║
                        ║ (2) Markdown +              ║
                        ║     Rexx code expanded      ║
                        ║                             ║
                        ╚═════════════════════════════╝
                                       │
                                       │ ◀──── pandoc
                                       │
                                       ▼
                        ╔═════════════════════════════╗
                        ║                             ║
                        ║ (3) HTML code (inner part   ║
                        ║     of the page)            ║
                        ║                             ║
                        ╚═════════════════════════════╝
                                       │
                                       │ ◀──── default.md2html + md2html.custom.rex
                                       │
                                       ▼
                        ╔═════════════════════════════╗
                        ║                             ║
                        ║ (4) Final HTML + CSS code   ║
                        ║                             ║
                        ╚═════════════════════════════╝
```

A sample `md2html.custom.rex` is distributed with the Rexx Parser.
To allow for maximum customization, the md2html utility looks for
`md2html.custom.rex` first in the path specified by the `-p` or `--path` options,
if present, then in the current directory,
then in the destination directory, then (in batch mode) in the
source directory, and finally using the standard Rexx search order
for external files.

Pandoc is used to convert the source Markdown content into
the inner part of the HTML file. The structure of the whole
HTML page is defined in a separate template file called
`default.md2html`, which is searched in the same order
as `md2html.custom.rex`. Md2html looks for this file and reads
a line at a time. Lines starting with `"--"` (in the first column)
are considered to be comments and are completely ignored.
Other lines will be copied to the target file as-is,
and some special markers will be expanded by md2html.
A sample `default.md2html` is distributed with the Rexx Parser; it can
be found in the `bin` subdirectory.

Complete list of markers accepted in `default.md2html`
-----------------------------------------------------

The following markers are recognized in the template file (they should
appear alone on a line, in lowercase):

`%title%`
: Replaced by the contents of the first `<h1>` header found in the file.

`%header%`
: Calls the `Md2html.Header` routine.

`%contentheader%`
: Calls the `Md2html.ContentHeader` routine.

`%contents%`
: Replaced by the HTML output generated by Pandoc.

`%footer%`
: Calls the `Md2html.Footer` routine.

`%sidebar%`
: Calls the `Md2html.Sidebar` routine.

`%printstyle%`
: If a print style CSS file exists for the current file (see below), inserts a link to it.

`%filenamespecificstyle%`
: If a filename-specific style has been defined (see below), inserts a link to it.

`%usedStyles%`
: Replaced by `<link>` elements for every Rexx highlighting CSS style used in
  the fenced code blocks of the file.

`%cssbase%` and `%jsbase%`
: Replaced early during template loading with the values of the corresponding options.

`%SectionNumbers%`
: Replaced by the CSS class for section numbering (e.g. `section-numbers-3`).
  The default depth depends on the filename: 3 for `article` (and others),
  2 for `book`, 0 for `slides`.  Can be overridden in the YAML front matter.

`%NumberFigures%`
: Replaced by `number-figures` when figure/listing numbering is active
  (the default), or by an empty string when disabled in the YAML front matter.

`%printFigures%`
: Inserts a `<script>` tag loading `numberFigures.js` from the JavaScript
  base directory.  This script processes `data-caption` attributes on code
  blocks and numbers figures and listings.

Structure of the `md2html.custom.rex` file
------------------------------------------

The `md2html.custom.rex` routine is called just before the
moment when the individual Markdown files are processed.
The custom file may contain a series of public routines called
<code>md2html.<em>name</em></code>. The conceptual page model
is as follows (all parts except the page contents are optional):

```
--      +-------------------------------------------------------------+
--      |              page header, including the title               |
--      +-------------------------------------------------------------+
--      |                content header               |   side bar    |
--      +---------------------------------------------+               |
--      |                                             |               |
--      |                  contents                   |               |
--      |                                             |               |
--      +-------------------------------------------------------------+
--      |                          page footer                        |
--      +-------------------------------------------------------------+
```

The `md2html`
processor attempts a call to each of these routines
in the following contexts:

`Md2html.Exception`
: Called every time a file is processed. Arg(1) is the filename (including
  the extension). Should return `1` when a file should _not_ be processed,
  and `0` otherwise.

`Md2html.Extension`
: Returns the extension for the HTML files generated by md2html (default is `"html"`).
  In the default implementation, returns the value
  of the package-local `.Extension` environment variable.

`Md2html.Header`
: Called whenever a `%header%` marker is found in the `default.md2html` file.

`Md2html.ContentHeader`
: Called whenever a `%contentheader%` marker is found in the `default.md2html` file.

`Md2html.Footer`
: Called whenever a `%footer%` marker is found in the `default.md2html` file.

`Md2html.SideBar`
: Called whenever a `%sidebar%` marker is found in the `default.md2html` file.

`Md2html.TranslatedName`
: Called every time a file is processed. Arg(1) is the filename (including
  the extension). Returns the translated filename, or `.Nil` when no
  translation is necessary. In the default implementation, returns the value
  returned by the package-local `.TranslateFilename[Arg(1)]`.

`Md2html.FilenameSpecificStyle`
: Called every time a file is processed. Arg(1) is the filename (including
  the extension). Returns the name of a filename-specific CSS style (without
  the `.css` extension), or `.Nil` when no specific style is needed.

CSS and JavaScript
------------------

Most HTML pages use a combination of CSS and JavaScript.
You can specify their location by using the `-c`, `--css`,
`-j` and `--js` options. If the destination directory
contains first-level `css` or `js` directories and these
options have not been specified, md2html will use these
directories, using the `file:///` scheme, which can
be useful for debugging purposes and on local installations.

Print styles
------------

Special print styles, like running headers and running footers,
can be specified by storing in the same directory a file
with the same filename as the Markdown file and
with an additional `.css` extension.
For example, a print style for `readme.md` should be
stored in `readme.md.css`.

A sample run (on Windows)
-------------------------

Open a command window, locate the Rexx Parser directory,
and run `setenv`. Now create a test directory in another drive,
say `C:\Test`. Change to the `C:` drive, and `cd \Test`.
Create a `css` directory under `C:\Test`, and copy the
following files from the `css` subdirectory of the Rexx
Parser distribution: `markdown.css`, `rexx-dark.css` and
`rexx-light.css`. Now, run

<pre>
md2html <em>directory</em>
</pre>

where <em>directory</em> is the Rexx Parser installation
directory.

After a few seconds, you will have a complete, working, translation
of the whole Markdown tree under `C:\Test`.

Please note that, since this is a sample demo run,
header, footer, and sidebar links point to
<https://rexx.epbcn.com/>.