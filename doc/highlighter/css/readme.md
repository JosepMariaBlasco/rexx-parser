CSS Support
===========

--------------

The HTML highlighter driver
---------------------------

CSS stylesheets reside in the `css` directory.
They are directly used by the HTML highlighter driver,
which tags the elements of a program (and
element parts or _subelements_, like the quotes that enclose strings,
or exponent signs) and assigns to these elements a series of _HTML classes_.
For example, an appearance of the built-in function (BIF)
name `Length` may be tagged as follows:

~~~
<span class="rx-const rx-bif-func">Length</span>
~~~

Class names are defined in [/bin/Globals.css](../../../bin/Globals.cls?view=highlight);
the default class prefix is the string `"rx-"`. Class names help
to identify the syntactical nature of elements and subelements with
various levels of detail. For example, the `rx-const` class states
that `Length` is a _name_, that is, in this case, a "symbol which is taken as a constant",
while `rx-bif-func` is more specific and indicates that this is
a built-in function name which is being used as a function
call (as opposed to being used as a procedure call). Style sheet implementors
may choose to associate a single style for all names, that is, to
all elements with class `rx-const`, or
be more and more specific, to the point of discriminating between
`Length` being used as a built-in function call, as a built-in procedure
call, or as something else (like an
internal function call).

Once an element or subelement has been assigned a set of classes
and the styling associated to these classes has been defined by the
corresponding CSS stylesheet, the work of the HTML driver is done.
It's now the turn of a web browser (Firefix, Chrome, etc.) to
correctly display the highlighted program source.

Using the CSS stylesheets with other drivers
--------------------------------------------

We want to reuse these stylesheets with other highlighter drivers, like ANSI or LaTeX.
To that purpose, we must be able to parse the CSS stylesheet and abstract
its contents, so that the other drivers can use them.

Generally speaking, CSS parsing is a formidable task. We only support
rigidly formatted stylesheets: they are enough to produce excellent
HTML results and at the same time simple enough to be manually parsed
and used by the ANSI and LaTeX drivers.

Where are stylesheets located
-----------------------------

Stylesheets reside in the [/css](../../../css) directory. Given a style name <code><em><u>style</u></em></code>,
the corresponding stylesheet file is

<pre>
/css/rexx-<em><u>style</u></em>.css
</pre>

Format of a stylesheet file
---------------------------

To our parser, a stylesheet is simply a list of (possibly nested) rules.
Rules that start with <code>".highlight-rexx-<em>style</em>"</code> are recognized and
processed; all other rules are ignored.

### Flattening

The parser first _flattens_ the recognized rules in several simple ways:

<pre>
selector<sub>1</sub>, ..., selector<sub>n</sub> {declaration block}
</pre>

is flattened to

<pre>
selector<sub>1</sub> {declaration block}
...
selector<sub>n</sub> {declaration block}
</pre>

Similarly,

<pre>
selector {declaration<sub>1</sub>; ...; declaration<sub>n</sub>}
</pre>
is flattened to

<pre>
selector declaration<sub>1</sub>;
...
selector declaration<sub>n</sub>;
</pre>

### Undoing nesting

The flattening process also eliminates nesting:

<pre>
.class<sub>1</sub> {.class<sub>2</sub> rules}
</pre>

flattens to

<pre>
.class<sub>1</sub> .class<sub>2</sub> rules
</pre>

while

<pre>
.class<sub>1</sub> {&.class<sub>2</sub> rules}
</pre>

flattens to

<pre>
.class<sub>1</sub>.class<sub>2</sub> rules     /* No blank separates the classes */
</pre>

Other CSS combinators like `+`, `>` or `~` are not recognized.

### Format of the flattened styles

Flattening is recursive, so that, in the end, we are left up with a
list of triples in the format

<pre>
&langle;selector, property, value&rangle;,
</pre>

which is excellent to implement the cascading algorithms
for specificity and order.

Limitations:
------------

+ We only recognize and process rules where selectors consist
  of class names.
+ A selector must be composed of exactly two words. The first word must be
  <code>".highlight-rexx-<em>style</em>"</code>, as described above. The second word must be
  an abutted list of classes starting with a period,
  <code>".class<sub>1</sub>.class<sub>2</sub>...class<sub>n</sub>"</code>. Rules starting with other selectors
  are ignored.
+ Comment-like constructions inside strings are not supported
+ Braces `"{"` and `"}"` inside strings are not supported
+ We cannot process function line constructs that use commas.
+ For the `font-style` property, we only recognize `italic` and `normal` as values.
+ For the `font-weight` property, we only recognize `bold` and `normal` as values.
+ For the `text-decoration` property, we only recognize `underline` and `none` as values.
+ For the `color` and `background-color` properties,
  we only recognize colors specified using one of the following formats:
  <code>#<em>rgb</em></code>, <code>#<em>rgba</em></code>,
  <code>#<em>rrggbb</em></code>, <code>#<em>rrggbbaa</em></code>, or a named color.

