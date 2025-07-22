Detailed string highlighting
=============================

-------------------------------------------------------

Strings are highlighted as composed of an opening
delimiter (a single or a double quote), a string
contents (which may be empty), a closing delimiter,
and an optional suffix.

~~~
string := delimiter contents delimiter [suffix]
~~~

The delimiters and the suffix are highlighted
according to the `.EL.STRING_OPENING_DELIMITER`,
`EL.STRING_CLOSING_DELIMITER` and
`EL.STRING_SUFFIX` element categories,
and the string contents according to the
corresponding string element category.

```rexx {unicode}
Say "This is a string with a suffix"T
```

Please note that the Rexx Parser returns
a single element to represent the whole string;
the Highlighter uses the categories above
to introduce more detail and to improve the
highlighting results.

When the string is neither a binary string,
nor hexadecimal string or a Unicode U-string,
and the contents of the string represent a
number (that is, if the `DATATYPE` built-in
function returns `"NUM"`), then the contained
number is also highlighted, according to the
rules defined in the documentation about
[detailed highlighting for numbers](../numbers/).

```rexx {unicode}
Say " + 1234.5678e-1027  "    -- Highlighting of a number inside a string
```

[This page](../../examples/) contains more examples
of number and string highlighting.

