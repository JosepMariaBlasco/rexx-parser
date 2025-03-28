HTML instruction highlighting test
==================================

-----------------------------------------------------------

See also:

+ [All cases](/rexx-parser/doc/highlighter/html/all/).
+ [All directives](/rexx-parser/doc/highlighter/html/directives/).

#### `ADDRESS`

```rexx
Address                                 -- Switch environments
Address Command                         -- Change environment
Address Command "Erase backup log a0"   -- Issue a command
Address Value "Co" || "mmand"           -- Calculated environment
Address ("Co" || "mmand")               -- Calculated environment
```

#### `ADDRESS ... WITH`

```rexx
Address E With Input Normal         Output Normal         Error Normal
Address E With Input Stem      a.   Output Stem      b.   Error Stem      c.
Address E With Input Stream   "a"   Output Stream   "b"   Error Stream   "c"
Address E With Input Stream   1.2   Output Stream   2.3   Error Stream   3.4
Address E With Input Stream    3a   Output Stream    3b   Error Stream    3c
Address E With Input Stream    .a   Output Stream    .b   Error Stream    .c
Address E With Input Stream (."a")  Output Stream (."b")  Error Stream (."c")
Address E With Input Using    "a"   Output Using    "b"   Error Using    "c"
Address E With Input Using    1.2   Output Using    2.3   Error Using    3.4
Address E With Input Using     3a   Output Using     3b   Error Using     3c
Address E With Input Using     .a   Output Using     .b   Error Using     .c
Address E With Input Using  (."a")  Output Using  (."b")  Error Using  (."c")
```

#### `ARG`

```rexx
  Arg
  Arg x . y "a" x, , =3 w.1 -2 x[2] +3 w~next[2] =12
```

#### `CALL`

```rexx
  Call Proc
  Call Proc a, x+y, ,  z~last[12], "a"
  Call ("P"roc)
  Call ("P"roc) a, x+y, , z~last[12], "a"
```

#### `CALL ON`

```rexx
  Call On Any
  Call On Any Name Label1
  Call On Error
  Call On Failure
  Call On Halt
  Call On Notready
  Call On User Condition
Label1:
  Call On User Condition Name Label2
```

#### `CALL OFF`

```rexx
  Call Off Any
  Call Off Error
  Call Off Failure
  Call Off Halt
  Call Off Notready
  Call Off User Condition
```

#### `DO` (simple)

```rexx
  Do; Say A; End
  Do Label L; Say A; Leave L; Say B; End
```

#### `DO` (simple repetitive)

```rexx
  Do 3; Say A; End
  Do 3 While 1 = 1; Say A; End
  Do 3 Until 1 = 1; Say A; End
  Do 3*12; Say A; End
  Do Label L 3; Say A; Leave L; Say B; End
  Do Label L 3*12; Say A; Leave L; Say B; End
  Do Counter C 3; Say C; End
  Do Counter C 3*12; Say C; End
  Do Label L Counter C 3; Say A; Leave L; Say C; End
  Do Label L Counter C 3*12; Say A; Leave L; Say C; End
  Do Counter C Label L 3; Say A; Leave L; Say C; End
  Do Counter C Label L 3*12; Say A; Leave L; Say C; End
```

#### `DO` (controlled repetitive)

```rexx
  Do i = 1;                  Say i*i; End
  Do i = 1 By 2;             Say i*i; End
  Do i = 1 To 10;            Say i*i; End
  Do i = 1 By 2 To 10;       Say i*i; End
  Do i = 1 To 10 By 2;       Say i*i; End
  Do i = 1 For 4;            Say i*i; End
  Do i = 1 By 2 For 4;       Say i*i; End
  Do i = 1 For 4 By 2;       Say i*i; End
  Do i = 1 To 10 For 4;      Say i*i; End
  Do i = 1 For 4 To 10;      Say i*i; End
  Do i = 1 For 4 By 2 To 10; Say i*i; End
  Do i = 1 By 2 For 4 To 10; Say i*i; End
  Do i = 1 By 2 To 10 For 4; Say i*i; End
  Do i = 1 For 4 To 10 By 2; Say i*i; End
  Do i = 1 To 10 For 4 By 2; Say i*i; End
  Do i = 1 To 10 By 2 For 4; Say i*i; End
  Do i = 1 To 10 By 2 For 4 While a = b*c
    Say i*i
  End
  Do i = 1 To 10 By 2 For 4 Until a = b*c
    Say i*i
  End
```

#### `DO` (over collections)

