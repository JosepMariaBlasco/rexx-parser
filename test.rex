#!/usr/bin/env rexx
/*----------------------------------------------------------------------------*/
/*                                                                            */
/* Copyright (c) 2007-2023 Rexx Language Association. All rights reserved.    */
/*                                                                            */
/* This program and the accompanying materials are made available under       */
/* the terms of the Common Public License v1.0 which accompanies this         */
/* distribution. A copy is also available at the following address:           */
/* https://www.oorexx.org/license.html                                        */
/*                                                                            */
/* Redistribution and use in source and binary forms, with or                 */
/* without modification, are permitted provided that the following            */
/* conditions are met:                                                        */
/*                                                                            */
/* Redistributions of source code must retain the above copyright             */
/* notice, this list of conditions and the following disclaimer.              */
/* Redistributions in binary form must reproduce the above copyright          */
/* notice, this list of conditions and the following disclaimer in            */
/* the documentation and/or other materials provided with the distribution.   */
/*                                                                            */
/* Neither the name of Rexx Language Association nor the names                */
/* of its contributors may be used to endorse or promote products             */
/* derived from this software without specific prior written permission.      */
/*                                                                            */
/* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        */
/* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT          */
/* LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS          */
/* FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   */
/* OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,      */
/* SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED   */
/* TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,        */
/* OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY     */
/* OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING    */
/* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS         */
/* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.               */
/*                                                                            */
/*----------------------------------------------------------------------------*/
  parse source . . s
  group = .TestGroup~new(s)
  group~add(.CALL.testGroup)

  if group~isAutomatedTest then return group

  testResult = group~suite~execute~~print

return testResult



::requires 'ooTest.frm' -- load the ooRexxUnit classes
::requires 'FileUtils.cls'    -- load the FileUtils classes

::class "CALL.testGroup" subclass ooTestCase public

::method test_invalid
  self~assertSyntaxError(19.2, "call") -- String or symbol expected after CALL keyword
  self~assertSyntaxError(19.2, "call +")
  self~assertSyntaxError(36.901, "call (") -- Left parenthesis .. requires a corresponding right parenthesis
  self~assertSyntaxError(35.932, "call ()") -- Missing expression for calculated CALL name

  self~assertSyntaxError(20.911, "call on") -- Symbol expected after ON keyword
  self~assertSyntaxError(20.911, "call on ''")
  self~assertSyntaxError(20.911, "call off") -- Symbol expected after OFF keyword
  self~assertSyntaxError(20.911, "call off 'ERROR'")
  self~assertSyntaxError(25.1, "call on lostdigits") -- CALL ON must be followed by one of the keywords ERROR, FAILURE, HALT, NOTREADY, USER, or ANY
  self~assertSyntaxError(25.914, "call on any all") -- CALL ON condition must be followed by the keyword NAME
  self~assertSyntaxError(21.904, "call off error on") -- Data must not follow the condition name
  self~assertSyntaxError(21.904, "call off notready name n") -- Data must not follow the condition name
  self~assertSyntaxError(19.3, "call on halt name") -- String or symbol expected after NAME keyword
  self~assertSyntaxError(19.3, "call on any name /") -- String or symbol expected after NAME keyword

  self~assertSyntaxError(20.915, "call on user") -- Symbol expected after USER keyword
  self~assertSyntaxError(20.915, "call on user ''") -- Symbol expected after USER keyword
  self~assertSyntaxError(20.915, "call off user 'cond'") -- Symbol expected after USER keyword
  self~assertSyntaxError(19.3, "call on user cond name") -- String or symbol expected after NAME keyword

-- CALL targets
::routine label; return "routine"
::routine "arg"; return "routine"
::routine ""; return "routine"

-- trap routine
::routine trap
  call value "CALL.trap", "routine", ""

::method test_symbol
  -- search order is internal labels, built-in functions, external functions
  call label; self~assertSame("internal", result)
  call arg; self~assertSame("internal", result) -- should not call ARG built-in
  call upper; self~assertSame("internal", result) -- should not call UPPER built-in
  call digits; self~assertSame(9, result) -- should call DIGITS built-in, not "digits" label

  -- namespace-prefixed call target
  pkg = .Package~new("", ("::routine call public", "return 'routine'"))
  .context~package~addPackage(pkg, "space")
  call space:call; self~assertSame("routine", .CALL.trap)

  -- now repeat for function syntax; not really a CALL test, but still ..
  self~assertSame("internal", label())
  self~assertSame("internal", arg())
  self~assertSame("internal", upper())
  self~assertSame(9, digits())
  self~assertSame("routine", space:call())

  return

  label: arg: "UPPER": "digits": return "internal"

