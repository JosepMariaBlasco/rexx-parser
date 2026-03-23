md2epub
=======

----------------

MD2EPUB ("MarkDown to EPUB") is a command
that transforms Markdown files to EPUB ebooks, after expanding
all Rexx fenced code blocks.

Md2epub operates in two modes: when the argument is a file,
it converts that single file to EPUB; when the argument is a directory,
it converts all `.md` files in it (and its subdirectories) to EPUB.

The pipeline is simpler than md2pdf: Pandoc generates the EPUB
directly, without the intermediate pagedjs-cli step.  Pandoc handles
the cover, the table of contents, metadata (author, title, language,
date), and chapter structure.  Rexx syntax highlighting is preserved
in the EPUB through embedded CSS stylesheets.

Usage
-----

<pre>
[rexx] md2epub [<em>options</em>] <em>filename</em>
[rexx] md2epub [<em>options</em>] <em>source-directory</em> [<em>destination-directory</em>]
</pre>

In single-file mode, <em>filename</em> is a file containing Markdown.
If the file is not found and does not already have an extension,
`.md` is appended automatically.

In batch mode, all `.md` files in <em>source-directory</em> and its
subdirectories are converted to EPUB.
If a <em>destination-directory</em> is given, the output EPUB files
are placed there, replicating the source directory structure;
otherwise, each EPUB is placed alongside its source `.md` file.

When called without arguments, md2epub displays help information and exits.

Options
-------

\

----------------------------------------- ------------------------------
`--chapter-level` N                       Set the heading level for EPUB chapter splits
                                          (default: 1)
`--continue`                              Continue when a file fails (batch mode)
`--cover` FILE                            Set the cover image for the EPUB
`-c`, `--css` DIR                         Set the CSS base directory
`--csl` NAME|PATH                         Set the Citation Style Language style
`--default` "options"                     Default options for all code blocks
`-exp`, `--experimental`                  Enable Experimental features for all code blocks
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
Parser installation.  The directory is expected to contain the
`flattened/` subdirectory with highlighting stylesheets.  EPUB
readers do not support CSS nesting, so md2epub always uses the
flattened versions of the highlighting stylesheets.

The `--chapter-level` option controls at which heading level Pandoc
splits the EPUB into separate internal chapters.  The default is 1,
meaning every `<h1>` starts a new EPUB chapter.  Set it to 2 if the
document uses `<h1>` for parts and `<h2>` for chapters.

The `--cover` option specifies a cover image file.  The image is
embedded in the EPUB and displayed as the first page by most ebook
readers.  Common formats are JPEG and PNG.  The cover can also be
specified in the YAML front matter with `cover:` under `rexxpub:`.

The `--continue` option is useful in batch mode: when a file fails
(due to a syntax error in a fenced code block or any other error),
processing continues with the remaining files instead of aborting.
At the end, a summary reports the number of files processed and the
number of failures.

The `-xtr`/`--executor`, `-exp`/`--experimental`, and
`-u`/`--tutor`/`--unicode` options enable the corresponding language
extensions for all Rexx fenced code blocks in the document.  They
are equivalent to specifying `executor`, `experimental`, or `tutor`
in the `--default` string, or to adding those attributes to every
individual fenced code block.

YAML front matter
-----------------

Md2epub reads RexxPub options from the YAML front matter block of each
Markdown file.  Options are placed under the `rexxpub:` key, separate
from Pandoc's standard metadata:

```
---
bibliography: references.bib
rexxpub:
  language: en
  section-numbers: 3
  number-figures: true
  style: dark
  cover: cover.jpg
  chapter-level: 1
---
```

The supported options under `rexxpub:` include `style`,
`section-numbers`, `number-figures` (which accepts `0`, `1`, `true`,
or `false`, case-insensitive), `language`, `cover` (path to a cover
image), `chapter-level`, as well as the Pandoc top-level
`highlight-style`.

All options except `style` are author options and can only be set in the
YAML front matter.  The highlighting `style` follows a **reader-wins**
policy: the `--style` command-line option takes precedence over the YAML
value, which in turn takes precedence over the default (`dark`).

See the [YAML front matter documentation](../../rexxpub/yaml/) for the
full specification.

Differences from md2pdf
-----------------------

Md2epub shares the same front-end as md2pdf — FencedCode processes
Rexx fenced code blocks, YAMLFrontMatter and RexxPubOptions parse
options — but the back-end is different:

- **No pagedjs-cli**: Pandoc generates the EPUB directly with
  `--to epub`.  No headless Chromium is needed.
- **No document classes**: EPUB readers control the page layout.
  The `docclass`, `size`, and `outline` options have no effect.
- **Flattened CSS only**: EPUB readers do not support CSS nesting.
  Md2epub always loads stylesheets from the `flattened/` directory.
- **No Bootstrap**: the EPUB contains only the highlighting
  stylesheet and the Pandoc syntax highlighting CSS.
- **Title extraction**: the document title is extracted from the
  first Markdown heading and passed to Pandoc as metadata.

Prerequisites
-------------

+ A working installation of <a href="https://pandoc.org/">Pandoc</a>
  is required.

No other external tools are needed.  Unlike md2pdf, md2epub does not
require pagedjs-cli, Node.js, Python, or pikepdf.

Please refer to [this page](../../rexxpub/) for more installation details.

Program operation
-----------------

In single-file mode, md2epub reads the contents of the provided
*filename*, changes to the directory containing the file (so that
Pandoc can resolve relative paths for bibliographies and other
resources), processes all Rexx fenced code blocks through FencedCode,
extracts the document title from the first heading, and invokes
Pandoc with `--to epub`, `--citeproc` for citation processing, and
`--css` for each highlighting stylesheet needed.

Pandoc packages the result into a standard EPUB file (internally
XHTML + CSS + metadata in a ZIP archive).  The Rexx syntax
highlighting is preserved through CSS class annotations on `<span>`
elements, exactly as in the other RexxPub pipelines.

In batch mode, md2epub uses `SysFileTree` to recursively list
all `.md` files in the source directory and processes them in turn,
applying the same pipeline to each file.