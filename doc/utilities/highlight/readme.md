Highlight
=========

----------------------------

### Usage:

<pre>
[rexx] highlight [<em>options</em>] <em>file</em>
</pre>

If <em>file</em> has a `.md` or a `.html` extension,
process all Rexx fenced code blocks
in FILE and highlight them.
Otherwise, we assume that this is a Rexx file,
and we highlight it directly.

### Options:

------------------------------------------------------- ------------------------------
`-a`, `--ansi`                                          Select ANSI SGR terminal highlighting
`--css`                                                 Include links to css files (HTML only)
`-h`, `--html`                                          Select HTML highlighting
`-l`, `--latex`                                         Select LaTeX highlighting
`--noprolog`                                            Don't print a prolog
`-n`, `--numberlines`&nbsp;&nbsp;                       Print line numbers
`--patch=`<code><em>patches</em></code>                 Apply the semicolon-separated list of *patches*.
`--patchfile=`<code><em>file</em></code>                Apply the patches contained in *file*.
`--prolog`                                              Print a prolog (LaTeX driver only)
`--startFrom=`<code><em>n</em></code>                   Start line numbers at *n*.
`-s`, `--style=`<code><em>style</em></code>&nbsp;&nbsp; Use the <code>rexx-<em>style</em>.css</code> style sheet
`--tutor`                                               Enable TUTOR-flavored Unicode
`-u` , `--unicode`                                      Enable TUTOR-flavored Unicode
`-w`, <code>--width=<em>n</em></code>                   Ensure that lines have width <em>n</em> (ANSI only)
------------------------------------------------------- ------------------------------

#### css

When generating a HTML highlighting, the `css` option adds a skeleton
HTML5 envelope to the generated code. This envelope includes, in its
head, up to three links to the style file referenced in the `-s` or `--style`
options: one to a possible version stored in the <https://rexx.epbcn.com> site,
another one in a path relative to the `highlight` utility, and an
optional third one pointing to the style file, if such a file exists.

**Note**: The `css` option is a quick and dirty hack intended to facilitate
development in RAD scenarios, not a way to generate distribution-ready
or production files.

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