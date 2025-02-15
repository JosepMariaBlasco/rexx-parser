The Driver Class
================

----------------------------------

The Driver class is abstract, and all Rexx Highlighter
drivers should subclass it. It provides a
common architecture for all highlighter drivers
to follow, and it also centralizes a set
of common services.

Conceptually, the output produced by a highlighter driver
is composed of a [*prolog*](#prolog),
a body and an [*epilog*](#epilog); the prolog and the
epilog are specific to each driver. The *body* contains
the driver-specific translations of every element in the
source program.

### new (Class method)

![new](Driver.new.svg) \

Returns a new instance of of the Driver class. *Options.*
is a stem containing Highlighter options and internal values,
and *output* is an array that will receive the highlighter output.

### emit

![emit](Driver.emit.svg) \

Adds *string* to the current output line. Conceptually,
it is equivalent to `"CharOut ,string"`.

### epilog (abstract method) {#epilog}

![epilog](Driver.epilog.svg) \

This is an abstract method, which should be
defined by all subclasses of the Driver class.

### prolog (abstract method) {#prolog}

![prolog](Driver.prolog.svg) \

This is an abstract method, which should be
defined by all subclasses of the Driver class.

### say

![say](Driver.say.svg) \

Adds *string* to the current output line, outputs the line,
and starts a new one. Conceptually,
it is equivalent to `"Say string"`.

### startLine

![startLine](Driver.startLine.svg) \

This method is called at the beginning of each line of code.
It can be used, for example, to print line numbers.

### tags2highlight

![tags2highlight](Driver.tags2highlight.svg) \

This is a utility method. *Tags* is a blank-separated
set of HTML tags, and *extra* contains the
highlighting information provided in the
optional style patch. This method looks up the CSS
highlightings defined by every tag in *tags*, combines
them in order, and then applies the highlighting
in *extra*, if any.

The returned value is a string
with the following format

~~~
bold italic underline color"/"background
~~~

where *bold*, *italic* and *underline* are boolean values (that is,
either `0` or `1`), and *color* and *background*, which are
both optional, use the `#rrggbb` CSS color format.