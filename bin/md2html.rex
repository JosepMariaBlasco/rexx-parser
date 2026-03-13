/******************************************************************************/
/*                                                                            */
/* md2html.rex - Markdown to HTML conversion tool                             */
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
/* 20241222    0.4a First public release                                      */
/* 20251226         Send error messages to .error, not .output                */
/* 20251226         Unify searches for default.md2html & md2html.custom.rex   */
/* 20251226         Implement --path option                                   */
/* 20251227         Use .SysCArgs when available                              */
/* 20251228         Implement --default attributes                            */
/* 20260101         Change [*STYLES*] -> %usedStyles%                         */
/* 20260102         Standardize help options to -h and --help                 */
/* 20260307    0.5  Add single-file mode                                      */
/* 20260308         Add --section-numbers option                              */
/* 20260310         Add figure/listing caption support and numbering          */
/* 20260312         Add limited support for YAML front matter blocks          */
/* 20260312         Add YAML support for language; template %Language%        */
/* 20260312         Add YAML listings: and figures: sub-options               */
/* 20260312         Add YAML highlight-style for Pandoc syntax highlighting   */
/* 20260313         Refactor YAML/caption code to RexxPubOptions.cls          */
/*                                                                            */
/******************************************************************************/

  Call Time R

  package =  .context~package

  myName  =   package~name
  Parse Caseless Value FileSpec( "Name", myName ) With myName".rex"
  myHelp  = ChangeStr(                                         -
   "myName",                                                   -
   "https://rexx.epbcn.com/rexx-parser/doc/utilities/myName/", -
    myName)
  Parse Source . how .
  If how == "COMMAND", .SysCArgs \== .Nil
    Then args = .SysCArgs
    Else args = ArgArray(Arg(1))
  myself = FileSpec("Name"    ,myName)
  mydir  = FileSpec("Location",myName)

  ------------------------------------------------------------------------------
  -- Ensure that we have access to pandoc                                     --
  ------------------------------------------------------------------------------

  Address COMMAND "pandoc -v" With Output Stem Discard. Error Stem Discard.
  If rc \== 0 Then
    Call Error myself "needs a working version of pandoc. Aborting..."

  attributes     = ""
  cssbase        = ""
  jsbase         = ""
  itrace         = 0
  language       = "en"
  highlightStyle = "pygments"
  sectionNumbers = -1                     -- -1 = use docclass default
  numberFigures  = 1
  path           = ""
  continue       = 0

ProcessOptions:

  Loop While args~size > 0, args[1][1] == "-"
    option = args[1]
    args~delete(1)

    Select Case Lower(option)
      When "-h", "--help" Then Signal Help
      When "-it", "--itrace" Then itrace = 1
      When "--default" Then Do
        If args~size == 0 Then
          Call Error "Missing attributes after '"option"' option."
        attributes = args[1]
        args~delete(1)
      End
      When "--continue" Then continue = 1
      When "--section-numbers" Then Do
        If args~size == 0 Then
          Call Error "Missing depth after '"option"' option."
        sectionNumbers = args[1]
        If \DataType(sectionNumbers,"W") | sectionNumbers < 0 | sectionNumbers > 4 Then
          Call Error "Section number depth should be a whole number between 0 and 4, found '"sectionNumbers"'."
        args~delete(1)
      End
      When "--no-number-figures" Then numberFigures = 0
      When "-c", "--css" Then Do
        If args~size == 0 Then
          Call Error "Missing base directory after '"option"' option."
        cssbase = args[1]
        args~delete(1)
      End
      When "-p", "--path" Then Do
        If args~size == 0 Then
          Call Error "Missing path after '"option"' option."
        path = args[1]
        args~delete(1)
      End
      When "-j", "--js" Then Do
        If args~size == 0 Then
          Call Error "Missing base directory after '"option"' option."
        jsbase = args[1]
        args~delete(1)
      End
      Otherwise Call Error "Invalid option '"option"'."
    End
  End

  ------------------------------------------------------------------------------
  -- Determine mode: single file or batch directory                           --
  ------------------------------------------------------------------------------

  Select Case args~items
    When 0 Then Signal Help
    When 1 Then Do
      arg1 = args[1]
      If SysIsFileDirectory(arg1) Then Do
        -- Batch mode: source directory, destination = current directory
        source      = arg1
        destination = Directory()
        Signal BatchMode
      End
      -- Single file mode: output goes to the current directory
      file = arg1
      If \SysFileExists(file) Then Do
        If SysFileExists(file".md") Then file ||= ".md"
        Else Call Error "File '"file"' not found."
      End
      destination = Directory()
      Signal SingleFile
    End
    When 2 Then Do
      arg1 = args[1]
      arg2 = args[2]
      If \SysFileExists(arg1) Then Do
        If SysFileExists(arg1".md") Then Do
          -- Single file with .md appended; check if second arg is a directory
          arg1  = arg1".md"
          file  = arg1
          If \SysFileExists(arg2) Then
            Call Error "Destination directory '"arg2"' does not exist."
          If \SysIsFileDirectory(arg2) Then
            Call Error "'"arg2"' is not a directory."
          destination = .File~new(arg2)~absolutePath
          Signal SingleFile
        End
        Call Error "'"arg1"' not found."
      End
      If SysIsFileDirectory(arg1) Then Do
        -- Batch mode: source + destination directories
        source = arg1
        If \SysFileExists(arg2) Then
          Call Error "Destination directory '"arg2"' does not exist."
        If \SysIsFileDirectory(arg2) Then
          Call Error "'"arg2"' is not a directory."
        destination = .File~new(arg2)~absolutePath
        Signal BatchMode
      End
      -- arg1 is a file; arg2 should be a destination directory
      file = arg1
      If \SysFileExists(arg2) Then
        Call Error "Destination directory '"arg2"' does not exist."
      If \SysIsFileDirectory(arg2) Then
        Call Error "'"arg2"' is not a directory."
      destination = .File~new(arg2)~absolutePath
      Signal SingleFile
    End
    Otherwise Call Error "Unexpected argument '"args[3]"'."
  End

  -- This is never reached
  Exit

  ------------------------------------------------------------------------------
  -- Common setup: cssbase, jsbase, template, custom                          --
  ------------------------------------------------------------------------------

