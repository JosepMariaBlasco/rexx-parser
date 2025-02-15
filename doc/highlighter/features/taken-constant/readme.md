Taken constant highlighting
===========================

-------------------------------------------

In many places of the Rexx syntax, a "taken constant" is required. Generally
speaking, a "taken constant" is a string or a symbol which is taken as a constant,
although some few contexts may impose additional limitations to the acceptable
elements, for example by not allowing strings, or by limiting the types of
possible symbols.

A "taken constant" may have the syntactic form of a compound variable but, since
it is taken as a constant, no variable substitution takes place, and, therefore,
it has to be highlighted differently.

```rexx
  ------------------------------------------------------------------------------
  -- Compound variables versus taken constants                                --
  ------------------------------------------------------------------------------

  Say    stem.abc.123.4FG..i            -- A compound variable
  Signal stem.abc.123.4FG..i            -- SIGNALing a label
stem.abc.123.4FG..i:                    -- A label
  self~stem.abc.123.4FG..i              -- Calling a method
  Nop
::Method stem.abc.123.4FG..i            -- A method name
```

The highlighter assigns different highlighting classes to every
subcategory of taken constants. This allows to specify different highlighting
choices for labels, method, routine and resource names, etc.

```rexx
  ------------------------------------------------------------------------------
  -- Different forms of highlighting for different classes of taken constans  --
  ------------------------------------------------------------------------------

::Class    myClass  Public              -- A class name
::Method   myMethod Class               -- A method name
  Return   myRoutine(12)                -- Calling a ::Routine
::Routine  myRoutine                    -- A routine name
  Return  .Resources[myResource][2]|| -
   .myClass~myMethod                    -- A message term
::Resource myResource End "The end"     -- A resource
A resource line
Another resource line
This is line number 3
The end is near (additionally, "is near" and what follows it are ignored)
```