```rexx
  Do vector Over Matrix
    Say vector[1]
  End
  Do vector Over Matrix While vector~size > 10
    Say vector[1]
  End
  Do vector Over Matrix For 12
    Say vector[1]
  End
  Do vector Over Matrix For 12 Until vector[2] = "test"
    Say vector[1]
  End
```

#### `DO` (over suppliers)

```rexx
  Do With Index ix Item it Over Supplier;       Say ix it; End
  Do With Index ix Item it Over Supplier For 3; Say ix it; End
  Do With Item it Index ix Over Supplier;       Say ix it; End
  Do With Item it Index ix Over Supplier For 3; Say ix it; End
  Do With Index ix         Over Supplier;       Say ix   ; End
  Do With          Item it Over Supplier;       Say    it; End
  Do With Index ix         Over Supplier For 3; Say ix   ; End
  Do With          Item it Over Supplier For 3; Say    it; End
  Do With Item it Index ix Over Supplier For 3 While it + ix <= 12
    Say ix it
  End
  Do With Item it Index ix Over Supplier For 3 Until it > ix
    Say ix it
  End
```

#### `DO FOREVER`

```rexx
  Do Counter C Label L Forever
    If C = 12 Then Leave L
  End
  Do Counter C Label L Forever While 2 < 3
    If C = 12 Then Leave L
  End
```

#### `DROP`

```rexx
  Drop a s. (b)
```

#### `EXIT`

```rexx
  Exit
  Exit some*expression
  Exit an, array, term, result
```

#### `EXPOSE`

```rexx
::Method M
  Expose a s. (b)
```

#### `FORWARD`

```rexx
::Method M
  Forward
  Forward Continue
  Forward Arguments  "abc"
  Forward Continue Arguments  "abc"
  Forward Arguments  "abc"  Continue
  Forward Arguments   5de
  Forward Arguments  .env
  Forward Arguments (f,g,h)
  Forward Array     (1,2,3)
  Forward Message    "abc"
  Forward Message     5de
  Forward Message    .env
  Forward Message   ("M"sg)
  Forward Class      "abc"
  Forward Class       5de
  Forward Class      .env
  Forward Class     ("C"ls)
  Forward To         "abc"
  Forward To          5de
  Forward To         .env
  Forward To        ("O"bj)
  Forward Message "Msg" Class .String To ("O"bj) Continue Array (1,2,3)
```

#### `GUARD`

```rexx
::Method myMethod
  Expose obj
  Guard On
  Guard Off
  Guard On  When obj == 2
  Guard Off When obj~isNil
```

#### `IF`

```rexx
  If a Then b
  If a, b, c Then d
  If x Then Do; Say y; Nop; End
  If a Then b; Else c
  If a Then b
  Else c
  If a
    Then b
    Else c
```

#### `INTERPRET`

```rexx
  Interpret "Call Proc"
```

#### `ITERATE`

```rexx
  Loop Label outer o = 1 To 100
    Loop Label inner i = o+1 To 100
      Call Proc
      If result > 12 Then Iterate inner
      If result > 14 Then Iterate
      Say i+o
    End
  End
```

#### `LEAVE`

```rexx
  Loop Label outer o = 1 To 100
    Loop Label inner i = o+1 To 100
      Call Proc
      If result > 12 Then Leave inner
      If result > 14 Then Leave
      Say i+o
    End
  End
```

#### `LOOP`

```rexx
  Loop Counter C Label L 3*12; Say A; Leave L; Say C; End
  Loop i = 1 To 10 By 2 For 4 While a = b*c
    Say i*i
  End
  Loop vector Over Matrix For 12 Until vector[2] = "test"
    Say vector[1]
  End
  Loop With Item it Index ix Over Supplier For 3 While it + ix <= 12
    Say ix it
  End
  Loop Counter C Label L Forever While 2 < 3
    If C = 12 Then Leave L
  End
```

#### `NOP`

```rexx
  Nop
```

#### `NUMERIC`

```rexx
  Numeric Digits
  Numeric Digits 100000
  Numeric Digits 100*100
  Numeric Form Scientific
  Numeric Form Engineering
  Numeric Form Value "Eng" || "ineering"
  Numeric Form ( "Eng" || "ineering" )
  Numeric Fuzz
  Numeric Fuzz 3
  Numeric Fuzz 1+2
```

#### `OPTIONS`

```rexx
  Options "what" || "ever"
```

#### `PARSE`

