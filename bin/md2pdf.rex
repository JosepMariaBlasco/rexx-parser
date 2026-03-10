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
/* 20260228         Add --outline and --fix-outline                           */
/* 20260228         Add support for codepages other than 65001 (thanks, JLF!) */
/* 20250303    0.5  Add support for size and for letter and slides docclasses */
/* 20260307         Add batch directory mode                                  */
/* 20260308         Add support for optional --section-numbers                */
/* 20260308         Add -xtr, --executor, -exp, --experimental, -u, --unicode */
/* 20260310         Allow arbitrary sizes (thanks, JLF!)                      */
/* 20260310         Add -c, --css option (thanks, JLF!)                       */
/*                                                                            */
/******************************************************************************/

  Call Time "R"

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

  check = "✔"
  fail  = "❌"
  -- Under windows, if we are not using the UTF8 codepage,
  -- revert to plain ASCII.
  If .RexxInfo~platform~startsWith("Windows") Then Do
    Address COMMAND "CHCP" With Output Stem O.
    Parse Var O.1 ":" codepage .
    If codepage \== 65001 Then Do
      check = "[Ok]"
      fail  = "[Fail!]"
    End
  End

  defaultTheme   = "dark"
  docClass       = ""
  quiet          = .False
  language       = "en"
  defaultOptions = ""
  csl            = "rexxpub"            -- Default Citation Style Language style
  outline        = 3                    -- Outline H1, H2 and H3
  fixOutline     = 0
  size           = 12
  continue       = 0
  sectionNumbers = 0
  executor       = 0
  experimental   = 0
  unicode        = 0
  itrace         = 0
  cssDir         = ""

ProcessOptions:

  Loop While args~size > 0, args[1][1] == "-"
    option = args[1]
    args~delete(1)

    Select Case Lower(option)
      When "--fix-outline"    Then fixOutline = 1
      When "-h",  "--help"    Then Signal Help
      When "-it", "--itrace"  Then itrace = 1
      When "--check-deps"     Then Call CheckDeps
      When "--continue"       Then continue = 1
      When "--size"           Then Do
        If args~size == 0 Then
          Call Error "Missing size after '"option"' option."
        size = args[1]
        If Words(size) > 1 | \DataType(size,"W") | size < 1 Then
          Call Error "Size has to be a positive whole number, found '"size"'."
        args~delete(1)
      End
      When "--outline"        Then Do
        If args~size == 0 Then
          Call Error "Missing outline number after '"option"' option."
        outline = args[1]
        If \DataType(outline,"W") | outline < 0 | outline > 6 Then
          Call Error "Outline should be a non-negative whole number smaller than 7, found '"outline"'."
        args~delete(1)
      End
      When "--section-numbers" Then Do
        If args~size == 0 Then
          Call Error "Missing depth after '"option"' option."
        sectionNumbers = args[1]
        If \DataType(sectionNumbers,"W") | sectionNumbers < 0 | sectionNumbers > 4 Then
          Call Error "Section number depth should be a whole number between 0 and 4, found '"sectionNumbers"'."
        args~delete(1)
      End
      When "-xtr", "--executor"           Then executor     = 1
      When "-exp", "--experimental"       Then experimental = 1
      When "-u", "--tutor", "--unicode"   Then unicode      = 1
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
        If \.File~new(rootDir"/csl/"csl".csl")~exists Then
          Call Error 'CSL style "'csl'.csl" not found in the "'rootDir'/csl" directory.'
        args~delete(1)
      End
      When "-c", "--css"      Then Do
        If args~size == 0 Then
          Call Error "Missing CSS directory after '"option"' option."
        cssDir = args[1]
        If \SysFileExists(cssDir) Then
          Call Error "CSS directory '"cssDir"' not found."
        If \SysIsFileDirectory(cssDir) Then
          Call Error "'"cssDir"' is not a directory."
        cssDir = .File~new(cssDir)~absolutePath
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

  -- Determine the CSS base directory
  If cssDir == "" Then cssDir = rootDir"/css"

  -- Validate the highlighting style (common to both modes)
  cssFile = cssDir"/flattened/rexx-"defaultTheme".css"
  If \.File~new(cssFile)~exists Then
     Call Error "Style '"defaultTheme"' not found."
  If  .File~new(cssFile)~isDirectory Then
     Call Error "File '"cssFile"' is a directory."

  -- Precompute the CSS that is common to all files:
  -- Bootstrap + highlighting style + rexxpub base
  baseFile     =  cssDir"/print/rexxpub-base.css"
  bootstrap    =  cssDir"/bootstrap.css"
  commonCSS    =  CharIn(bootstrap, 1, Chars(bootstrap) )
  commonCSS  ||=  CharIn(cssFile,   1, Chars(cssFile)   )
  commonCSS  ||=  CharIn(baseFile,  1, Chars(baseFile)  )

  -- The HTML template is the same for all files
  HTMLtemplate = .Resources~HTML~makeString

  ------------------------------------------------------------------------------
  -- Determine mode: single file or batch directory                           --
  ------------------------------------------------------------------------------

  Select Case args~items
    When 0 Then Signal Help
    When 1 Then Do
      arg1 = args[1]
      If SysIsFileDirectory(arg1) Then
        Signal BatchMode
      -- Single file mode
      file = arg1
      If \SysFileExists(file) Then Do
        If SysFileExists(file".md") Then file ||= ".md"
        Else Call Error "File '"file"' not found."
      End
      Call Directory .File~new(file)~parentFile~absolutePath
      Call ProcessFile file, docClass
      Exit
    End
    When 2 Then Do
      arg1 = args[1]
      If \SysFileExists(arg1) Then Do
        If SysFileExists(arg1".md") Then
          -- Single file with .md appended; second argument is unexpected
          Call Error "Unexpected argument '"args[2]"'."
        Call Error "'"arg1"' not found."
      End
      If SysIsFileDirectory(arg1) Then
        Signal BatchMode
      -- arg1 is a file; second argument is unexpected
      Call Error "Unexpected argument '"args[2]"'."
    End
    Otherwise Call Error "Unexpected argument '"args[3]"'."
  End

  -- This is never reached
  Exit

  ------------------------------------------------------------------------------
  -- Batch directory mode                                                     --
  ------------------------------------------------------------------------------

