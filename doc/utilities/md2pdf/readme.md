md2pdf
=======

----------------

MD2PDF ("MarkDown to PDF") is a command
that transforms a Markdown file to PDF, after expanding
all Rexx fenced code blocks.

Usage
-----

<pre>
[rexx] md2pdf [<em>options</em>] <em>filename</em>
</pre>

<em>Filename</em> is a file containing Markdown.
If the file is not found and does not already have an extension,
`.md` is appended automatically.

When called without arguments, display help information and exit.

Options
-------

\

----------------------------------------- ------------------------------
`--check-deps`                            Check that all dependencies are installed
`--csl` NAME                              Set the Citation Style Language style
`--default` "options"                     Default options for all code blocks
`--docclass` CLASS                        Control the overall layout and CSS
`--fix-outline`                           Fix PDF so that the outline shows automatically
                                          (requires python and pikepdf)
`-h`, `--help`                            Display help and exit
`-it`, `--itrace`                         Print internal traceback on error
`-l`, `--language` CODE&nbsp;&nbsp;&nbsp; Set document language (e.g. en, es, fr)
`--outline` N                             Generate outline with H1,...,HN (default: 3, range: 0-6)
`--size` SIZE                             Set the font size in pt (10, 12 or 14; default: 12)
`--style` NAME                            Set the default visual theme for Rexx code blocks
----------------------------------------- ------------------------------

\

The default language is `en`, the default Citation Style Language
style is `ieee`, and the default Rexx highlighting theme is `dark`.
CSL files should be stored in the `csl` subdirectory.

When `--docclass` is not specified, the document class defaults to
the base name of the input file (e.g. `article` for `article.md`).

When `--outline` is set to 0, no outline is generated.

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

Please refer to [this page](../../publisher/) for more installation details.

Program operation
-----------------

Md2pdf reads the contents of the provided *filename*
and converts it to HTML using `Pandoc`. It then creates
a whole, self-contained, HTML+CSS file, containing
all the necessary CSS and the provided HTML.
Finally `pagedjs-cli` is invoked to transform
the result into a print-quality PDF file.
Paged.js starts a headless version of Chromium
and injects the necessary JavaScript
to simulate the features of the
[CSS Paged Media standard](https://www.w3.org/TR/css-page-3/).

Program source
--------------

~~~rexx {source=../../../bin/md2pdf.rex}
~~~