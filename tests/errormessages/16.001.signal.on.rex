-- EARLY ERROR DETECTION --
-- This error is catched at execution time by the ooRexx interpreter, and,
-- if asked, at parse time by the Rexx parser. We include the offending
-- instruction ("1/0") in the same line as the SIGNAL ON line so that the
-- error line reported is the same in both cases.
Signal On Syntax; 1/0