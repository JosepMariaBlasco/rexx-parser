# Structure of A Token

**Tokens** are the most basic elements that constitute a program. A program is made of tokens, and it can be accurately represented by its unique *token chain*.

Our definition of *token* is slightly different from the Rexx definition of token: we say, for example, that a comment is an *ignorable token*; Rexx would instead say that comments are not tokens. Similarly, ignorable blanks (that is, blanks that are not concatenation operators) are ignored in Rexx (although they can play a role as delimiters), and therefore are not considered to be tokens; we will say that an ignorable blanks is an ignorable token.

>Our terminology is chosen so that we can completely identify a program with a sequence of tokens. This is necessary in a number of contexts, for example, when writing a program code highlighter, or an extractor of special comments, *à la* Javadoc.

## Extent of a token

Every token has an *extent*, determined by its `from` and `to` methods. Both `from` and `to` are string values with the same format:

```rexx
line col
```

`Token~from` refers to the position of the first character of a token, and `token~to` refers to the position of the first character *after* the token, if it exists, or one character to the right of the last character in the line, when it is the last token in the line.

You can access these values easily using the `Parse Value` instruction:

```rexx
Parse Value token~from With line col
```

Please note that the `line` in `token~from` will always be the same as the `line` in `token~to`, except for classic comments which start and end in different lines.

This definition of `from` and `to` was chosen because it is easy to remember and, additionaly, it has a number of desirable properties:

1. Except for classic comments spanning more than one line, `Word(to,2) - Word(from,2)` is always the length of a token.
2. When two tokens `T1` and `T2` are consecutive and reside in the same line, `T1~to == T2~from`.

## Inserted tokens

[The Rexx Parser](TheRexxParser.md) inserts a number of tokens in the program token sequence. Some of these tokens are inserted following the Rexx language definition: 
for example, a semicolon is implied by any line end, except when inside a classic comment. 
Some other tokens go beyond these definitions, and they are inserted as a convenience for the programmer. 
For example, a semicolon is inserted at the beginning of each program: this ensures that all clauses are delimited by a starting and an ending semicolon.

Inserted tokens are characterized by the fact that their extent is null, that is, they occupy no space:

```rexx
token~from == token~to
```

## Source and value

Every token `T` which is not a classic comment has a *source*, `T~source` and a *value*, `T~value`. The *source* is the token as it appears in the source file. The *value* is, generally speaking the same as the source, but it may differ in a number of cases:

* *String values* are interpreted, that is, hexadecimal and binary strings are converted to byte strings, internal double quotes are removed, etc.
* *Symbols* are translated to uppercase.
* *Inserted tokens* have their own values; for example, inserted semicolons have the value `";"`.

## Class of a token

Every token has a *class* that identifies its nature. Token classes are enumerated in the `TokenClasses` constant, which is defined in the `rexx.parser/Tokenizer.cls` package. Every token class constant is assigned a one-byte value at parser startup time. Class constant names are stored as environment variables:

```rexx
.INTEGER_NUMBER      -- A number without dots or an exponent
.FRACTIONAL_NUMBER   -- We have a dot, but no exponent
.EXPONENTIAL_NUMBER  -- An exponent (and maybe a dot)
```

The same package also defines a series of convenient sets:

```rexx
.NUMBER == ( .INTEGER_NUMBER    || -
             .FRACTIONAL_NUMBER || -
             .EXPONENTIAL_NUMBER   -
           )
```

The `"<"` operator has been overloaded so that you can use it both with a "is" and a "in" semantics. For example, `token < .INTEGER_NUMBER` will mean that the class of `token` is `.INTEGER_NUMBER`, while `token < .NUMBER` will have the same meaning as

```rexx
  token < .INTEGER_NUMBER     | -
  token < .FRACTIONAL_NUMBER  | -
  token < .EXPONENTIAL_NUMBER
```

Token class values are represented by a single byte, so that value sets are byte strings, and set membership can be implemented using the `set~contains(class)` construct, which is very efficient.


## Normal, instance and class variables

Variables are classified as *"normal"* variables (i.e., local variables), *instance* variables (i.e., variables appearing in an `EXPOSE` instruction of an instance method), and *class* variables (appearing in an `EXPOSE` instruction of an instance method). This applies to simple variables, to stems, and to compound variables; a suitable set is provided for every variable class.

```rexx
  .VARIABLE                = ( -
    .SIMPLE_VAR             || -
    .COMPOUND_VAR           || -
    .STEM_VAR                  -
  )

  .ANY_STEM_VAR           == ( -
    .STEM_VAR               || -
    .CLASS_STEM_VAR         || -
    .INSTANCE_STEM_VAR         -
  )

  .ANY_COMPOUND_VAR       == ( -
    .COMPOUND_VAR           || -
    .CLASS_COMPOUND_VAR     || -
    .INSTANCE_COMPOUND_VAR     -
  )
```

## Special tokens

Some tokens are *special*, in the sense that they have a rich substructure: [compound variables](CompoundVariables.md) have a dual nature, in that they behave as normal variables but, at the same time, they are composed of *parts*; and certain identifiers, like labels, class, routine or method names, are [strings or symbols taken a constants](TakenConstants.md). They are both described in separate chapters.
