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

When called without arguments, display help information and exit.

Options
-------

\

----------------------------------------- ------------------------------
`--check-deps`                            Check that all dependencies are installed
`--continue`                              Continue when a file fails (batch mode)
`--csl` NAME                              Set the Citation Style Language style
`--default` "options"                     Default options for all code blocks
`--docclass` CLASS                        Control the overall layout and CSS
`-exp`, `--experimental`                  Enable Experimental features for all code blocks
`--fix-outline`                           Fix PDF so that the outline shows automatically
                                          (requires python and pikepdf)
`-h`, `--help`                            Display help and exit
`-it`, `--itrace`                         Print internal traceback on error
`-l`, `--language` CODE&nbsp;&nbsp;&nbsp; Set document language (e.g. en, es, fr)
`--outline` N                             Generate outline with H1,...,HN (default: 3, range: 0-6)
`--section-numbers` N                     Number sections down to depth N (0=off, max 4)
`--size` SIZE                             Set the font size in pt (10, 12 or 14; default: 12)
`--style` NAME                            Set the default visual theme for Rexx code blocks
`-u`, `--tutor`, `--unicode`              Enable TUTOR-flavoured Unicode for all code blocks
`-xtr`, `--executor`                      Enable Executor support for all code blocks
----------------------------------------- ------------------------------

\

The default language is `en`, the default Citation Style Language
style is `rexxpub`, and the default Rexx highlighting theme is `dark`.
CSL files should be stored in the `csl` subdirectory.

When `--docclass` is not specified, the document class defaults to
the base name of the input file (e.g. `article` for `article.md`).
If the inferred document class does not correspond to an existing
CSS file, the `default` class is used as a fallback.

When `--outline` is set to 0, no outline is generated.

When `--section-numbers` is used, headings are automatically
numbered up to the specified depth: 1 for h1 only, 2 for h1
and h2, and so on up to 4.  The numbering follows the LaTeX
convention (e.g. 1., 1.1, 1.1.1).  Headings marked with
Pandoc's `{.unnumbered}` or `{-}` attribute are excluded from
numbering, as are headings with the `.part` or `.chapter`
classes, and headings inside `.title-page` or `.toc-exclude`
containers.  The default is 0 (no section numbering).

The `--continue` option is useful in batch mode: when a file fails
(due to a syntax error in a fenced code block, a missing document
class, or any other error), processing continues with the remaining
files instead of aborting.  At the end, a summary reports the number
of files processed and the number of failures.

The `-xtr`/`--executor`, `-exp`/`--experimental`, and
`-u`/`--tutor`/`--unicode` options enable the corresponding language
extensions for all Rexx fenced code blocks in the document.  They
are equivalent to specifying `executor`, `experimental`, or `tutor`
in the `--default` string, or to adding those attributes to every
individual fenced code block.

Prerequisites
-------------

+ A working installation of <a href="https://pandoc.org/">Pandoc</a> is required.
+ A working installation of <a href="https://pagedjs.org/">pagedjs-cli</a> is required.
+ To be able to install `pagedjs-cli`, you will have to install
  <a href="https://nodejs.org">Node.js</a> first. `Node.js` automatically
  installs `npm`.

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

Program source
--------------

~~~rexx {source=../../../bin/md2pdf.rex}
~~~