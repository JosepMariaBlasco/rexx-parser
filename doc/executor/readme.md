Executor support
================

--------------------------

[Executor](https://github.com/jlfaucher/executor) is
a dialect of ooRexx designed by [jlfaucher](https://github.com/jlfaucher) and
featuring an important and very
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

+ Rexx fenced code blocks can use Executor syntax by using the `executor` attribute
  on the first fence of the code block. Or you can simply use "executor" as
  your language id, but take into account that other sites (like GitHub) will
  not recognize it.

+ [The `identtest` utility](../utilities/identtest/) includes support for Executor. You
  can activate it by using the `-xtr` or `-executor` options.

+ [The `highlight` utility](../utilities/highlight/) includes support for Executor. You
  can activate it by using the `-xtr` or `--executor` options.

+ [The `trident` utility](../utilities/trident/) includes support for Executor. You
  can activate it by using the `-xtr` or `--executor` options.

+ [The `rxcheck` utility](../utilities/rxcheck/) includes support for Executor. You
  can activate it by using the `-xtr` or `-executor` options.


Here are some (non-exhaustive) examples of Executor features in action. For the full details,
please refer to the
[Executor GitHub repository](https://github.com/jlfaucher/executor)
and to the
[executor documentation](https://jlfaucher.github.io/executor/).

### Modifications to the scanner

```rexx {executor}
-- Executor parses "2i" as a number ("2") followed by (concatenated to) a symbol ("i"):

x = 3 + 2i
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

### Source literals and code blocks

```rexx {executor}
--
-- Note: Executor already includes a "map" method for Arrays. This sample
-- defines a "map" extension method to show how source literals work.
--

double     = {Use Arg x; x+x}           -- A routine that doubles its argument
square     = {Use Arg x; x*x}           -- A routine that squares its argument

vector     = .Array~of(1,2,3)           -- A one-dimensional array
res        = vector~map(square)         -- Square it...
Loop index Over res~allIndexes          -- ...and print it.
  Say index":" res[index]
End

array      = .Array~new                 -- A two-dimensional array...
array[1,2] = 15                         -- ...sparsely populated
array[2,1] = 25
res        = array~map(double)          -- Let's double it, ...
Loop index Over res~allIndexes          -- ...and print it.
  Call CharOut ,"["
  Loop n = 1 To index~items
    Call CharOut , index[n]
    If n < index~items Then Call CharOut ,", "
  End
  Call CharOut ,"]: "
  Say res[index]
End

::Extension Array                       -- Extending the (predefined) Array class
::Method Map                            -- This method is second order...
  Use Strict Arg fun                    -- ...as its argument is itself a routine.
  res = .Array~new
  Do index Over self~allIndexes         -- 'allIndexes' is agnostic regarding dimensionality
    res[index] = fun~(self[index])      -- 'fun~(args)' is Executor's way to call 'fun'
  End
  Return res

::Requires "extension/extensions.cls"
```

### Compatibility with Classic Rexx

```rexx {executor}
-- Allow "^" and "¬", in addition to "\", to express negation

Say 1 \= 1                              -- 0
Say 1 ^= 1                              -- 0
Say 1 ¬= 1                              -- 0

-- Both Latin-1 "¬" ("AC"X) and UTF-8 "¬" ("C2 AC"X) are accepted

--------------------------------------------------------------------------------

-- Allow "#", "@", "$" and "¢" as letters when forming symbols

#2 = "ab"
Say #2 #2                               -- "ab ab"

-- Both Latin-1 "¢" ("A2"X) and UTF-8 "¢" ("C2A2"X) are accepted

--------------------------------------------------------------------------------

-- Allow "Symbol =" in assignments (assigns the null string)

V =
Say V~length V~class                    -- 0 The String class

--------------------------------------------------------------------------------

-- (Others)
```