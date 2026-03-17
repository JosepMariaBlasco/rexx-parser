md2pdf
======

----------------

MD2PDF ("MarkDown to PDF") is a command
that transforms Markdown files to PDF, after expanding
all Rexx fenced code blocks.

Md2pdf operates in two modes: when the argument is a file,
it converts that single file to PDF; when the argument is a directory,
it converts all `.md` files in it (and its subdirectories) to PDF.

Usage
-----

<pre>
[rexx] md2pdf [<em>options</em>] <em>filename</em>
[rexx] md2pdf [<em>options</em>] <em>source-directory</em> [<em>destination-directory</em>]
</pre>

In single-file mode, <em>filename</em> is a file containing Markdown.
If the file is not found and does not already have an extension,
`.md` is appended automatically.

In batch mode, all `.md` files in <em>source-directory</em> and its
subdirectories are converted to PDF.
If a <em>destination-directory</em> is given, the output PDF files
are placed there, replicating the source directory structure;
otherwise, each PDF is placed alongside its source `.md` file.

When called without arguments, md2pdf displays help information and exits.

Options
-------

\

----------------------------------------- ------------------------------
`--check-deps`                            Check that all dependencies are installed
`--continue`                              Continue when a file fails (batch mode)
`-c`, `--css` DIR                         Set the CSS base directory
`--csl` NAME|PATH                         Set the Citation Style Language style
`--default` "options"                     Default options for all code blocks
`-exp`, `--experimental`                  Enable Experimental features for all code blocks
`--fix-outline`                           Fix PDF so that the outline shows automatically
                                          (requires python and pikepdf)
`-h`, `--help`                            Display help and exit
`-it`, `--itrace`                         Print internal traceback on error
`--style` NAME                            Set the default visual theme for Rexx code blocks
`--pandoc-highlighting-style` NAME        Set Pandoc syntax highlighting theme for
                                          non-Rexx code blocks (default: pygments)
`-u`, `--tutor`, `--unicode`              Enable TUTOR-flavoured Unicode for all code blocks
`-xtr`, `--executor`                      Enable Executor support for all code blocks
----------------------------------------- ------------------------------

\

The default Citation Style Language style is `rexxpub`, and the default
Rexx highlighting theme is `dark`.
When `--csl` receives a plain name (no path separators), it looks for
the corresponding `.csl` file in the `csl` subdirectory of the Rexx
Parser installation (e.g. `--csl rexxpub` resolves to `csl/rexxpub.csl`).
When the argument contains a `/` or `\`, it is treated as a file path
and used as-is, which allows referencing CSL files stored outside the
distribution.

When `--css` is used, all CSS files are loaded from the specified
directory instead of the default `css/` directory inside the Rexx
Parser installation. The directory is expected to contain the same
internal structure: `bootstrap.css` at the root, highlighting styles
under `flattened/`, and document class styles under `print/`.
This allows users to publish their own documents using custom
styles and document classes independently of the Rexx Parser
installation.

The document class defaults to the base name of the input file
(e.g. `article` for `article.md`).  If the inferred document class
does not correspond to an existing CSS file, the `default` class is
used as a fallback.  The document class can be overridden in the
YAML front matter using the `docclass` option.

The `--continue` option is useful in batch mode: when a file fails
(due to a syntax error in a fenced code block, a missing document
class, or any other error), processing continues with the remaining
files instead of aborting.  At the end, a summary reports the number
of files processed and the number of failures.

By default, figures and code listings that have a caption are
automatically numbered following the LaTeX convention ("Figure 1",
"Listing 1", etc.).  Figures and listings use independent counters.
Listing captions are placed above the code block, and figure captions
below the image, matching the LaTeX defaults.  These defaults can be
changed in the YAML front matter.

The `-xtr`/`--executor`, `-exp`/`--experimental`, and
`-u`/`--tutor`/`--unicode` options enable the corresponding language
extensions for all Rexx fenced code blocks in the document.  They
are equivalent to specifying `executor`, `experimental`, or `tutor`
in the `--default` string, or to adding those attributes to every
individual fenced code block.

YAML front matter
-----------------

Md2pdf reads RexxPub options from the YAML front matter block of each
Markdown file.  Options are placed under the `rexxpub:` key, separate
from Pandoc's standard metadata:

```
---
bibliography: references.bib
rexxpub:
  docclass: article
  language: es
  section-numbers: 3
  number-figures: true
  size: 12
  style: print
  outline: 3
---
```

The supported options under `rexxpub:` include `style`, `size`,
`section-numbers`, `number-figures` (which accepts `0`, `1`, `true`,
or `false`, case-insensitive), `docclass`, `language`, `outline`,
as well as `listings:` and `figures:` sub-tables for caption and
frame customization, and the Pandoc top-level `highlight-style`.

All options except `style` are author options and can only be set in the
YAML front matter.  The highlighting `style` follows a **reader-wins**
policy: the `--style` command-line option takes precedence over the YAML
value, which in turn takes precedence over the default (`dark`).

See the [YAML front matter documentation](../../rexxpub/yaml/) for the
full specification.

Prerequisites
-------------

+ A working installation of <a href="https://pandoc.org/">Pandoc</a> is required.
+ A working installation of <a href="https://pagedjs.org/">pagedjs-cli</a> is required.
+ To be able to install `pagedjs-cli`, you will have to install
  <a href="https://nodejs.org">Node.js</a> first. `Node.js` automatically
  installs `npm`.
+ The `--fix-outline` option additionally requires
  <a href="https://www.python.org/">Python</a> and the
  <a href="https://pypi.org/project/pikepdf/">pikepdf</a> library.

You can verify that all dependencies are correctly installed by running:

<pre>
[rexx] md2pdf --check-deps
</pre>

This checks for the presence of pandoc, Node.js, npm and pagedjs-cli.

Please refer to [this page](../../rexxpub/) for more installation details.

Program operation
-----------------

In single-file mode, md2pdf reads the contents of the provided
*filename*, changes to the directory containing the file (so that
Pandoc can resolve relative paths for bibliographies and other
resources), and converts it to HTML using `Pandoc` with `--citeproc`
for citation processing and the `inline-footnotes.lua` Lua filter
for paged.js-compatible footnotes.  It then creates a whole,
self-contained, HTML+CSS file, containing all the necessary CSS
and the generated HTML.  Finally `pagedjs-cli` is invoked to transform
the result into a print-quality PDF file.  Paged.js starts a headless
version of Chromium and injects the necessary JavaScript to simulate
the features of the
[CSS Paged Media standard](https://www.w3.org/TR/css-page-3/).

In batch mode, md2pdf uses `SysFileTree` to recursively list
all `.md` files in the source directory and processes them in turn,
applying the same pipeline to each file.  The document class for each
file is inferred from its filename, so a directory tree containing
`article.md`, `slides.md` and `readme.md` files will produce PDFs
using the `article`, `slides` and `default` classes respectively.