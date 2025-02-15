/******************************************************************************/
/*                                                                            */
/* Load.Parser.Module.rex                                                     */
/* ======================                                                     */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx.parser/]                                  */
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
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/* A common initializer for all Rexx parser modules                           */
/******************************************************************************/

-- A list of package names (without the .cls extension), separated by blanks
Use Strict Arg dependencies = ""

-- We were called by (a prolog routine), located in a certain package.
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
--   className":"methodName
--
-- Such a method name will be ~defined into the className class with the
-- name methodName and the source found in the caller package.
--
methods = callerPackage~definedMethods
Do name Over methods
  Parse Var name class":"method
  If .environment[ class ] == .Nil Then Do
    Say "Internal error! Class" class "not found."
    Raise Halt
  End
  .environment[ class ] ~ define( method, methods[ name ] )
End
