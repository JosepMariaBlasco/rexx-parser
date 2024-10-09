# The Rexx.Parser class

## new (Class method)

![Syntax diagram for the new method of the Rexx.Parser class](../img/Rexx.Parser.new.svg)

Returns a new instance of the Rexx.Parser class, which is a representation of the code contained in the _source_.
The _name_ is a string. The _source_ can be a single string or an array of strings containing
individual method lines. If _source_ isn't specified, _name_ identifies a file that will be used as the code
source.

You can optionally specify a set of _options_ that control the behaviour of the parser. When specified, _options_ has
to be an array of two-element arrays, which will be sent as the arguments of an `of` message to the `Directory` class.

## package

![Syntax diagram for the package method of the Rexx.Parser class](../img/Rexx.Parser.package.svg)

Returns a [Rexx.Package](Rexx.Package.md) representing the parser program.