SingleFile:
  singleFileMode = 1
  Signal CommonSetup

BatchMode:
  singleFileMode = 0
  fullSource = .File~new(source)~absolutePath

  Call SysFileTree fullSource || .File~separator || "*.md", "md.", "FOS"

  If md.0 == 0 Then Do
    Say "No .md files found in '"source"'. Nothing to do."
    Exit 0
  End

CommonSetup:

  If cssbase = "" Then Do
    cssdir = .File~new(destination"/css")
    If cssdir~exists, cssdir~isDirectory Then cssbase = "file:///"cssdir~absolutePath
  End

  If jsbase = "" Then Do
    jsdir = .File~new(destination"/js")
    If jsdir~exists, jsdir~isDirectory Then jsbase = "file:///"jsdir~absolutePath
  End

  --
  -- Load default.md2html, a template to drive the .md to .html translation process.
  --

  template = "default.md2html"

  -- 0) If --path has been specified, look there
  If path \== "" Then Do
    try = path"/"template
    If .File~new(try)~exists Then Signal TemplateFound
  End

  -- 1) Look in the current directory

  try = Directory()"/"template
  If .File~new(try)~exists Then Signal TemplateFound

  -- 2) Look in the destination directory

  try = destination"/"template
  If .File~new(try)~exists Then Signal TemplateFound

  -- 3) In batch mode, look in the source directory

  If \singleFileMode Then Do
    try = fullSource"/"template
    If .File~new(try)~exists Then Signal TemplateFound
  End

  -- 4) Use the normal Rexx external search order

  try = .context~package~findProgram(template)
  -- Check that this is really the file we are looking for
  -- (could be default.md2html.rex or default.md2html.cls...)
  If FileSpec("Name",try) == template Then Signal TemplateFound

  Call Error "Could not find file 'default.md2html'. Aborting."

