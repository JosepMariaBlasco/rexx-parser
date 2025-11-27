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

---------------------------------- ------------------------------
`-e`, `--experimental`&nbsp;&nbsp; Enable Experimental features (also `-exp`)
`-xtr`, `--executor`               Enable Executor support
`--from [LINE]`                    Show elements starting at line LINE
`--help`                           Display this information
`--lua`                            Enable OPTIONS LUA (also `-lua`)
`--to   [LINE]`                    Stop showing elements after line LINE
`--tutor`                          Enable TUTOR-flavored Unicode
`-u`, `--unicode`                  Enable TUTOR-flavored Unicode
---------------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/elements.rex}
~~~