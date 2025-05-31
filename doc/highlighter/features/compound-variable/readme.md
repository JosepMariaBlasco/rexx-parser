Compound variable highlighting
==============================

--------------------------------------

**Compound variables** are special, in the sense that
they have two simultaneous aspects: they are,
at the same time, *variables*, and *indexed stem references*.
The Rexx Parser honors this duality by returning
compound variables as single elements that include
a number of *sub-parts*, and the Rexx Highlighter
then highlights these parts individually.

```rexx
  -- An indexed reference
  Say Matrix.1.2A.j..
```

When highlighting sub-parts,
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

```rexx
::Method myMethod
  Expose var stem.
  local = var + 1
  Say stem.12..2E.var.local
```
