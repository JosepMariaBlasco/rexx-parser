/******************************************************************************/
/*                                                                            */
/* Load.Parser.Module.rex                                                     */
/* ======================                                                     */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
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
/* 20241206    0.1  First public release                                      */
/* 20250318    0.2  Change syntax to class::method                            */
/* 20250326         Detect when a module tries to define an already-defined   */
/*                  method.                                                   */
/* 20250328         Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250714    0.2d Add 'override' parameter                                  */
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/* A common initializer for all Rexx parser modules                           */
/******************************************************************************/

--
-- Parameters
--
-- Dependencies: A list of package names (without the .cls extension),
--   separated by blanks
-- Override: true when existing methods can be redefined by this execution
--   of the loader.
Use Strict Arg dependencies = "", override = 0

-- We were called by a prolog routine, located in a certain package.
callerPackage = .context~stackFrames[2]~executable~package

-- Ensure that we run this initializer only once per package
If callerPackage~local~initializerRun == 1 Then Return
callerPackage~local~initializerRun = 1

-- Store public classes defined by the caller package in the global environment
Do With index name item class Over callerPackage~publicClasses
  .environment[name] = class
End

-- Now load the requested dependencies
Do package Over dependencies~makeArray(" ")
  callerPackage~loadPackage(package".cls")
End

-- Floating methods name format:
--
--   className"::"methodName
--
-- Such a method name will be ~defined into the className class with the
-- name methodName and the source found in the caller package.
--
methods = callerPackage~definedMethods
Do name Over methods
  Parse Var name class"::"method
  If .environment[ class ] == .Nil Then Do
    Say "Internal error! Class" class "not found."
    Raise Halt
  End
  theClass = .environment[ class ]
  If \override, HasMethod( theClass, method ) Then Do
    Say "Internal error! Method" method "already defined in class" class"."
    Raise Halt
  End
  theClass ~ define( method, methods[ name ] )
End

Exit

--------------------------------------------------------------------------------
-- The definition of ~method is very strange: it traps when the method does   --
-- not exist...                                                               --
--------------------------------------------------------------------------------

HasMethod: Signal On Syntax Name DementedAPI

  throwAway = Arg(1)~method( Arg(2) )
  Return 1

DementedAPI: Return 0