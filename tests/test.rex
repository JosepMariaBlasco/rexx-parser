#!/usr/bin/env rexx
do clz over .test, .testSingleton   -- iterate over the two classes
   rounds=3
   say "creating" rounds "objects of type:" clz
   do i=1 to rounds
      say "   round #" i":" clz~new -- create new instance
   end
   say
end

/* ========================================================================= */
/** This Test class counts the number of instances that get created for it.  */
::class Test
/* ------------- class method and class attribute definitions -------------- */
::method init class  -- class constructor
  expose counter
  counter=0          -- make sure attribute is initialized to 0

::attribute counter get private class  -- getter method that increases counter
  expose counter     -- access attribute
  counter+=1         -- increase counter by 1
  return counter     -- return new counter value
/* ------------- instance method and instance attribute definitions -------- */
::attribute nr get   -- getter method

::method init        -- constructor that sets the value of attribute nr
  expose nr          -- expose attribute
  nr=self~class~counter -- new instance: fetch new counter from class and save it

::method makestring  -- a string representation of the object
  expose nr          -- expose attribute
                     -- return a string representation
  return "a" self~class~id"[nr="nr",identityHash="self~identityHash"]"

/* ========================================================================= */
/** This class makes sure that only a single instance of it gets created by
*   using Singleton as its metaclass.
*/
::class TestSingleton subclass Test metaclass Singleton