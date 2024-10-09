# Compound variables

*Compound variables* are special, in the sense that they are at the same time variables, and an indexed reference to a stem value. [The Rexx Parser](TheRexxParser.md) honors this duality by returning compound variables as single tokens that include a number of sub-parts. As a single token, a compound variable `T` will have a class such that 

```rexx
T < .ANY_COMPOUND_VAR 

-- Where

.ANY_COMPOUND_VAR == ( 
  .COMPOUND_VAR          || -
  .CLASS_COMPOUND_VAR    || -
  .INSTANCE_COMPOUND_VAR    -
)
```

An `.INSTANCE_COMPOUND_VAR` is a compound variable whose stem has been exposed using an `EXPOSE` instruction in an instance method, and similarly for  `.CLASS_COMPOUND_VAR` and class methods. A non-exposed compound variable is always a `.COMPOUND_VAR`.

## Compound variable parts

A compound variable token has a number of *parts*. These parts can be accessed by using the `parts` method, which returns an array of parts. The first element of the array is always the compound variable stem, and the rest of the array contain the different elements composing the tail, including the dots. For example, the `parts`method for the symbol `Stem.i..2.3a` will be the following:

| Index | Token   | Token class           |
| ----- | ------- | --------------------- |
| 1     | `Stem.` | `.STEM_VAR` (maybe)   |
| 2     | `i`     | `.SIMPLE_VAR` (maybe) |
| 3     | `.`     | `.TAIL_SEPARATOR`     |
| 4     | `.`     | `.TAIL_SEPARATOR`     |
| 5     | `2`     | `.INTEGER_NUMBER`     |
| 6     | `.`     | `.TAIL_SEPARATOR`     |
| 7     | `3a`    | `.LITERAL_SYMBOL`     |

The stem part of the compound variable will have a different class, depending on whether it is a normal stem variable, an instance stem variable, or a class stem variable; the whole compound variable will have a the same qualification (that is, normal, instance or class) as its stem. Individual variables may have a qualification which is different from the stem variable.




