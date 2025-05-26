/******************************************************************************/
/*                                                                            */
/* Highlighter.cls - Rexx highlighter class                                   */
/* ========================================                                   */
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
/* 20241208    0.1a Add support for extraletters option                       */
/*                  c/CLASSIC_COMMENT/STANDARD_COMMENT/                       */
/* 20241222    0.1c Add support for .numberLines, numberWidth, startFrom      */
/*                  and pad                                                   */
/* 20241225    0.1d Add support for doc-comments                              */
/* 20241229    0.1e Add support for ANSI highlighing                          */
/*                  Rename to Rexx.Highlighter                                */
/* 20241231         Use new driver system                                     */
/* 20250102    0.1f Add "prolog" option                                       */
/* 20250103         Add "unicode" and "tutor" options                         */
/* 20250106         Rename to Highlighter, move to cls directory              */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250519    0.2b Fix error computing mypath, add dependencies              */
/* 20250520         Ensure that options. == 0                                 */
/*                                                                            */
/******************************************************************************/

-- Make our class known to everybody,

.environment~Highlighter =  .Highlighter

-- Create ".."

package      = .context~package
pkgLocal     =  package~local
myName       =  package~name
mypath       =  FileSpec( "Drive", myName )FileSpec( "Path", myName )
pkgLocal ~ . = .File~new( mypath"../" )~absolutePath

/******************************************************************************/
/* Dependencies                                                               */
/******************************************************************************/

::Requires "BaseClassesAndRoutines.cls"
::Requires "Rexx.Parser.cls"
::Requires "StylePatch.cls"
::Requires "HLDrivers/Drivers.cls"
::Requires "HTMLClasses.cls"

/******************************************************************************/
/*                                                                            */
/* This is the main highlighting class. To create an instance, we need        */
/* a name, a source array, and an options stem. The Parse method, which       */
/* accepts an optional StylePatch argument, retuns a new array                */
/* containing the highlighted source code.                                    */
/*                                                                            */
/******************************************************************************/

::Class Highlighter Public

--------------------------------------------------------------------------------
-- INIT method                                                                --
--------------------------------------------------------------------------------

::Method init
  Expose name source options.

  Use Strict Arg name, source, options. = (.Nil)

 .Validate~classType( "name",   name,   .String )
 .Validate~classType( "source", source, .Array  )

  -- Set some sane default for Options.
  If options. == .Nil Then Options. = 0

  If options.[] \== 0 Then Do
    Say ">>> Default value for options argument to Highlighter~new is not 0. <<<"
    Raise Halt
  End

  If \ Options.~hasIndex(mode)        Then Options.mode        = "HTML"
  If \ Options.~hasIndex(operator)    Then Options.operator    = "group"
  If \ Options.~hasIndex(assignment)  Then Options.assignment  = "group"
  If \ Options.~hasIndex(special)     Then Options.special     = "group"
  If \ Options.~hasIndex(constant)    Then Options.constant    = "full"
  If \ Options.~hasIndex(classprefix) Then Options.classprefix = "rx-"
  If \ Options.~hasIndex(style)       Then Options.style       = "dark"
  If \ Options.~hasIndex(compound)    Then Options.compound    = 1
  If \ Options.~hasIndex(startFrom)   Then Options.startFrom   = 1

  If Verify(Options.style, XRange(AlNum)".-_") > 0 Then
    Raise Halt -
      Array("Style names are limited to letters, numbers, '.', '-' and '_'.")

  Do tail Over Options.~allIndexes
    Options.tail = Lower( options.tail )
  End
  Options.mode = Upper( Options.mode )

  -- For ANSI and LaTex highlight, read manually the CSS
  If Options.mode == "ANSI" | Options.mode == "LATEX" Then Do
    array = ParseCSS(Options.)
    Tag2Attr.  = array[1]
    TagColors. = array[2]
    Options.!Tag2Attr  = Tag2Attr.
    Options.!TagColors = TagColors.
  End

  If Options.mode == "ANSI", \Options.~hasIndex(width)
                                      Then Options.width       = 80

  Options.!Source    = source

--------------------------------------------------------------------------------
-- PARSE method                                                               --
--------------------------------------------------------------------------------