BatchMode:

  source = .File~new(arg1)~absolutePath

  If args~items == 2 Then Do
    destination = args[2]
    If \SysFileExists(destination) Then
      Call Error "Destination directory '"destination"' does not exist."
    If \SysIsFileDirectory(destination) Then
      Call Error "'"destination"' is not a directory."
    destination = .File~new(destination)~absolutePath
  End
  Else destination = ""                   -- PDFs go alongside their .md files

  Call SysFileTree source || .File~separator || "*.md", "md.", "FOS"

  If md.0 == 0 Then Do
    Say "No .md files found in '"arg1"'. Nothing to do."
    Exit 0
  End

  prefixLength = Length(source) + 2
  processed    = 0
  failed       = 0
  sep          = .File~separator

  Loop i = 1 To md.0
    file = .File~new(md.i)

    If destination \== "" Then Do
      -- Replicate directory structure in destination
      dir    = SubStr(file~parent, prefixLength)
      new    = destination"/"dir
      newDir = .File~new(new)
      new    = newDir~absolutePath
      If newDir~exists Then Do
        If \newDir~isDirectory Then
          Call Error "'"new"' already exists, but it is not a directory. Aborting."
      End
      Else Do
        Say Time("Long") "Creating directory '"new"'..."
        If \newDir~makeDirs Then
          Call Error "Directory creation failed. Aborting..."
      End
    End

    Say Time("Long") "Processing" file"..."
    savedDir = Directory()
    Call Directory file~parent
    If destination \== ""
      Then processRC = ProcessFile(file~absolutePath, docClass, newDir~absolutePath)
      Else processRC = ProcessFile(file~absolutePath, docClass)
    Call Directory savedDir
    If processRC \== 0 Then Do
      failed += 1
      If \continue Then Do
        Say Copies("-",80)
        Say Time("Long") "Aborted after" processed "files (" failed "failed),"  -
          "took" Time("E") "seconds."
        Exit 1
      End
    End
    Else processed += 1
  End

  Say Copies("-",80)
  If failed == 0
    Then Say Time("Long") "Processed" processed "files, took" Time("E") "seconds."
    Else Say Time("Long") "Processed" processed "files (" failed "failed),"  -
      "took" Time("E") "seconds."

  If failed > 0 Then Exit 1
  Exit 0

--------------------------------------------------------------------------------

