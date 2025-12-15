Identtest
=======

----------------

Identtest ("IDENTity TEST") is a self-consistency utility.

When run, it will recursively examine the current directory
and all its subdirectories, looking for `.rex` and `.cls` files,
and it will run [the `elident` test](../elident/)
and [the `trident` test](../trident/) against each of these
files, stopping when all files are processed, or When
a file doesn't pass some test, whichever happens first.

Options allow to include `.testGroup` files in the search,
to activate support for [Executor](../../Executor), and
to selectively deactivate searching for `.rex` or `.cls` files,
or to choose only one of the identity tests instead of both.

Usage
-----

<pre>
[rexx] identtest [OPTIONS]
</pre>

Options
-------

---------------------------------------- ----------------------------
`--help`, `-h`, `-?`                     Display this help
`--executor`, `-xtr`                     Support Executor syntax
`--testgroup`, `-tg`                     Analyze `.testgroup` files
`--noelements`, `-ne`                    Don't run the elident test
`--notree`, `-nt`                        Don't run the trident test
`--norexx`, `--norex`, `-nr`&nbsp;&nbsp; Don't analyze `.rex` files
`--nocls`, `-nc`                         Don't analyze `.cls` files
---------------------------------------- --------------------------------

Examples
--------

### Perform a self-test of the Rexx Parser files

First `cd` to the root
directory of the Parser, and then simply run

```
[rexx] identtest
```

### Perform a self-test of Executor features

First `cd` to the root of the Executor files, and then run

```
[rexx] identtest -xtr
```

### Perform a self-test of the ooress test/trunk files

First `cd` to the ooRexx `test/trunk` directory, and then run

```
[rexx] identtest -tg
```

--------------

Program source
--------------

~~~rexx {source=../../../bin/identtest.rex}
~~~