Elident
=======

----------------

Elident is a self-consistency utility.
It checks that a program is identical to the concatenation
of the values of all its parsed elements.

Usage
-----

<pre>
[rexx] elident [<em>options</em>] <em>file</em>
</pre>

Options
-------

---------------------------------- ------------------------------
`-xtr`, `--executor`&nbsp;&nbsp;   Enable Executor support
`-?`, `--help`                     Display this information
---------------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/elident.rex}
~~~