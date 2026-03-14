/******************************************************************************/
/*                                                                            */
/* CLISupport.cls -- Common CLI boilerplate for Rexx Parser utilities         */
/* ==================================================================         */
/*                                                                            */
/* This file is part of the Rexx Parser package                               */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260314    0.5   Initial version                                          */
/*                                                                            */
/******************************************************************************/

/******************************************************************************/
/*                                                                            */
/* InitCLI() -- Common utility initialization                                 */
/*                                                                            */
/* Performs the standard initialization sequence shared by all Rexx Parser    */
/* command-line utilities: extracts the program name, builds the help URL,    */
/* and resolves command-line arguments.                                       */
/*                                                                            */
/* No arguments are needed.  The routine inspects the call stack to find      */
/* the caller's program name and arguments:                                   */
/*                                                                            */
/*   .context~stackFrames[1]  is InitCLI itself                               */
/*   .context~stackFrames[2]  is the caller (type PROGRAM), providing:        */
/*     ~name       the full path of the .rex file                             */
/*     ~arguments  the Arg(1) passed to the prolog                            */
/*                                                                            */
/* .SysCArgs (in .Local) is used when available (COMMAND invocation);         */
/* otherwise the prolog's Arg(1) is parsed via ArgArray().                    */
/*                                                                            */
/* Returns: an Array with three items:                                        */
/*   callerName  - Program name without .rex extension (e.g. "highlight")     */
/*   callerHelp  - URL pointing to the utility's documentation                */
/*   args    - An Array of command-line arguments                             */
/*                                                                            */
/* Usage:                                                                     */
/*                                                                            */
/*   CLIhelper = InitCLI()                                                    */
/*   myName = CLIhelper~name                                                  */
/*   myHelp = CLIhelper~help                                                  */
/*   myArgs = CLIhelper~args                                                  */
/*                                                                            */
/******************************************************************************/

::Routine InitCLI Public

  frames    = .context~stackFrames
  caller    =  frames[2]
  stackSize =  frames~size

  callerName = caller~name
  Parse Caseless Value FileSpec("Name", callerName) With callerName".rex"
  callerHelp = ChangeStr(                                          -
   "callerName",                                                   -
   "https://rexx.epbcn.com/rexx-parser/doc/utilities/callerName/", -
    callerName)

  If stackSize == 2, .SysCArgs \== .Nil Then callerArgs = .SysCArgs
  Else Do
    callerArgs = caller~arguments
    If callerArgs~items > 0
      Then callerArgs =  ArgArray(callerArgs[1])
      Else callerArgs = .Array~new
  End

  CLIHelper      = .Directory~new
  CLIHelper~name =  callerName
  CLIHelper~help =  callerHelp
  CLIHelper~args =  callerArgs

  Return CLIHelper

::Requires "BaseClassesAndRoutines.cls"