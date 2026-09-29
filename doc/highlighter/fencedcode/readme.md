Rexx Fenced code blocks
=======================

-----------------------------------------

The *FencedCode* routine processes
Markdown-style Rexx fenced code blocks
and highlights its contents according
to a set of provided options.

*FencedCode* is language-agnostic, in the
sense that it is only interested in processing
the Rexx fenced code blocks. This means that
you can use it to highlight Markdown files,
but, additionally, if you are willing to use
the Markdown fenced code block format in other
contexts, you can also highlight, for example,
code blocks present in html files.

Argument
--------

An array of strings containing the code (usually, Markdown or HTML)
containing the Rexx fenced code blocks we want to highlight.

Returns
-------

A new array where all the Rexx fenced code blocks are substituted
by their highlighted versions.

+ Both <code>```</code> and <code>~~~</code> markers are accepted, but they should start on column 1.
+ You can use three or more backticks or twiddles, but the closing marker
  has to have exactly the same number of backticks or twiddles than the
  opening one.
+ You cannot start with <code>```</code> and end with <code>~~~</code>, or viceversa.
+ The word `rexx` has to follow the backtick or twiddle marker, with or without
  intervening blanks or tabs. Code blocks that are not marked with `rexx`
  will not be processed by this routine. Please note that you should
  specify "rexx" exactly as shown, i.e., all in lowercase letters. This means
  that other variants, like "Rexx" or "REXX", will not be recognized.
+ `executor` is also accepted as a language tag. Using <code>```executor {attributes}</code>
  is equivalent to <code>```rexx {executor attributes}</code>.
+ If you want to specify additional attributes, you may do so by enclosing
  them between braces after the `rexx` marker. Blanks and/or tabs after
  `rexx` and before the left brace are optional.

~~~~
~~~rexx {attributes}
~~~~

Optional attributes
-------------------

Attributes are blank-separated booleans, which are usually preceded
by a dot, or `name=value` pairs. When a value contains blanks,
it has to be enclosed in single or double quotes.

~~~~
~~~rexx {.boolean1 name1=value1 .boolean2 name2="long value" ...}
~~~~

Possible attributes are:

#### `assignment= "group" | "full" | "detail"`

Determines how assignment operator sequences will be highlighted.
When "group" is specified, a single, generic, HTML class will be
assigned to every assignment sequence. When "detail" is specified,
every assigment sequence will get its own, different, HTML class
(this means, for example, that all simple assignments, "=", will
be assigned the same HTML class, all "+=" assignments will be
assigned a different class, and so on). When "full" is specified,
both a generic and a specific class will be assigned, in this
order.

#### `.blanks`, `blanks= "data" | "all"` {#blanks}

Make the blanks of the listing visible, as a small open box drawn under
each one. Copying the listing still copies real blanks.

`.blanks` (the same as `blanks=data`) marks the blanks the *program* can
see: those inside a string, and the blank concatenation operator, since
`Say A B` is not `Say A||B`. Indentation and the air around an `=` are
left alone. `blanks=all` marks every blank.

A **tab** is whitespace to Rexx too, but it is not a blank, and it is as
wide as the distance to the next tab stop. So it gets a mark of its own,
the one editors use: an arrow running into a wall, `--->|`, the wall being
the tab stop. Two tabs in a row show as two arrows, never as boxes. If a listing is meant to show *blanks*,
make sure the editor did not put tabs there.

The same attribute works on a prose mention:
`` `Say A B`{.rexx .blanks} ``.

#### <code>caption=<em>"text"</em></code> {#caption}

Add a caption to the code block.  The caption text is emitted as
a `data-caption` attribute on the outer `<div>`, and
`numberFigures.js` converts it to a visible `<figcaption>` at
render time.  When figure numbering is active (the default in
all pipelines), the caption is prefixed with "Listing N."
following the LaTeX convention.  Listing captions are placed
above the code block, and figure captions (for Pandoc images)
below the image.

~~~~
~~~rexx {caption="A sample listing"}
Say "Hello, world!"
~~~
~~~~

produces:

~~~rexx {caption="A sample listing"}
Say "Hello, world!"
~~~

#### `classprefix= "rx-"`

Define the class prefix used for HTML classes. Default is "rx-".

#### `cms` (or `rexxvm`) {#cms}

Enables [CMS (Classic Rexx) syntax](/rexx-parser/doc/rexxvm/), as parsed
by the Rexx/VM interpreter. The names `cms` and `rexxvm` are equivalent.

#### `constant= "group" | "full" | "detail"`

Determines how taken constants (strings or symbols taken as a
constant) will be highlighted.

