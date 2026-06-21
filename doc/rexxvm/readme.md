Rexx/VM support
================

--------------------------

The language Mike Cowlishaw designed and first
implemented in VM/CMS is what we now call *Classic Rexx*.
The Rexx Parser implements optional support for parsing programs
as the Rexx/VM interpreter would parse them.

In the following example, which uses Rexx/VM support, you can see that
`FIND` and `LENGTH` are highlighted as built-in functions (BIFs),
while `CHANGESTR` is considered to be an external function,
since it is an ANSI addition.

```rexx {rexxvm}
p = Find("a b c", "b")                  /* Rexx/VM-specific BIF               */
s = ChangeStr("a", "banana", "o")       /* ANSI addition: external here       */
n = Length("banana")                    /* Common to Rexx/VM and ooRexx       */
```

Activating Rexx/VM support
--------------------------

### Activating Rexx/VM support in a Parser instance

When creating a [Rexx.Parser](../ref/classes/rexx.parser) instance,
you can use the `CMS` or `REXXVM` options, set to any value (although `1`
is recommended and may be mandatory in future releases) to activate
Rexx/VM support.

### Activating Rexx/VM support when using the Rexx Parser utilities

When using any of the
[`elements`](../utilities/elements/),
[`elident`](../utilities/elident/),
[`identtest`](../utilities/identtest/),
[`highlight`](../utilities/highlight/) and
[`trident`](../utilities/trident/)
utilities, you
can activate Rexx/VM support by using the `-cms`, `--cms`, `-rexxvm` or `--rexxvm` options.

[The `rxcheck` utility](../utilities/rxcheck/) also includes support for Rexx/VM. You
can activate it by using the `+cms`, `-cms`, `+rexxvm` or `-rexxvm` options.

### Activating Rexx/VM support in Rexx Fenced code blocks

Rexx fenced code blocks can use Rexx/VM syntax by using the `cms` (or
`rexxvm`) attribute on the first fence of the code block, for example,
<code>```rexx {cms}</code>.

Please note that the same Markdown or HTML file can contain
both Rexx/VM fenced code blocks and other Rexx fenced code blocks
using different Rexx variants. For example, you can have
Rexx/VM, Executor, Experimental and standard ooRexx code blocks
in the same file.

What does "parsing like Rexx/VM" mean
-------------------------------------

The Rexx Parser is a *parser*: it attempts to reproduce the **parse-time** behavior
of the Rexx/VM interpreter, not its run-time behavior.

Please note that not all ooRexx constructs will produce errors when parser
with Rexx/VM support enabled. For example, a `Do var Over collection`
instruction will be properly parsed -- and fail unless `var Over collection`,
a _concatenation_, evaluates at runtime as a valid whole number.

Other constructs, like `CALL (expression)`, are invalid in Rexx/VM
and will produce the corresponding syntax error (in this case,
an error 19, "String or symbol expected").

List of Rexx/VM parsing differences
===================================

Lexical differences
--------------------

### Extra letters in symbols

Rexx/VM support enables the `#`, `@`, `$` and `¢` characters to act as letters when forming symbols.

```rexx {cms}
#a     = 1
@x     = 2
$total = 3
```

Both Latin-1 `¢` (`"A2"X`) and UTF-8 `¢` (`"C2A2"X`) are accepted.

### No message-send operator, no brackets

Rexx/VM support does not recognize the `~`, `[` or `]` characters.

### Negation operators

Recognized negation characters are `\` and `¬`.

```rexx {cms}
Say 1 \= 1     /* 0 */
Say 1 ¬= 1     /* 0 */
```

All of IBM-850 '¬' (`"AA"X`), Latin-1 `¬` (`"AC"X`) and UTF-8 `¬` (`"C2AC"X`) are accepted.

### Multi-line strings

Rexx/VM allows multi-line strings. The contents of all lines
are concatenated without any intervening separator.

```rexx {cms}
Say "A multi-
line string"        -- Prints "A multi-line string"
```

### No line comments

Rexx/VM support recognizes only `/* ... */` block comments.
The `--` line comment is an ooRexx addition.

### No "-" continuation

Rexx/VM support uses the comma as its only continuation character.

```rexx {cms}
x = 1 ,
    + 2          /*  valid: comma continuation              */