```rexx
  Parse                Arg x . y, , "abc" z
  Parse Upper          Arg x . y, , "abc" z
  Parse Lower          Arg x . y, , "abc" z
  Parse       Caseless Arg x . y, , "abc" z
  Parse Upper Caseless Arg x . y, , "abc" z
  Parse Lower Caseless Arg x . y, , "abc" z
  Parse       Caseless Arg x . y, , "abc" z
  Parse Caseless Upper Arg x . y, , "abc" z
  Parse Caseless Lower Arg x . y, , "abc" z
  Parse Caseless Lower LineIn x . y "abc" z
  Parse Caseless Lower Pull   x . y "abc" z
  Parse Lower Source os .
  Parse Value With no thing
  Parse Value some data With two vars
  Parse Version . languageLevel .
```

#### `PROCEDURE`

```rexx
  A: Procedure
  B: Procedure Expose a b. b.a (a) c
```

#### `PULL`

```rexx
  Parse Caseless Lower Pull x . y "abc" z
```

#### `PUSH`

```rexx
  Push
  Push a + b
```

#### `QUEUE`

```rexx
  Queue
  Queue a + b
```

#### `RAISE`

```rexx
  Raise Error "12"
  Raise Error  12
  Raise Error .env
  Raise Error ("1"2)
  Raise Error  12 Additional    "abc"
  Raise Error  12 Additional     123
  Raise Error  12 Additional    .env
  Raise Error  12 Additional   (1,2,3)
  Raise Error  12 Array        (1,2,3)
  Raise Error  12 Description   "abc"
  Raise Error  12 Description    123
  Raise Error  12 Description   .env
  Raise Error  12 Description  ("D"esc)
  Raise Error  12 Exit
  Raise Error  12 Exit   "abc"
  Raise Error  12 Exit    123
  Raise Error  12 Exit   .env
  Raise Error  12 Exit   ("x"y)
  Raise Error  12 Return
  Raise Error  12 Return "abc"
  Raise Error  12 Return  123
  Raise Error  12 Return .env
  Raise Error  12 Return ("x"y)
  Raise Failure "-3"
  Raise Halt
  Raise LostDigits
  Raise NoMethod
  Raise NoString
  Raise NotReady
  Raise NoValue
  Raise Syntax 16.1 Additional "badLabel"
  Raise User MyCondition
  Raise Propagate
  Raise Syntax 16.1 Array ("badLabel") Description "myDesc" Exit 12
```

#### `REPLY`

```rexx
  Reply
  Reply a/c
```

#### `RETURN`

```rexx
  Return
  Return a/c
```

#### `SAY`

```rexx
  Say
  Say a/c
```

#### `SELECT`

```rexx
  Select
    When case1 Then Action1
    When case2 Then Action2
    Otherwise
      Some
      More
      Actions
  End
  Select Label myLabel
    When case1 Then Action1
    When case2 Then Do
      If whatever Then Leave myLabel
    End
  End
  Select Case value
    When One Then Say "One"
    When Two Then Say "Two"
    Otherwise Nop
  End
```

#### `SIGNAL`

```rexx
  Signal myLabel
  Signal Value my || label
  Signal ( my || label )
myLabel:
  Nop
```

#### `SIGNAL OFF`

```rexx
  Signal Off Any
  Signal Off Error
  Signal Off Failure
  Signal Off Halt
  Signal Off LostDigits
  Signal Off NoMethod
  Signal Off NoString
  Signal Off Notready
  Signal Off NoValue
  Signal Off Syntax
  Signal Off User myCondition
```

#### `SIGNAL ON`

```rexx
  Signal On Any
  Signal On Error
  Signal On Failure
  Signal On Halt
  Signal On LostDigits
  Signal On NoMethod
  Signal On NoString
  Signal On Notready
  Signal On NoValue
  Signal On Syntax
  Signal On Syntax Name mySyntax
  Signal On User myCondition
mySyntax:
  Nop
```

#### `TRACE`

```rexx
  Trace
  Trace ?
  Trace Normal
  Trace ?All
  Trace All
  Trace Commands
  Trace Failure
  Trace Intermediates
  Trace Labels
  Trace Off
  Trace Results
  Trace 3
  Trace +3
  Trace - 2
  Trace Value ? || a
  Trace (? || a)
```

#### `USE ARG`

```rexx
  Use        Arg
  Use Strict Arg
  Use Strict Arg a = "x", b, c[2] = (a + b), d~this = .False, ...
```

#### `USE LOCAL`
```rexx
::Method method1
  Use Local
::Method method2
  Use Local a b.
```

