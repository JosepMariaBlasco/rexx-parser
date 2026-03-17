Test suite
==========

The test suite uses [ooRexxUnit](framework/OOREXXUNIT.CLS) with
[ooTest extensions](framework/ooTest.frm). All tests are in
`.testGroup` files under [`suites/`](suites/).

Running the tests
-----------------

From the `tests/` directory:

```
rexx RunTests.rex
```

This first runs [`CheckMessages.rex`](CheckMessages.rex), which
verifies that the error messages in the parser source code are
consistent with `rexxmsg.xml`. If this check fails, the run aborts
before executing any suite.

Then it discovers all `.testGroup` files in `suites/` and runs them.

Individual suites can also be run standalone:

```
cd tests
PATH="framework:suites:../bin:$PATH" rexx suites/BIFs.testGroup
```

Test suites
-----------

| Suite | Tests | Assertions | What it covers |
|---|---|---|---|
| BIFs | 70 | 549 | BIF argument validation (parametric) |
| FencedCode | 26 | 26 | Fenced code block processing |
| Highlighter | 108 | 108 | Highlighter engine, ANSI driver, StylePatch |
| KeywordInstructions | 3 | 12 | LEAVE, ITERATE, GUARD, SIGNAL |
| Regressions | 8 | 10 | Reported regressions (JLF, 20250419) |
| RexxPubOptions | 62 | 62 | YAML option parsing, CSS overrides |
| SyntaxErrors | 31 | 297 | Syntax errors 6–47, 89, 98, 99 |
| YAMLFrontMatter | 43 | 43 | YAML front matter parsing |
| **Total** | **351** | **1107** | |

Framework
---------

[`ParserTestCase.cls`](framework/ParserTestCase.cls) extends ooTestCase
with three helpers:

- **`parserError(code, source)`** — asserts that the parser raises the
  expected syntax error for the given source.
- **`parserOK(source)`** — asserts that the parser accepts the source
  without errors.
- **`parserOnly(source)`** — like `parserOK`, but only runs the parser
  (no interpreter). Needed for code with uninitialized variables,
  infinite loops, or interactive trace.

Known parser/interpreter divergences
-------------------------------------

Documented as comments in `SyntaxErrors.testGroup`:

- **10.003, 10.007**: substitution parameters swapped in the parser
  message (variable name where line number should go).
- **47.003**: parser raises 47.003, interpreter raises 18.001
  (a label "consumes" the THEN).
- **47.004**: parser raises 47.004, interpreter raises 18.002
  (same mechanism as 47.003).
- **99.913**: second-pass error, not detectable with earlyCheck options.

See also
--------

- Documentation for [identtest.rex](../doc/utilities/identtest/)