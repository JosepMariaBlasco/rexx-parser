Error handling
==============

-----------------------------------------

Source program errors and parser errors
---------------------------------------

New `Rexx.Parser` instances are created
by passing a Rexx source program array as an argument,
and this source program may contain errors.
We say that these are _source program errors_.

On the other hand, the Rexx parser itself,
being a (relatively large) computer program, may have its own bugs.
These are _(internal) parser errors_.

Source program errors are produced by the Rexx Parser by raising
the SYNTAX condition using the 98.900 syntax error number and
passing a number of additional items that will be described below.

```rexx
  Raise Syntax 98.900 Additional( additional )
```

Standard parser errors are produced in the usual way.

A program using the Rexx Parser should turn the SYNTAX trap on
at the beginning of the program, or, at least,
before any Rexx Parser instance is created.

```rexx
  Signal On Syntax
```

The first thing that a SYNTAX condition handler should do
is to examine the SYNTAX error number: if it is not 98.900,
we can safely assume that this is a Parser error.

```rexx
Syntax:
  co = Condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End
```

When the error number is indeed 98.900,
we can safely assume that this is a source program error
which has been detected and raised by the Rexx Parser
(we are of course assuming that no other process
is raising a 98.900 SYNTAX error).

```rexx
Syntax:
  co = Condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End

  -- The additional array is used to pass information about the error
  additional = Condition("A")
  -- "Syntax error nn.nnn at line line:"
  Say additional[1]":"
  -- Retrieve the line number where the error occurred
  line = Additional~lastItem~position
  -- We assume that "source" is the parsed program array
  Say Right(line,6) "*-*" source[line]
  Say Copies("-",80)
  -- Dump the stack frame array
  Say co~stackFrames~makeArray
  additional = additional~lastItem

  -- Re-raise the error, so that Rexx can print the appropriate message
  Raise Syntax (additional~code) Additional (additional~additional)

  Exit
```