TemplateFound:
  chunk = CharIn( try, 1, Chars(try) )
  Call Stream try, "C", "Close"
  chunk = ChangeStr("%cssbase%",chunk,cssbase)
  chunk = ChangeStr("%jsbase%",chunk,jsbase)
  template1 = chunk~makeArray
  template = .Array~new
  Loop line Over template1
    If line[1,2] \== "--" Then template~append(line)
  End

  --
  -- Call md2html.custom.rex. This will have the side effect to load a set
  -- of optional routines. You can customize the translation process by placing
  -- a modified version of md2html.custom.rex in the current directory, in
  -- the destination directory, in the source directory, or in a place
  -- accesible by the Rexx external program search order (in that order
  -- of precedence).
  --

  custom = "md2html.custom.rex"

  -- 0) If --path has been specified, look there

  If path \== "" Then Do
    try = path"/"custom
    If .File~new(try)~exists Then Signal CustomFound
  End

  -- 1) Look in the current directory

  try = Directory()"/"custom
  If .File~new(try)~exists Then Signal CustomFound

  -- 2) Look in the destination directory

  try = destination"/"custom
  If .File~new(try)~exists Then Signal CustomFound

  -- 3) In batch mode, look in the source directory

  If \singleFileMode Then Do
    try = fullSource"/"custom
    If .File~new(try)~exists Then Signal CustomFound
  End

  -- 4) Use the normal Rexx external search order

  try = custom

  CustomFound:
    Call (try)

  ------------------------------------------------------------------------------
  -- Branch to the appropriate mode                                           --
  ------------------------------------------------------------------------------

  If singleFileMode Then Signal DoSingleFile

  ------------------------------------------------------------------------------
  -- Batch directory mode                                                     --
  ------------------------------------------------------------------------------

  prefixLength = Length(fullSource) + 2

  processed = 0

  Loop i = 1 To md.0
    file   = .File~new(md.i)
    dir    = SubStr(file~parent, prefixLength)
    new    = destination"/"dir            -- Windows accepts "/"
    newDir = .File~new(new)
    new    = newDir~absolutePath          -- Normalize name
    If newDir~exists Then Do
      If \newdir~isDirectory Then
        Call Error "'"new"' already exists, but it is not a directory. Aborting."
    End
    Else Do
      Say Time("Long") "Creating directory '"new"'..."
      If \newDir~makeDirs Then
        Call Error "Directory creation failed. Aborting..."
    End
    Say Time("Long") "Processing" file"..."
    Call ProcessFile file, newDir, md.i, template, cssbase, jsbase, -
      itrace, attributes, continue, sectionNumbers, singleFileMode, -
      numberFigures
    processed += 1
  End

  Say Copies("-",80)
  Say Time("Long") "Processed" processed "files, took" Time("E") "seconds."

  Exit

  ------------------------------------------------------------------------------
  -- Single file mode                                                         --
  ------------------------------------------------------------------------------

DoSingleFile:

  fileObj = .File~new(file)
  If \fileObj~exists Then
    Call Error "File '"file"' not found."

  destDir = .File~new(destination)
  If \destDir~exists Then
    Call Error "Destination directory '"destination"' does not exist."

  Say Time("Long") "Processing" file"..."
  Call Directory fileObj~parentFile~absolutePath
  Call ProcessFile fileObj, destDir, fileObj~absolutePath, template, -
    cssbase, jsbase, itrace, attributes, continue, sectionNumbers, -
    singleFileMode, numberFigures

  Say Copies("-",80)
  Say Time("Long") "Processed 1 file, took" Time("E") "seconds."

  Exit

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

--------------------------------------------------------------------------------

