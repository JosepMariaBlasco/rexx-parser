md2html
=======

----------------

MD2Html ("MarkDown to HTML") is a batch utility
that transforms a set of Markdown files to HTML, after expanding
all Rexx fenced code blocks.

Usage
-----

<pre>
[rexx] md2html [<em>options</em>] <em>source</em> [<em>destination</em>]
</pre>

<em>Source</em> and <em>destination</em> should be existing directories.
<em>Destination</em> defaults to the current directory.

Options
-------

\

--------------------------------------------------------------------------------- ------------------------------
`-?`                                                                              Display this help
<code>-c <em>cssbase</em></code>, <code>--css <em>cssbase</em></code>&nbsp;&nbsp; Where to locate the CSS files
`-h`, `--help`                                                                    Display this help
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

Program operation
-----------------

The `md2html.rex` uses SysFileTree to recursively list all the Markdown
(`.md`) files found in the source directory and processes them in turn.
For each file, the utility first expands all the Rexx fenced code blocks,
using [the Rexx Highlighter](../../highlighter),
then runs <a href="https://pandoc.org/">Pandoc</a> against result to convert
it to HTML, and finally calls a set of routines
found in `md2html.custom.rex`, which provide the constant or
almost constant parts of an HTML page, like headers, footers,
menus or sidebars.

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
                                       │ ◀──── default.md2html + m2html.custom.rex
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
`md2html.custom.rex` first in path specified by the `-p` or `--path` options,
if present, then in the current directory,
then in the destination directory, then in the
source directory, and finally using the standard Rexx search order
for external files.

Pandoc is used to convert the source Markdown content into
the inner part of the HTML file. The structure of the whole
HTML page is defined in a separate template file called
`default.md2html`, which is searched in the same order
that `md2html.custom.rex`. Md2html looks for this file and reads
a line at a time. Lines starting with `"--"` (in the first column)
are considered to be comments and are completely ignored.
Other lines will be copied to the target file as-is,
and some special markers will be expanded by md2html. For example,
`%contents%` will be substituted by the output generated by
Pandoc, %sidebar% will be substituted by the text returned
by a routine in `md2html.custom.rex`, if found, and so on.
A sample `default.md2html` is distributed with the Rexxx Parser; it can
be found in the `bin` subdirectory.

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

`Md2html.TranslateFilename`
: Called every time a file is processed. Arg(1) is the filename (including
  the extension). Returns the translated filename, or `.Nil` when no
  translation is necessary. In the default implementation, returns the value
  returned by the package-local `.TranslateFilename[Arg(1)]`.

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

Filename-specific styles
------------------------

TBD.

Complete list of markers accepted in `default.md2html`
-----------------------------------------------------

TBD.

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

Program source
--------------

~~~rexx {source=../../../bin/md2html.rex}
~~~