::method test_literal
  -- if name is a literal string any internal labels are bypassed
  call ""; self~assertSame("routine", result) -- should not call internal "" label
  call ''b; self~assertSame("routine", result) -- binary nullstring
  call "label"; self~assertSame("routine", result) -- always case-insensitive
  call "Label"; self~assertSame("routine", result) -- always case-insensitive
  call "LABEL"; self~assertSame("routine", result) -- should not call internal label
  call "arg"; self~assertSame("routine", result) -- should neither call ARG built-in nor "arg" label
  call "ARG"; self~assertSame(0, result) -- should call ARG built-in
  call '41 52 47'x; self~assertSame(0, result) -- "ARG" as hex string

  -- repeat for function syntax
  self~assertSame("routine", ""())
  self~assertSame("routine", ''b())
  self~assertSame("routine", "label"())
  self~assertSame("routine", "Label"())
  self~assertSame("routine", "arg"())
  self~assertSame(0, "ARG"())
  self~assertSame(0, '41 52 47'x())

  return

  "": label: arg: "arg": return "internal"

::method test_expression
  -- if name is an expression, internal labels are honored
  call (""); self~assertSame("internal", result)
  call ("label"); self~assertSame("routine", result)
  call ("Label"); self~assertSame("routine", result) -- always case-insensitive @@is this documented??
  call ("LABEL"); self~assertSame("internal", result)
  call ("arg"); self~assertSame("internal", result) -- should call internal "arg"
  call ("ARG"); self~assertSame("internal", result) -- should not call ARG built-in
  call ((,)); self~assertSame("internal", result) -- evaluates to nullstring
  -- there's no function equivalent for CALL (expression)
  return

  "": label: arg: "arg": return "internal"

::method test_on
  call on any
  call on error
  call on failure
  call on halt
  call on notready
  call on user c

::method test_on_name
  -- trap is a built-in; not useful but should work
  -- note that the trap routine receives a condition object as its
  -- argument @@is this documented?
  call on notready name WORDS -- should call the built-in
  call charin "/"

  -- trap is an internal label
  state = ""
  call on notready name fuzz -- should call label fuzz, not the built-in
  call charin "/"
  self~assertSame("internal", state)

  -- trap is a routine
  call value "CALL.trap", "", ""
  call on notready name trap
  call charin "/"
  self~assertSame("routine", .CALL.trap)

  fuzz: words:
    state = "internal"
    return


::method test_off
  call off any
  call off error
  call off failure
  call off halt
  call off notready
  call off user c

::method test_args
  -- more than 250 args are valid
  call max 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300
  self~assertSame(300, result)

::method test_stacksize
  -- we expect a maximum recursion depth of at least 5000 (arbitrary)
  n = 0
  signal on syntax
  f:
    n += 1
    call f

  syntax:
  self~assertTrue(n >= 5000, "maximum recursion depth expected to be at least 5000, found" n)


::method "test_1"
   -- Create our external functions. There are 3 of them.
   path = .ooRexxUnit.dir || .ooRexxUnit.directory.separator
   src = .array~new()
   src[1] = "Parse Version version"
   src[2] = "Parse Source fn"
   src[3] = "Return '4'"
   call createFile src, path'SCICAL1A'
   src[3] = "Return 3"
   call createFile src, path'SCICAL1B'
   src[3] = "Return 4"
   call createFile src, path'SCICAL1C'

   -- now do the tests
   call junktest; sigl0=sigl /* base to check sigl       */
   call internal1
   Call internal2; s=s||left(result,1); sigl2=sigl
   cALL internal3; sigl3=sigl
   CALL,
        'SCICAL1A'; s=s||result
   call/**/"XRANGE" '5','5'; s=s||result
   call left '6789',1; s=s||result
   call scical1B; s=s||result;
   call scical1C; s=s||result;
   call 15
   Call 15.3
   Call .
   CAll ,
   abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij
   self~assertSame(s, '12345634DEFG')
   self~assertSame((sigl1 sigl2 sigl3), (sigl0+1) (sigl0+2) (sigl0+3))

   -- now remove the external functions
   call deleteFile path'SCICAL1A'
   call deleteFile path'SCICAL1B'
   call deleteFile path'SCICAL1C'

   return

   internal1: s='1'; sigl1=sigl; Return
   internal2: Procedure; Return '2'
   internal3: Procedure Expose s; s=s'3'; Return
   LEFT: Return "LEFT"("ARG"(1),1); /* internal routine overrides bif   */
                                    /* unless literal as function-name  */
   15:   s=s||'D'; Return
   15.3: s=s||'E'; Return
   .:    s=s||'F'; Return
   abcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghijabcdefghij:
         s=s||'G'; Return 0
   -- this routine is here just so the caller can set sigl
   junktest: return

::method "test_2"
   self~expectSyntax(41.1)
   call sub('a'+2)                  /* invalid expression */

