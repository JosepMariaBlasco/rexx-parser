Executor support
================

--------------------------

[Executor](https://github.com/jlfaucher/executor) is
a dialect of ooRexx featuring an important and very
interesting set of extensions to the language. The
Rexx Parser implements full, optional, support for the parsing of
ooRexx programs that contains Executor enhancements.

Namely,

+ When creating a [Rexx.Parser](../ref/classes/rexx.parser) instance,
  you can use the `EXECUTOR` option, set to any value (although `1`
  is recommended and may be mandatory in future releases) to activate
  Executor support.

+ [The `elements` utility](../utilities/elements/) includes support for Executor. You
  can activate it by using the `-xtr` or `--executor` options.

+ [The `elident` utility](../utilities/elident/) includes support for Executor. You
  can activate it by using the `-xtr` or `--executor` options.

+ Rexx fenced code blocks can use Executor syntax by using the `executor` option
  on the first fence line of the code block.

+ [The `highlight` utility](../utilities/highlight/) includes support for Executor. You
  can activate it by using the `-xtr` or `--executor` options.

+ [The `trident` utility](../utilities/trident/) includes support for Executor. You
  can activate it by using the `-xtr` or `--executor` options.

+ [The `rxcheck` utility](../utilities/rxcheck/) includes support for Executor. You
  can activate it by using the `-xtr` or `-executor` options.

+ [The `xtrtest` utility](../utilities/xtrtest/) has been specifically created
  to test the working of the Rexx Parser when handling Executor programs.

Here are some examples of Executor features in action. For the full details,
please refer to the
[Executor GitHub repository](https://github.com/jlfaucher/executor)
and to the
[executor documentation](https://jlfaucher.github.io/executor/).

### Modifications to the scanner

```rexx {executor}
-- Executor parses "2i" as a number ("2") followed by
-- (concatenated to) a symbol ("i"):

x = 2i
```

### New `::EXTENSION` directive

```rexx {executor}
Say "1234"~thanks             -- You're welcome

-- The ::EXTENSION directive works for predefined classes too
::Extension String
::Method Thanks
  Return "You're welcome"
```

### Named arguments

```rexx {executor}
Call Touch x: 2, y: 3         -- (2, 3)
Call Touch y: 2, x: 3         -- (3, 2)
Exit

Touch: Procedure
  Use Named Arg x, y
  Say "(" || x", "y")"
Return
```