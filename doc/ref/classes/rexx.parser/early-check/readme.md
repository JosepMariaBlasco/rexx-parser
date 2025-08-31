Early checks
============

--------------------------------------

The [Rexx Parser](..) is able to detect at parse time
certain errors that other processors are only able
to detect at execution time. Since the detection
is done at parse time, the parser is able to reach dead
code, like branches that cannot be taken,
or code after a `EXIT` or `RETURN` instructions,
and also procedures and `::ROUTINES` that will
never be called.

We have attempted to mimick the behaviour
of the ooRexx interpreter, even when this behaviour is obviously erroneous;
please refer to [the Bugs section](#bugs) for details.

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
`"BIFS"`, `"GUARD"`, `"ITERATE"`, `"LEAVE"` and `"SIGNAL"`. The effect of
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
(`"Too many arguments in invocation; &1 expected"`:
this is due to an [anomaly](#bugs) in the ooRexx
interpreter, by which BEEP, DIRECTORY and FILESPEC are
handled as external functions, even when they are defined
to be BIFs; their error handling is also
different from the other BIFs).


```rexx
  Say ChangeStr(a,b,c,d,e)    -- Too many arguments in invocation of CHANGESTR; maximum expected is 3
```

If the number of arguments passed to the function
is _smaller_ than the minimum number of required arguments,
a `SYNTAX` error is raised. In most cases, the error raised
is 40.3, `"Not enough arguments in invocation of &1; minimum expected is &2"`,
although for some few BIFs, 88.901 is raised instead
(`"Missing argument; argument &1 is required"`).

```rexx
  Say Left("String")          -- Not enough arguments in invocation of LEFT; minumum expected is 2
```

If there are enough arguments but some of the required arguments
are missing, a `SYNTAX` error is raised. In most cases, the error
raised is 40.5, `"Missing argument in invocation of &1; argument &2 is required"`,
although for some few BIFs, 88.901 is raised instead.

```rexx
  x = ChangsStr(,'b','c')     -- Missing argument in invocation of CHANGESTR; argument 1 is required
```

When the BIF has a one-letter argument (that is, an argument of which only the first letter
is examined) and the corresponding parmeter is a string literal, this string literal
is checked. BIFs checked this way are `ARG`, `CONDITION`, `DATATYPE`, `DATE`, `FILESPEC`, `LINES`, `RXQUEUE`, `STREAM`,
`STRIP`, `TIME`, `TRACE` and `VERIFY`. The message for the `TRACE` BIF is special. Some of the
other BIFs raise a 40.904 `SYNTAX` error, `&1 argument &2 must be one of &3; found "&4"`,
while still others raise a 93.915, `Method option must be one of "&1"; found "&2"`,
which is [a bug](#bugs). `DATE` and `TIME` do not check that literal dates
and times are in the required format.

~~~rexx
  Var = "*"
  Call Trace Var              -- "Var" is a variable; not checked
  Call Trace "*"              -- TRACE request letter must be one of "ACEFILNOR"; found "*"
~~~

When the BIF expects a whole number, literal strings, numbers, and prefix expressions
consisting of any number of "-" and "+" signs followed by a number are checked. Checking is done
using the `DATATYPE(x,"Internal")` BIF.

~~~rexx
  Say WordPos(a,string,0)     -- Invalid position argument specified; found "0".
~~~

When the BIF expects a number (i.e., it may be whole or not),
literal strings, numbers, and prefix expressions
consisting of any number of "-" and "+" signs followed by a number are checked. Checking is done
using the `DATATYPE(x,"Number")` BIF. This applies to the following BIFs: `ABS`, `FORMAT`,
`MAX`, `MIN`, `SIGN`, `TRUNC`.

~~~rexx
  Call Abs -+- "- 12"         -- result = 12
~~~

In the case of `XRANGE`, literal arguments are checked to ensure that they are either
a single character in length, or one of the allowed POSIX classes.

~~~rexx
  Call XRange "42"            -- XRANGE argument 1 must be a character class name or a single character; found "42"
~~~

In the case of `D2C` and `D2X`, the first argument, which is a whole number,
may not have more digits than "the current setting of NUMERIC DIGITS", which is
an execution-time value. In this case, the parser only checks that the supplied
constant value is a number (`DATATYPE(x,"Number")`) containing no blanks, no dots,
and no "E" exponential mark, and, if the second argument is omitted, that
the supplied constant is not negative.

~~~rexx
  Call D2C -1                 -- Length must be specified to convert a negative value
~~~

Pad characters are checked that they have exactly one character in length,
and separators to see that they are the null string or a single character.
Some combinations of separators are not valid in the `TIME` BIF,
depending on the options chosen; this is not checked.

```rexx
  Call Left 'a',12,'ww'       -- LEFT argument 3 must be a single character; found "ww".
  Call Date ,'20/04/25', 'E', '**' --  DATE argument 4 must be a single non-alphanumeric
                              -- character or the null string; found "**"
```

`STREAM` and `RXQUEUE` are not early-checked at this time.

## GUARD

`GUARD` instructions are only allowed in the body of a method. The ooRexx interpreter
raises a SYNTAX condition (code 99.911: `"GUARD can only be issued in an object method invocation"`)
when it attempts to _execute_ a `GUARD` instruction in a code body which is not
a method body. When the `earlychecks` array contains an item whose
value is `"GUARD"`, the Rexx Parser will exit with a 99.911 error code
whenever a `GUARD` instruction is found in a non-method code body.

```rexx
::Routine R
  Say "Exiting..."
  Exit

  Guard On                    -- GUARD can only be issued in an object method invocation
```

## ITERATE

When the `earlychecks` array has an item equal to
`"ITERATE"`, `ITERATE` instructions are checked for validity
at parse time. Namely,

+ If a `ITERATE` instruction without a name appears out of a
  repetitive loop, a 28.2 syntax error is raised.
+ If a `ITERATE` instruction has a name which does not match the name
  of a containing repetitive loop or `SELECT` instruction,
  a 28.4 syntax error is raised.

## LEAVE

When the `earlychecks` array has an item equal to
`"LEAVE"`, `LEAVE` instructions are checked for validity
at parse time. Namely,

+ If a `LEAVE` instruction without a name appears out of a
  repetitive loop, a 28.1 syntax error is raised.
+ If a `LEAVE` instruction has a name which does not match the name
  of a containing repetitive loop or `SELECT` instruction,
  a 28.3 syntax error is raised.


## SIGNAL

When a `SIGNAL` instruction targets a _labelname_ which is not dynamically
evaluated (i.e., when the label is a string or a symbol taken as a constant),
it is easy to check whether a branchable label exists with the corresponding
name. If the such a label does not exist, a 16.1 `SYNTAX` error is raised
(`'Label "&1" not found.'`).

```rexx
  Signal NoNo                 -- Label "NONO" not found
```