ProcessFile: Procedure Expose rootDir cssDir commonCSS HTMLtemplate check fail -
  defaultTheme defaultOptions language outline fixOutline size continue -
  itrace csl sectionNumbers executor experimental unicode

  Use Strict Arg file, requestedDocClass, outputDir = ""

  fileName = FileSpec("Name", file)
  If fileName~endsWith(".md") Then
    fileName = Left(fileName,Length(fileName)-3)

  -- Determine the document class for this file
  If requestedDocClass \== ""
    Then thisDocClass = requestedDocClass
    Else thisDocClass = fileName

  docClassFile = cssDir"/print/"thisDocClass".css"
  If \.File~new(docClassFile)~exists Then Do
    -- If the inferred class doesn't exist, fall back to default
    If requestedDocClass \== "" Then Do
      -- Explicit --docclass: no fallback, report error
     .Error~Say( "Document class '"thisDocClass"' not found." )
      Return 1
    End
    thisDocClass = "default"
    docClassFile = cssDir"/print/"thisDocClass".css"
    If \.File~new(docClassFile)~exists Then Do
     .Error~Say( "Document class 'default' not found." )
      Return 1
    End
  End
  If  .File~new(docClassFile)~isDirectory Then Do
   .Error~Say( "File '"docClassFile"' is a directory." )
    Return 1
  End

  sizeFile = cssDir"/print/"thisDocClass"-"size"pt.css"
  If \.File~new(sizeFile)~exists Then Do
    If size == 12 Then
      sizeFile = ""
    Else Do
     .Error~Say( "Size" size"pt not available for document class '"thisDocClass"'" -
        "(file '"thisDocClass"-"size"pt.css' not found)." )
      Return 1
    End
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

  -- Build the full CSS: common + docclass + size
  CSS          =  commonCSS
  CSS        ||=  CharIn(docClassFile, 1, Chars(docClassFile) )
  If sizeFile \== "" Then
    CSS      ||=  CharIn(sizeFile,     1, Chars(sizeFile)     )

  HTML         =  HTMLtemplate

  Signal On Syntax Name IndividualFileFailed

  combinedDefaults = defaultOptions
  If executor     Then combinedDefaults = Strip(combinedDefaults "executor")
  If experimental Then combinedDefaults = Strip(combinedDefaults "experimental")
  If unicode      Then combinedDefaults = Strip(combinedDefaults "unicode")

  defaultOptions. = 0
  defaultOptions.default  = combinedDefaults
  If continue Then defaultOptions.["CONTINUE"] = 1

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

  Return 1

AllWentWell:

  contents = .Array~new
  pandocCommand = 'pandoc' -
    '--citeproc' -
    '--csl="'rootDir'/csl/'csl'.csl"' -
    '-M link-citations=true' -
    '--lua-filter="'rootDir'/cgi/inline-footnotes.lua"'
  -- Say pandocCommand /* For debug */
 .Error~CharOut("Invoking Pandoc... ")
  Address COMMAND pandocCommand -
    With Input Using (source) Output Using (contents) Error Stem Error.
  If rc \== 0 Then Do
   .Error~Say(fail "Pandoc failed with return code" rc":")
    Loop i = 1 To Error.0
     .Error~Say(Error.i)
    End
    Return rc
  End
 .Error~say(check)

  contents = contents~makeString

  -- Scan for per-block highlighting styles (e.g. style=vim-dark-darkblue)
  -- and load the corresponding CSS files, same as the CGI does.
  allowed = XRange("ALNUM")".-_"
  loaded  = .Set~new
  rest = contents
  Loop While rest~pos('class="highlight-rexx-') > 0
    Parse Var rest 'class="highlight-rexx-'extraStyle'">'rest
    If extraStyle == "" Then Iterate
    If extraStyle~verify(allowed) > 0 Then Iterate
    If extraStyle == defaultTheme Then Iterate
    If loaded~hasIndex(extraStyle) Then Iterate
    extraCSSFile = cssDir"/flattened/rexx-"extraStyle".css"
    If .File~new(extraCSSFile)~exists, \.File~new(extraCSSFile)~isDirectory Then Do
      CSS ||= CharIn(extraCSSFile, 1, Chars(extraCSSFile))
      loaded~put(extraStyle)
    End
  End

  HTML = HTML~caselessChangeStr("%CSS%", CSS)

  If contents~~pos('div id="toc"') > 0 Then Do
    createToc =  rootDir"/js/createToc.js"
    chunk     =  CharIn(createToc, 1, Chars(createToc) )
    TOCHandler = "<script>"chunk"</script>"
  End
  Else TOCHandler = ""

  If sectionNumbers > 0 Then Do
    sectionNumbersClass = "section-numbers-"sectionNumbers
    numberSections = rootDir"/js/numberSections.js"
    chunk = CharIn(numberSections, 1, Chars(numberSections) )
    sectionNumbersHandler = "<script>"chunk"</script>"
  End
  Else Do
    sectionNumbersClass = ""
    sectionNumbersHandler = ""
  End

  Select Case fileName
    When "article", "slides", "book" Then Do
      Parse Caseless Var contents With "<h1" ">"title"</"
      If title = "" Then title = "*** Missing title ***"
      Parse Caseless Var title title "<small>"
      Do While title~caselessPos("<br>") > 0
        title = title~caselessChangeStr("<br>","")
      End
      Do While title~caselessPos("<br") > 0
        Parse Caseless Var title With before "<br" ">" after
        title = before after
      End
      Do While Pos("<",title) > 0
        Parse Var title before "<" ">" after
        title = before after
      End
    End
    When "letter" Then Do
      Parse Caseless Var contents With '<div class="recipient">' '<p>'title'</p>'
      If title \== "" Then title = "Letter to" title
      Else Do
        Parse Caseless Var contents With '<div class="opening">' '<p>'title'</p>'
        If title \== "" Then Do
          title = "Letter -" title
          If title~endsWith(",") Then title = Left(title, Length(title)-1)
        End
        Else title = "Letter"
      End
    End
    Otherwise title = fileName
  End

  HTML = HTML                                                   -
    ~caselessChangeStr("%Language%",       language           ) -
    ~caselessChangeStr("%Content%",        contents           ) -
    ~caselessChangeStr("%Title%",          title              ) -
    ~caselessChangeStr("%TOCHandler%",     TOCHandler         ) -
    ~caselessChangeStr("%SectionNumbers%", sectionNumbersClass) -
    ~caselessChangeStr("%SectionNumbersHandler%", sectionNumbersHandler)

  Call SysFileDelete htmlFilename

  Call lineout htmlFilename, HTML
  Call lineout htmlFilename

  outlineTags = "h1"
  Do i = 2 To outline
    outlineTags ||= ",h"i
  End

  -- Determine the output directory for the PDF
  If outputDir \== ""
    Then outDir = outputDir
    Else outDir = fileDir

 .Error~Say("Invoking pagedjs-cli (this may take some time)... ")
  outFile = '"'outDir || sep || name'.pdf"'
  cmd = 'pagedjs-cli "'htmlFilename'"'  -
    '--outline-tags' outlineTags -
    '-o' outFile
  Address COMMAND cmd
  cmdRC = rc

  Call SysFileDelete htmlFilename

  If cmdRC \== 0 Then Do
   .Error~Say(fail "pagedjs-cli failed with return code" cmdRC".")
    Return cmdRC
  End

  If fixOutline Then Do
   .Error~Say("Fixing PDF file so that the document outline opens automatically... ")
    Address COMMAND "python" rootDir"/bin/fix_pdf_outline.py" outFile
    If rc == 0 Then Say check "Document outline activated in" outFile
  End

  Return 0