::Method parse
  Expose name source options. HTMLClass

  -- We should catch syntax errors present in our source
  Signal On Syntax

  numberLines = options.numberLines

  output = .Array~of("")

  Select Case Options.mode
    When "HTML"  Then
      Options.!Driver =  .HTML.Highlighter~new( Options., output )
    When "ANSI" Then
      Options.!Driver =  .ANSI.Highlighter~new( Options., output )
    When "LATEX" Then
      Options.!Driver = .LaTeX.Highlighter~new( Options., output )
    Otherwise Nop
  End

  Use Strict arg patch = (.Nil)

  If patch == .Nil Then Do
    If Options.~hasIndex(additional) Then
      patch = Options.additional
  End
  If patch~isA(.String) Then patch = .StylePatch~of( patch )
  Else If patch~isA(.Array) Then patch = .StylePatch~of(patch)
  Else If patch \== .Nil Then
    .Validate~classType("patch", patch, .StylePatch)
  Options.!Patch = patch

  If patch \== .Nil Then Do
    -- If we are going to use an additional patch, we will need
    -- to generate a unique ID for our DIV.
    id = Lower(                                              -
      Random(0, 16777215)~d2x(3)Random(0, 16777215)~d2x(3)|| -
      Random(0, 16777215)~d2x(3)Random(0, 16777215)~d2x(3)   -
    )
    Options.!UniqueID = id
  End

  HTMLClass = HTMLClasses(options.)
  Options.!HTMLClass = HTMLClass

  Options.!inc = 1

  parserOptions = .Array~new
  If options.~hasIndex(extraletters) Then
    parserOptions~append( (extraletters, options.extraletters) )
  If options.unicode == 1 | options.tutor == 1 Then
    parserOptions~append( (unicode, 1) )

  -- Instantiate a parser, parse the program, and get the first element
  parser  = .Rexx.Parser~new(file, source, parserOptions)
  package = parser~package
  element = package~firstElement

  -- Emit a prolog
  Options.!Driver~Prolog

  -- Process all elements in turn until the element chain is exhausted

  currentLine = 1
  last = .Nil
  Loop Until element == .Nil
    -- Print an element...
    Call Print source, output, element, Options., >currentLine, HTMLClass
    -- ... and fetch the next one.
    last  = element
    element = element~next
  End

  -- Emit our epilog
  Options.!Driver~Epilog

  Return output

-- This is the standard condition handler for the Rexx parser

Syntax:
  co = condition("O")
  If co~code \== 98.900 Then Do
    Say "Error" co~code "in" co~program", line" co~position":"
    Raise Propagate
  End
  br = (.Parser.Options~hasIndex(html) == "1")~?("<br>",.endOfLine)

  additional = Condition("A")
  Say additional[1]":"
  line = Additional~lastItem~position
  Say Right(line,6) "*-*" source[line]
  Say Copies("-",80)
  Say co~stackFrames~makeArray~makeString("L",br)
  additional = additional~lastItem

  Raise Syntax (additional~code) Additional (additional~additional)

  Exit

/******************************************************************************/
/* Print -- Process an element: enclose it between the relevant HTML tags     */
/*   and append it to the output array.                                       */
/******************************************************************************/

::Routine Print

  Use arg source, output, element, Options., >currentLine, HTMLClass

  -- Since we are skipping zero-width elements, ...
  -- ... we will have to take special care about line ends
  Parse Value element~from With line .
  Do While Options.!inc < line
    Call NewLine Options.!inc + Options.startFrom
    currentLine += 1
  End

  -- If this is an inserted element, there is nothing to print
  If element~from == element~to Then Return

  -- Strings or symbols taken as a constant require special handling
  constant = .EL.TAKEN_CONSTANT
  If element < constant                 Then Signal TakenConstant

  -- Compound variables are optionally displayed highlighting all the
  -- elements in the tail.
  If element < .ALL.COMPOUND_VARIABLES  Then Signal CompoundVariable

  -- Classic comments may be multi-line, in which case they also
  -- require special handling
  If element < .EL.STANDARD_COMMENT     Then Signal BlockComments
  If element < .EL.DOC_COMMENT          Then Signal BlockComments
  If element < .EL.DOC_COMMENT_MARKDOWN Then Signal BlockComments

  -- Process ::Resources (probably multi-line)
  If element < .EL.RESOURCE_DATA Then Signal ResourceData

  -- Standard case
StandardCase:
  tag = HTMLClass[ element~category ]
  Call Highlight element~category, "", tag, element~source

Exit

Highlight:
  Options.!Driver~highlight( Arg(1), Arg(2), Arg(3), Arg(4) )
Return

NewLine:
  Options.!Driver~startLine( Arg(1) )
  options.!inc += 1
Return

TakenConstant:
  tag = HTMLClass[ constant, element~subCategory ]
  Call Highlight constant, element~subCategory, tag, element~source
Exit

ResourceData:
  start   = element~from~word(1)
  end     = element~  to~word(1)
  tag     = HTMLClass[ element~category ]
  padding = options.pad
  Do Counter c line = start to end
    If c > 1 Then Do
      displayLine = currentLine + (c-1) + options.startFrom - 1
      Call NewLine displayLine
    End
    sourceLine = source[line]
    If padding > 0, padding > sourceLine~length Then
      sourceLine = Left(sourceLine, padding)
    Call Highlight element~category, "", tag, sourceLine
  End
  displayLine = currentLine + c + options.startFrom - 1
  Call NewLine displayLine
  currentLine += end - start + 1
