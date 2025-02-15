Element categories, category sets, and taken constant names
===========================================================

-------------------------------------

A Rexx program (a package, a source file) can be viewed
as a stream of *elements*. An element is a normal Rexx token,
or some other code element, like  a comment, or a non-significant blank.
The concatenation of all elements is, by construction,
identical to the original Rexx program.

The description of the working and the features
of the element stream are part of
[the Element API](../../guide/elementapi/),
one of the two ways to access a parsed Rexx program.

Elements have a set of properties, which are described in more detail
[in the reference documentation for the Element class](../classes/element/).

This article documents the values returned by the
[*category*](../classes/element/#category)
and [*subCategory*](../classes/element/#subcategory) instance methods of
[the Element class](../classes/element/). These values are sufficient to build
quite sophisticated tools, like
[very fine-grained highlighters](/rexx.parser/doc/highlighter/),
and are described in the source file which defines them, reproduced below.

Source program
--------------

```rexx {source=../../../cls/Globals.cls}
```