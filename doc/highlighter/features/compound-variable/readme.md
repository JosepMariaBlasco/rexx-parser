Compound variable highlighting
==============================

--------------------------------------

**Compound variables** are special, in the sense that
they have two simultaneous aspects: they are,
at the same time, *variables*, and *indexed stem references*.
The Rexx Highlighter honors this duality by returning
compound variables as single elements that include
a number of *sub-parts*; you can decide which of
the two aspects of a compound variable will determine
the highlighting mode.

<div class="row">
<div class="col-xs-6">
```rexx
  -- As an indexed reference
  Say Matrix.1.2A.j..
```
</div>
<div class="col-xs-6">
```rexx {compound=false}
  -- As a whole
  Say Matrix.1.2A.j..
```
</div>
</div>

You can select the compound variable highlighting
mode using the `compound=true|false` attribute
on the `rexx` fenced code block marker. The default is
to highlight all the components individually.

<div class="row">
<div class="col-xs-6">
<pre>
&#96;``rexx {compound=true}
(rexx code goes here)
&#96;``</pre>
</div>
<div class="col-xs-6">
<pre>
&#96;``rexx {compound=false}
(rexx code goes here)
&#96;``</pre>
</div>
</div>

When highlighted as a single element, a compound variable
will have a class of `.EL.COMPOUND_VARIABLE` or,
if the variable is exposed (i.e., it is an instance variable), of
`.EL.EXPOSED_COMPOUND_VARIABLE`.

```rexx
::Method myMethod
  Expose var stem.
  local = var + 1
  Say stem.12..2E.var.local
```

When taking sub-parts into account (which is the default),
different highlighting attributes will be used
for the *stem name* (a `.EL.STEM_VARIABLE` or a `.EL.EXPOSED_STEM_VARIABLE`)
and for all the components of its *tail*.
The first dot in a compound variable is part of the *stem name*.
The rest of the symbol, the *tail*,
is an arbitrary sequence of:
*variables* (either *local*, `.EL.SIMPLE_VARIABLE`, or *exposed*, `.EL.EXPOSED_SIMPLE_VARIABLE`);
signless *integers* (`.EL.INTEGER_NUMBER`);
pure dotless *constant symbols* (`.EL.SYMBOL_LITERAL`), and
*tail separators* dots (`.EL.TAIL_SEPARATOR`).
