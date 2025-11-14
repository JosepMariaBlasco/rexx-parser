#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* EnableExperimentalFeatures.rex                                             */
/* ==============================                                             */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20251113    0.3a First version                                             */
/*                                                                            */
/******************************************************************************/

-- We have to pass the caller's .METHODS stringtable as a parameter
-- because of https://sourceforge.net/p/oorexx/bugs/2037/

Use Strict Arg methods

/******************************************************************************/
/* Implement METHOD EXTENDS and METHOD OVERRIDES                              */
/******************************************************************************/

pkgLocal = .context~package~local
pkgLocal~classExtensions = .Set~new

callerPackage = .context~stackFrames[2]~executable~package

-- Ensure that we process extension methods only once per caller
If .ClassExtensions~hasIndex( callerPackage ) Then Return
.ClassExtensions[] = callerPackage

-- Extension methods have the following syntax:
--
--   ::METHOD methodName ... EXTENDS   class ...
--   ::METHOD methodName ... OVERRIDES class ...
--
-- where class is
--
--   [nameSpace:]className
--
-- The compiler for Experimental features removes the EXTENDS or
-- OVERRIDES phrase, and replaces the method name by
--
--   '"'methodName"<"sep">"[nameSpace:]className'"',
--
-- where sep is "+" for EXTENDS and "*" for OVERRIDES.
--

extends   = "<+>"
overrides = "<*>"

-- We first check all floating methods defined by the caller.

Do name Over methods
  Select
    When Pos(extends,   name) > 0 Then Do
      Parse Var name methodName(extends)className
      Call ProcessNameSpaceAndFindClass
      If HasMethod( class, methodName ) Then
        Raise Syntax 99.900 Array("Method" methodName "already defined in class" className)
    End
    When Pos(overrides, name) > 0 Then Do
      Parse Var name methodName(overrides)className
      Call ProcessNameSpaceAndFindClass
    End
    Otherwise Iterate
  End
  -- Define the method in the extended class...
  class~define( methodName, methods[ name ] )
  -- ...and remove it from the caller's .METHODS stringTable.
  methods~remove(name)
End

-- We now check all classes defined in the caller package.

Do With item containingClass Over callerPackage~classes
  Do With Index name Item method Over containingClass~methods
    If method == .Nil Then Iterate -- Skip over hidden methods
    Select
      When Pos(extends,   name) > 0 Then Do
        Parse Var name methodName(extends)className
        Call ProcessNameSpaceAndFindClass
        If HasMethod( class, methodName ) Then
          Raise Syntax 99.900 Array("Method" methodName "already defined in class" className)
      End
      When Pos(overrides, name) > 0 Then Do
        Parse Var name methodName(overrides)className
        Call ProcessNameSpaceAndFindClass
      End
      Otherwise Iterate
    End
    -- Define the method in the extended class...
    class~define( methodName, method )
    -- ...and remove it from the class where it was defined.
    containingClass~delete(name)
  End
End

Exit

ProcessNameSpaceAndFindClass:
  If Pos(":", className) > 0 Then Do
    Parse Var className nameSpace":"className
    package = callerPackage~findNameSpace( nameSpace)
    If package == .Nil Then
      Raise Syntax 98.987 Array(nameSpace, callerPackage~name)
  End
  Else package = callerPackage
  class = package~findClass(className)
  If class == .Nil Then Raise Syntax 98.909 Array(className)
Return

--------------------------------------------------------------------------------
-- The definition of ~method is very strange: it traps when the method does   --
-- not exist...                                                               --
--------------------------------------------------------------------------------

HasMethod: Signal On Syntax Name StrangeAPI

  throwAway = Arg(1)~method( Arg(2) )
  Return 1

StrangeAPI: Return 0