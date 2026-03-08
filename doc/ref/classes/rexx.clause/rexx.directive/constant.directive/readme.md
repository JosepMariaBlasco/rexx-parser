The Constant.Directive class
============================

--------------------------

The Constant.Directive class creates objects which
represent the `::CONSTANT` directives of an ooRexx program.

Superclass: [Rexx.Directive](../)

Methods of the Constant.Directive class
---------------------------------------

### name

![name](Constant.Directive.name.svg) \

Returns the name of the constant, as a string element or a symbol element.

### value

![value](Constant.Directive.value.svg) \

Returns the value of the constant. The return value depends on the
form of the directive:

- When the value is a simple string or symbol (e.g. `::CONSTANT Pi 3.14159`),
  returns the value element.
- When the value is a signed number (e.g. `::CONSTANT Offset -10`),
  returns a two-element array containing the sign element and the
  number element.
- When the value is a parenthesized expression
  (e.g. `::CONSTANT Size (rows * cols)`), returns the expression object.
- When no value was specified, returns `.Nil`.

### constant

![constant](Constant.Directive.constant.svg) \

Gets or sets the constant object associated to this directive.