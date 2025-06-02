Related ooRexx bugs
===================

--------------------------

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