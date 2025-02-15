Style patches
=============

----------------------------------------------

A highlighting style can be *patched* by modifiying
the highlighting associated to one or more
element categories or subcategories, thus allowing
a certain form of "highlighting inside the highlighting",
which can be very useful in a number of contexts, like
teaching, or when preparing technical demos.

```rexx {patch="n method #000/#c0c; element Simple_Variable #000/#cc0 bold"}
::Method methodName
  -- In this code fragment, the standard dark mode highlighting style is used.
  -- Additionally, local variables are specially highlighted with a bold black
  -- font over a yellow background, and the highlighting for method names is
  -- modified to have a black foreground over a magenta background.
  len = Length("String")
  n   = Pos("x", value)
```

Patches can be specified as an optional argument
of the *parse* method of the *Highlighter* class,
or as attributes of a fenced code block.

### Patches and code blocks

#### Inine patches

Style patches can be specified inline using the `patch=` attribute of the `rexx`
fenced code block marker. As an example, here is the source for the above code block:

<pre>
&#96;``rexx {patch="n method #000/#c0c; element Simple_Variable #000/#cc0 bold"}
::Method methodName
  -- In this code fragment, the standard dark mode highlighting style is used.
  -- Additionally, local variables are specially highlighted with a bold black
  -- font over a yellow background, and the highlighting for method names is
  -- modified to have a black foreground over a magenta background.
  len = Length("String")
  n   = Pos("x", value)
&#96;``
</pre>

#### External patch files

You can also use the `patchfile=` attribute to specify
a filename where the style patch resides:

<pre>
&#96;``rexx {patchfile=filename}
(code block to patch)
&#96;``
</pre>