::method "test_3"
   -- Create our external functions.
   path = .ooRexxUnit.dir || .ooRexxUnit.directory.separator
   src = .array~new()
   src[1] = "Parse Source fn"
   src[2] = "   num=Arg()"
   src[3] = "   sum=0"
   src[4] = "   Do i=1 To num"
   src[5] = "     sum=sum+Arg(i)"
   src[6] = "     End"
   src[7] = "   Return sum"
   call createFile src, path'SCICAL3A'

   -- now do the tests
   ai=0
   Call a a(0),a(1),a(2),a(3),a(4),a(5),a(6),a(7),a(8),a(9)
   self~assertSame(result, xrange('0','9'))

   ai=0
   Call a a(0),a(1),a(2),a(3),a(4),a(5),a(6),a(7),a(8),a(9),10
   self~assertSame(result, '012345678910')

   v202='vVv'
   v203="COPIES"('xx',5000)
   v207.='ab'
   v207.1='cd'
   Call sub0201 'abc'; self~assertSame(result, 201)
   Call sub0202 v202;  self~assertSame(result, 0202)
   Call sub0203 v203;  self~assertSame(result, 203)
   Call sub0204 (2+3); self~assertSame(result, 204)
   Numeric Digits 2
   Call sub0205 +205;  self~assertSame('2.1E+2', +result)
   Numeric Digits 9
   Call sub0206 12a,'0102'X;
                       self~assertSame(result, '0201'x)
   Call sub0207 v207.,v207.1
                       self~assertSame(result, 'abcd')
   Call sub0208 '',''; self~assertSame(result, '')
   Call sub0209 bitor('0102'X,'2011'X),'a,' 'b,' 'and c'
                       self~assertSame(result, 'a,*b,*and*c')
   Do i=1 to 21
     a.i=i
     End
   Call a20 a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, a.9, a.10,,
            a.11,a.12,a.13,a.14,a.15,a.16,a.17,a.18,a.19,a.20
   self~assertSame(result, 210)
   Call scical3a a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, a.9, a.10,,
                 a.11,a.12,a.13,a.14,a.15,a.16,a.17,a.18,a.19,a.20
   self~assertSame(result, 210)
   Call a20 a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, a.9, a.10,,
            a.11,a.12,a.13,a.14,a.15,a.16,a.17,a.18,a.19,a.20,a.21
   Call scical3a a.1, a.2, a.3, a.4, a.5, a.6, a.7, a.8, a.9, a.10,,
                 a.11,a.12,a.13,a.14,a.15,a.16,a.17,a.18,a.19,a.20,a.21

   -- now remove the external functions
   call deleteFile path'SCICAL3A'
   return

   a:
   If "ARG"()>1 Then Do;               /* concatenate all arguments      */
      s='';
      Do ai=1 To "ARG"();
         self~assertSame((ai-1), "ARG"(ai))
         s=s||"ARG"(ai);
         End;
      Return s
      End
                                       /* call as argument expression    */
   self~assertSame("ARG"(1), ai)
   ai=ai+1;                            /* increment to new number        */
   Return ai-1                         /* return old number as value     */

   sub0201: self~assertSame(arg(1), 'abc'); Return '201'
   sub0202: self~assertSame(arg(1), 'vVv'); Return 0202
   sub0203: self~assertSame(arg(1), "COPIES"('x',10000)); Return +0.0203e+004
   sub0204: self~assertSame(arg(1), ""5); Return 200+4
   sub0205: Numeric Digits 9
            self~assertSame(arg(1), "2.1E+2"); Return 205
   sub0206: self~assertSame(arg(1), "12A")
            self~assertSame(arg(2), "0102"X)
            Return "RIGHT"("ARG"(2),1)"LEFT"("ARG"(2),1)
   sub0207: self~assertSame(arg(1), "ab")
            self~assertSame(arg(2), "cd")
            Return "ARG"(1)||"ARG"(2)
   sub0208: self~assertSame(arg(1), "")
            self~assertSame(arg(2), ""x)
            v208=''
            Return "ARG"(1)||"ARG"(2)||v208
   sub0209: self~assertSame(arg(1), "2113"X)
            self~assertSame(arg(2), 'a, b, and c')
            Return "TRANSLATE"("ARG"(2),'*','             ')
   a20: Procedure
        sum=0
        Do i=1 To arg()
           sum=sum+Arg(i)
           End
        Return sum