#### `doccomments= "detailed" | "block"` {#doccomments}

Determines whether doc-comment parts are individually highlighted.
When "detailed" is specified (the default), each part of a doc-comment
(tag names, parameter names, descriptive text, etc.) gets its own
HTML class.  When "block" is specified, the entire doc-comment is
highlighted as a single block.

#### `executor` {#executor}

Enables Executor extensions in the code block.

#### `experimental` {#experimental}

Enables Experimental features in the code block.

#### <code>extraletters=<em>string</em></code> {#extraletters}

Allows all characters in *string* to be part of identifiers.
The string has to be specified between quotes. For example,
if you specify `extraletters="@#$"` the following
will be valid identifiers:

~~~~
~~~rexx {extraletters="@#$"}
  ...
~~~
~~~~

produces:

~~~rexx {extraletters="@#$"}
  -- The following is a standard Rexx and ooRexx variable
  var  = 1
  -- The next variables are considered to have valid names
  -- only because extraletters="@#$" was specified
  var@ = 2
  var# = 3
  var$ = 4
~~~

#### `.numberLines` (or `.number-lines`) {#numberlines}

Include line numbers in the code listing:

~~~~
~~~rexx {.numberLines}
  If a = b Then Say "Yes"
  Else Say "No"
~~~
~~~~

produces:

~~~rexx {.numberLines}
  If a = b Then Say "Yes"
  Else Say "No"
~~~

