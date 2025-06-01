Highlighting examples
====================

The following code highlights [strings](../features/strings/)
by assigning a different background color
depending on the Unicode (TUTOR) string type.

[Numbers](../features/numbers/) are also highlighted, and they
inherit the background corresponding
to the string type.

Several [strings used as numbers](../features/numbers/) are also
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

The same code block, with a patch that sets `All String_delimiters /green`:

~~~rexx {style=test1 unicode patch="All String_delimiters /green"}
Say "Hello"  || 12.34e-56 || " + 12.34e-56 "
Say "Hello"Y || 12.34e-56 || " + 12.34e-56 "Y
Say "Hello"P || 12.34e-56 || " + 12.34e-56 "P
Say "Hello"G || 12.34e-56 || " + 12.34e-56 "G
Say "Hello"T || 12.34e-56 || " + 12.34e-56 "T

Say "0110 1000"B "FA E0"X "4565"U

"Length": Say "Length"(2) + "LENGTH"(2) + "LENGTH"G(2) + 2~"length"
~~~

Ditto, with `All String_components /teal`. Please note that
in the case of taken constant strings, only the quotes and the
optional suffix obey the patch.

~~~rexx {style=test1 unicode patch="All String_components /teal"}
Say "Hello"  || 12.34e-56 || " + 12.34e-56 "
Say "Hello"Y || 12.34e-56 || " + 12.34e-56 "Y
Say "Hello"P || 12.34e-56 || " + 12.34e-56 "P
Say "Hello"G || 12.34e-56 || " + 12.34e-56 "G
Say "Hello"T || 12.34e-56 || " + 12.34e-56 "T

Say "0110 1000"B "FA E0"X "4565"U

"Length": Say "Length"(2) + "LENGTH"(2) + "LENGTH"G(2) + 2~"length"
~~~
