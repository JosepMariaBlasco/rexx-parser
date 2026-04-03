Highlight
=========

----------------------------

### Usage

<pre>
[rexx] highlight [<em>options</em>] <em>file</em>
</pre>

The utility can run in one of four <em>modes</em>, namely,
ANSI mode, HTML mode, LaTeX mode, and DocBook mode; every mode
determines how the file will be highlighted.

When calling `highlight` as a command, the default mode is ANSI;
otherwise, the default mode is HTML.

When <em>file</em> is a single dash ("-") which is the last
option in the command line argument, input is taken from the
`.input` monitor. In all other cases, <em>file</em> has to refer
to a filesystem file; when the extension of that file is `.md`, `.htm`
or `.html`, the utility processes all Rexx fenced code blocks in
<em>file</em> and highlights them. Otherwise, the utility assumes that <em>file</em>
is a Rexx file, it is highlighted accordingly.

When called without arguments, display help information and exit.

### Options

------------------------------------------------------- ------------------------------
`-a`, `--ansi`                                          Select ANSI SGR terminal highlighting
`--continue`                                            Continue when a fenced code block is in error (HTML only)
`--css`                                                 Include links to css files (HTML only)
`-d`, `--docbook`                                       Select DocBook XML highlighting
`--default` <code><em>attributes</em></code>            Select default attributes for code blocks
`--doccomments detailed|block`&nbsp;&nbsp;              Select highlighting level for doc-comments
`-e`, `-exp`, `--experimental`                          Enable Experimental features
`-xtr`, `--executor`                                    Enable support for Executor
`-h`, `--html`                                          Select HTML highlighting (see note below)
`--help`                                                Display help and exit
`-it`, `--itrace`                                       Print internal traceback on error
`-l`, `--latex`                                         Select LaTeX highlighting
`--noprolog`                                            Don't print a prolog
`-n`, `--numberlines`&nbsp;&nbsp;                       Print line numbers
`--pad=`<code><em>n</em></code>                         Pad doc-comments and ::resources to *n* characters
`--patch=`<code><em>patches</em></code>                 Apply the semicolon-separated list of *patches*.
`--patchfile` <code><em>file</em></code>                Apply the patches contained in *file*.
`--prolog`                                              Print a prolog (LaTeX driver only)
`--startFrom` <code><em>n</em></code>                   Start line numbers at *n*.
`-s` , `--style` <code><em>style</em></code>             Use the <code>rexx-<em>style</em>.css</code> style sheet
`--tutor`                                               Enable TUTOR-flavored Unicode
`-u` , `--unicode`                                      Enable TUTOR-flavored Unicode
`-w`, `--width` <code>=<em>n</em></code>                Ensure that lines have width <em>n</em> (ANSI only)
------------------------------------------------------- ------------------------------

\

**Note on `-h`**: The `-h` option selects HTML mode. When it is the only option
and no *file* is specified, help is displayed instead (since processing options
without a file to process always displays help).

