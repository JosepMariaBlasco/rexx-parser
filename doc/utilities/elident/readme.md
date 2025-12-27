Elident
=======

----------------

Elident ("ELement IDENTity") is a self-consistency utility.
It checks that a program is identical to the concatenation
of the values of all its parsed elements.

Usage
-----

<pre>
[rexx] elident [<em>options</em>] <em>file</em>
</pre>

Options
-------

---------------------------------------- ------------------------------
`-it`, `--itrace`                        Print internal traceback on error
`-u`, `--tutor`, `--unicode`&nbsp;&nbsp; Enable TUTOR-flavored Unicode
`-xtr`, `--executor`                     Enable Executor support
`-?`, `--help`                           Display this information
---------------------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/elident.rex}
~~~