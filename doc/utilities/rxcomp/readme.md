RxComp
======

----------------

RxComp ("ReXx COMPare") compares two files to determine if
they contain the same program, irrespective of casing, continuations,
line numbers, comments, etc. For example,

```rexx
If a = b Then Say "Hello"
```

and

```rexx
if - /* A continuation and
a multiline comment */
A=B
THEN
SAY,    -- Another continuation
"Hello"
```

will compare equal.

RxComp returns 0 when two files compare equal, and 1 when help
is displayed or files do not compare equal. Programs containing
errors cannot be compared, as errors terminate the parsing process.

Usage
-----

<pre>
[rexx] rxcomp [<em>options</em>] <em>file1</em> <em>file2</em>
</pre>

Options
-------

---------------------------------- ------------------------------
`-it`, `--itrace`                  Print internal traceback on error
`-e`, `--experimental`             Enable Experimental features (also `-exp`)
`-xtr`, `--executor`&nbsp;&nbsp;   Enable Executor support
`-h`, `--help`                     Display this information
`-u`, `--unicode`                  Enable TUTOR support
`--tutor`                          Enable TUTOR support
---------------------------------- ------------------------------

Program source
--------------

~~~rexx {source=../../../bin/rxcomp.rex}
~~~