--------------------------------------------------------------------------------

CheckDeps: -- Check dependencies

  ------------------------------------------------------------------------------
  -- Ensure that pandoc is installed                                          --
  ------------------------------------------------------------------------------

 .Error~charOut("Checking that pandoc is installed...")
  Address COMMAND "pandoc -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " "fail myName "needs a working version of pandoc."
 .Error~say(check)

  ------------------------------------------------------------------------------
  -- Ensure that node is installed                                            --
  ------------------------------------------------------------------------------

.Error~charOut("Checking that Node.js is installed...")
  Address COMMAND "node -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " "fail myName "needs a working version of Node.js."
 .Error~say(check)

  ------------------------------------------------------------------------------
  -- Ensure that npm is installed                                             --
  ------------------------------------------------------------------------------

 .Error~charOut("Checking that npm is installed...")
  Address COMMAND "npm -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " "fail myName "needs a working version of npm."
 .Error~say(check)

  ------------------------------------------------------------------------------
  -- Ensure that we have pagedjs-cli is installed                             --
  ------------------------------------------------------------------------------

 .Error~charOut("Checking that pagedjs-cli is installed...")
  Address COMMAND "pagedjs-cli --help" -
    With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error " "fail myName "needs a working version of pagedjs-cli."
 .Error~say(check)

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
       [rexx] myname OPTIONS source-directory [destination-directory]

When the argument is a file, convert that single file to PDF.
When the argument is a directory, convert all .md files in it
(and its subdirectories) to PDF.

If a destination directory is given, the output PDF files are
placed there, replicating the source directory structure.
Otherwise, each PDF is placed alongside its source .md file.

Options:

--check-deps          Checks that all the dependencies are installed
--continue            Continue when a file fails (batch mode)
-c, --css DIR         Set the CSS base directory
--csl NAME            Sets the Citation Style Language style
--default OPTIONS     Set default options for Rexx code blocks
--docclass CLASS      Control overall layout and CSS class
-exp, --experimental  Enable Experimental features for all code blocks
-h, --help            Display this help
-it, --itrace         Print internal traceback on error
-l, --language CODE   Set document language (e.g. en, es, fr)
--section-numbers n   Number sections down to depth n (0=off, max 4)
--size SIZE           Set the size in pt (default: 12)
--outline n           Generate outline with H1,...,Hn (default: 3)
--fix-outline         Fix PDF so that the outline shows automatically
                      (requires python and pikepdf)
--style NAME          Set the default visual theme for Rexx code blocks
-u, --tutor,
    --unicode         Enable TUTOR-flavoured Unicode for all code blocks
-xtr, --executor      Enable Executor support for all code blocks

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
         <div class="content %SectionNumbers%">
            %Content%
         </div>
      </div>
    </div>
    %SectionNumbersHandler%
    %TOCHandler%
  </body>
</html>
::END
