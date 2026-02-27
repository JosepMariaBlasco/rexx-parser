/******************************************************************************/
/*                                                                            */
/* md2pdf.rex - Markdown to PDF conversion tool                               */
/* ============================================                               */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260219    0.4a First public release                                      */
/*                                                                            */
/******************************************************************************/

  package =  .context~package

  myName  =  package~name
  rootDir = .File~new(myName)~parentFile~parent
  rootDir =  ChangeStr("\",rootDir,"/")
  Parse Caseless Value FileSpec( "Name", myName ) With myName".rex"
  myHelp  = ChangeStr(                                         -
   "myName",                                                   -
   "https://rexx.epbcn.com/rexx-parser/doc/utilities/myName/", -
    myName)
  Parse Source . how .
  If how == "COMMAND", .SysCArgs \== .Nil
    Then args = .SysCArgs
    Else args = ArgArray(Arg(1))

  defaultTheme   = "dark"
  docClass       = "article"
  quiet          = .False
  language       = "en"
  defaultOptions = ""
  csl            = "ieee"               -- Default Citation Style Language style

ProcessOptions:

  Loop While args~size > 0, args[1][1] == "-"
    option = args[1]
    args~delete(1)

    Select Case Lower(option)
      When "-h",  "--help"    Then Signal Help
      When "-it", "--itrace"  Then itrace = 1
      When "--check-deps"     Then Call CheckDeps
      When "--default"        Then Do
        If args~size == 0 Then
          Call Error "Missing options after '"option"' option."
        defaultOptions = args[1]
        args~delete(1)
      End
      When "--csl"            Then Do
        If args~size == 0 Then
          Call Error "Missing CSL style name after '"option"' option."
        csl = Lower(args[1])
        If \.File~new(rootDir"/"csl".csl")~exists Then
          Call Error 'CSL style "'csl'.csl" not found in the "'rootDir'/csl" directory.'
        args~delete(1)
      End
      When "-l", "--language" Then Do
        If args~size == 0 Then
          Call Error "Missing language code after '"option"' option."
        language = Lower(args[1])
        args~delete(1)
      End
      When "--style" Then Do
        If args~size == 0 Then
          Call Error "Missing style name after '"option"' option."
        defaultTheme = Lower(args[1])
        args~delete(1)
      End
      When "--docclass" Then Do
        If args~size == 0 Then
          Call Error "Missing class name after '"option"' option."
        docClass = Lower(args[1])
        args~delete(1)
      End
      Otherwise Call Error "Invalid option '"option"'."
    End
  End

  cssFile = rootDir"/css/flattened/rexx-"defaultTheme".css"
  If \.File~new(cssFile)~exists Then
     Call Error "Style '"defaultTheme"' not found."
  If  .File~new(cssFile)~isDirectory Then
     Call Error "File '"cssFile"' is a directory."

  docClassFile = rootDir"/css/print/"docClass".css"
  If \.File~new(docClassFile)~exists Then
     Call Error "Document class '"docClass"' not found."
  If  .File~new(docClassFile)~isDirectory Then
     Call Error "File '"docClassFile"' is a directory."

  Select Case args~items
    When 0 Then Signal Help
    When 1 Then Do
      file = args[1]
      If \SysFileExists(file) Then Do
        If SysFileExists(file".md") Then file ||= ".md"
        Else Call Error "File '"file"' not found."
      End
      If SysIsFileDirectory(file) Then
        Call Error "'"file"' is a directory."
    End
    Otherwise Call Error "Unexpected argument '"args[2]"'."
  End

  source       =  CharIn(file,1,Chars(file))~makeArray
  Call Stream file, "c", "Close"

  fileObj      = .File~new(file)
  sep          = .File~separator
  absFile      =  fileObj~absolutePath
  extension    =  FileSpec("Extension",absFile)
  name         =  FileSpec("Name",absFile)
  name         =  Left(name, Length(name) - Length(extension) - 1)
  fileDir      =  fileObj~parent
  tmpDir       = .File~temporaryPath~absolutePath
  htmlFilename =  SysTempFileName(tmpDir"/"name"?????.html")

  bootstrap    =  rootDir"/css/bootstrap.css"

  CSS          =  CharIn(bootstrap,    1,Chars(bootstrap)    )
  CSS        ||=  CharIn(cssFile,      1,Chars(cssFile)      )
  CSS        ||=  CharIn(docClassFile, 1,Chars(docClassFile) )

  HTML         = .Resources~HTML~makeString
  HTML         =  HTML~caselessChangeStr("%CSS%",CSS)

  Signal On Syntax Name IndividualFileFailed

  defaultOptions. = 0
  defaultOptions.default  = defaultOptions

  source = FencedCode( file, source, defaultTheme, defaultOptions. )

  Signal Off Syntax
  Signal AllWentWell

IndividualFileFailed:
  co         = condition("O")
  additional = Condition("A")
  extra = additional~lastitem
  If \extra~hasMethod("position") Then Raise Propagate
  line  = extra~position
  Parse Value co~code With major"."minor
 .Error~Say( Right(line,6) "*-*" extra~sourceline                            )
   -- Try to reconstruct the line number if we have enough information
  name = extra~name
  majorMessagePrinted = 0
  If Right(name,1) == "]" Then Do
    Parse Var name name1" [lines "start"-"end"]"
    If name == name1" [lines "start"-"end"]" Then Do
      majorMessagePrinted = 1
     .Error~Say( "Error" major "in" name1", line" (start+line)": " ErrorText(major) )
    End
  End
  If \majorMessagePrinted Then
   .Error~Say( "Error" major "in" extra~name", line" line": " ErrorText(major) )
 .Error~Say( "Error" co~code": " Ansi.ErrorText( co~code, additional )       )

  If itrace Then Do
   .Error~Say
   .Error~Say( "Trace follows:"         )
   .Error~Say( Copies("-",80)           )
   .Error~Say( co~stackFrames~makeArray )
  End

  Exit

AllWentWell:

  contents = .Array~new
  pandocCommand = 'pandoc' -
   '--citeproc' -
   '--csl="'rootDir'/csl/'csl'.csl"' -
   '--lua-filter="'rootDir'/cgi/inline-footnotes.lua"'
  -- Say pandocCommand /* For debug */
 .Error~CharOut("Invoking Pandoc... ")
  Address COMMAND pandocCommand -
    With Input Using (source) Output Using (contents) Error Stem Error.
  If rc \== 0 Then Do
   .Error~Say("❌ Pandoc failed with return code" rc":")
    Loop i = 1 To Error.0
     .Error~Say(Error.i)
    End
    Exit rc
  End
 .Error~say('✔')

  contents = contents~makeString
  Parse Caseless Var contents With "<h1" ">"title"</"
  If title = "" Then title = "*** Missing title ***"
  Parse Caseless Var title title "<small>"
  HTML = HTML                                 -
    ~caselessChangeStr("%language%",language) -
    ~caselessChangeStr("%content%",contents)  -
    ~caselessChangeStr("%title%",  title   )

  Call SysFileDelete htmlFilename

  Call lineout htmlFilename, HTML
  Call lineout htmlFilename

 .Error~Say("Invoking pagedjs-cli (this may take some time)... ")
  cmd = 'pagedjs-cli "'htmlFilename'" -o "'fileDir || sep || name'.pdf"'
  Address COMMAND cmd

  Call SysFileDelete htmlFilename

  Exit rc

--------------------------------------------------------------------------------

CheckDeps: -- Check dependencies

  ------------------------------------------------------------------------------
  -- Ensure that pandoc is installed                                          --
  ------------------------------------------------------------------------------

 .Error~charOut("Checking that pandoc is installed...")
  Address COMMAND "pandoc -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " ❌" myName "needs a working version of pandoc."
 .Error~say('✔')

  ------------------------------------------------------------------------------
  -- Ensure that node is installed                                            --
  ------------------------------------------------------------------------------

.Error~charOut("Checking that Node.js is installed...")
  Address COMMAND "node -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " ❌" myName "needs a working version of Node.js."
 .Error~say('✔')

  ------------------------------------------------------------------------------
  -- Ensure that npm is installed                                             --
  ------------------------------------------------------------------------------

 .Error~charOut("Checking that npm is installed...")
  Address COMMAND "npm -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " ❌" myName "needs a working version of npm."
 .Error~say('✔')

  ------------------------------------------------------------------------------
  -- Ensure that we have pagedjs-cli is installed                             --
  ------------------------------------------------------------------------------

 .Error~charOut("Checking that pagedjs-cli is installed...")
  Address COMMAND "pagedjs-cli --help" -
    With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " ❌" myName "needs a working version of pagedjs-cli."
 .Error~say('✔')

Return

--------------------------------------------------------------------------------

Error:
 .Error~Say(Arg(1))
  Exit 1

--------------------------------------------------------------------------------

Help:
  Say .Resources[Help]~makeString        -
    ~caselessChangeStr("myName", myName) -
    ~caselessChangeStr("myHelp", myHelp)
  Exit 1

::Resource Help End "::End"
myname -- Convert Markdown documents to styled PDF using Pandoc and paged.js

Usage: [rexx] myname OPTIONS filename

Options:

--check-deps          Checks that all the dependencies are installed
--csl NAME            Sets the Citation Style Language style
--defaultoptions OPTS Set default options for Rexx code blocks
--docclass CLASS      Control overall layout and CSS class
-h, --help            Display this help
-it, --itrace         Print internal traceback on error
-l, --language CODE   Set document language (e.g. en, es, fr)
--style NAME          Set the default visual theme for Rexx code blocks

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::End

::Requires "ANSI.ErrorText.cls"
::Requires "BaseClassesAndRoutines.cls"
::Requires "ErrorHandler.cls"
::Requires "FencedCode.cls"

::Resource HTML
<!doctype html>
<html lang='%Language%'>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>
      %Title%
    </title>
    <style>
      %CSS%
    </style>
  </head>
  <body>
    <div class='container bg-white' lang='en'>
      <div class="row">
         <div class="content">
            %Content%
         </div>
      </div>
    </div>
  </body>
</html>
::END