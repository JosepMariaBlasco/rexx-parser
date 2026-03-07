ERexx
=====

--------------

The [Experimental Rexx runner, `erexx.rex`](../../../bin/erexx.rex?view=highlight),
transforms programs written in Rexx enhanced with
some of the [Parser Experimental features](../../experimental/)
into a standard ooRexx program and then executes it.

Usage
-----

<pre>
[rexx] erexx [<em>options</em>] <em>file</em> [<em>arguments</em>]
</pre>

If *file* does not include an extension, `.erx` is tried
after the original name.

Any extra *arguments* after *file* are passed to the compiled
program.

When called without arguments, display help information and exit.

Options
-------

---------------------------------- ----------------------
`-h`, `--help`                     Display help and exit
`-it`, `--itrace`                  Print internal traceback on error
`-l`                               Print the translated program and exit
`-xtr`, `--executor`&nbsp;&nbsp;   Enable Executor support
---------------------------------- ----------------------

Program source
--------------

~~~rexx {source=../../../bin/erexx.rex}
~~~