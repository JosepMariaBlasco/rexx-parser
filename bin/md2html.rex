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
/*                                                                            */
/******************************************************************************/

Call Time R

name = .context~package~name
myself = FileSpec("Name"    ,name)
mydir  = FileSpec("Location",name)

Address COMMAND "pandoc -v" With Output Stem Discard. Error Stem Discard.
If rc \== 0 Then Do
 .Error~Say( myself "needs a working version of pandoc. Aborting..." )
  Exit 1
End

Parse Arg args

args    = Strip(args)
cssbase = ""
jsbase  = ""
itrace  = 0
path    = ""

Loop While args[1] == "-"
  Parse Var args option args
  Select Case Lower(option)
    When "-h", "-?", "--help" Then Signal Help
    When "-it", "--itrace" Then itrace = 1
    When "-c", "--css" Then Do
      Parse Var args cssbase args
    End
    When "-p", "--path" Then Do
      Parse Var args path args
      If path == "" Then Do
       .Error~Say( "Missing path after '"option"' option." )
        Exit 1
      End
    End
    When "-j", "--js" Then Do
      Parse Var args jsbase args
    End
    Otherwise Do
     .Error~Say( "Invalid option '"option"'." )
      Exit 1
    End
  End
  args = Strip(args)
End

Parse Var args source destination
If source = "" Then Signal Help

If \SysFileExists(source) Then Do
 .Error~Say( "Source directory '"source"' does not exist." )
  Exit 1
End

If \SysIsFileDirectory(source) Then Do
 .Error~Say( "'"source"' is not a directory." )
  Exit 1
End

If destination = "" Then destination = Directory()
Else Do
  If \SysFileExists(destination) Then Do
   .Error~Say( "Destination directory '"destination"' does not exist." )
    Exit 1
  End
  If \SysIsFileDirectory(destination) Then Do
   .Error~Say( "'"destination"' is not a directory." )
    Exit 1
  End
  destination = .File~new(destination)~absolutePath
End

If cssbase = "" Then Do
  cssdir = .File~new(destination"/css")
  If cssdir~exists, cssdir~isDirectory Then cssbase = "file:///"cssdir~absolutePath
End

If jsbase = "" Then Do
  jsdir = .File~new(destination"/js")
  If jsdir~exists, jsdir~isDirectory Then jsbase = "file:///"jsdir~absolutePath
End

fullSource = .File~new(source)~absolutePath

Call SysFileTree fullSource"/*.md", "md.", "FOS"

If md.0 == 0 Then Do
  Say "No .md files found in '"source"'. Nothing to do."
  Exit
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

-- 3) Look in the source directory

try = fullsource"/"template
If .File~new(try)~exists Then Signal TemplateFound

-- 4) Use the normal Rexx external search order

try = .context~package~findProgram(template)
-- Check that this is really the file we are looking for
-- (could be default.md2html.rex or default.md2html.cls...)
If FileSpec("Name",try) == template Then Signal TemplateFound

.Error~Say( "Could not find file 'default.md2html'. Aborting." )
Exit 1

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

-- 3) Look in the source directory

try = fullsource"/"custom
If .File~new(try)~exists Then Signal CustomFound

-- 4) Use the normal Rexx external search order

try = custom

CustomFound:
  Call (try)

prefixLength = Length(fullSource) + 2

processed = 0

Loop i = 1 To md.0
  file   = .File~new(md.i)
  dir    = SubStr(file~parent, prefixLength)
  new    = destination"/"dir            -- Windows accepts "/"
  newDir = .File~new(new)
  new    = newDir~absolutePath          -- Normalize name
  If newDir~exists Then Do
    If \newdir~isDirectory Then Do
     .Error~Say( "'"new"' already exists, but it is not a directory. Aborting." )
      Exit 1
    End
  End
  Else Do
    Say Time("Long") "Creating directory '"new"'..."
    If \newDir~makeDirs Then Do
     .Error~Say( "Directory creation failed. Aborting..." )
      Exit 1
    End
  End
  Say Time("Long") "Processing" file"..."
  Call ProcessFile file, newDir, md.i, template, cssbase, jsbase, itrace
  processed += 1