Exit

BlockComments:
  comment = element~source
  lines   = comment~items
  tag = HTMLClass[ element~category ]
  padding = options.pad
  Do Counter c line Over element~source
    If c > 1 Then Do
      currentline += 1
      displayLine = currentLine + options.startFrom - 1
      Call NewLine displayLine
    End
    If element < .ALL.DOC_COMMENTS, padding > 0, padding > line~length Then
      line = Left(line, options.pad)
    Call Highlight element~category, "", tag, line
  End
  If element < .ALL.DOC_COMMENTS Then Do
    currentLine += 1
    displayLine = currentLine + options.startFrom - 1
    Call NewLine displayLine
  End
Exit

CompoundVariable:
  If \options.compound Then Signal StandardCase
  Do part Over element~parts
    tag = HTMLClass[ part~category ]
    Call Highlight part~category, "", tag, part~source
  End
Exit

--------------------------------------------------------------------------------
-- PARSECSS Routine                                                           --
--------------------------------------------------------------------------------

-- See https://en.wikipedia.org/wiki/Xterm#/media/File:Xterm-256color.svg

::Routine ParseCSS

  Use Strict Arg Options.

  prefix = Options.classPrefix
  style  = Options.style
  patch  = Options.!Patch

  cssFileName = .File~new( .."/css/rexx-"style".css")
  If \cssFileName~exists | \cssFileName~isFile Then Do
    Say "File '"cssFileName~absolutePath"' does not exist."
    Raise Halt
  End

  source = CharIn(cssFileName,1,Chars(cssFileName))
  Call Stream cssFileName,"c","close"

  -- Very simple CSS parsing

  -- Copy into a mutable buffer to speed things up
  source = .MutableBuffer~new(source)

  -- Delete block comments
  Loop
    open  = source~pos("/*")
  If open == 0 Then Leave
    close = source~pos("*/")
    source~overlay(" ", open, close - open + 2 )
  End

  -- Get rid of CRs and LFs
  source~translate("  ","0d0a"x)

  -- Get rid of multiple spaces
  source~space

  Tag2Attr.  = ""
  TagColors. = ""

  Loop Until source == ""
    Parse Var source selectors "{"attributes"}" source

    attr       = "."
    attributes = Space(attributes,0)
    basicAttr  = ""
    color      = ""
    background = ""
    Loop Until attributes == ""
      Parse Var attributes attribute";" attributes
      Select Case Lower( attribute )
        When "font-style:italic"         Then Do
          attr      ||= "I"
          basicAttr ||= "3;"
        End
        When "font-style:normal"         Then Do
          attr      ||= "i"
          basicAttr ||= "23;"
        End
        When "text-decoration:underline" Then Do
          attr      ||= "U"
          basicAttr ||= "4;"
        End
        When "text-decoration:none" Then Do
          attr      ||= "u"
          basicAttr ||= "24;"
        End
        When "font-weight:bold"          Then Do
          attr      ||= "B"
          basicAttr ||= "1;"
        End
        When "font-weight:normal"        Then Do
          attr      ||= "b"
          basicAttr ||= "21;"
        End
        Otherwise Do
          Parse Var attribute key":"value
          Select Case key
            When "color"            Then color      = value
            When "background-color" Then background = value
            Otherwise Nop
          End
        End
      End
    End

    color      = NormalizeColor( color )
    background = NormalizeColor( background )

    -- We now examine the selectors. We are only interesed in selectors
    -- of the form
    --
    --   .highlight-rexx-<style> .key
    --
    -- Where <style> is the default style, or the style
    -- specified as an option.

    keys = ""
    sel = selectors
    Loop Until sel == ""
      Parse Var sel selector"," sel
      -- No initial dot
      If Word(selector,2)[1] \== "." Then Iterate
      Parse Var selector a b c
      If c \== "" Then Iterate
      If a \== ".highlight-rexx-"style Then Iterate
      If \b~startsWith(".") Then Iterate
      Parse Var b (".")key
      keys = keys key
      Tag2Attr.key  = attr color"/"background
      TagColors.key = color"/"background
    End

    If keys == "" Then Iterate

  End

  Return Tag2Attr., TagColors.

NormalizeColor: Procedure
  If color == ""           Then Return color
  Parse Arg color +1 color
  If color == ""           Then Return color
  If Length( color ) \== 3 Then Return color
  Parse Value color With a +1 b +1 c +1
  Return Space( a a b b c c , 0 )