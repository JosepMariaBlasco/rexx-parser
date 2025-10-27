Lua support
===========

The Parser includes an optional Lua mode which
enables a number of syntax modifications and extensions
in preparation for a yet unannounced project.

You can enable Lua support by specifying the `"LUA"` option
with an arbitrary value (e.g., `("LUA",1)`)
when you invoke the parser,

```rexx
  parser = .Rexx.Parser~new(.filename, source,   -
    .Array~of(                                   -
      ( Lua, 1 )                                 -
     ,-- Other options...                        -
    )                                            -
  )
```

You can also switch it on from your source program
by specifying

```rexx
Options Lua
```

<em>at the start of your source file</em>.
Behaviour when you use `Options Lua` in other places is
undefined.

What happens when `Options Lua` is in effect
--------------------------------------------

### Keywords and constants

When `Options Lua` is in effect, the parser recognizes
three Lua keywords, `and`, `not` and `or`, and four
constants, `fail`, `false`, `nil` and `true`.

These keywords and values are recognized only when
they are completely written in lowercase; in all other cases,
they can be normally used as variable names, function call
names, etc.

```rexx
  Options Lua                           -- Enable Lua extensions support

  Nil = 2                               -- We assign the value "2" to the "Nil" variable
  Nil = nil                             -- Now we assign Lua nil to Nil
  If not Nil Then Say "Taken!"          -- The branch will be taken, as the Nil variable
                                        -- has the value nil, one of Lua's falsy values.
  Fail = Nil or Not                     -- Assigns the value of Not to Nil
  Fail = Nil or not Fail                -- Now Fail is true iff Not was falsy
```

### Extended initializers, or table constructors

When `Options Lua` is in effect, the parser recognizes
table constructors (or table initializers), with the following
syntax:

```ebnf
  initializer := "[" [field_list] "]"
  field_list  := field ("," field)+
  field       := "(" expression ")" "=" expression
               | VAR_SYMBOL "=" expression
               | expression
```

This mimicks the Lua definition of table constructors, which
for Lua 5.5 beta is the following:

```ebnf
  tableconstructor := "{" [fieldlist] "}"
  fieldlist        := field {fieldsep field} [fieldsep]
  field            := "[" exp "]" "=" exp | Name "=" exp | exp
  fieldsep         := "," | ";"
```

Rexx outer brackets are "[" and "]" instead of "{" and "}", to get
a syntax which is coherent with NetRexx array initializers.
Left-hand-side expressions should be enclosed between parentheses,
the field separator has to be a comma, and no extra comma
is allowed at the end of the list, because this could erroneous
seem to imply some form of presence, like in ooRexx array terms.

### Lambda expressions and Lambda blocks

As a shorthand for defining nested functions, you can use
<em>Lambda expressions</em>. The simplest form of a Lambda expression
consists of a single argument name, followed by the "maps to"
operator, "->", followed by an expression. For example,

```rexx
Options Lua
double = x -> 2*x
```

assigns a function which doubles its only argument to a variable called
`double`.

If you have more or less than one argument, you must enclose the argument
names between parentheses:

```rexx
Options Lua
add = (x,y) -> x+y
```

In the case of a single arguments, and as a convenience, parenthesesa
are optional.

The expression to the right of the "->" operator can be a Lambda expression
too, that is, a function can return another function. For example,
if we write

```rexx
Options Lua
multiplier = x -> y -> y*x
```

then `multiplier(3)` returns a function that multiplies by 3 its only argument.

Please note that the "->" operator is <em>right-associative</em>.

When an expression follows the "->" operator, an implicit `return` instructions
is assumed.
You can also use several instructions after the "->" operator, and
in this case you should enclose these instructions inside an unlabeled
single `DO` block:

```rexx
Options Lua

multiple = op -> Do
  Select Case op
    When "+" Then Return (x,y) -> x+y
    When "-" Then Return (x,y) -> x-y
    When "*" Then Return (x,y) -> x*y
    When "/" Then Return (x,y) -> x/y
  End
End
```

```ebnf
  lambda_expression := argument_list "->"
                       lambda_expression | expression | block
  block             := "DO"
                         [instruction]+
                       "END"
  argument_list     := argument_name | "(" ")"
                       | "(" argument_name [, argument_name]* ")"
```

### Syntax modifications to allow for first-class functions

Since when Lua extensions are in effect an expression can have
a function as a value, a small modification of Classic Rexx syntax
has had to be introduced. In Classic Rexx, an expression of the
form

```rexx
(whatever)(x)
```

is parsed as a concatenation, that is, an implicit abuttal operator
is inserted between the two adjacent parentheses, as if

```rexx
(whatever)||(x)
```

had been written. Since we now accept values which can themselves be
functions, this behaviour of the parser is no longer desirable.
Therefore, when `Options Lua` is in effect, the above expression
 will be parsed *as a function call*, that is, the value of
 `(whatever)` will be evaluated, assuming that it is a function,
 and then this function will be called with `x` as its only argument.

Please note that, contrary to Lua, where blanks before argument lists
are optional, in Rexx they are now, and, therefore, if there are
one or more blanks between the two adjacent parentheses, an implicit
concatenate-with-a-blank-in-between is assumed, that is,
the two following expressions will be equivalent:

```rexx
(whatever)   (x)                        -- Implicit concatenation
(whatever)' '(x)                        -- Two abuttals with a blank in between
```

As an indexed element can also be a function, this modification of
the syntax also applies when a left parenthesis is found immediately
after a right bracket.

### Examples

```rexx
Options Lua
x = []                                  -- An empty table
x = ["a", "b", "c"]                     -- An array with three string elements
                                        -- Now x[1] = "a", x[2] = "b" and x[3] = "c"
x = [                         -         -- A table with two fields
     name    = "Josep Maria", -         -- Now x.name (or x["name"]) = "Josep Maria",
     surname = "Blasco"       -         -- and x.surname = "Blasco"
    ]
x = [ (a+b) = v1, (a-b) = v2 ]          -- A table with two fields
                                        -- Now x[a+b] = v1 and x[a-b] = v2
x = [ a, b, c, d, n = 4]                -- An array with an extra field x.n
                                        -- indicating its length.
```

```rexx
-- Activate Lua extensions and compile for maximum efficiency
Options Lua FullBinary

-- An array constructor, a la NetRexx (works also for
-- directory-like tables and for mixed forms).
vector = [1,2,3,4]

-- "x -> 2*x" is a Lambda-expression, in this case a function
-- that returns its only argument, doubled. We assign this
-- function to the variable "double" (Lua, and Lua-extended
-- Rexx, support first-class functions).
double = x -> 2*x

-- Now we define the classical "map" function. The body of the
-- function needs several instructions: we enclose them between
-- "do" and "end" (in the case of a single expression there is
-- an implicit "return").
map = (a,f) -> Do
  b = []
  Loop i = 1 To #a -- "#a" is the Lua idiom for the length of "a"
    b[i] = f(a[i])
  End
  Return b
End

result = map(vector,double)

Loop i = 1 To #result                   -- 1: 1 -> 2
  Say i":" vector[i] "->" result[i]     -- 2: 2 -> 4
End                                     -- 3: 3 -> 6
                                        -- 4: 4 -> 8

-- We now define a higher-order Lambda function.
-- (Note that "->" is right-associative).
higher = y -> x -> x*y

-- Using the higher-order function.
Say higher(2)(21)                       -- 42
```