End

Say Copies("-",80)
Say Time("Long") "Processed" processed "files, took" Time("E") "seconds."

Exit

Help:
  Say .Resources~help
  Exit 1

--------------------------------------------------------------------------------

::Routine ProcessFile
  Use Strict Arg file, directory, sourceFn, template, cssbase, jsbase, itrace

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

  printstyle = Stream(filename".css","Command","Query Exists")
  If printstyle \== "" Then Do
    p = LastPos(.File~separator,printstyle)
    printstyle = SubStr(printstyle,p+1)
  End

  ------------------------------------------------------------------------------
  -- We process Rexx fenced code blocks first                                 --
  ------------------------------------------------------------------------------

  defaultTheme = "dark"

  Signal On Syntax Name IndividualFileFailed

  source = FencedCode( filename, source, defaultTheme )

  Signal Off Syntax
  Signal AllWentWell
IndividualFileFailed:
  co         = condition("O")
  additional = Condition("A")
  extra = additional~lastitem
  line  = extra~position
  Parse Value co~code With major"."minor
 .Error~Say( Right(line,6) "*-*" extra~sourceline                            )
 .Error~Say( "Error" major "in" extra~name", line" line": " ErrorText(major) )
 .Error~Say( "Error" co~code": " Ansi.ErrorText( co~code, additional )       )

  If itrace Then Do
   .Error~Say
   .Error~Say( "Trace follows:"         )
   .Error~Say( Copies("-",80)           )
   .Error~Say( co~stackFrames~makeArray )
  End

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

  Do line Over template
    Select
      When line = "%title%"         Then res~append( title )
      When line = "%contents%"      Then
        Do line Over contents
          res~append( line )
        End
      When line = "%header%"        Then Call OptionalCall Header,  res, title
      When line = "%footer%"        Then Call OptionalCall Footer,  res
      When line = "%sidebar%"       Then Call OptionalCall Sidebar, res
      When line = "%contentheader%" Then Call OptionalCall ContentHeader, filename
      When line = "%printstyle%"    Then
        If printstyle \== "" Then
          res~append(                                                       -
            "    <link rel='stylesheet' media='print' href='"printstyle"'>" -
          )
      When line = "%filenameSpecificStyle%"      Then
        If filenameSpecificStyle \== ""   Then
          res~append(                                                       -
            "    <link rel='stylesheet' href='"cssbase"/"filenameSpecificStyle".css'>"   -
          )
      Otherwise res~append( line )
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
    If res[i] == "[*STYLES*]" Then subs = i
  End

  If i > items Then Raise Halt Array("No '</head>' line found.")
  If subs == 0 Then Raise Halt Array("No '[*STYLES*]' line found.")

  allowed = XRange(AlNum)".-_"
  styles = .Array~new
  Do i = i + 1 To res~items
    Parse Value res[i] With ' class="highlight-rexx-'style'">'
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
md2html -- Markdown to HTML conversion tool

Usage: [rexx] md2html OPTIONS source [destination]

"source" and "destination" should be existing directories.
The destination directory defaults to the current directory.

Options:

-?                         Display this help
-c cssbase, --css cssbase  Where to locate the CSS files
-h, --help                 Display this help
-it, --itrace              Print internal traceback on error
-j jsbase, --js jsbase     Where to locate the JavaScript files
-p path, --path path e     Search path for default.md2html and md2html.custom.rex

cssbase and jsbase default to "css" and "js" subdirectories
in the destination directory, when they exist.
::End

::Requires "ANSI.ErrorText.cls"
::Requires "ErrorHandler.cls"
::Requires "FencedCode.cls"