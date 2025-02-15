The Element class
===============

-----------------------------

Definitions
-----------

### The element chain

A **Element** object is an element of a sequential
[**element stream**](/rexx.parser/doc/glossary/#element-stream) or
[**element chain**](/rexx.parser/doc/glossary/#element-chain)
produced by [the Rexx Parser](/rexx.parser/) when
parsing a Rexx program.

### Portions and markers

Each element represents
an elementary [**portion**](#portion) of the parsed program,
or a parser-generated [**marker**](#marker). Each marker is located between
two portions and occupies no space.

### Element categories and subcategories

Every element has a [**element category**](../../categories/)
that identifies its syntactic category; additionally,
when the element category is `.EL.TAKEN_CONSTANT`,
the element also has a [**subcategory**](../../categories/),
which further specifies the type and use of the taken constant.

### Inserted element {#marker}

[**Markers**](/rexx.parser/doc/glossary/#marker-element)
are used to convey additional meaning to the element
chain. For example, a marker may indicate
that a clause has ended, or that an implicit
`EXIT` instruction has to be assumed at the end
of a code section. Markers are also called
[**inserted**](/rexx.parser/doc/glossary/#inserted-element),
[**implied**](/rexx.parser/doc/glossary/#implied-element),
or [**zero-length**](/rexx.parser/doc/glossary/#zero-length-element)
elements.

Some of the markers are dictated by the Rexx Language
conventions (for example, a semicolon is assumed
after `THEN`, `ELSE` and `OTHERWISE`, or before `THEN`),
and others are added by the Rexx Parser to enhance
the element stream by ensuring that it has certain
properties (for example, that a clause is always
delimited by two end-of-clause markers).

### Non-inserted elements {#portion}

**Portions**, or **non-inserted** elements
represent fragments of the source
program, and, although they roughly correspond to the
Rexx notion of token, their concept is extended
to encompass elements that are not considered
tokens by Rexx, like comments, or non-significant
whitespace. This definition is chosen so that
the following invariant becomes true:

> A program source is always equivalent to the
> ordered concatenation of the values of its
> element chain.

### Ignorable elements

Elements which are [non-inserted](#portion)
but do not fall under the Rexx definition of token
are [**ignorable elements**](/rexx.parser/doc/glossary/#ignorable-element).

You can check whether a element is ignorable by using the
[isIgnorable](#isignorable) method of the [Element](.) class,
and you can make an element ignorable by using the
[makeIgnorable](#makeignorable) method.

Please note that the knowledge of the fact that
a certain element is or is not ignorable may imply
a quite involved syntactical analysis
of a relatively large part of the program.
Think, for example, of ignorable and non-ignorable whitespace
when parsing a template containing complex expressions
which include blank operators.

### Parts of a compound variable {#compound-parts}

A element `C` representing a compound variable can be managed as a whole,
or decomposed into its constituent elements or **parts**, by using
the [parts](#parts) instance method of the Element class (see below).

This method is only available when the class of the element is
`.EL.COMPOUND_VARIABLE` or `.EL.EXPOSED_COMPOUND_VARIABLE`,
and then it returns an array containing all the parts
(elements) of the compound variable.

The first element of the array is always the stem name,
that is, it is of class `.EL.STEM_VARIABLE` or `.EL.EXPOSED_STEM_VARIABLE`,
and it includes the first dot in the compound variable name.
The rest of the components are a sequence of either
simple variables, of class `.EL.SIMPLE_VARIABLE` or `.EL.EXPOSED_SIMPLE_VARIABLE`;
signless integers, of class `.EL.INTEGER_NUMBER`;
pure dotless constant symbols, of class `.EL.SYMBOL_LITERAL`; or
separator dots, of class `.EL.TAIL_SEPARATOR`.

Element categories and sets of element categories
-------------------------------------------------

A fundamental property of an element `E` is its
[**element categories**](/rexx.parser/doc/glossary/#element-class),
`E~category`, a one-byte value that identifies the syntactic
category of the element, regardless of whether it is ignorable or not,
or implied or not. The Rexx Parser is able to recognize and assign
a very wide variety of categories; you can browse the
listing of possible classes [here](/rexx.parser/doc/ref/categories/).

At initialization time, the Rexx Parser stores a set of symbolic
element names in the global environment. All these names start
with the `.EL.` prefix.

~~~rexx
--------------------------------------------------------------------------------
-- Some sample element categories                                               --
--------------------------------------------------------------------------------
 .EL.EXPOSED_STEM_VARIABLE              -- A stem variable that has been exposed
 .EL.ENVIRONMENT_SYMBOL                 -- An environment symbol
 .EL.DIRECTIVE_START                    -- The directive start sequence, "::"
 .EL.ELLIPSIS                           -- The ARG instruction ellipsis, "..."
 .EL.ASG.PLUS                           -- The "+=" compound assignment sequence
~~~

The `CategoryName` public routine returns the symbolic
form of an element category value.

~~~rexx
  Say CategoryName( .EL.ELLIPSIS )      -- EL.ELLIPSIS
~~~

A collection of convenient names for several
*category sets* is also created;
these start with the `.ALL.` prefix.
More information about the sets of element categories
can be found [here](/rexx.parser/doc/ref/categories/).

~~~rexx
--------------------------------------------------------------------------------
-- Some sample category sets                                                  --
--------------------------------------------------------------------------------
 .ALL.SPECIAL_CHARS                     -- All the special chars
 .ALL.STRINGS                           -- Standard, hexadecimal and binary
 .ALL.NUMBERS                           -- Integers, fractional and exponential
~~~

Elements and the `<` and `<<` operators
---------------------------------------

The Element class redefines the `<` and `\<` operators to simplify
testing for element categories and sets of categories:

~~~rexx
  element  < category; /* is equivalent to */    element~category  == category
  element  < set;      /* is equivalent to */    set~contains(element~category)
  element \< category; /* is equivalent to */    element~category \== category
  element \< set;      /* is equivalent to */   \set~contains(element~category)
~~~

`"<"` can be read as "is", "is a", "belongs to", or "in",
depending on the context:

~~~rexx
                                        -- element is...
  element < .EL.DIRECTIVE_START         -- ...a directive start sequence
  element < .ALL.NUMBERS                -- ...a numeric element
  element < .EL.KEYWORD                 -- ...a keyword
~~~

The case of taken constants: element subcategories
--------------------------------------------------

A "taken constant" is "a string or a symbol taken as a constant" (it is an
unfortunate name, but, for lack of a shorter one, it has stuck; see the ANSI
standard, 6.3.2.22, `taken_constant`). Taken constants appear in several
places in the Rexx language syntax definition. For example, a symbol
appearing in a label position is "taken as a constant", in the sense
that no variable substitution is performed, and, if its syntactical
form is that of a compound variable, no component value is substituted.

~~~rexx
  Say This.is.a.compound.variable...1234.3ea56...but
This.is.not.a.compound.variable:
  Exit
~~~

A taken constant element `E` has always the same element category,
`.EL.TAKEN_CONSTANT` but, additionally, it has
an extra attribute, `E~subCategory`, which further
determines the syntactic category of the element. Like its
element category, the element subcategory is also a one-byte value,
and it also has a set of symbolic names created
at parser initialization time.

In the case of taken constants, `element << subcategory`
is redefined to mean "the category of the element is .EL.TAKEN_CONSTANT,
and the subbcategory of the element is *subcategory*", and
similarly for the `\<<` operator.

~~~rexx
--------------------------------------------------------------------------------
-- Some sample possible taken constant subCategory values                     --
--------------------------------------------------------------------------------
 .BUILTIN.FUNCTION.NAME       -- A BIF name, i.e., not an internal or external
                              -- routine, nor a ::RESOURCE name
 .LABEL.NAME                  -- A label
 .METHOD.NAME                 -- A method name
 .RESOURCE.DELIMITER.NAME     -- The optional end delimiter of a ::RESOURCE
~~~

Most subcategory names *end with* the `.NAME` suffix, except
for some very few ones, which end with `.VALUE`.

The `ConstantName` public routine returns the symbolic
form of a subcategory value.

~~~rexx
  Say ConstantName( .LABEL.NAME )       -- LABEL.NAME
~~~

Methods of the Element class
----------------------------

### &lt; {#less}

![less](Element.less.svg) \

The expression `element < categories` returns `.True` when
`categories~contains(element~category)`,
and `.False` otherwise. Please note that when *categories*
contains only one byte (i.e., it represents a single element category),
`element < categories` is equivalent to `element~category == categories`.

### &lt;&lt; {#lessless}

![lessless](Element.lessless.svg) \

The expression `element << subcategories` returns `.True` when
`element~category == .EL.TAKEN_CONSTANT & subcategories~contains(element~subcategory)`,
and `.False` otherwise.

### &bsol;&lt; {#notless}

![notless](Element.notless.svg) \

The negation of the `<` operator, `\<`, is also overloaded.

### &bsol;&lt;&lt; {#notlessless}

![notlessless](Element.notlessless.svg) \

The negation of the `<<` operator, `\<<`, is also overloaded.


### category

![category](Element.category.svg) \

Returns a one-byte value determining the category of the element.
Element categories are described in detail
[here](/rexx.parser/doc/ref/categories/).

### from

![less](Element.from.svg) \

Returns a string formatted as `"line column"`.
This is the position of the first character in the element,
when the element has an extent. Otherwise, it is the position
of the first character of the following element in the same line,
if one exists, or the position of the first character
after the previous element in the same line, if one exists, or both.
A semicolon inserted in an empty line will have a from value of "line 1".

See also method [to](#to).

### isAssigned {#isassigned}

![isAssigned](Element.isAssigned.svg) \

Returns `.True` when the destination element is one of:

- A variable assignment target (i.e., the left-hand-side of an assignment)
- A assignment message target object in an assignment instruction.
- A parsing template variable (when this variable will receive a value,
  not when the variable is used as part of a pattern).
- An argument variable in a `USE ARG` instruction.
- A variable reference term in a `USE ARG` instruction.
- A assignment message target object in a `USE ARG` instruction.
- A counter specified using the `COUNTER` subkeyword
  in a `DO` or `LOOP` instruction.
- A control variable used in an iterative loop.

See also method [setAssigned](#setassigned).

### isIgnorable

![isIgnorable](Element.isIgnorable.svg) \

Returns `.True` when the destination element is ignorable.
Comments are always ignorable, as are, in many cases,
whitespace sequences. Higher levels of parsing
"jump over" (i.e., they *ignore*) ignorable elements.
Please refer to the description of
[ignorable elements](#ignorable-elements), above.

See also method [makeIgnorable](#makeignorable).

### makeIgnorable

![makeIgnorable](Element.makeIgnorable.svg) \

Makes the destination element ignorable.

See also method [isIgnorable](#isignorable).

### next

![next](Element.next.svg) \

The next element in the parsing stream,
or `.Nil` if this is the last element in the stream.

See also method [prev](#prev).

### parts

![parts](Element.parts.svg) \

Returns an array containing the parts that constitute a compound variable.
This method is only available when the element is a compound variable.
You can find more information about this method [here](#compound-parts).

### prev

![prev](Element.prev.svg) \

Returns the previous element in the parsing stream,
or `.Nil` if this is the first element in the stream.

See also method [next](#next).

### setAssigned {#setassigned}

![setAssigned](Element.setAssigned.svg) \

Marks the element as assigned, so that subsequent calls to
[isAssigned](#isassigned) will return `.True`.

### source

![source](Element.source.svg) \

Returns the contents of the element,
as it appears on the source file.
This method cannot be used with comments
and other element classes that are potentially
multi-line, like the resource data of a resource.

### subCategory

![subCategory](Element.subCategory.svg) \

Returns a one-byte value determining the element subCategory.
This method is only available when the element class is
`.EL.TAKEN_CONSTANT`. Element subcategories are described in detail
[here](/rexx.parser/doc/ref/categories/).

### to

![to](Element.to.svg) \

Returns a string formatted as `"line column"`.
The position of the first character after the element,
when the element has a positive extent;
please note that this can point to the first character
"out of the line" when the element is at the end of the line.
When a element is inserted or implied
(that is, it has a zero length extent),
`to` returns the same value as `from`.

See also method [from](#from).

### value

![value](Element.value.svg) \

Returns the contents of the element, partially interpreted
(see the description for [the source method](#source)).
Symbols are translated to uppercase, and strings are interpreted,
i.e., double quotes are deleted in literal strings,
and binary and hexadecimal strings are transformed into byte strings.
As an example, and assuming an ASCII encoding,
this means that the strings `"a"`, `"61"X` and `"0110 0001"B`
have different [sources](#source), but identical [values](#value).