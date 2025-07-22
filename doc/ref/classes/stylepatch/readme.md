StylePatch
==========

------------------------

Methods
-------

### Of (Class method)

![of](StylePatch.of.svg) \

Creates a new StylePatch object containing the provided *styles*.
This is the only way to create a Patch object (the *new* class method
is a private method).

*Styles* is an ordered set of lines.
These lines may be separated by semicolons,
or be items in a Rexx Array, or both.

Style patches
-------------

~~~
-- Sample style patch file
-- =======================
--
-- Lines starting with "--" are comments and are ignored
--
-- Patch simple variable elements to display as bold black over 75% yellow
element EL.SIMPLE_VARIABLE #000:#cc0 bold
-- Patch method names to display as black over 75% magenta
name  METHOD.NAME        #000:#c0c
~~~

Style patches have a very simple format: they
are arrays of strings consisting of:

+ *Blank lines*, containing only whitespace, which are completely ignored.
+ *Comments*, starting with two dashes `"--"`, which also are completely ignored.
+ Other lines containing semicolons. In that case, these lines are
  split at the semicolons, the semicolons are discarded, and the
  lines are inserted at the beginning of the list.
+ Once comment lines starting with `"--"` have been discarded,
  all dashes `"-"` are replaced by blanks `" "`. This can be very useful
  in certain contexts like certain Linux shells,
  where enclosing arguments between quotes may be cumbersome.
+ Highlighting patches for *element categories*:
     <pre>Element <em>class</em> <em>highlighting</em></pre>
  `Element` can be abbreviated to `E`, and the *class* name
  can omit the `EL.` prefix, if desired.
+ Highlighting patches for *element category sets*:
     <pre>All <em>set</em> <em>highlighting</em></pre>
  `All` can be abbreviated to `A`, and the *set* can omit
  the `ALL.` prefix, if desired.
+ Highlighting patches for *taken constant names*:
     <pre>Name <em>constantName</em> <em>highlighting</em></pre>
  `Name` can be abbreviated to `N`, and the *constantName* can
  omit the `.NAME` suffix, if desired.
+ *Highlighting* is a blank-separated sequence
  of case-insensitive elements, selected between
  + *Foreground colors*, in the format `#rgb`, `#rrggbb`, or
    one of the 147 standard CSS named colors
    [defined here](https://www.w3.org/TR/css-color-4/#named-colors).
  + *Foreground:background color combination*,
    in the format `fg:bg` (with no blanks),
    where `fg` and `bg` are either `#rgb`, `#rrggbb`, or
    one of the 147 CSS named colors
    [defined here](https://www.w3.org/TR/css-color-4/#named-colors).
  + *Background colors*, in the format `:#rgb`, `:#rrggbb`, or
    a colon immediately followed by one of the 147 standard CSS named colors
    [defined here](https://www.w3.org/TR/css-color-4/#named-colors).
  + One of the single words `bold`, `italic` or `underline`.
  + The single word `no`, which has to be followed by
    one of `bold`, `italic` or `underline`.
+ Element categories, category sets, and subcategories
  [are described in detail here](/rexx-parser/doc/ref/categories/).

```rexx {patch="n method #000:#c0c; element Simple_Variable #000:#cc0 bold"}
::Method methodName
  -- In this code fragment, the standard dark mode highlighting style is used.
  -- Additionally, local variables are specially highlighted with a bold black
  -- font over a yellow background, and the highlighting for method names is
  -- modified to have a black foreground over a magenta background.
  len = Length("String")
  n   = Pos("x", value)
```

Program source
---------------

~~~rexx {source=../../../../bin/StylePatch.cls}
~~~