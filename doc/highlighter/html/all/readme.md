HTML Highlighter general tests
==============================

---------------------------------------------------

See also:

+ [All directives](/rexx.parser/doc/highlighter/html/directives/)
+ [All instructions](/rexx.parser/doc/highlighter/html/instructions/)

#### Comments

```rexx
/*
 * A multi-line comment
 */

-- A line comment
```

#### Keywords, and directive keywords

```rexx
  If a = b Then Say "Hello"; Else Nop

::Requires "some/path/a.program.rex"
::Routine myRoutine
  Loop Label myLoop Counter c Forever
    Say c
    If c = 3 Then Leave myLoop
  End
```

#### Symbols

```rexx
::Method myMethod
  Expose var stem.                      -- Exposed variables
  Say local var a. stem.                -- Local and exposed variables
  Say 12 12.3 12.3e-3                   -- Numbers
  Say 12A15 3.A11.K                     -- Constant symbols
  Say stem.local.12.3d..x               -- Compound variables
  Say a.var.37e2..zz...                 -- Compound variables
  Say .True .Nil .Here.we.are           -- Environment symbols
```

#### Strings

```rexx
  "Hello!"                              -- A literal string
  "0110"B                               -- A binary string
  "0CBA"X                               -- An hexadecimal string
```

#### Operators

```rexx
  x = (a // b + c % d) <<= 21 ** (1/z)
```

#### Assignments

```rexx
  x   = (a  = b)                        -- Assignment vs. comparison
  x  += (a <= b)
  x **= (a == b)
  x ||= y
  Loop i = (1 = 1) To 23 + (2 == 3)     -- Assignment to a control variable
    Say "Wow"
  End
```

#### Resources

```rexx
::Resource xx End "Final" ; Ignored 1
  Line 1
  Line 2
  Line 3
Final Ignored 2
```

#### Internal calls and built-in functions

```rexx
  Say Length("A string")                -- This is a BIF call
  Say Pos("A string")                   -- This is an internal procedure call
  Exit 1

Pos: Return 1
```

#### External calls and ::Routine calls

```rexx
  Call External                         -- Not found? --> An external call
  Call myRoutine                        -- A locally defined ::Routine
  Call NameSpace:Routine                -- Namespaced? An external ::Routine

::Routine myRoutine
```

#### Class and method definitions, and method calls

```rexx
::Class MyClass SubClass String
::Method length
  Return self~length:.String
```