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
The default extension is `.md`.

Options
-------

\

----------------------------------------- ------------------------------
`--check-deps`                            Checks that all the dependencies are installed
`--csl` NAME                              Sets the Citation Style Language style
`--docclass` CLASS                        Controls the overall layout and CSS
`--default` "options"                     Default options for all code blocks
`-h`, `--help`                            Display this help
`-it`, `--itrace`                         Print internal traceback on error
`-l`, `--language` CODE&nbsp;&nbsp;&nbsp; Set document language (e.g. en, es, fr)
`--style` NAME                            Sets the default theme for Rexx code blocks
----------------------------------------- ------------------------------

\

The default document class is `article`, the default language is `en`,
and the default Citation Style Language is `ieee`.
CSL files should be stored in the `csl` subdirectory.

Prerequisites
-------------

+ A working installation of <a href="https://pandoc.org/">Pandoc</a> is required.
+ A working installation of <a href="https://pagedjs.org/">pagedjs-cli</a> is required.
+ To be able to install `pagedjs-cli`, you will have to install
  <a href="https://nodejs.org">Node.js</a> first. `Node.js` automatically
  installs `npm`.

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
to simulate the features of
[CSS Paged Media standard](https://www.w3.org/TR/css-page-3/).

Program source
--------------

~~~rexx {source=../../../bin/md2pdf.rex}
~~~