::method "test_4"
   -- Create our external functions.
   path = .ooRexxUnit.dir || .ooRexxUnit.directory.separator
   src = .array~new()
   src[1] = "Parse Version version"
   src[2] = "Parse Source fn"
   src[3] = "  Parse Version sys rexxlevel ."
   src[4] = "  Address CMD"
   src[5] = "  Numeric Fuzz 0"
   src[6] = "  Numeric Digits 100"
   src[7] = "  Numeric Form Scientific"
   src[8] = "  t='TIME'('R')"
   src[9] = "  dff=digits() fuzz() form()"
   src[10] = "  Return dff"
   call createFile src, path'SCICAL4A'

   -- now do the tests
   cmd = address()
   cnt.=0
   g_.=''
   Numeric Digits 5
   Numeric Fuzz 1
   Numeric Form Engineering
   call time 'r'
   Call sysSLEEP 1.1   -- a little longer than we test for to account for clock resolution problems.

   Do i=1 to 2
      ic=0                              /* Iteration counter              */
      Do j=1 to 5
         Do k=1 to 3
           If j=2 & k=2 Then Do
              If i=1 Then
               Call isub
              Else
               Call SCICAL4a
              subdff=result
              dff=digits() fuzz() form()
              self~assertSame(dff, '5 1 ENGINEERING')
              self~assertSame(subdff, '100 0 SCIENTIFIC')
              self~assertSame(novalued_var, 'NOVALUED_VAR')
              self~assertSame(novalued_var, 'NOVALUED_VAR')
              id=1001; Call gt "TIME"('E'),1
              self~assertSame("ADDRESS"(), cmd)
              End
           ic=ic+1
           End
        End
     self~assertSame(ic, 15)
     End
   self~assertSame(4, cnt.ok, "Okay count should be 4")

   -- now remove the external functions
   call deleteFile path'SCICAL4A'
   return

   isub:
   /***********************************************************************
   * Internal subroutine that does all kinds of changes to the
   * "important settings"
   ***********************************************************************/
     Numeric Fuzz 0
     Numeric Digits 100
     Numeric Form Scientific
     Signal On Novalue
     Signal Off Syntax
     id=1004; Call gt "TIME"('E'),1
     tt="TIME"('R')
     id=1005; Call lt "TIME"('E'),1
     dff=digits() fuzz() form()
     Signal subret
     garbage in sub
     the signal within the subroutine has no effect on the do control

   subret:
      Address ''
      self~assertSame("ADDRESS"(), '')
      Return dff
   gt: Procedure Expose id cnt. self
      self~assertTrue(arg(1)>=arg(2), "subTest4-gt id:" id "TIME('E')>1")
      cnt.ok=cnt.ok+1
      Return
   lt: Procedure Expose id cnt. self
      self~assertTrue(arg(1)<arg(2), "subTest4-lt id:" id "TIME('E')>1")
      cnt.ok=cnt.ok+1
      Return

::method "test_5"
   -- Create our external functions.
   path = .ooRexxUnit.dir || .ooRexxUnit.directory.separator
   src = .array~new()
   src[1] = "Parse Version version"
   src[2] = "Parse Source fn"
   src[3] = "/* Address setting must be 'CMS' */"
   src[4] = "return  address()"
   call createFile src, path'SCICAL5A'

   -- now do the tests
   cmd = address()
   self~assertSame(scical5a(), cmd)

   -- now remove the external functions
   call deleteFile path'SCICAL5A'

