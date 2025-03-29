Highlight
=========

----------------------------

#### Usage:

<pre>
[rexx] highlight [<em>options</em>] <em>file</em>
</pre>

If <em>file</em> has a `.md` or a `.html` extension,
process all Rexx fenced code blocks
in FILE and highlight them.
Otherwise, we assume that this is a Rexx file,
and we highlight it directly.

#### Options:

------------------------------------------------------- ------------------------------
`-a`, `--ansi`                                          Select ANSI SGR terminal highlighting
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

#### Program source:

~~~rexx {source=../../../samples/highlight.rex}
~~~