::Routine ProcessFile
  Use Strict Arg file, directory, sourceFn, template, -
    cssbase, jsbase, itrace, attributes, continue, sectionNumbers, -
    singleFileMode, numberFigures

  filename = file~absolutePath
  name     = FileSpec("Name",filename)
  Call OptionalCall Exception, name
  If result \== "RESULT", result Then Do
    Say Time("Long") "--> Skipped."
    Return 0
  End
  stream   = .Stream~new(file)
  source   = stream~arrayIn             -- The .md file to translate
  stream~close

  ------------------------------------------------------------------------------
  -- Parse YAML front matter for RexxPub options                              --
  -- Precedence:                                                              --
  --   style:          CLI > YAML > default  (no CLI option in md2html)       --
  --   everything else: YAML > CLI > default  (author's intent prevails)      --
  ------------------------------------------------------------------------------

  yaml = YAMLFrontMatter(source)
  opts = ParseRexxPubYAML(yaml)

  -- For structural options, YAML always wins
  If opts["section-numbers"] \== .Nil Then sectionNumbers = opts["section-numbers"]
  If opts["number-figures"]  \== .Nil Then numberFigures  = opts["number-figures"]
  If opts["language"]        \== .Nil Then language       = opts["language"]
  If opts["highlight-style"] \== .Nil Then highlightStyle = opts["highlight-style"]

  contents = .Array~new                 -- Will hold the pandoc translation
  res      = .Array~new                 -- Will hold the final result

  ------------------------------------------------------------------------------
  -- See if the name needs translation                                        --
  ------------------------------------------------------------------------------

  Call OptionalCall TranslatedName, name
  If result \== "RESULT", result \== .Nil
    Then targetName = result
    Else targetName = Left(name, Length(name) - 3)

  ------------------------------------------------------------------------------
  -- Compute the extension                                                    --
  ------------------------------------------------------------------------------

  Call OptionalCall Extension
  If result \== "RESULT"
    Then extension = result
    Else extension = "html"

  ------------------------------------------------------------------------------
  -- Construct the target filename                                            --
  ------------------------------------------------------------------------------

  target   = directory"/"targetName"."extension -- Where to place the result

  ------------------------------------------------------------------------------
  -- See if the name is associated to a filename-specific style               --
  ------------------------------------------------------------------------------

  Call OptionalCall FilenameSpecificStyle, name
  If result \== "RESULT", result \== .Nil
    Then filenameSpecificStyle = result
    Else filenameSpecificStyle = ""

  ------------------------------------------------------------------------------
  -- See if an accompanying print style .css file exists                      --
  --   This is is a file with the same name as the .md file, with ".css"      --
  --   added at the end, as an extra extension. It is useful for specifying   --
  --   variables that are file-dependent, like the running header and footer  --
  --   (it should be possible to be done with the string-set property, but it --
  --   is not properly implemented in the major browsers).                    --
  ------------------------------------------------------------------------------

  printStyle = Stream(filename".css","Command","Query Exists")
  If printStyle \== "" Then Do
    p = LastPos(.File~separator,printstyle)
    printStyle = SubStr(printStyle,p+1)
  End

  ------------------------------------------------------------------------------
  -- We process Rexx fenced code blocks first                                 --
  ------------------------------------------------------------------------------

  defaultTheme = "dark"

  -- YAML style overrides the default (md2html has no --style CLI option)
  If opts["style"] \== .Nil Then defaultTheme = opts["style"]

  Signal On Syntax Name IndividualFileFailed

  defaultOptions. = 0
  defaultOptions.default  = attributes

  If singleFileMode Then defaultOptions.["CONTINUE"] = 1
  Else If continue Then defaultOptions.["CONTINUE"] = 1

  source = FencedCode( filename, source, defaultTheme, defaultOptions. )

  Signal Off Syntax
  Signal AllWentWell

IndividualFileFailed:
  If \IsAParseError(Condition("O"), itrace) Then Raise Propagate
  Exit

AllWentWell: Nop

  ------------------------------------------------------------------------------
  -- We now call pandoc. It will transform markdown into html by default      --
  ------------------------------------------------------------------------------

  Address COMMAND 'pandoc --from markdown-smart+footnotes' -
    '--reference-location=section' -
    With Input Using (source) Output Using (contents) Error Stem Discard.

  ------------------------------------------------------------------------------
  -- As the document title, pick the contents of the first h1 header          --
  ------------------------------------------------------------------------------

  title = "::: Missing title :::"
  chunk = contents~makeString("L"," ")
  If chunk~contains("<h1") Then
    Parse Var chunk "<h1" ">"title"</h1>"

  ------------------------------------------------------------------------------
  -- Copy the HTML resource, with some substitutions                          --
  ------------------------------------------------------------------------------

  -- Resolve sectionNumbers default based on filename
  If sectionNumbers == -1 Then Do
    baseName = Left(name, Length(name) - 3)  -- Remove ".md"
    sectionNumbers = DefaultSectionNumbers(baseName)
  End

  If sectionNumbers > 0
    Then sectionNumbersClass = "section-numbers-"sectionNumbers
    Else sectionNumbersClass = ""

  If numberFigures
    Then numberFiguresClass = "number-figures"
    Else numberFiguresClass = ""

  /* Build listing and figure data-* attributes and CSS overrides            */
  captionResult = BuildCaptionOverrides(opts)
  overrideCSS   = captionResult["overrideCSS"]
  listingsAttrs = captionResult["listingsAttrs"]
  figuresAttrs  = captionResult["figuresAttrs"]

  Do line Over template
    Select Case Strip(Lower(line))
      When "%title%"         Then res~append( title )
      When "%header%"        Then Call OptionalCall Header,  res, title
      When "%contentheader%" Then Call OptionalCall ContentHeader, filename
      When "%contents%"      Then
        Do line Over contents
          res~append( line )
        End
      When "%footer%"        Then Call OptionalCall Footer,  res
      When "%sidebar%"       Then Call OptionalCall Sidebar, res
      When "%printstyle%"    Then
        If printStyle \== "" Then
          res~append(                                                       -
            "    <link rel='stylesheet' media='print' href='"printStyle"'>" -
          )
      When "%filenamespecificstyle%"      Then
        If filenameSpecificStyle \== ""   Then
          res~append(                                                       -
            "    <link rel='stylesheet' href='"cssbase"/"filenameSpecificStyle".css'>"   -
          )
      When "%highlightstyle%"            Then
        If cssbase \== "" Then
          res~append(                                                       -
            "    <link rel='stylesheet' href='"cssbase"/pandoc/"highlightStyle".css'>" -
          )
      When "%listingsstyle%"             Then
        If overrideCSS \== "" Then
          res~append( "    <style>" || overrideCSS || "</style>" )
      When "%printfigures%"  Then
        If jsbase \== "" Then
          res~append(                                                       -
            "    <script src='"jsbase"/numberFigures.js'></script>"         -
          )
      Otherwise res~append( line                                            -
        ~changeStr("%SectionNumbers%", sectionNumbersClass)                 -
        ~changeStr("%NumberFigures%",  numberFiguresClass)                  -
        ~changeStr("%ListingsAttrs%",  listingsAttrs)                       -
        ~changeStr("%FiguresAttrs%",   figuresAttrs)                        -
        ~changeStr("%Language%",       language)                            -
      )
    End
  End

  ------------------------------------------------------------------------------
  -- Hack: Review entire result array, detect CSS styles used in fenced code  --
  -- blocks, and dynamically update the array to refer to these CSS files.    --
  ------------------------------------------------------------------------------
Hack:

  lines = res~items

  -- We choose "</head>" because it has no attributes.

  subs = 0
  Do i = 1 To lines Until res[i] = "</head>"
    If res[i] = "%usedStyles%" Then subs = i
  End

  If i > items Then Raise Halt Array("No '</head>' line found.")
  If subs == 0 Then Raise Halt Array("No '%usedStyles%' line found.")

  allowed = XRange(AlNum)".-_"
  styles = .Array~new
  Do i = i + 1 To res~items
    Parse Value res[i] With ' class="highlight-rexx-'style'"'
    If style == "" Then Iterate
    If Verify(style, allowed) > 0 Then Iterate
    If \styles~hasItem(style) Then styles~append(style)
  End

  new = "    "
  Do style Over styles
    new ||= "<link rel='stylesheet' href='"cssbase"/rexx-"style".css'>"
  End

  res[subs] = new

  targetStream = .Stream~new(target)
  targetStream~open("Write Replace")
  If result \== "READY:" Then Do
   .Error~Say( "Error opening" target", " result )
    Exit 1
  End
  targetStream~charOut(res~makeString)
  targetStream~close

  Return 0

OptionalCall: Procedure
  Signal On Syntax Name OptionalRoutineMissing
  routineName = "md2html."Arg(1)
  Call (routineName) Arg(2), Arg(3), Arg(4)
  Return result
OptionalRoutineMissing:
  code = Condition("O")~code
  If code == 43.1, Condition("A")[1] = routineName Then Return result
Raise Propagate

::Resource Help End "::End"
myname -- Markdown to HTML conversion tool

Usage: [rexx] myname OPTIONS filename [destination]
       [rexx] myname OPTIONS source-directory [destination-directory]

When the argument is a file, convert that single file to HTML.
When the argument is a directory, convert all .md files in it
(and its subdirectories) to HTML.

The destination directory defaults to the current directory.

Options:

--default attributes       Specify default attributes for code blocks
--continue                 Continue when a fenced code block is in error
-c cssbase, --css cssbase  Where to locate the CSS files
-h, --help                 Display this help
-it, --itrace              Print internal traceback on error
-j jsbase, --js jsbase     Where to locate the JavaScript files
-p path, --path path       Search path for default.md2html and md2html.custom.rex
--section-numbers n        Number sections down to depth n (0=off, max 4)
                           Default: 3 for article, 2 for book, 0 for slides
--no-number-figures        Disable automatic figure/listing numbering

cssbase and jsbase default to "css" and "js" subdirectories
in the destination directory, when they exist.

The 'myname' program is part of the Rexx Parser package,
see https://rexx.epbcn.com/rexx-parser/. It is distributed under
the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0).

Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>.

See myhelp for details.
::End

::Requires "BaseClassesAndRoutines.cls"
::Requires "ErrorHandler.cls"
::Requires "FencedCode.cls"
::Requires "YAMLFrontMatter.cls"
::Requires "RexxPubOptions.cls"