::method "test_6"
   i=0
   Call SUB1
   self~assertSame(i, 250)
   return

   SUB1: i=i+1; Call SUB2; Return
   SUB2: i=i+1; Call SUB3; Return
   SUB3: i=i+1; Call SUB4; Return
   SUB4: i=i+1; Call SUB5; Return
   SUB5: i=i+1; Call SUB6; Return
   SUB6: i=i+1; Call SUB7; Return
   SUB7: i=i+1; Call SUB8; Return
   SUB8: i=i+1; Call SUB9; Return
   SUB9: i=i+1; Call SUB10; Return
   SUB10: i=i+1; Call SUB11; Return
   SUB11: i=i+1; Call SUB12; Return
   SUB12: i=i+1; Call SUB13; Return
   SUB13: i=i+1; Call SUB14; Return
   SUB14: i=i+1; Call SUB15; Return
   SUB15: i=i+1; Call SUB16; Return
   SUB16: i=i+1; Call SUB17; Return
   SUB17: i=i+1; Call SUB18; Return
   SUB18: i=i+1; Call SUB19; Return
   SUB19: i=i+1; Call SUB20; Return
   SUB20: i=i+1; Call SUB21; Return
   SUB21: i=i+1; Call SUB22; Return
   SUB22: i=i+1; Call SUB23; Return
   SUB23: i=i+1; Call SUB24; Return
   SUB24: i=i+1; Call SUB25; Return
   SUB25: i=i+1; Call SUB26; Return
   SUB26: i=i+1; Call SUB27; Return
   SUB27: i=i+1; Call SUB28; Return
   SUB28: i=i+1; Call SUB29; Return
   SUB29: i=i+1; Call SUB30; Return
   SUB30: i=i+1; Call SUB31; Return
   SUB31: i=i+1; Call SUB32; Return
   SUB32: i=i+1; Call SUB33; Return
   SUB33: i=i+1; Call SUB34; Return
   SUB34: i=i+1; Call SUB35; Return
   SUB35: i=i+1; Call SUB36; Return
   SUB36: i=i+1; Call SUB37; Return
   SUB37: i=i+1; Call SUB38; Return
   SUB38: i=i+1; Call SUB39; Return
   SUB39: i=i+1; Call SUB40; Return
   SUB40: i=i+1; Call SUB41; Return
   SUB41: i=i+1; Call SUB42; Return
   SUB42: i=i+1; Call SUB43; Return
   SUB43: i=i+1; Call SUB44; Return
   SUB44: i=i+1; Call SUB45; Return
   SUB45: i=i+1; Call SUB46; Return
   SUB46: i=i+1; Call SUB47; Return
   SUB47: i=i+1; Call SUB48; Return
   SUB48: i=i+1; Call SUB49; Return
   SUB49: i=i+1; Call SUB50; Return
   SUB50: i=i+1; Call SUB51; Return
   SUB51: i=i+1; Call SUB52; Return
   SUB52: i=i+1; Call SUB53; Return
   SUB53: i=i+1; Call SUB54; Return
   SUB54: i=i+1; Call SUB55; Return
   SUB55: i=i+1; Call SUB56; Return
   SUB56: i=i+1; Call SUB57; Return
   SUB57: i=i+1; Call SUB58; Return
   SUB58: i=i+1; Call SUB59; Return
   SUB59: i=i+1; Call SUB60; Return
   SUB60: i=i+1; Call SUB61; Return
   SUB61: i=i+1; Call SUB62; Return
   SUB62: i=i+1; Call SUB63; Return
   SUB63: i=i+1; Call SUB64; Return
   SUB64: i=i+1; Call SUB65; Return
   SUB65: i=i+1; Call SUB66; Return
   SUB66: i=i+1; Call SUB67; Return
   SUB67: i=i+1; Call SUB68; Return
   SUB68: i=i+1; Call SUB69; Return
   SUB69: i=i+1; Call SUB70; Return
   SUB70: i=i+1; Call SUB71; Return
   SUB71: i=i+1; Call SUB72; Return
   SUB72: i=i+1; Call SUB73; Return
   SUB73: i=i+1; Call SUB74; Return
   SUB74: i=i+1; Call SUB75; Return
   SUB75: i=i+1; Call SUB76; Return
   SUB76: i=i+1; Call SUB77; Return
   SUB77: i=i+1; Call SUB78; Return
   SUB78: i=i+1; Call SUB79; Return
   SUB79: i=i+1; Call SUB80; Return
   SUB80: i=i+1; Call SUB81; Return
   SUB81: i=i+1; Call SUB82; Return
   SUB82: i=i+1; Call SUB83; Return
   SUB83: i=i+1; Call SUB84; Return
   SUB84: i=i+1; Call SUB85; Return
   SUB85: i=i+1; Call SUB86; Return
   SUB86: i=i+1; Call SUB87; Return
   SUB87: i=i+1; Call SUB88; Return
   SUB88: i=i+1; Call SUB89; Return
   SUB89: i=i+1; Call SUB90; Return
   SUB90: i=i+1; Call SUB91; Return
   SUB91: i=i+1; Call SUB92; Return
   SUB92: i=i+1; Call SUB93; Return
   SUB93: i=i+1; Call SUB94; Return
   SUB94: i=i+1; Call SUB95; Return
   SUB95: i=i+1; Call SUB96; Return
   SUB96: i=i+1; Call SUB97; Return
   SUB97: i=i+1; Call SUB98; Return
   SUB98: i=i+1; Call SUB99; Return
   SUB99: i=i+1; Call SUB100; Return
   SUB100: i=i+1; Call SUB101; Return
   SUB101: i=i+1; Call SUB102; Return
   SUB102: i=i+1; Call SUB103; Return
   SUB103: i=i+1; Call SUB104; Return
   SUB104: i=i+1; Call SUB105; Return
   SUB105: i=i+1; Call SUB106; Return
   SUB106: i=i+1; Call SUB107; Return
   SUB107: i=i+1; Call SUB108; Return
   SUB108: i=i+1; Call SUB109; Return
   SUB109: i=i+1; Call SUB110; Return
   SUB110: i=i+1; Call SUB111; Return
   SUB111: i=i+1; Call SUB112; Return
   SUB112: i=i+1; Call SUB113; Return
   SUB113: i=i+1; Call SUB114; Return
   SUB114: i=i+1; Call SUB115; Return
   SUB115: i=i+1; Call SUB116; Return
   SUB116: i=i+1; Call SUB117; Return
   SUB117: i=i+1; Call SUB118; Return
   SUB118: i=i+1; Call SUB119; Return
   SUB119: i=i+1; Call SUB120; Return
   SUB120: i=i+1; Call SUB121; Return
   SUB121: i=i+1; Call SUB122; Return
   SUB122: i=i+1; Call SUB123; Return
   SUB123: i=i+1; Call SUB124; Return
   SUB124: i=i+1; Call SUB125; Return
   SUB125: i=i+1; Call SUB126; Return
   SUB126: i=i+1; Call SUB127; Return
   SUB127: i=i+1; Call SUB128; Return
   SUB128: i=i+1; Call SUB129; Return
   SUB129: i=i+1; Call SUB130; Return
   SUB130: i=i+1; Call SUB131; Return
   SUB131: i=i+1; Call SUB132; Return
   SUB132: i=i+1; Call SUB133; Return
   SUB133: i=i+1; Call SUB134; Return
   SUB134: i=i+1; Call SUB135; Return
   SUB135: i=i+1; Call SUB136; Return
   SUB136: i=i+1; Call SUB137; Return
   SUB137: i=i+1; Call SUB138; Return
   SUB138: i=i+1; Call SUB139; Return
   SUB139: i=i+1; Call SUB140; Return
   SUB140: i=i+1; Call SUB141; Return
   SUB141: i=i+1; Call SUB142; Return
   SUB142: i=i+1; Call SUB143; Return
   SUB143: i=i+1; Call SUB144; Return
   SUB144: i=i+1; Call SUB145; Return
   SUB145: i=i+1; Call SUB146; Return
   SUB146: i=i+1; Call SUB147; Return
   SUB147: i=i+1; Call SUB148; Return
   SUB148: i=i+1; Call SUB149; Return
   SUB149: i=i+1; Call SUB150; Return
   SUB150: i=i+1; Call SUB151; Return
   SUB151: i=i+1; Call SUB152; Return
   SUB152: i=i+1; Call SUB153; Return
   SUB153: i=i+1; Call SUB154; Return
   SUB154: i=i+1; Call SUB155; Return
   SUB155: i=i+1; Call SUB156; Return
   SUB156: i=i+1; Call SUB157; Return
   SUB157: i=i+1; Call SUB158; Return
   SUB158: i=i+1; Call SUB159; Return
   SUB159: i=i+1; Call SUB160; Return
   SUB160: i=i+1; Call SUB161; Return
   SUB161: i=i+1; Call SUB162; Return
   SUB162: i=i+1; Call SUB163; Return
   SUB163: i=i+1; Call SUB164; Return
   SUB164: i=i+1; Call SUB165; Return
   SUB165: i=i+1; Call SUB166; Return
   SUB166: i=i+1; Call SUB167; Return
   SUB167: i=i+1; Call SUB168; Return
   SUB168: i=i+1; Call SUB169; Return
   SUB169: i=i+1; Call SUB170; Return
   SUB170: i=i+1; Call SUB171; Return
   SUB171: i=i+1; Call SUB172; Return
   SUB172: i=i+1; Call SUB173; Return
   SUB173: i=i+1; Call SUB174; Return
   SUB174: i=i+1; Call SUB175; Return
   SUB175: i=i+1; Call SUB176; Return
   SUB176: i=i+1; Call SUB177; Return
   SUB177: i=i+1; Call SUB178; Return
   SUB178: i=i+1; Call SUB179; Return
   SUB179: i=i+1; Call SUB180; Return
   SUB180: i=i+1; Call SUB181; Return
   SUB181: i=i+1; Call SUB182; Return
   SUB182: i=i+1; Call SUB183; Return
   SUB183: i=i+1; Call SUB184; Return
   SUB184: i=i+1; Call SUB185; Return
   SUB185: i=i+1; Call SUB186; Return
   SUB186: i=i+1; Call SUB187; Return
   SUB187: i=i+1; Call SUB188; Return
   SUB188: i=i+1; Call SUB189; Return
   SUB189: i=i+1; Call SUB190; Return
   SUB190: i=i+1; Call SUB191; Return
   SUB191: i=i+1; Call SUB192; Return
   SUB192: i=i+1; Call SUB193; Return
   SUB193: i=i+1; Call SUB194; Return
   SUB194: i=i+1; Call SUB195; Return
   SUB195: i=i+1; Call SUB196; Return
   SUB196: i=i+1; Call SUB197; Return
   SUB197: i=i+1; Call SUB198; Return
   SUB198: i=i+1; Call SUB199; Return
   SUB199: i=i+1; Call SUB200; Return
   SUB200: i=i+1; Call SUB201; Return
   SUB201: i=i+1; Call SUB202; Return
   SUB202: i=i+1; Call SUB203; Return
   SUB203: i=i+1; Call SUB204; Return
   SUB204: i=i+1; Call SUB205; Return
   SUB205: i=i+1; Call SUB206; Return
   SUB206: i=i+1; Call SUB207; Return
   SUB207: i=i+1; Call SUB208; Return
   SUB208: i=i+1; Call SUB209; Return
   SUB209: i=i+1; Call SUB210; Return
   SUB210: i=i+1; Call SUB211; Return
   SUB211: i=i+1; Call SUB212; Return
   SUB212: i=i+1; Call SUB213; Return
   SUB213: i=i+1; Call SUB214; Return
   SUB214: i=i+1; Call SUB215; Return
   SUB215: i=i+1; Call SUB216; Return
   SUB216: i=i+1; Call SUB217; Return
   SUB217: i=i+1; Call SUB218; Return
   SUB218: i=i+1; Call SUB219; Return
   SUB219: i=i+1; Call SUB220; Return
   SUB220: i=i+1; Call SUB221; Return
   SUB221: i=i+1; Call SUB222; Return
   SUB222: i=i+1; Call SUB223; Return
   SUB223: i=i+1; Call SUB224; Return
   SUB224: i=i+1; Call SUB225; Return
   SUB225: i=i+1; Call SUB226; Return
   SUB226: i=i+1; Call SUB227; Return
   SUB227: i=i+1; Call SUB228; Return
   SUB228: i=i+1; Call SUB229; Return
   SUB229: i=i+1; Call SUB230; Return
   SUB230: i=i+1; Call SUB231; Return
   SUB231: i=i+1; Call SUB232; Return
   SUB232: i=i+1; Call SUB233; Return
   SUB233: i=i+1; Call SUB234; Return
   SUB234: i=i+1; Call SUB235; Return
   SUB235: i=i+1; Call SUB236; Return
   SUB236: i=i+1; Call SUB237; Return
   SUB237: i=i+1; Call SUB238; Return
   SUB238: i=i+1; Call SUB239; Return
   SUB239: i=i+1; Call SUB240; Return
   SUB240: i=i+1; Call SUB241; Return
   SUB241: i=i+1; Call SUB242; Return
   SUB242: i=i+1; Call SUB243; Return
   SUB243: i=i+1; Call SUB244; Return
   SUB244: i=i+1; Call SUB245; Return
   SUB245: i=i+1; Call SUB246; Return
   SUB246: i=i+1; Call SUB247; Return
   SUB247: i=i+1; Call SUB248; Return
   SUB248: i=i+1; Call SUB249; Return
   SUB249: i=i+1; Call SUB250; Return
   SUB250: i=i+1; Call SUB251; Return
   SUB251: Return

