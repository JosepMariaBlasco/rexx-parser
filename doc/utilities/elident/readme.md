Elident
=======

----------------

Elident ("ELement IDENTity") is a self-consistency utility.
It checks that a program is identical to the concatenation
of the values of all its parsed elements.

Compound variables are checked part by part, and
standard comments, doc comments, and resource data are
handled specially.

If the check succeeds, Elident exits silently with exit code 0.
If a difference is found, Elident displays the mismatching
source and parsed lines and exits with exit code 1.

Usage
-----

<pre>
[rexx] elident [<em>options</em>] <em>file</em>
</pre>

When called without arguments, display help information and exit.

Options
-------

---------------------------------------- ------------------------------
`-h`, `--help`                           Display help and exit
`-e`, `--experimental`&nbsp;&nbsp;       Enable Experimental features (also `-exp`)
`-it`, `--itrace`                        Print internal traceback on error
`-u`, `--tutor`, `--unicode`&nbsp;&nbsp; Enable TUTOR-flavored Unicode
`-xtr`, `--executor`                     Enable Executor support
---------------------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/elident.rex}
~~~