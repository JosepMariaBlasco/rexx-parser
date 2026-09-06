# Highlighting inline code

Consider the following toy, working, program. It's been
highlighted by our highlighter.

```rexx
/* The square root of two, using continuous fractions */

-- We don't handle errors
Arg digits . 

Numeric Digits (digits+2)
Tolerance = 10**(-digits)

-- We first calculate sqrt(2)+1 

this = 2

Loop Counter c
  next = 2 + (1 / this)
  If Abs(this-next) < Tolerance Then Leave
  Say "Iteration" Right(c,5)":" next
  this = next
End

-- Now we subtract 1 and present the result

Say "The square root of two, with a precision of" ,
    digits "digits, is:" Format(this-1, , digits-1)
```

Now imagine that we are in a class. We want to discuss about our program.
We might want to point out that starting a program with
a `/* block comment */`{.rexx} is good practice, for example.
Or maybe we prefer to stress the fact that Rexx does not have
reserved words, so that `digits`{.rexx} as a variable can coexist
with `Digits`{.rexx-subkeyword} as a subkeyword of the
`Numeric`{.rexx-instruction} instruction. It should be obvious that
having the inline code fragments highlighted in the very same way
as the code blocks greatly improves the readability and understandability
of our texts.

## The easiest cases

In the easiest cases, you simply enclose your inline code
`` `between backticks` ``, and add `{.rexx}` at the end (without
intervening blanks). So, for example, 
`` `If Abs(this-next) < Tolerance Then Leave`{.rexx} ``
will display as `If Abs(this-next) < Tolerance Then Leave`{.rexx}.

What makes a case "easy"? A case is "easy" _when, by itself, it parses as_
_a complete, self-contained, program_.

## The not-so-easy cases

In other cases, the Parser, left to itself, does not have
enough information to determine the nature of an element. Let's
go back to our sample program. `Digits`{.rexx} by itself is a variable
name --- indeed, if found alone it would represent a command instruction.
In that case, using `{.rexx}` works perfectly. But what if we want
to refer to the `Digits`{.rexx-subkeyword} _subkeyword_? In that case,
we have to inform the highlighter of our intent -- by default,
as we have seen, `Digits`{.rexx} is a variable. We do that by using
the corresponding inline highlighting tag, `.rexx-subkeyword`:
we write `` `Digits`{.rexx-subkeyword} `` and `Digits`{.rexx-subkeyword}
is displayed.

## Symbols and strings

In most cases, symbols and strings are recognized by `` {.rexx} `` 
without further ado: `variable`{.rexx} is styled as a (simple) _variable_,
`stem.`{.rexx} as a _stem_, and `m.i.2.3D...?`{.rexx} as a (hopeless) _compound variable_.
Similarly, `"String"`{.rexx} is styled as a _string_, `"DEAD BEEF"X`{.rexx}
is styled as an _hexadecimal string_, and `"1000 0001"B`{.rexx} is styled
as a _binary string_.

`.Environment`{.rexx} is styled as an _environment symbol_, and true constant symbols
like `3D`{.rexx} are properly styled too. `123.45e678`{.rexx} is clearly a _number_;
please note that the highlighter recognizes `" - 123.456e-789 "`{.rexx} 
numbers-as-strings too.

When you want to use the name of a keyword instruction as a variable name
(and this also includes `THEN`{.rexx-variable},
`ELSE`{.rexx-variable}, `WHEN`{.rexx-variable}, `OTHERWISE`{.rexx-variable} or
`END`{.rexx-variable}, which start clauses), you have to be explicit
about it and use the tag `{.rexx-variable}`, so that the Parser
doesn't get confused: `Parse`{.rexx-instruction} is the start of
an incomplete instruction, while `Parse`{.rexx-variable} is a
viable variable name.

---

## Keywords, subkeywords, and keywords-as-variables

Named for what the author *asserts the thing to be*, not for the syntactic role
it would play in some unwritten context. One word covers the whole category.

