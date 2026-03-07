Identtest
=========

----------------

Identtest ("IDENTity TEST") is a self-consistency utility.

When run, it will recursively examine the current directory
and all its subdirectories, looking for `.rex`, `.cls`,
`.testGroup`, `.jrexx`, `.oodTestGroup`, `.rxj`, `.rxo`,
`.testUnit` and `.rxu` files,
and it will run [the `elident` test](../elident/)
and [the `trident` test](../trident/) against each of these
files, stopping when all files are processed, or when
a file doesn't pass some test, whichever happens first.

Files with a `.rxu` extension are tested with TUTOR-flavored Unicode
enabled.

A number of known exceptions are hardcoded in the program and
automatically skipped.

Options allow to activate support for [Executor](../../executor/),
and to selectively deactivate either of the two identity tests.

Usage
-----

<pre>
[rexx] identtest [<em>options</em>] [start]
</pre>

When called without arguments, display help information and exit.

The optional `start` argument can be specified as the last argument
to explicitly indicate that the tests should begin. It is not
required: the tests will run as long as at least one argument is present.

Options
-------

---------------------------------------- ----------------------------
`-h`, `--help`                           Display help and exit
`-it`, `--itrace`                        Print internal traceback on error
`-ne`, `--noelements`                    Don't run the elident test
`-nt`, `--notree`                        Don't run the trident test
`-xtr`, `--executor`                     Enable Executor support
---------------------------------------- --------------------------------

Examples
--------

### Perform a self-test of the Rexx Parser files

First `cd` to the root
directory of the Parser, and then simply run

```
[rexx] identtest start
```

### Perform a self-test of Executor features

First `cd` to the root of the Executor files, and then run

```
[rexx] identtest -xtr
```

### Perform a self-test of the ooRexx test/trunk files

First `cd` to the ooRexx `test/trunk` directory, and then run

```
[rexx] identtest start
```

--------------

Program source
--------------

~~~rexx {source=../../../bin/identtest.rex}
~~~