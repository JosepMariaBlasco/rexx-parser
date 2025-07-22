The Rexx Highlighter
====================

The **Rexx Highlighter** is a child project of [the Rexx Parser](/rexx-parser/).
Developed around a common code base,
it currently includes output [drivers](#drivers) for
three modes: [HTML](html/),
[ANSI terminals emulators](ansi/),
and [(Lua)LaTeX](latex/).

<div class="row">
<div class="col-sm-6">
~~~~
~~~rexx
Say "Done!" -- Inform the user
~~~
~~~~
</div>
<div class="col-sm-6">
~~~rexx
Say "Done!" -- Inform the user
~~~
</div>
</div>

The figure above shows [the HTML highlighter](html/) in action, or,
to be more precise, the effect of a
[Rexx fenced code block](fencedcode/)
in a Markdown file.


-----------------------


Architecture
============

Irrespective of the mode, the highlighter works
against a set of [CSS](#css) files,
an optional [style patch system](#stylepatch), and
[a mapping](#category2html) that assigns
HTML classes to every
[element category and subcategory](../ref/categories/).
The actual highlighting is taken care of by an
extensible system of [drivers](#drivers).

#### CSS {#css}

The highlighter is distributed with an
extensible system of **CSS stylessheets**.
These stylesheets have to use a limited subset
of CSS, as, although they are _directly used_ by the
HTML highlighter (i.e., by web browsers),
they are _interpreted_ in by the ANSI and LaTeX
drivers.

You can read about the supported level of CSS and
the interpretation process [here](css/).

Two samples are provided:
<code>[rexx-light.css](/rexx-parser/css/rexx-light.css)</code>,
a light grey background one (currently incomplete),
and the default style,
<code>[rexx-dark.css](/rexx-parser/css/rexx-dark.css)</code>,
a dark background one.

<div class="row">
<div class="col-sm-6">
~~~rexx
Say "Done!" -- Inform the user
~~~
<p class="text-center"><em>Dark background</em></p>
</div>
<div class="col-sm-6">
~~~rexx {style=light}
Say "Done!" -- Inform the user
~~~
<p class="text-center"><em>Light grey background</em></code></p>
</div>
</div>

You can select a style by using the `style=` attribute on a
[Rexx fenced code block](fencedcode/), or the
`--style=` option of the [highlight](../utilities/highlight/) utility.
The [Highlighter class](../ref/classes/highlighter/) class
also allows to specify a style in the options argument.


#### The style patch system {#stylepatch}

The [**style patch system**](../ref/classes/stylepatch/)
allows one-time, simple and easy patching of a
CSS style.

<div class="row">
<div class="col-sm-6">
~~~rexx
Say "Done!" -- Inform the user
~~~
<p class="text-center"><em>Standard highlighting</em></p>
</div>
<div class="col-sm-6">
~~~rexx {patch="all comments yellow"}
Say "Done!" -- Inform the user
~~~
<p class="text-center"><em>With</em> <code>patch="all comments yellow"</code></p>
</div>
</div>

Style patches can be specified by using the `patch=` attribute
of a [Rexx fenced code block](fencedcode/#patch), or the
`--patch=` option of the [highlight](../utilities/highlight/) utility.
[The *parse* method](../ref/classes/highlighter/#parse) of the
[Highlighter class](../ref/classes/highlighter/)
also accepts an optional [style patch](../ref/classes/stylepatch/) argument.

#### From element categories to HTML classes {#category2html}

The Rexx Parser assigns a [category](../ref/categories/)
to all the elements in a program, and, in the case
of [taken constants](../glossary/#taken-constant) (i.e.,
syntactical constructs which are specified to be
strings or symbols that are taken as a constant), it
also assigns a [subcategory](../ref/categories/).

The [HTMLClasses](HTMLClasses/) routine creates a mapping
between element categories and subcategories and **HTML classes**.
The mapping provided by [HTMLClasses](HTMLClasses/) is *reductive*:
it assigns the same HTML class to several, different,
element categories or subcategories.
For example, all special and operator characters
are assigned the same HTML class. This is so because,
in normal circumstances, you will neither need nor desire
to highlight, say, parentheses and the plus sign using
different colors. There may be cases, though (for instance,
some teaching contexts), where such a discrimination may be
useful or interesting. In these cases, you can write
your own version of [HTMLClasses](HTMLClasses/) (and
prepare the corresponding CSS files), or simply use
the [style patch system](../ref/classes/stylepatch/)
and temporarily patch the highlighting styles.

#### Drivers {#drivers}

Actual highlighting is taken care of by [an extensible
system of **drivers**](../ref/classes/driver/), for [HTML](html/),
[ANSI Terminals](ansi/), and [(Lua)LaTeX](latex/).
Each driver encapsulates the specificities of
an output format.

-------------------------------

Documentation
=============

- [Highlighter documentation](.), including:
  - [Common features](features/).
  - [The HTML Highlighter](html/).
  - [The ANSI Highlighter](ansi/).
  - [The (Lua)LaTeX Highlighter](latex/).
  - [CGI installation](cgi/).
  - [Exploiting CSS Paged Media](paged-media/).

Included software
-----------------

- [`Highlighter.cls`](../ref/classes/highlighter) -
  A [Highlighter](../ref/classes/highlighter)
  instance is created by supplying the class with
  a program source array and a stem containing options.
  The *parse* method takes
  [an optional style patch](../ref/classes/stylepatch/)
  as an argument, and it returns the source program,
  highlighted according to the supplied options and
  patches.
- [`FencedCode.cls`](fencedcode/) -
  [A highly configurable routine](fencedcode/)
  that processes Markdown-style Rexx fenced code blocks
  and highlights them using the Rexx Parser.
- [`StylePatch.cls`](../ref/classes/stylepatch/) - An abstraction
  defining [a way to apply style patches](../ref/classes/stylepatch/)
  to defined highlighting styles.
- [`HTMLClasses.cls`](htmlclasses/) -
  [A program](htmlclasses/) that assigns HTML
  classes to element categories and taken constant names.

Utilities
---------

- [Highlight](../utilities/highlight/) - A
  [sample utility program](../utilities/highlight/) that
  highlights Markdown, HTML, Rexx and LaTeX files.