::method "test_7"
   i=0
   Call a 'a'; self~assertSame((result i), 'a 1')
   Call b 'b'; self~assertSame((result i), 'b 2')
   Call c 'c'; self~assertSame((result i), 'c 3')
   Call d 'd'; self~assertSame((result i), 'd 4')
   Call e 'e'; self~assertSame((result i), 'e 5')
   Call f 'f'; self~assertSame((result i), 'f 6')
   Call g 'g'; self~assertSame((result i), 'g 6')
   Call h 'h'; self~assertSame((result i), 'h 6')
   Call i 'i'; self~assertSame((result i), 'i 6')
   Call k 'k'; self~assertSame((result i), 'k 7')

   i=0
   self~assertSame((a('a') i b('b') i c('c') i), 'a 1 b 2 c 3')
   self~assertSame((d('d') i), 'd 4')
   self~assertSame((e('e') i), 'e 5')
   self~assertSame((f('f') i), 'f 6')
   self~assertSame((g('g') i), 'g 6')
   self~assertSame((h('h') i), 'h 6')
   self~assertSame((i('i') i), 'i 6')
   self~assertSame((k('k') i), 'k 7')
   return

   a: b:
   c:
     i=i+1
     Return("ARG"(1))

   d: e:
   f: Procedure Expose j i j k
     i=i+1
     Return("ARG"(1))

   g: h:
   i: Procedure
     i=1
     Return("ARG"(1))

   k: Procedure Expose i
     i=i+1
     Return("ARG"(1))

