Highlighting examples
====================

The following code highlights strings
by assigning a different background color
depending on the Unicode (TUTOR) string type.

Numbers are also highlighted, and they
inherit the background corresponding
to the string type.

Several strings used as names are also
highlighted; the quote delimiters and the
string suffix are highlighted separately.

Please refer to the "test1" CSS file,
[rexx-test1.css](../../../css/rexx-test1.css),
for details.

~~~rexx {style=test1 unicode}
Say "Hello"  || 12.34e-56 || " + 12.34e-56 "
Say "Hello"Y || 12.34e-56 || " + 12.34e-56 "Y
Say "Hello"P || 12.34e-56 || " + 12.34e-56 "P
Say "Hello"G || 12.34e-56 || " + 12.34e-56 "G
Say "Hello"T || 12.34e-56 || " + 12.34e-56 "T

Say "0110 1000"B "FA E0"X "4565"U

"Length": Say "Length"(2) + "LENGTH"(2) + "LENGTH"G(2) + 2~"length"
~~~