Say -100.233 + .3e-44 + "-1.23E-567"    -- Numbers can have internal highlighting
Say "(Lobster)"U                        -- Low-level Unicode strings. Prints "🦞"
Say "नमस्ते"T                             -- UTF-8 Unicode strings (Sanskrit for "Namaste")
Say "Barcelona"                         -- String quotes may have a different color

/* After the Executor extension below, all strings will have a new method "Giraffe"     */

Say "abc"~giraffe                       -- Prints "🦒"

::Constant Ducks "🦆🦆🦆"G             -- A Graphemes TUTOR string

::Extension String                      -- We are extending the predefined String class

--- The Giraffe method. This is a doc-comment
--- @param optional Does nothing

::Method Giraffe                        -- Directive keywords can have their own highlighting
  Use Arg optional
  Return "🦒"