::method "test_8"
   x=0; Call 0001
   self~assertSame(x, 10)
   return

   0003: x=x+1; Call 0004; Return /* 0003 */
   0009: x=x+1; Call 0010; Return /* 0004 */
   0008: x=x+1; Call 0009; Return /* 0001 */
   0005: x=x+1; Call 0006; Return /* 0010 */
   0004: x=x+1; Call 0005; Return /* 0007 */
   0007: x=x+1; Call 0008; Return /* 0005 */
   0001: x=x+1; Call 0002; Return /* 0009 */
   0010: x=x+1; Call 0011; Return /* 0006 */
   0006: x=x+1; Call 0007; Return /* 0002 */
   0002: x=x+1; Call 0003; Return /* 0008 */
   0011: Return

::method "test_9"
   Call on Notready
   mode='c'
   cndd='A/B/C'
   chk=id
   String="x=Linein('A/B/C')"
   Interpret String
   self~assertSame(chk, '*')
   Return

   Notready:
   self~assertSame(condition('cs'), 'NOTREADY')
   self~assertSame(condition('d'), cndd)
   self~assertSame(condition('i'), 'CALL')
   self~assertSame(condition('s'), 'DELAY')
   chk='*'
   return

::method "test_10"
   call on error
   trace off -- we don't want ERROR trace output

   caught = .false
   -- a non-existing command should always raise ERROR
   address "" "non-existing-command" with error using (.Array~new)
   if \caught then
     self~assertFail("'non-existing-command' should have raised ERROR")
   return

   error:
   self~assertSame(condition('cs'), 'ERROR')
   self~assertSame(condition('i'), 'CALL')
   self~assertSame(condition('s'), 'DELAY')
   caught = .true
   return