**Note**: Several of the options
(`-exp`, `-s`, `-u`, `-xtr`, `--executor`, `--experimental`,
`--unicode`, `--style` or `--tutor`)
do not make sense when highlighting files
containing fenced code blocks, like
Markdown or HTML files. In these cases,
you should use either [the `--default` option]{#default}
or [the desired attributes](../../highlighter/fencedcode/)
in every of the ```` ```rexx ```` or ```` ```executor ```` fences.

#### -a, --ansi {#ansi}

Selects [ANSI highlighting](../../highlighter/ansi/)
using ANSI SGR (Select Graphic Rendition) codes.

#### --continue {#continue}

When processing fenced code blocks, the default behaviour of highlight.rex is
to stop when an error is found or all the blocks have been processed,
whichever occurs first. You can change this behaviour by specifying The
`--continue` option; in that case, processing continue even in the
presence of an error: blocks in error cannot be highlighted,
but they will be substituted by a big warning box, with a red background,
displaying the line in error.

#### --css {#css}

When generating HTML highlighting, the `--css` option adds a skeleton
HTML5 envelope to the generated code. This envelope includes, in its
`head` tag, up to three links to the style file referenced in the `-s` or `--style`
options: one to a possible version stored in the <https://rexx.epbcn.com/> site,
another one to a path relative to the `highlight` utility, and an
optional third one pointing to the style file, if such a file exists
in the current directory.

**Note**: The `css` option is a quick and dirty hack intended to facilitate
development in RAD scenarios, not a way to generate distribution-ready
or production files.

#### --default <em>attributes</em> {#default}

Specifies the default attributes to be applied to all the highlighted
code blocks.

#### -d, --docbook {#docbook}

Selects DocBook XML highlighting.  In this mode, each token is wrapped
in an XML element whose name is derived from its CSS classes:
`rx-kw` becomes `<rexx_kw>`, `rx-op rx-add` becomes `<rexx_op_add>`,
etc.  Whitespace is emitted as plain text (not wrapped in elements).
All content is XML-escaped.

The output is intended to be inserted into DocBook `<programlisting>`
blocks and rendered via XSL templates generated by
[css2xsl](../css2xsl/).

See also [css2xsl](../css2xsl/).

#### --doccomments [detailed|block]

Select the highlighting level for doc-comments. When "detailed" is specified
(the default), some sub-elements of doc-comments, like the summary
statement, block tags or tag values, receive their own, separated
styling; when "block" is specified, all the doc-comment as a whole
gets a single style.

#### --executor {#executor}

Enables support for JLF's Executor extensions.

#### -e, -exp, --experimental {#exp}

Enables [Experimental Rexx features](../../experimental/) so that they are recognized
by the Parser.

#### -h, --html

Selects [HTML highlighting](../../highlighter/html/).

See also [--css] (#css).

#### -l, --latex {#latex}

Selects [LaTeX highlighting](../../highlighter/latex/).

#### --noprolog {#noprolog}

Don't print a prolog (LaTeX only).

See also [--prolog](#prolog).

#### -n, --numberlines {#numberlines}

Print line numbers.

See also [--startFrom](#startFrom).

#### --pad=*n* {#pad}

Pad doc-comments and `::resource` blocks to *n* characters.

#### --patch "*patches*"

Apply the semicolon-separated list of patches.

See also [--patchFile](#patchFile).

#### --patchFile *file*

Apply the patches contained in *file*.

See also [--patch](#patch).

#### --prolog

Print a prolog (LaTeX driver only).

See also [--latex](#latex) and [--noprolog](#noprolog).

#### --startFrom *n*

Start numbering lines at line *n*.

See also [--numberlines](#numberlines)

#### -s, --style *style*

Use the <code>rexx-<em>style</em>.css</code> style sheet.
The default is `rexx-dark.css`.

#### --tutor {#tutor}

Enable TUTOR-flavored Unicode.

See also [--unicode](#unicode).

#### -u, --unicode {#unicode}

Enable TUTOR-flavored Unicode.

See also [--tutor](#tutor).

#### -w, --width *n*

Ensure that lines have a minimum width of *n* characters
(ANSI highlighting only).

See also [--ansi](#ansi).

#### -xtr, --executor {#xtr}

Enables support for JLF's Executor extensions.

--------------

##### Example:

The following command

<pre>
highlight --css --style <em>mystyle</em> sample.html
</pre>

could generate the following `head` section:

<pre>
  &lt;head>
    &lt;link rel='stylesheet' href='https://rexx.epbcn.com/rexx-parser/css/rexx-mystyle.css'>
    &lt;link rel='stylesheet' href='file:///C:/<em>path</em>/rexx-parser/bin/../css/rexx-mystyle.css'>
    &lt;link rel='stylesheet' href='rexx-mystyle.css'>
  &lt;/head>
</pre>

where `path` is the path where the `rexx-parser` resides, and the third link would
only be generated if the `rexx-mystyle.css` file was placed in the directory
where the highlight utility was run.

### Program source

~~~rexx {source=../../../bin/highlight.rex}
~~~