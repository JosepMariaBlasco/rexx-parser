Highlight
=========

----------------------------

### Usage:

<pre>
[rexx] highlight [<em>options</em>] <em>file</em>
</pre>

The utility can run in one of three <em>modes</em>, namely,
ANSI mode, HTML mode, and LaTeX mode; every mode determines
how the file will be highlighted.

When calling `highlight` as a command, the default mode is ANSI;
otherwise, the default mode is HTML.

When <em>file</em> is a single dash ("-") which is the last
option in the command line argument, input is taken from stdin.
In all other cases, <em>file</em> has to refer to a filesystem
file; when the extension of that file is `.md`, `.htm` or `.html`,
the utility processes all Rexx fenced code blocks in <em>file</em>
and highlights them. Otherwise, the utility assumes that <em>file</em>
is a Rexx file, it is highlighted accordingly.

### Options:

------------------------------------------------------- ------------------------------
`-a`, `--ansi`                                          Select ANSI SGR terminal highlighting
`--css`                                                 Include links to css files (HTML only)
`-h`, `--html`                                          Select HTML highlighting
`-l`, `--latex`                                         Select LaTeX highlighting
`--noprolog`                                            Don't print a prolog
`--number=`<code><em>mode</em></code>                   <code>detail</code> (the default) or <code>whole</code>
`-n`, `--numberlines`&nbsp;&nbsp;                       Print line numbers
`--patch=`<code><em>patches</em></code>                 Apply the semicolon-separated list of *patches*.
`--patchfile=`<code><em>file</em></code>                Apply the patches contained in *file*.
`--prolog`                                              Print a prolog (LaTeX driver only)
`--startFrom=`<code><em>n</em></code>                   Start line numbers at *n*.
`--string=`<code><em>mode</em></code>                   <code>detail</code> (the default) or <code>whole</code>
`-s`, `--style=`<code><em>style</em></code>&nbsp;&nbsp; Use the <code>rexx-<em>style</em>.css</code> style sheet
`--tutor`                                               Enable TUTOR-flavored Unicode
`-u` , `--unicode`                                      Enable TUTOR-flavored Unicode
`-w`, <code>--width=<em>n</em></code>                   Ensure that lines have width <em>n</em> (ANSI only)
------------------------------------------------------- ------------------------------

#### -a, --ansi {#ansi}

Selects [ANSI highlighting](../../highlighter/ansi/)
using ANSI SGR (Select Graphic Rendition) codes.

#### --css {#css}

When generating HTML highlighting, the `css` option adds a skeleton
HTML5 envelope to the generated code. This envelope includes, in its
`head` tag, up to three links to the style file referenced in the `-s` or `--style`
options: one to a possible version stored in the <https://rexx.epbcn.com/> site,
another one to a path relative to the `highlight` utility, and an
optional third one pointing to the style file, if such a file exists
in the current directory.

**Note**: The `css` option is a quick and dirty hack intended to facilitate
development in RAD scenarios, not a way to generate distribution-ready
or production files.

#### -h, --html

Selects [HTML highlighting](../../highlighter/html/).

See also [--css](#css).

#### -l, --latex {#latex}

Selects [LaTeX highlighting](../../highlighter/latex/).

#### --noprolog {#noprolog}

Don't print a prolog (LaTeX only).

See also [--prolog](#prolog).

#### -n, --numberlines {#numberlines}

Print line numbers.

See also [--startFrom](#startFrom).

#### --number=_mode_

This options affects number highlighting.

When mode is <code>detail</code> (the default),
the decimal point, the exponent mark ("E" or "e"),
and the exponent sign are highlighted with
individual styles. Additionally, strings
which are numbers and are not hexadecimal or binary
strings are also internally highlighted.
In such cases, the number sign is also highlighted.

When mode is <code>whole</code>, the number
is highlighted with a single style, and strings
that are numbers are highlighted accordingly to their
corresponding string category.

#### --patch="_patches_"

Apply the semicolon-separated list of patches.

See also [--patchFile](#patchFile).

#### --patchFile=_file_

Apply the patches contained in _file_.

See also [--patch](#patch).

#### --prolog

Print a prolog (LaTeX driver only).

See also [--latex](#latex) and [--noprolog](#noprolog).

#### --startFrom=_n_

Start numbering lines at line _n_.

See also [--numberlines](#numberlines)

#### --string=_mode_

This options affects string highlighting.
When mode is <code>detail</code> (the default), the opening and closing quotes and
the optional suffix get a distinct highlighting; when mode is "whole",
the whole string is highlighted using a single style.

#### -s, --style=_style_

Use the <code>rexx-<em>style</em>.css</code> style sheet.
The default is `rexx-dark.css`.

#### --tutor {#tutor}

Enable TUTOR-flavored Unicode.

See also [--unicode](#unicode).

#### --u, --unicode {#unicode}

Enable TUTOR-flavored Unicode.

See also [--tutor](#tutor).

#### -w, --width=_n_

Ensure that lines have a minimum width of _n_ characters
(ANSI highlighting only).

See also [--ansi](#ansi).

--------------

##### Example:

The following command

<pre>
highlight --css --style=<em>mystyle</em> sample.html
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
only be generated if the `rexx-mystyle.css` file was places in the directory
where the highlight utility was run.

### Program source:

~~~rexx {source=../../../bin/highlight.rex}
~~~