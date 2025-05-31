Detailed highlighting for numbers
=================================

-------------------------------------------------------

Numbers are highlighted as composed of a sequence
of optional components:

+ An optional number sign (only for strings which are numbers).
+ An integer part
+ A decimal point
+ A fractional part
+ An exponent mark ("E" or "e")
+ An exponent sign
+ An exponent

Both the integer part and the fractional part are optional,
but they cannot both be absent; the last three components
form the exponent, which is itself optional; the exponent
sign is also optional.

~~~rexx
Say 12 + 12.34 - 12e34 * 12e-34 / 12.34e-56
~~~

The Parser returns the numbers as single elements,
with categories of `.EL.DECIMAL_NUMBER`,  `.EL.INTEGER_NUMBER` and
`.EL.EXPONENTIAL_NUMBER`, and the Highlighter adds details
to these elements, by subdividing the elements into its constituent
parts and assigning or more of the new categories `.EL.NUMBER_SIGN`,
`.EL.INTEGER_PART`, `.EL.DECIMAL_POINT`, `.EL.FRACTIONAL_PART`,
`.EL.EXPONENT_MARK`, `.EL.EXPONENT_SIGN` and `.EL.EXPONENT`,
which can be styled individually.

Strings containing numbers (i.e., strings such that `DATATYPE`
returns `"NUM"`) are highlighted as numbers. In this case,
the number may have an optional sign, which does not need to
be adjacent to the number, and the number may be surrounded
by optional whitespace.

```rexx
Say - " + 12.34e-56   "   -- A string containing a number
```

[This page](../../examples/) contains more examples
of number and string highlighting.

