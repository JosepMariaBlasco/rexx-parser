Elements
========

------

Usage
-----

<pre>
[rexx] elements [<em>options</em>] <em>file</em>
</pre>

Transform *file* into a list of elements, according to
*options*, and print the list.

Options
-------

----------------------------- ------------------------------
`--from [LINE]`               Show elements starting at line LINE
`--to   [LINE]`               Stop showing elements after line LINE
`--tutor`                     Enable TUTOR-flavored Unicode
`-u`, `--unicode`&nbsp;&nbsp; Enable TUTOR-flavored Unicode
----------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/elements.rex}
~~~