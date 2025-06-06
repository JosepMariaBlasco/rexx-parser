Related ooRexx bugs
===================

--------------------------

During the process of writing the Parser and the highlighter, a number
of bugs in the ooRexx interpreter have been uncovered. We are listing them
here for reference.

## The symbol part of a namespace-qualified symbol cannot be an expression terminator

I.e., `Do i = N:to To 2` is valid, if namespace `N` exists
(see <https://sourceforge.net/p/oorexx/bugs/1945/#80b2/a9a0>),
but this is not documented in RexxRef chapter 16. That's an unreported
bug (besides the just referenced comment).

## The label bugs

See the following two posts in the developers list, and their
corresponding threads:

* <https://sourceforge.net/p/oorexx/mailman/message/58813104/>
* <https://sourceforge.net/p/oorexx/mailman/message/58832816/>

In particular, if you follow the second thread, you will see that
Mike C. comments, in <https://sourceforge.net/p/oorexx/mailman/message/58833223/>:

> So I'd go for option 2.  Labels in themselves are neither useless nor evil (they are used to 'name' a loop, or other point of interest; for example, "see weirdcode: below").   Branching to them can indeed be 'bad' nowadays, so it's the attempt to branch to them that should be flagged, not the label itself, which is just a label.

and in <https://sourceforge.net/p/oorexx/mailman/message/58844205/>,

>Lifting that restriction would be good .. it is really against the concept of a 'label'.
>
>The (Concise) Oxford Dictionary includes, under label:
>
>   > _Computing:  a string of characters used to refer to a particular instruction in a program._
>
>which is exactly the intent I had for labels (hence 'Trace L'), and in
>NetRexx the labelling of loops, etc.   A label is just a name.
>
>So any restriction should be in something that branches to a 'bad' place.
>It's not the fault of the label :-).

What is Mike referring to? Well, some modifications
have been introduced in the ooRexx interpreter. **These modifications
<u>disallow labels that cannot be branched to</u>, instead of <u>disallowing only the branches themselves</u>.**
This unfortunate confusion is a mistake, because it breaks compatibility
with other processors, like Regina, and goes against ANSI. It would have
been enough to _disallow branching_ to these labels, and not the labels themselves
(again, this is what ANSI recommends).

See the following bugs:

* <https://sourceforge.net/p/oorexx/bugs/1945/> and
* <https://sourceforge.net/p/oorexx/bugs/1946/>,

and also the whole chain of comments and references in each of these bugs.

Please note that the name for bug [1945](https://sourceforge.net/p/oorexx/bugs/1945/)
has been changed from "Interpreter hangs when SIGNALing into a SELECT instruction"
to "No labels should be allowed within DO/LOOP, IF, SELECT",
which begs the question. Similarly, the name for
[1946](https://sourceforge.net/p/oorexx/bugs/1946/) has been changed from
"SIGNAL inside group instructions should produce a 16.2 syntax error"
to "Labels should not be allowed within DO/LOOP, IF, SELECT", and the bug has been
marked as "wont-fix", as it has been "consolidated" with
[1946](https://sourceforge.net/p/oorexx/bugs/1946/).

Regarding [1945](https://sourceforge.net/p/oorexx/bugs/1945/),
apart from [1946](https://sourceforge.net/p/oorexx/bugs/1946/),
it also consolidated [1977](https://sourceforge.net/p/oorexx/bugs/1977/),
[1978](https://sourceforge.net/p/oorexx/bugs/1978/),
[1979](https://sourceforge.net/p/oorexx/bugs/1979/) and
[1980](https://sourceforge.net/p/oorexx/bugs/1980/),
which is unfortunate, because it has become a very large bug,
and these ofted tend to be unmanageable

For example,

* `::Method M; L: Expose m` complains that `EXPOSE` should be the first instruction
  in a method, not that `X` is not allowed in such a place (the same happens
  with `USE LOCAL`; see <https://sourceforge.net/p/oorexx/bugs/1945/#e174>).
* `If 1 Then Nop; X: Else Nop` complains that the label `ELSE` is not allowed (should be `X`).
* `If 1; X: Then; Nop` complains that there is no `THEN` clause, when there is one;
  what is wrong (if we accept that such labels are not allowed) is the label `"X"`.
* `If 1 Then X: Nop` and `If 1 Then; X: Nop` produce different results,
  and the first version complains about a label named `"IF"`.

## ADDITIONAL array wrong

* <https://sourceforge.net/p/oorexx/bugs/2022/> (`ADDITIONAL` array wrong in a large number of messages).

## SysIsFile BIF

* <https://sourceforge.net/p/oorexx/bugs/1940/> (`SysIsFile` under Linux gives wrong result when filename ends with an extra "/").

## SetLocal BIF

* <https://sourceforge.net/p/oorexx/documentation/341/> (Typo in Example 7.70. Builtin function `SETLOCAL`, and information imprecise).

## ::RESOURCE directive

* <https://sourceforge.net/p/oorexx/documentation/307/> (Stuff after the `::RESOURCE` directive,
  but in the same line, is ignored -- but this is undocumented).

## Related to early check

* <https://sourceforge.net/p/oorexx/bugs/2006/> (Errors 93.903 wrong for `MIN` and `MAX`, incoherent behaviour with respect to 40.5).
* <https://sourceforge.net/p/oorexx/bugs/2007/> (Wrong second arg to `DATATYPE` BIF raises 93.915 instead of 40.904).
* <https://sourceforge.net/p/oorexx/bugs/2008/> (`Arg(-n)` returns `""` instead of crashing).
* <https://sourceforge.net/p/oorexx/bugs/2009/> (Wrong message for `CALL BEEP "*"`).
* <https://sourceforge.net/p/oorexx/bugs/2010/> (`CHANGESTR`, `CHARIN`, `OPEN`, `TRUNC` wrong message when arg negative)..
* <https://sourceforge.net/p/oorexx/bugs/2011/> (`Call CharIn ,,-1` produces wrong 88.907 with wrong arg number).
* <https://sourceforge.net/p/oorexx/bugs/2012/> (`Call Insert a,b,-1` complains about a length but -1 is a pos).
* <https://sourceforge.net/p/oorexx/bugs/2014/> (`Call linein test,,3` produces a 93.0).
* <https://sourceforge.net/p/oorexx/bugs/2015/> (`Call Trunc "A"` produces a 93.943 instead of a 40.11).
* <https://sourceforge.net/p/oorexx/bugs/2016/> (`Call ABS "A"` produces a 93.943 instead of a 40.11).

## BEEP, DIRECTORY and FILESPEC treated as non-BIFS

`BEEP`, `DIRECTORY` and `FILESPEC` are defined to be BIFs,
but they behave as if they were external functions.
The bug was marked as "invalid" because "this is to
be expected" (by whom?).

* <https://sourceforge.net/p/oorexx/bugs/1885/>