See also [numberWidth](#numberwidth) and [startFrom](#startfrom).

#### <code>numberWidth=<em>width</em></code> {#numberwidth}

Ensures that the line numbers will occupy at least <em>width</em>
characters in the listing. The highlighter may use more that
<em>width</em> characters if this is necessary to correctly
display the line numbers.

See also [.numberLines](#numberlines) and [startFrom](#startfrom).

#### `operator= "group" | "full" | "detail"`

Determines how operator character sequences will be highlighted.

#### <code>pad=<em>column</em></code> {#pad}

Ensures that `::RESOURCE` data lines and doc-comments
will be padded up to <em>column</em> if they have less than
<em>column</em> characters. This may be useful when using
contrasting backgrounds, because it will ensure that the
whole resource/comment displays as a rectangle.

~~~~
~~~rexx {pad=80 patch="element EL.RESOURCE_DATA #FF0:#F0F"}
  ...
~~~
~~~~

produces:

~~~rexx {pad=80 patch="element EL.RESOURCE_DATA #FF0:#F0F"}
--------------------------------------------------------------------------------
-- This code block is using "pad=80" and a high-contrast style patch for      --
-- ::RESOURCE data lines.                                                     --
--------------------------------------------------------------------------------
::Resource Text END "The End"
Haya o no haya haya en La Haya,
me dice mi aya que alla en La Haya
el haya se halla.
The End
~~~

#### <code>patch=<em>"patches"</em></code> {#patch}

A semicolon-separated list of inline style patches to be applied
to the code block.

#### <code>patchfile=<em>filename</em></code> {#patchfile}

Apply the style patches contained in *filename* to the code block.
*Filename* is relative to the file containing the code block.

#### <code>program=<em>name</em></code> {#program}

Marks this fence as one fragment of a larger logical program. Every
Rexx fence that carries the same *name* &mdash; wherever it sits in the
document &mdash; is treated as a single listing: the fragments are
fused, highlighted together as one unit, and then rendered back in
their original places. Because the whole program is parsed as a unit,
stateful highlighting (a block comment, a `::RESOURCE`, a line
continuation) is resolved correctly across the gaps between fragments,
and line numbering flows continuously from one fragment to the next.

This lets you split a single program across, say, two side-by-side
slide columns, several pages, or code interleaved with prose in a
paged article, while the highlighter still sees
&mdash; and colours &mdash; one coherent program.

Fragments are grouped by a *normalised* form of the name: any run of
blanks and/or dashes collapses to a single dash and the result is
upper-cased, so `program="The Towers of Hanoi"`,
`program=the-towers-of-hanoi` and `program="The Towers  of  Hanoi"`
all refer to the same program, `THE-TOWERS-OF-HANOI`. Note that
normalisation collapses runs of blanks and dashes and changes case,
but it does not add or remove words: `program="Towers of Hanoi"`
normalises to `TOWERS-OF-HANOI`, which is a *different* program.
As with any attribute, a value that contains blanks must be quoted. 

#### <code>size=<em>size</em></code> {#size}

Add <code>style="font-size:<em>size</em>"</code> to the `<pre>` block
(HTML only).  This allows overriding the font size for individual
code blocks.  The value is used as-is in the CSS `font-size` property,
so any valid CSS size value is accepted (e.g. `size=10pt`, `size=0.8em`).

#### <code>source=<em>filename</em></code> {#source}

Read the code to highlight from *filename* instead of the code block.
*Filename* is relative to the file containing the code block.

#### `special= "group" | "full" | "detail"`

Determines the highlighting of special character sequences.

#### <code>spot=<em>"beats"</em></code> {#spot}

Marks lines of this listing with the *spotlight*: a highlighter pen
that strikes across whole lines, the way one marks a printed listing
before talking about it.

The value names the **beats** this listing takes part in, and which of
its lines light up in each one:

~~~~
~~~rexx {.numberLines spot="init:2 salary:5-7,9"}
  ...
~~~
~~~~

A *beat* is a named group of things that happen together; its name
ignores case, as a Rexx symbol does. Terms are
separated by blanks or by semicolons, as you prefer &mdash;
`spot="init:2 salary:5"` and `spot="init:2; salary:5"` are the same
thing. Lines may be given singly (`2`), as an inclusive range (`5-7`),
or as a comma-separated list of both (`2,5-7,9`). Line numbers are the
ones the reader sees: under [startFrom=97](#startfrom), `spot="x:97"`
means the first line of the block. Requires
[.numberLines](#numberlines) &mdash; if you are going to say "line 5",
your reader needs to be able to count to it.

A few words can be marked instead of a line, by writing them between
square brackets: `spot="trap:[NOVALUE NAME ANY],[ANY:]"` marks those
texts wherever they appear in the block, and `trap:5[ANY:]` only on
line 5. The match is by whole words, ignores case and stays within one
line; brackets inside the text pair up (`[a[1]]`). A text needs no
line numbers, so it works on an unnumbered block too. The marks are
drawn by the slide runtime; see
[the md2slides documentation](../../utilities/md2slides/#marking-words).

**The point is the correspondence.** Two listings that share a beat
light up together, in the same colour, with no further ceremony:

~~~~
~~~rexx   {.numberLines spot="init:2"}
  ...
~~~

~~~output {.numberLines spot="init:1"}
  ...
~~~
~~~~

That says *"this line of the program produces this line of the
output"* &mdash; and says it in a way that survives the reader looking
away. The two blocks need not come from the same highlighter: an
`output`, `python` or plain-text fence carries `spot=` with exactly
the same spelling, and shares the colour.

The colours belong to the chosen [style](#style), which declares four
pens beside its own token palette, so a beat reads correctly on a
light ground and on a dark one. Beats are given a pen in the order
they appear.

In a **paged or static** rendering &mdash; an HTML page, a PDF, an
EPUB &mdash; every beat is simply struck: there is no "advance", so
the marks collapse into one finished picture. In a **slide deck**,
where there is an advance, each beat fires on its own keypress and the
marks accumulate; and a prose fragment may join a beat, so the
sentence and the marks arrive together:

~~~~
::: {.fragment spot=init}
This line builds the object...
:::
~~~~

Because a beat waits for the last of its participants to appear, where
you write that fragment decides when the pen strikes.

#### <code>startFrom=<em>nnn</em></code> {#startfrom}

When used with the `.numberLines` option, set the line number
of the first line to *nnn*.

See also [.numberLines](#numberlines) and [numberWidth](#numberwidth).

~~~~
~~~rexx {.numberLines startFrom=97}
  ...
~~~
~~~~

produces:

~~~rexx {.numberLines startFrom=97}
--------------------------------------------------------------------------------
-- This small listing will start at line 97
--------------------------------------------------------------------------------

Exit
~~~

#### <code>style=<em>style</em></code> {#style}

Enclose the code with a <code>&lt;div class="highlight-rexx-<em>style</em>"&gt;</code> tag.
Default is "dark". Style names can only use uppercase or lowercase ANSI letters or numbers
(i.e., XRange("ALNUM")), plus ".", "-" or "_".

#### `tutor` {#tutor}

Enables [TUTOR-flavored Unicode support](/rexx-parser/doc/unicode/).

See also [unicode](#unicode).

#### `unicode` {#unicode}

Enables [TUTOR-flavored Unicode support](/rexx-parser/doc/unicode/).

See also [tutor](#tutor).

An example: the `FencedCode` program source
----------------------------------------------------------------

The program listing below is produced by inserting the two following lines in the HTML source.

~~~~
~~~rexx {source=../../../bin/parser/FencedCode.cls}
~~~
~~~~

Here is the program output:

~~~rexx {source=../../../bin/parser/FencedCode.cls}
~~~