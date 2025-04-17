Early checks
============

--------------------------------------

The [Rexx Parser](..) is able to detect at parse time
certain errors that other processors are only able
to detect at execution time. Since the detection
is done at parse time, the parser is able to reach dead
code, like branches that will never be taken,
or code after a `EXIT` or `RETURN` instructions,
and also procedures and `::ROUTINES` that will
never be called.

Error detection mimicks the behaviour of the ooRexx interpreter,
enhanced with TUTOR BIFs when so requested.

~~~rexx
  If .False Then Say Length(a,b) -- Dead branch, too many arguments
  Exit
                                 -- Unreachable code
  Guard On                       -- GUARD is only valid inside a method

::Method NeverCalled             -- Method never calles
  Signal NonExistent             -- This label does not exist
~~~

Early checking is controlled by the `earlycheck`
entry of the options passed to the [Rexx.Parser](..) class.
The value associated with `earlycheck` has to be
an array of uppercase strings chosen between
`"BIFS"`, `"GUARD"` and `"SIGNAL"`. The effect of
specifiying these options is described below.

## BIFS

When the `earlychecks` array has an item equal to
`"BIFS"`, built-in function calls, procedural calls to
built-in functions, and `CALL ON` instructions whose
trapname is a built-in function are checked against
the built-in function definition. Namely,

If the number of arguments passed to the function is
_greater_ than the maximum arguments allowed, a `SYNTAX`
error is raised. In most cases, the error raised
is 40.4, `"Too many arguments in invocation of &1; maximum expected is &2"`,
but in some few cases 88.922 is raised instead
(`"Too many arguments in invocation; &1 expected"`).[^1885]

```rexx
  Say ChangeStr(a,b,c,d,e)    -- Too many arguments in invocation of CHANGESTR; maximum expected is 3
```

If the number of arguments passed to the function
is _smaller_ than the minimum number of required arguments,
a `SYNTAX` error is raised. In most cases, the error raised
is 40.3, `"Not enough arguments in invocation of &1; minimum expected is &2"`,
although in some special cases, described in the footnote, 88.901 is raised instead
(`"Missing argument; argument &1 is required"`).

```rexx
  Say Left("String")          -- Not enough arguments in invocation of LEFT; minumum expected is 2
```

If there are enough arguments but some of the required arguments
are missing, a `SYNTAX` error is raised. In most cases, the error
raised is 40.5, `"Missing argument in invocation of &1; argument &2 is required"`,
although in some special cases, described in the footnote, 88.901 is raised instead.

```rexx
  x = ChangsStr(,'b','c')     -- Missing argument in invocation of CHANGESTR; argument 1 is required
```

When the BIF has a one-letter argument (that is, an argument of which only the first letter
is examined) and the corresponding parmeter is a string literal, this string literal
is checked. BIFs checked are `ARG`,  `CONDITION`, `DATATYPE`, `DATE`, `FILESPEC`, `LINES`, `RXQUEUE`, `STREAM`,
`STRIP`, `TIME`, `TRACE` and `VERIFY`. The message for the `TRACE` BIF is special. Some of the
other BIFs raise a 40.904 `SYNTAX` error, `&1 argument &2 must be one of &3; found "&4"`,
while some others raise a 93.915, `Method option must be one of "&1"; found "&2"`,
which constitutes an interpreter bug.[^93.915]

[^93.915]: <small>See <https://sourceforge.net/p/oorexx/bugs/2007/>.</small>

~~~rexx
  Var = "*"
  Call Trace Var              -- "Var" is a variable; not checked
  Call Trace "*"              -- TRACE request letter must be one of "ACEFILNOR"; found "*"
~~~

## GUARD

`GUARD` instructions are only allowed in the body of a method. The ooRexx interpreter
raises a SYNTAX condition (code 99.911: `"GUARD can only be issued in an object method invocation"`)
when it attempts to _execute_ a `GUARD` instruction in a code body which is not
a method body. When the `earlychecks` array contains an item whose
value is `"GUARD"`, the Rexx Parser will exit with a 99.911 error code
whenever a `GUARD` instruction is found in a non-method code body.

[^1885]: <small>This is due to an anomaly present in the ooRexx
interpreter, by which BEEP, DIRECTORY and FILESPEC are
handled as external functions, even when they are defined
to be BIFs; additionally, their error handling is
different from the other BIFs. See <https://sourceforge.net/p/oorexx/bugs/1885/></small>.

```rexx
::Routine R
  Say "Exiting..."
  Exit

  Guard On                    -- GUARD can only be issued in an object method invocation
```

## Signal

When a `SIGNAL` instruction targets a _labelname_ which is not dynamically
evaluated (i.e., when the label is a string or a symbol taken as a constant),
it is easy to check whether a branchable label exists with the corresponding
name. If the such a label does not exist, a 16.1 `SYNTAX` error is raised
(`'Label "&1" not found.'`).

```rexx
  Signal NoNo                 -- Label "NONO" not found
```