| Tag                        | For                                       |
|----------------------------|-------------------------------------------|
| `rexx-instruction`         | `Say`{.rexx-instruction}, `Do`{.rexx-instruction}, `If`{.rexx-instruction}, `Call`{.rexx-instruction}, `Procedure`{.rexx-instruction}…      |
| `rexx-subkeyword`          | `To`{.rexx-subkeyword}, `By`{.rexx-subkeyword}, `Until`{.rexx-subkeyword}, `While`{.rexx-subkeyword}…             |
| `rexx-directive`           | `::Method`{.rexx-directive}, `::Class`{.rexx-directive} — including the `::`{.rexx-directive-start} directive start |
| `rexx-directive-start`     | `::`{.rexx-directive-start} alone |
| `rexx-directive-keyword`   | the directive keyword alone (`Method`{.rexx-directive-keyword})    |
| `rexx-directive-subkeyword`| `Public`{.rexx-directive-subkeyword}, `Subclass`{.rexx-directive-subkeyword}, `Private`{.rexx-directive-subkeyword}, `Inherit`{.rexx-directive-subkeyword}|
| `rexx-variable`            | a simple variable, like `Select`{.rexx-variable}, which is also an instruction keyword |
| `rexx-exposed-variable`    | exposed simple `variable`{.rexx-exposed-variable}  |
| `rexx-exposed-compound`    | exposed `compound.variable.2`{.rexx-exposed-compound} |
| `rexx-exposed-stem`        | exposed `stem.`{.rexx-exposed-stem}                      |

---

## Names (and some delimiters and values)

| Public tag               | For                               |
|--------------------------|-----------------------------------|
| `rexx-class`             | `::Class`{.rexx-directive} `name`{.rexx-class}                  |
| `rexx-constant-value`    | `::Constant`{.rexx-directive} `constantName`{.rexx-method} `constantValue`{.rexx-constant-value}                |
| `rexx-method`            | `::Method`{.rexx-directive} `name`{.rexx-method}                  |
| `rexx-requires`          | `::Requires`{.rexx-directive} `name`{.rexx-requires} |
| `rexx-resource`          | `::Resource`{.rexx-directive} `name`{.rexx-resource}                     |
| `rexx-resource-delimiter`| `::Resource`{.rexx-directive} `name`{.rexx-resource} `End`{.rexx-directive-subkeyword} `delimiter`{.rexx-resource-delimiter}                |
| `rexx-routine`           | `::Routine`{.rexx-directive} `name`{.rexx-routine}                  |
| `rexx-label`             | label (`end:`{.rexx} → "the `end`{.rexx-label} label") |
| `rexx-namespace`         | `namespace`{.rexx-directive-subkeyword} `name`{.rexx-namespace}                    |
| `rexx-annotation`        | `::Annotate`{.rexx-directive} `class`{.rexx-directive-subkeyword} `MyClass`{.rexx-class} `myName`{.rexx-annotation} ...                   |
| `rexx-annotation-value`  | ... `"myValue"`{.rexx-annotation-value}                  |
| `rexx-argument`          | Argument names (Executor only)                     |
| `rexx-block`             | `Label`{.rexx-subkeyword} `name`{.rexx-block} (in `Do`{.rexx-instruction}, `Loop`{.rexx-instruction} and `Select`{.rexx-instruction}) |
| `rexx-environment`       | `.environment`{.rexx-environment} variable name                  |
| `rexx-user-condition`    | `Signal On User UserCondition`{.rexx}                    |


### Calls

| Function form                    | Subroutine form                    | Shortcut (= subroutine)  |
|----------------------------------|------------------------------------|--------------------------|
| `rexx-internal-function`         | `rexx-internal-subroutine`         | `rexx-internal`          |
| `rexx-builtin-function`          | `rexx-builtin-subroutine`          | `rexx-builtin`           |
| `rexx-package-function`          | `rexx-package-subroutine`          | `rexx-package`           |
| `rexx-external-function`         | `rexx-external-subroutine`         | `rexx-external`          |
| `rexx-external-package-function` | `rexx-external-package-subroutine` | `rexx-external-package`  |

