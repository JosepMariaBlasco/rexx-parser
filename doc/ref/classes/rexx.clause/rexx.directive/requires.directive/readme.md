The Requires.Directive class
============================

--------------------------

The Requires.Directive class creates objects which
represent the `::REQUIRES` directives of an ooRexx program.

Superclass: [Rexx.Directive](../)

Methods of the Requires.Directive class
---------------------------------------

### programName

![programName](Requires.Directive.programName.svg) \

Returns the name of the required program, as a string element
or a symbol element.

### nameSpace

![nameSpace](Requires.Directive.nameSpace.svg) \

Returns the namespace associated with this `::REQUIRES` directive,
as a symbol element, or `.Nil` when the `NAMESPACE` keyword was
not specified.

### library

![library](Requires.Directive.library.svg) \

Returns `1` when the `LIBRARY` keyword was specified on the directive,
otherwise returns `.Nil`.