Lua support
===========

The Parser includes an optional Lua mode which
enables a number of syntax modifications and extensions
in preparation of a yet unannounced project.

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