::method "test_11"
   call on error
   caught = .false
   call myproc
   if \caught then self~assertTrue(0)
   return

   error:
   self~assertSame(condition('cs'), 'ERROR')
   self~assertSame(condition('i'), 'CALL')
   self~assertSame(condition('s'), 'DELAY')
   caught = .true
   return

   myproc:
   raise error 44.1 return
   return

::method "test_12"
   call on user badvalue
   caught = .false
   call myproc
   if \caught then self~assertTrue(0)
   return

   badvalue:
   self~assertSame(condition('cs'), 'USER BADVALUE')
   self~assertSame(condition('i'), 'CALL')
   self~assertSame(condition('s'), 'DELAY')
   caught = .true
   return

   myproc:
   raise user badvalue return
   return

::method "test_13"
   call on failure
   trace off
   caught = .false
   address xyzzy 'grue'  -- this is a deliberate unknown command
   self~assertTrue(caught, "Error should be caught")
   return

   failure:
   self~assertSame(condition('cs'), 'FAILURE')
   self~assertSame(condition('i'), 'CALL')
   self~assertSame(condition('s'), 'DELAY')
   caught = .true
   return

::method "test_14"
   call on failure
   caught = .false
   call myproc
   if \caught then self~assertTrue(0)
   return

   failure:
   self~assertSame(condition('cs'), 'FAILURE')
   self~assertSame(condition('i'), 'CALL')
   self~assertSame(condition('s'), 'DELAY')
   caught = .true
   return

   myproc:
   raise failure 44.1 return
   return


-- test that an external call correctly searches the requested file
-- according to the documented external search order
-- for a file without extension, the expected search order is
-- 1) parent extension, 2) .REX/.rex, 3) without extension
-- NOTE: although ::REQUIRES Will search .cls first, CALL should not
::method test_search_order
  external = self~createFiles("search_order", ("cls", "testGroup", "REX", "rex", "other", ""))

  -- external calls with extension should work as-is
  call search_order.other
  self~assertSame("other", result)
  self~assertSame("other", search_order.other())
  -- this one must be quoted, because it's mixed case
  call "search_order.testGroup"
  self~assertSame("testGroup", result)
  self~assertSame("testGroup", "search_order.testGroup"())

  -- now external calls without extension
  -- this external call should resolve to .testGroup
  call search_order
  self~assertSame("testGroup", result)
  self~assertSame("testGroup", search_order())
  external["testGroup"]~delete

  -- next, but only on case-sensitive file systems, the same external
  -- call should resolve to .REX
  if external["REX"]~isCaseSensitive then do
    call search_order
    self~assertSame("REX", result)
    self~assertSame("REX", search_order())
    external["REX"]~delete
  end

  -- now the external call should resolve to .rex
  call search_order
  self~assertSame("rex", result)
  self~assertSame("rex", search_order())
  external["rex"]~delete

  -- and finally the external call should resolve to no extension
  call search_order
  self~assertSame("(none)", result)
  self~assertSame("(none)", search_order())

-- create temporary external files with a range of extensions
::method createFiles
  use strict arg baseName, extensionList

  external = .Stringtable~new
  do extension over extensionList
    file = .TemporaryTestFile~new(self, (baseName || "." || extension)~strip("t", "."))
    ext = (extension = "")~?("(none)", extension)
    file~create("return '" || ext || "'")
    external[extension] = file
  end
  return external

-- Test that the search order algorithm correctly identifies when a filename
-- has an extension (see SourceForge bug #1870)

::method test_search_order_file_has_extension

-- We need a directory with a dot to trigger this bug
my.dir = .TemporaryTestDirectory~new(self,"my.dir")~~create

-- Called program, with an extension
called.rex = .TemporaryTestFile~new(my.dir,"called.rex")~~create("return 'ext'")

s = .ooRexxUnit.directory.separator

-- Call "my.dir\called.rex". This will work.
call (my.dir~absolutePath()s"called.rex")
self~assertSame("ext", result)

-- Now call "my.dir\called". It's extensionless, so that the search order
-- should try a number of extensions. It will fail when the presence
-- of a dot in "my.dir" incorrectly makes ooRexx think that the filename
-- includes an extension.
call (my.dir~absolutePath()s"called")
self~assertSame("ext", result)

called.rex~delete
my.dir~delete
