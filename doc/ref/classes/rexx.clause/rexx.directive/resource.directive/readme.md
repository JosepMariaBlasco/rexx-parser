The Resource.Directive class
============================

--------------------------

The Resource.Directive class creates objects which
represent the `::RESOURCE` directives of an ooRexx program.

Superclass: [Rexx.Directive](../)

Methods of the Resource.Directive class
---------------------------------------

### name

![name](Resource.Directive.name.svg) \

Returns the name of the resource, as a string element or a symbol element.

### delimiter

![delimiter](Resource.Directive.delimiter.svg) \

Returns the delimiter string that marks the end of the resource data.
When the `END` keyword was used on the directive (e.g.
`::RESOURCE Help END "::End"`), this is the specified delimiter;
otherwise, the default value `"::END"` is returned.

### fromLine

![fromLine](Resource.Directive.fromLine.svg) \

Returns the starting line number of the resource data
(the first line after the directive itself).

### toLine

![toLine](Resource.Directive.toLine.svg) \

Returns the ending line number of the resource data
(the last line before the closing delimiter).