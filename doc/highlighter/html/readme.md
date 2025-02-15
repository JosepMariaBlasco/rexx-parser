The Rexx HTML Highlighter
=========================

--------------------------------

The *Rexx HTML Highlighter* is an application of
[the Rexx Parser](/rexx.parser/). It is distributed with
two sample highlighting styles:
[`rexx-light.css`](/rexx.parser/css/rexx-light.css),
a light grey background one

```rexx {style=light}
  -- Show several forms of function call
  Exit Length("x") + Pos("y") + External("z") + myRoutine("w")

Pos:
  Return "POS"(Arg(1)) + 1
::Routine myRoutine
  Return 45
```

and [`rexx-dark.css`](/rexx.parser/css/rexx-dark.css), a dark background one.

```rexx
  -- Show several forms of function call
  Exit Length("x") + Pos("y") + External("z") + myRoutine("w")
  Call Length

Pos:
  Return "POS"(Arg(1)) + 1
::Routine myRoutine
  Return 45
```

+ [Main features](../features/)
+ [Examples of instruction highlighting](./instructions/) (torture test).
+ [Examples of directive highlighting](./directives/) (another torture test).
+ Mappings between [element categories and subcategories and HTML classes](./classes/).
+ A small document showing most of the [highlighting cases](./all/).
