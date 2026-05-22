Rexx/VM support
================

--------------------------

Rexx was born on VM/CMS. The language Mike Cowlishaw designed and first
implemented there is what we now call *Classic Rexx*, and the Rexx/VM
interpreter remains its canonical reference. The Rexx Parser implements
full, optional support for parsing programs as the CMS interpreter,
Rexx/VM, would parse them.

This is the mirror image of the [Executor](../executor/) and
[Experimental](../experimental/) variants. Those *add* features to
ooRexx. Rexx/VM *removes* them: it recognizes only what Classic Rexx
recognized, and rejects the extensions that ooRexx introduced later.
Where ooRexx is a superset of Classic Rexx, Rexx/VM support models the
original subset.

Activating Rexx/VM support
--------------------------

+ When creating a [Rexx.Parser](../ref/classes/rexx.parser) instance,
  you can use the `CMS` or `REXXVM` options, set to any value (although `1`
  is recommended and may be mandatory in future releases) to activate
  Rexx/VM support.

+ [The `elements` utility](../utilities/elements/) includes support for Rexx/VM. You
  can activate it by using the `-cms`, `--cms`, `-rexxvm` or `--rexxvm` options.

+ [The `elident` utility](../utilities/elident/) includes support for Rexx/VM. You
  can activate it by using the `-cms`, `--cms`, `-rexxvm` or `--rexxvm` options.

+ [The `identtest` utility](../utilities/identtest/) includes support for Rexx/VM. You
  can activate it by using the `-cms`, `--cms`, `-rexxvm` or `--rexxvm` options.

+ [The `highlight` utility](../utilities/highlight/) includes support for Rexx/VM. You
  can activate it by using the `-cms`, `--cms`, `-rexxvm` or `--rexxvm` options.

+ [The `trident` utility](../utilities/trident/) includes support for Rexx/VM. You
  can activate it by using the `-cms`, `--cms`, `-rexxvm` or `--rexxvm` options.

+ [The `rxcheck` utility](../utilities/rxcheck/) includes support for Rexx/VM. You
  can activate it by using the `+cms`, `-cms`, `+rexxvm` or `-rexxvm` options.

+ Rexx fenced code blocks can use Rexx/VM syntax by using the `cms` (or
  `rexxvm`) attribute on the first fence of the code block, for example,
  <code>```rexx {cms}</code>.

A note on what "parsing like Rexx/VM" means
-------------------------------------------

The Rexx Parser is a *parser*: it reproduces the **parse-time** behavior
of the Rexx/VM interpreter, not its run-time behavior. This distinction is
the single most important design criterion behind Rexx/VM support, and it is
what makes the difference between a faithful screening and an overzealous
one.

Classic Rexx has no reserved keywords. Many constructs that *look* like
ooRexx-only syntax are, under Rexx/VM, simply valid expressions that the
interpreter parses without complaint and only rejects (if at all) when it
tries to run them. For those, the faithful behavior is **not** to raise a
parse error: we let the construct parse, exactly as Rexx/VM does, even though
it would fail at execution time.

A useful example is `DO x OVER collection`. Under ooRexx this is the
collection-iteration form. Under Rexx/VM there is no `OVER` keyword, so
`x OVER collection` is read as a repetitor expression; the clause parses,
and any non-integer repetition count becomes a run-time **Error&nbsp;26**,
never a parse error. We reproduce that: the clause parses under Rexx/VM.

Other constructs are genuine parse errors in Rexx/VM, because the offending
token cannot form a valid expression in the position where it appears.
`CALL (expr)` and the `:` namespace qualifier fall here. For those, we
attempt to raise the same error Rexx/VM raises, at parse time.

Lexical differences
--------------------

### Extra letters in symbols

Rexx/VM allows `#`, `@`, `$` and `¢` to act as letters when forming symbols.

```rexx {cms}
#a     = 1
@x     = 2
$total = 3
```

Both Latin-1 `¢` (`"A2"X`) and UTF-8 `¢` (`"C2A2"X`) are accepted.

### No message-send operator, no brackets

Rexx/VM does not recognize `~` (message send) nor `[` `]` (collection
indexing). These are ooRexx additions.

### Negation: only "\" and "¬"

Rexx/VM recognizes `\` and `¬` as negation characters. The `^` negator (a
TSO/E convenience) is **not** recognized under Rexx/VM.

```rexx {cms}
Say 1 \= 1     /* 0 */
Say 1 ¬= 1     /* 0 */
```

Both Latin-1 `¬` (`"AC"X`) and UTF-8 `¬` (`"C2AC"X`) are accepted.

### No line comments

Rexx/VM has only `/* ... */` block comments. The `--` line comment is an
ooRexx addition.

### No "-" continuation

Rexx/VM uses the comma as its only continuation character. A trailing `-` is
not a continuation; it is read as part of the expression, which then
dangles.

```rexx {cms}
x = 1 ,
    + 2          /*  valid: comma continuation              */
```

### No "::" directives

Rexx/VM has no directives. A `::` sequence is not recognized.

### No extended assignments

Rexx/VM recognizes only `=` as an assignment. The compound assignment
operators (`+=`, `-=`, `*=`, ...) are ooRexx additions.

### Symbol and string length limit

Rexx/VM symbols and strings cannot exceed 250 characters.

Instruction differences
------------------------

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