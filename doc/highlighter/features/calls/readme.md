Function and subroutine calls
=============================

-------------------------------------------------------

The Rexx Parser is able to differentiate between
*internal*, *built-in*, *local `::ROUTINE`*,
*namespaced `::ROUTINE`* and *external* function
and subroutine calls.

```rexx
  ------------------------------------------------------------------------------
  -- Testing different forms of function and subroutine calls                 --
  ------------------------------------------------------------------------------

  len =  Length(  var )                 -- Call a BIF as a function
  Call   Length   var                   -- Call a BIF as a subroutine
  b   =  Verify(  var )                 -- Internal routine, as a function
  Call   Verify   var                   -- Internal routine, as a subroutine
  v   = "VERIFY"( var )                 -- BIF function call
  Call  "VERIFY"  var                   -- BIF subroutine call
  v   = "Verify"( var )                 -- External function
  Call  "Verify"  var                   -- External subroutine
  Call   meaningOfLife                  -- Package-local ::ROUTINE, function
  x   =  meaningOfLife()                -- Package-local ::ROUTINE, subroutine
  n   =  Name:myRoutine()               -- External ::ROUTINE as a function
  Call   Name:myRoutine                 -- External ::ROUTINE as a subroutine
  e   =  External()                     -- External function
  Call   External                       -- External subroutine

  Signal On Syntax Name  Verify         -- A label
  Call   On Error  Name  Length         -- A BIF
  Call   On Error  Name "Length"        -- External

"VERIFY": Return .True                  -- An internal routine

::Routine meaningOfLife                 -- A locally defined ::ROUTINE
  Return 42                             -- The Meaning of Life
```

Please note that namespaced function and procedure
calls always refer to an (external) `::ROUTINE`.
