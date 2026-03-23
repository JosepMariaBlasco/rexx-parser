/******************************************************************************/
/*                                                                            */
/* md2epub.rex - Markdown to EPUB conversion tool                             */
/* ==============================================                             */
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
/* 20260323    0.1  First version                                             */
/*                                                                            */
/******************************************************************************/

  Call Time "R"

  CLIhelper    =  InitCLI()
  myName       =  CLIhelper~name
  myHelp       =  CLIhelper~help
  args         =  CLIhelper~args
  rootDir      = .File~new(.context~package~name)~parentFile~parent
  rootDir      =  ChangeStr("\",rootDir,"/")

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
  cliStyle       = 0                    -- Track if --style was specified
  language       = "en"
  defaultOptions = ""
  csl            = "rexxpub"            -- Default Citation Style Language style
  continue       = 0
  sectionNumbers = -1                   -- -1 = use docclass default
  numberFigures  = 1
  executor       = 0
  experimental   = 0
  unicode        = 0
  itrace         = 0
  cssDir         = ""
  highlightStyle = "pygments"           -- Default Pandoc highlight style
  coverImage     = ""
  chapterLevel   = 1

ProcessOptions:

  Loop While args~size > 0, args[1][1] == "-"
    option = args[1]
    args~delete(1)

    Select Case Lower(option)
      When "-h",  "--help"    Then Signal Help
      When "-it", "--itrace"  Then itrace = 1
      When "--continue"       Then continue = 1
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
        csl = args[1]
        args~delete(1)
      End
      When "-c", "--css"      Then Do
        If args~size == 0 Then
          Call Error "Missing CSS directory after '"option"' option."
        cssDir = args[1]
        args~delete(1)
      End
      When "--style" Then Do
        If args~size == 0 Then
          Call Error "Missing style name after '"option"' option."
        defaultTheme = Lower(args[1])
        cliStyle = 1
        args~delete(1)
      End
      When "--pandoc-highlighting-style" Then Do
        If args~size == 0 Then
          Call Error "Missing style name after '"option"' option."
        highlightStyle = Lower(args[1])
        args~delete(1)
      End
      When "--cover" Then Do
        If args~size == 0 Then
          Call Error "Missing image file after '"option"' option."
        coverImage = args[1]
        args~delete(1)
      End
      When "--chapter-level" Then Do
        If args~size == 0 Then
          Call Error "Missing number after '"option"' option."
        chapterLevel = args[1]
        args~delete(1)
        If \chapterLevel~dataType("W") | chapterLevel < 1 | chapterLevel > 6 Then
          Call Error "Chapter level must be a number between 1 and 6."
      End
      Otherwise Call Error "Invalid option '"option"'."
    End
  End

  -- Determine the CSS base directory
  If cssDir == "" Then cssDir = rootDir"/css"
  Else Do
    If \SysFileExists(cssDir) Then
      Call Error "CSS directory '"cssDir"' not found."
    If \SysIsFileDirectory(cssDir) Then
      Call Error "'"cssDir"' is not a directory."
    cssDir = .File~new(cssDir)~absolutePath
  End

  -- Validate the highlighting style (EPUB needs flattened CSS,
  -- because ebook readers do not support CSS nesting)
  cssFile = cssDir"/flattened/rexx-"defaultTheme".css"
  If \.File~new(cssFile)~exists Then
    Call Error "Style '"defaultTheme"' not found."
  If  .File~new(cssFile)~isDirectory Then
    Call Error "File '"cssFile"' is a directory."

  -- Resolve the CSL file path.
  If csl~contains("/") | csl~contains("\") Then Do
    cslPath = csl
    If \.File~new(cslPath)~exists Then
      Call Error 'CSL file "'cslPath'" not found.'
  End
  Else Do
    cslPath = rootDir"/csl/"Lower(csl)".csl"
    If \.File~new(cslPath)~exists Then
      Call Error 'CSL style "'csl'.csl" not found in the "'rootDir'/csl" directory.'
  End

  ------------------------------------------------------------------------------
  -- Determine mode: single file or batch directory                           --
  ------------------------------------------------------------------------------

  mode = "single"

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
      Call ProcessFile file, ""
      Exit
    End
    When 2 Then Do
      arg1 = args[1]
      If \SysFileExists(arg1) Then Do
        If SysFileExists(arg1".md") Then
          Call Error "Unexpected argument '"args[2]"'."
        Call Error "'"arg1"' not found."
      End
      If SysIsFileDirectory(arg1) Then
        Signal BatchMode
      Call Error "Unexpected argument '"args[2]"'."
    End
    Otherwise Call Error "Unexpected argument '"args[3]"'."
  End

  Exit

  ------------------------------------------------------------------------------
  -- Batch directory mode                                                     --
  ------------------------------------------------------------------------------

BatchMode:
  mode = "batch"

  source = .File~new(arg1)~absolutePath

  If args~items == 2 Then Do
    destination = args[2]
    If \SysFileExists(destination) Then
      Call Error "Destination directory '"destination"' does not exist."
    If \SysIsFileDirectory(destination) Then
      Call Error "'"destination"' is not a directory."
    destination = .File~new(destination)~absolutePath
  End
  Else destination = ""                   -- EPUBs go alongside their .md files

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
    relPath = SubStr(md.i, prefixLength)

    If destination \== "" Then Do
      relDir = FileSpec("Location", relPath)
      outDir = destination || sep || relDir
      Call SysMkDir outDir
    End
    Else outDir = ""

    Say Time("Long") "Processing" relPath"..."
    savedDir = Directory()
    Call Directory file~parentFile~absolutePath
    processRC = ProcessFile(md.i, outDir)
    Call Directory savedDir

    If processRC == 0
      Then processed += 1
      Else Do
        failed += 1
        If \continue Then Do
          Say "Aborting (use --continue to process remaining files)."
          Exit 1
        End
      End
  End

  If failed == 0
    Then Say Time("Long") "Processed" processed "files, took" Time("E") "seconds."
    Else Say Time("Long") "Processed" processed "files (" failed "failed),"  -
      "took" Time("E") "seconds."

  If failed > 0 Then Exit 1
  Exit 0

--------------------------------------------------------------------------------

ProcessFile: Procedure Expose rootDir cssDir cssFile check fail -
  defaultTheme cliStyle defaultOptions language continue -
  itrace cslPath sectionNumbers executor experimental unicode mode -
  numberFigures highlightStyle coverImage chapterLevel

  Use Strict Arg file, outputDir = ""

  fileName = FileSpec("Name", file)
  If fileName~endsWith(".md") Then
    fileName = Left(fileName,Length(fileName)-3)

  source = File2Array(file)

  ------------------------------------------------------------------------------
  -- Parse YAML front matter for RexxPub options                              --
  ------------------------------------------------------------------------------

  yaml = YAMLFrontMatter(source)
  opts = ParseRexxPubYAML(yaml)

  -- style: CLI > YAML > default
  thisTheme = defaultTheme
  If \cliStyle, opts["style"] \== .Nil Then
    thisTheme = opts["style"]

  -- Structural options: YAML wins
  thisLanguage       = language
  thisSectionNumbers = sectionNumbers
  thisNumberFigures  = numberFigures
  thisChapterLevel   = chapterLevel
  thisCoverImage     = coverImage

  If opts["language"]        \== .Nil Then thisLanguage       = opts["language"]
  If opts["section-numbers"] \== .Nil Then thisSectionNumbers = opts["section-numbers"]
  If opts["number-figures"]  \== .Nil Then thisNumberFigures  = opts["number-figures"]
  If opts["highlight-style"] \== .Nil Then highlightStyle     = opts["highlight-style"]

  -- EPUB-specific YAML options
  If opts["cover"]           \== .Nil Then thisCoverImage     = opts["cover"]
  If opts["chapter-level"]   \== .Nil Then thisChapterLevel   = opts["chapter-level"]

  -- Resolve sectionNumbers default (use article defaults for EPUB)
  If thisSectionNumbers == -1 Then thisSectionNumbers = 3

  fileObj   = .File~new(file)
  sep       = .File~separator
  absFile   = fileObj~absolutePath
  extension = FileSpec("Extension",absFile)
  name      = FileSpec("Name",absFile)
  name      = Left(name, Length(name) - Length(extension) - 1)
  fileDir   = fileObj~parent

  Signal On Syntax Name IndividualFileFailed

  combinedDefaults = defaultOptions
  If executor     Then combinedDefaults = Strip(combinedDefaults "executor")
  If experimental Then combinedDefaults = Strip(combinedDefaults "experimental")
  If unicode      Then combinedDefaults = Strip(combinedDefaults "unicode")

  options. = 0
  options.default  = combinedDefaults

  If mode == "single" Then options.["CONTINUE"] = 1
  Else If continue Then options.["CONTINUE"] = 1

  source = FencedCode( file, source, thisTheme, options. )

  Signal Off Syntax
  Signal AllWentWell

IndividualFileFailed:
  If \IsAParseError(Condition("O"), itrace) Then Raise Propagate
  Return 1

AllWentWell:

  ------------------------------------------------------------------------------
  -- Build the list of CSS files to embed in the EPUB                         --
  ------------------------------------------------------------------------------

  cssFiles = .Array~new

  -- Main highlighting theme
  cssFiles~append(cssFile)

  -- Pandoc syntax highlighting CSS
  pandocCSSFile = cssDir"/pandoc/"highlightStyle".css"
  If .File~new(pandocCSSFile)~exists Then
    cssFiles~append(pandocCSSFile)
  Else Do
    pandocCSSFile = cssDir"/pandoc/pygments.css"
    If .File~new(pandocCSSFile)~exists Then
      cssFiles~append(pandocCSSFile)
  End

  -- Scan source for per-block highlighting styles and add them
  contents = source~makeString
  allowed  = XRange("ALNUM")".-_"
  loaded   = .Set~new
  rest     = contents
  Loop While rest~pos('class="highlight-rexx-') > 0
    Parse Var rest 'class="highlight-rexx-'extraStyle'"'rest
    If extraStyle == "" Then Iterate
    If extraStyle~verify(allowed) > 0 Then Iterate
    If extraStyle == thisTheme Then Iterate
    If loaded~hasIndex(extraStyle) Then Iterate
    extraCSSFile = cssDir"/flattened/rexx-"extraStyle".css"
    If .File~new(extraCSSFile)~exists, \.File~new(extraCSSFile)~isDirectory Then Do
      cssFiles~append(extraCSSFile)
      loaded~put(extraStyle)
    End
  End

  ------------------------------------------------------------------------------
  -- Invoke Pandoc to generate EPUB                                           --
  ------------------------------------------------------------------------------

  -- Determine the output directory for the EPUB
  If outputDir \== ""
    Then outDir = outputDir
    Else outDir = fileDir

  outFile = outDir || sep || name".epub"

  ------------------------------------------------------------------------------
  -- Extract the title from the Markdown source                               --
  -- Look for a Setext h1 (underlined with ===) or ATX h1 (# Title)          --
  ------------------------------------------------------------------------------

  title = ""
  Loop j = 1 To source~items
    line = source[j]~strip
    If line == "" Then Iterate
    If line~left(2) == "# " Then Do
      title = line~substr(3)~strip
      Leave
    End
    If j < source~items Then Do
      nextLine = source[j+1]~strip
      If nextLine \== "", nextLine~verify("=") == 0 Then Do
        title = line
        Leave
      End
    End
  End
  -- Strip Pandoc attributes like {.class} and <small> subtitles
  If title~pos("{") > 0 Then
    Parse Var title title "{"
  If title~caselessPos("<small>") > 0 Then
    Parse Caseless Var title title "<small>"
  title = title~strip
  If title == "" Then title = fileName

  -- Build Pandoc command
  pandocCommand = 'pandoc'                                   -
    '--to epub'                                              -
    '--citeproc'                                             -
    '--csl="'cslPath'"'                                      -
    '-M link-citations=true'                                 -
    '-M title="'title'"'                                     -
    '--epub-chapter-level='thisChapterLevel                  -
    '-M lang='thisLanguage                                   -
    '-o "'outFile'"'

  -- Add CSS files
  Loop cssItem Over cssFiles
    pandocCommand ||= ' --css="'cssItem'"'
  End

  -- Add cover image if specified
  If thisCoverImage \== "" Then Do
    If .File~new(thisCoverImage)~exists Then
      pandocCommand ||= ' --epub-cover-image="'thisCoverImage'"'
    Else
     .Error~Say( "Warning: cover image '"thisCoverImage"' not found, ignored." )
  End

 .Error~CharOut("Invoking Pandoc (EPUB)... ")
  Address COMMAND pandocCommand -
    With Input Using (source) Error Stem Error.
  If rc \== 0 Then Do
   .Error~Say(fail "Pandoc failed with return code" rc":")
    Loop i = 1 To Error.0
     .Error~Say(Error.i)
    End
    Return rc
  End
 .Error~say(check)

  Return 0

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
myname -- Convert Markdown documents to EPUB using Pandoc

Usage: [rexx] myname OPTIONS filename
       [rexx] myname OPTIONS source-directory [destination-directory]

When the argument is a file, convert that single file to EPUB.
When the argument is a directory, convert all .md files in it
(and its subdirectories) to EPUB.

If a destination directory is given, the output EPUB files are
placed there, replicating the source directory structure.
Otherwise, each EPUB is placed alongside its source .md file.

Options:

--chapter-level N     Set the heading level for EPUB chapter splits
                      (default: 1)
--continue            Continue when a file fails (batch mode)
--cover FILE          Set the cover image for the EPUB
-c, --css DIR         Set the CSS base directory
--csl NAME|PATH       Sets the Citation Style Language style
                      (name looks in csl/; path is used as-is)
--default OPTIONS     Set default options for Rexx code blocks
-exp, --experimental  Enable Experimental features for all code blocks
-h, --help            Display this help
-it, --itrace         Print internal traceback on error
--style NAME          Set the default visual theme for Rexx code blocks
--pandoc-highlighting-style NAME
                      Set Pandoc syntax highlighting theme for non-Rexx
                      code blocks (default: pygments)
-u, --tutor,
    --unicode         Enable TUTOR-flavoured Unicode for all code blocks
-xtr, --executor      Enable Executor support for all code blocks

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::End

::Requires "BaseClassesAndRoutines.cls"
::Requires "ErrorHandler.cls"
::Requires "CLISupport.cls"
::Requires "FencedCode.cls"
::Requires "YAMLFrontMatter.cls"
::Requires "RexxPubOptions.cls"