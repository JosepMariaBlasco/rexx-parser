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

If *file* does not include an extension, `.rex` is automatically appended.

When called without arguments, display help information and exit.

Options
-------

---------------------------------- ------------------------------
`-h`, `--help`                     Display help and exit
`-e`, `--experimental`&nbsp;&nbsp; Enable Experimental features (also `-exp`, `--exp`)
`-xtr`, `--executor`               Enable Executor support
`--from [LINE]`                    Show elements starting at line LINE
`-it`, `--itrace`                  Print internal traceback on error
`--no-show-spaces`                 Leave spaces untouched
`--show-spaces`                    Show spaces as the "␣" character (default)
`--to   [LINE]`                    Stop showing elements after line LINE
`-u`, `--unicode`, `--tutor`       Enable TUTOR-flavored Unicode
---------------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/elements.rex}
~~~