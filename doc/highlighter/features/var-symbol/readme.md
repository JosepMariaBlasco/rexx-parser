Variable symbol highlighting
============================

--------------------------------------

Depending on the context, an element
with the morphology of a variable symbol
may play the role of a local *variable*,
of an instance variable, of an instruction
or directive *keyword*, or be taken as a *constant*,
like in the case of labels or method names.

The Rexx Parser assigns different element categories
to each symbol, depending on its role (and, in
the case of taken constants, it also assigns different subcategories),
and these differences are passed to the various
highlighter versions, so that they can highlight
each case appropriately.

```rexx
::Method then                           -- A method name
  Expose then expose                    -- Instance variables

If:                                     -- "If" is a label here
  If (then = 2)                         -- "then" is an instance variable
    Then else = 3                       -- "Then" keyword, "else" variable
    Else Do Label 4                     -- Three keywords
      end = 4                           -- A variable called "end"
      Signal Then                       -- Signaling the "then" label
    End 4                               -- A keyword
  self~then                             -- "then" as a method name

Then:                                   -- "Then" is a label
  value = Else()                        -- A ::ROUTINE call

::Routine Else                          -- A ::ROUTINE name
  Use Arg while                         -- Assign to the "while" variable
  Loop Label Forever forever = 1 By 1 - -- "forever", label and control variable
       While (while > forever)          -- Two uses of "while"
    If forever > 16 Then Return while   -- "forever" and "while" are variables
  End Forever                           -- "Forever" as a label
  Return forever                        -- "forever" as a variable
```
