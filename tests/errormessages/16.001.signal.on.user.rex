-- EARLY ERROR DETECTION --
-- This error is catched at execution time by the ooRexx interpreter, and,
-- if asked, at parse time by the Rexx parser. 
signal on user cond; call p; p: procedure; raise user cond return
