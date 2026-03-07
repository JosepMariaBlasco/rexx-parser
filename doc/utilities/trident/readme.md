Trident
=======

----------------

Trident ("TRee IDENTity") is a self-consistency utility.
It checks that a program is identical to its own parse tree
by running the identity compiler and comparing the output
line by line against the original source.

If the check succeeds, Trident exits silently with exit code 0.
If a difference is found, Trident displays the mismatching
source and parsed lines and exits with exit code 1.
If the number of lines differs, Trident reports the
line counts and exits with exit code 1.

Usage
-----

<pre>
[rexx] trident [<em>options</em>] <em>file</em>
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

~~~rexx {source=../../../bin/trident.rex}
~~~