```

### No "::" directives

Rexx/VM has no directives. A `::` sequence is not recognized.

### No extended assignments

Rexx/VM recognizes only `=` as an assignment.
Compound assignment
operators (`+=`, `-=`, `*=`, ...) are ooRexx additions.

### Symbol and string length limit

Rexx/VM symbols and strings cannot exceed 250 characters.

Instruction differences
------------------------

### TRACE ! and TRACE Scan

Rexx/VM supports `TRACE Scan` and `"!"` as a prefix option.

```rexx {cms}
Trace !Scan
```

### ooRexx-only instructions

`EXPOSE`, `FORWARD`, `GUARD`, `LOOP`, `RAISE`, `REPLY` and `USE` are
ooRexx-only instructions.

### UPPER instruction

Rexx/VM supports the `UPPER` instruction, which translates the values of
the named variables to uppercase.

```rexx {cms}
Upper a b c
```

### ADDRESS: "WITH" is not an expression terminator

The `WITH` redirection on `ADDRESS` is an ooRexx extension. Under Rexx/VM,
`WITH` is not an expression terminator.

### DO: no LABEL, COUNTER, OVER, WITH

CMS supports only:

    DO [name=expri [TO][BY][FOR] | FOREVER | exprr] [WHILE|UNTIL]

The ooRexx extensions `LABEL`, `COUNTER`, `OVER`, and `WITH ITEM/INDEX
OVER` are not recognized. Under Rexx/VM the offending token is read as part
of the repetitor expression, so the clause parses; a resulting
non-integer repetition count is a run-time Error&nbsp;26, not a parse
error.

```rexx {cms}
Do x Over coll    /* parses under CMS: "x Over coll" is an expression */
  Nop             /* (run-time Error 26 if the count is not whole)    */
End
```

### SELECT: no CASE, no LABEL

Bare `SELECT` is the only allowed Rexx/VM form. `SELECT CASE` and `SELECT LABEL` are
ooRexx extensions.

### PARSE: no LOWER, no CASELESS

Rexx/VM `PARSE` accepts `UPPER` but not `LOWER` or `CASELESS`.

### SIGNAL ON / CALL ON: only the classic conditions

Rexx/VM supports only the classic conditions, plus `NOTREADY`:
`ERROR`, `FAILURE`, `HALT`, `NOTREADY`, `NOVALUE`, `SYNTAX`.
The conditions `LOSTDIGITS`, `NOMETHOD`, `NOSTRING`, `USER` and `ANY` are
ooRexx extensions.

### CALL: no computed-name form

`CALL (expr)`, where the routine name is a computed expression, is an
ooRexx extension. Rexx/VM expects a symbol or a literal string after `CALL`.

### CALL: no namespace qualifier

The namespace-qualified call `CALL namespace:name` is an ooRexx
extension. Under Rexx/VM the `:` qualifier is not recognized; the dangling
`:` is an invalid expression.

Expression differences
-----------------------

### No namespace qualifier in expressions

More generally, the `namespace:name` qualifier is an ooRexx extension
anywhere it appears, not only in `CALL`. It also covers
namespace-qualified function calls and class references. Under Rexx/VM, none
of these is recognized; the `:` is an invalid expression.

### No array terms

Rexx/VM does not implement array terms.

Built-in function differences
-----------------------------

The set of names the Rexx Parser recognizes as built-in functions differs
between ooRexx and Rexx/VM.

### Built-in functions available only under Rexx/VM

`EXTERNALS`, `FIND`, `INDEX`, `JUSTIFY` and `LINESIZE` are Rexx/VM built-in
functions with no ooRexx counterpart.

### Built-in functions available only under ooRexx

`BEEP`, `CHANGESTR`, `COUNTSTR`, `DIRECTORY`, `ENDLOCAL`, `FILESPEC`, `GC`,
`LOWER`, `QUALIFY`, `RXFUNCADD`, `RXFUNCDROP`, `RXFUNCQUERY`, `RXQUEUE`,
`SETLOCAL`, `UPPER` and `VAR` are ooRexx built-in functions with no Rexx/VM
counterpart.

### Functions with a different signature under Rexx/VM

Several functions exist in both dialects but accept different arguments. Under
Rexx/VM support the parser enforces the Rexx/VM signature:

- `DELSTR` — the start position is required under Rexx/VM, whereas in ooRexx
  it can be omitted.
- `LASTPOS`, `POS`, `VERIFY` — the trailing *length* argument that ooRexx
  accepts is not part of the Rexx/VM signature.
- `LINES` — the ooRexx `C`/`N` option argument is not accepted under Rexx/VM.
- `TRANSLATE` — the ooRexx *start* and *length* arguments are not accepted.
- `DATE` and `TIME` — both the set of valid option letters and the number of
  accepted arguments differ. For example, the ooRexx `TIME` option `F` is not
  a valid Rexx/VM option letter.