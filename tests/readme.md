Consistency tests
=================

-----------------------------------

Error handling: [`errors.rex`](errors.rex)
------------------------------------------

[This program](errors.rex) resides in the [`tests`](.) directory.
It depends on two files located in the [`bin/resources`](/rexx-parser/bin/resources) directory:
`rexxmsg.xml`, which is part of the ooRexx source tree
(you can find it at `main/trunk/interpreter/messages`), and `revision`,
which contains the revision number of the `rexxmsg.xml` file.

The program executes the following tests:

1. Compare the version number contained in the `revision` file
   with the current ooRexx version number, and stop if they are not identical
2. Inspect the source files of the Rexx Parser,
   locate all the calls to the `Syntax` routine,
   and verify that the label and the arguments are the same,
   that they are integers, and that the message stored in the Parser
   is identical to the message stored in `rexxmsg.xml`.
3. For every syntax error that the parser is able to detect,
   run a program that produces exactly this error,
   and then compare the output produced by the ooRexx interpreter.
   Stop if the errors produced are not completely identical.

When `errors.rex` completes without errors,
you can be sure that the syntax errors detected by the Rexx Parser
are identical to the errors detected by (the current version of)
the ooRexx interpreter.

To run `errors.rex`, change to the Rexx Parser directory, and run

```
tests\errors
```

under Windows, or

```
rexx tests/errors
```

under Linux.

Self-parsing: [`idents.rex`](idents.rex)
----------------------------------------

The Rexx Parser includes two small programs called
[`elident.rex`](elident.rex) and
[`trident.rex`](trident.rex), located in the
[`tests`](.) subdirectory. They take a file name
as an argument; the contents of the file
is parsed and accesed using the Element API (elident)
or the Tree API (trident),
and the source file is compared to parsed result.
The programs return 0
when the comparison succeeds, and 1 otherwise.

The [`idents.rex`](idents.rex) utility, located in the same subdirectory,
builds over `elident.rex` and `trident.rex`, and it checks that the results of
parsing `Rexx.Parser.cls` and all the files
in the [`cls`](/rexx-parser/bin/) subdirectory are identical to their own scanning.

To run `idents.rex`, change to the Rexx Parser directory, and run

```
tests\idents
```

under Windows, or

```
rexx tests/idents
```

under Linux.
