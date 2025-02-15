Routine HTMLClasses
===================

-------------------------------------

### Argument

`Options.`, a stem. The following tails are examined:

* `Options.assignment`, for (extended) assignment operator characters and character sequences.
* `Options.constant`, for strings or symbols taken as a constant.
* `Options.operator`, for operator characters and operator character sequences.
* `Options.special`, for special characters and special character sequences.
* `Options.classprefix`, a prefix prepended to every HTML class. The default is "rx-".

The routine code assigns one or two HTML classes to every element category,
and, in the case of symbols taken as a constant, to every element subcategory.

When two classes are assigned, the first one is generic (for instance,
"spe" for special characters), and the second one identifies the
corresponding element (for example, "comma", or "colon").

The value of the corresponding compound variables determines the class
associated with every element category and subcategory, in the following way:

* When the value is `"group"`, only the generic class is assigned.
* When the value is `"detail"`, only the detailed class is assigned.
* When the value is `"full"`, two classes are assigned, the generic
  one and the detailed one (in this order).

### Returns

A stem (`"HTMLClass"`) mapping element categories and subcategories to html
classes. The default HTML class is `"rexx"`.

### Program logic

Irrespective of the whether we are producing output
for ANSI terminals, HTML, or LaTeX, the Highlighter assigns
one or more HTML class names to every element category
and subcategory.
This assignment is done in the `HTMLClasses` routine,
which can of course be customized.

In many cases, an element category is mapped directly to
a single HTML class. For example, `.EL.SHEBANG`,
the category that identifies shebang lines, is assigned
the class `"shb"`.

In many other cases, an element category is mapped
to *two* HTML classes: the first is a generic one,
which is the same for a whole set of
elements, and the second one is a more specialized one.
For example, `.EL.OP.MULTIPLICATION`, which identifies The
`"*"` operator, is assigned a generic class of `"op"`, for
"operator", and a specialized class of `"mul"`.

These class names are then prefixed with a special
prefix (by default, `"rx-"` is used) to avoid conflicts
with classes by other programs. In our example, the `"*"`
operator would be assigned classes `"rx-op"` and `"rx-mul"`.

### Coarse- vs. fine-grained class assignments

The sets of elements that are capable of being assigned
two classes instead of only one
are *assignments* (`"asg"` + a specific class),
*operators* (`"op"` + a specific class),
*special characters and special character sequences*
(`"spe"` + a specific class) and *taken constants*
(`"const"` + a specific class).

Depending on the supplied program options,
each run of the Highlighter may assign to the elements
belonging to each of these sets the first, generic class,
the second, more specialized class, or both.

For example, when using `rexx` fenced code blocks,
the `assignment` attribute may have a value of
`"group"` (the first class), `"detail"` (the second class),
or `"full"` (both).

This mechanism allows to choose, for every element
set, between very fine-grained and more coarse-grained class
assignments on a highlighter run-by-run basis.

<pre>
&#126;~~rexx {assignment=detail special=group operator=full constant=detail classprefix="P"}</pre>


### Program source

```rexx {source=../../../cls/HTMLClasses.cls}
```