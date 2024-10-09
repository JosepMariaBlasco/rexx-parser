# The Rexx.Package class

## prolog

![Syntax diagram for the prolog method of the Rexx.Package class](../img/Rexx.Package.prolog.svg)

Returns a [code body](Code.Body.md) containing a representation of the prolog.

__Note:__ Even if the prolog is empty, as it is a [code body](Code.Body.md), it will always contain
an implicit exit instruction. The Rexx Parser also inserts an additional implicit end-of-clause (a
semicolon) at the beginning of the source. This guarantees that all clauses are preceded and
ended by a semicolon.
