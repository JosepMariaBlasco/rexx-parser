/******************************************************************************/
/*                                                                            */
/* FencedCode.cls - Highlight Rexx fenced code blocks                         */
/* ==================================================                         */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
/* [See https://rexx.epbcn.com/rexx-parser/]                                  */
/*                                                                            */
/* Copyright (c) 2024-2025 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20241206    0.1  First public release                                      */
/* 20241206    0.1a Add "extraletters" attribute                              */
/* 20241219    0.1c Skip non-rexx code blocks                                 */
/* 20241222         Add "filename" parameter, relativize source= and patch=   */
/*                  Add ".numberLines", "startFrom", "numberWidth" and "pad"  */
/* 20250104    0.1f Add "unicode" and "tutor" options                         */
/* 20250106         Change "patch" to "patchfile", and add "patch='patches'"  */
/* 20250120         Add size attribute (HTML only)                            */
/* 20250222    0.2  Add drive to path for requires                            */
/* 20250317         Support a defaultstyle parameter (default="dark")         */
/* 20250328         Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250529    0.2c Add support for detailed string highlighting              */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
--
-- Arguments:
--   Filename:
--     A filename providing the context for the source array.
--     Its path component is used as the base to determine other file
--     locations, for example, when source= or patchfile= are specified,
--     their corresponding filenames are relative to the "filename" path.
--   Source:
--     An array of strings. The code (usually, Markdown or HTML)
--     containing the Rexx fenced code blocks we want to highlight.
--
-- Returns:
--   A new array where all the Rexx fenced code blocks are substituted
--   by their highlighted versions.
--
-- * Both the "```" and "~~~" markers are accepted, but they should start
--   on column 1.
-- * You can use three or more backticks or twiddles, but the closing marker
--   has to have exactly the same number of backticks or twiddles than the
--   opening one.
-- * You cannot start with "```" and end with "~~~", or viceversa.
-- * The word "rexx" has to follow "```" or "~~~", with or without
--   intervening blanks or tabs. Code blocks that are not marked with "rexx"
--   will not be processed by this routine.
-- * If you want to specify additional attributes, you may do so by enclosing
--   them between braces after the "rexx" marker. Blanks and/or tabs after
--   "rexx" and before the left brace are optional.
--
--     ```rexx {attributes}
--
-- Optional attributes:
--   Attributes are name=value pairs, separated by whitespace. When a value
--   contains blanks, it has to be enclosed in single or double quotes.
--
--     ```rexx {name1=value1 name2="long value" ...}
--
--   Possible name/value pairs are:
--
--   assignment= "group" | "full" | "detail"
--     Determines how assignment operator sequences will be highlighted.
--     When "group" is specified, a single, generic, HTML class will be
--     assigned to every assignment sequence. When "detail" is specified,
--     every assigment sequence will get its own, different, HTML class
--     (this means, for example, that all simple assignments, "=", will
--     be assigned the same HTML class, all "+=" assignments will be
--     assigned a different class, and so on). When "full" is specified,
--     both a generic and a specific class will be assigned.
--   classprefix= "rx-"
--     Define the class prefix used for HTML classes. Default is "rx-".
--   constant= "group" | "full" | "detail"
--     Determines how taken constants (strings or symbols taken as a
--     constant) will be highlighted.
--   extraletters= <string>
--     Allows symbols to contain characters present in <string>, which should
--     be specified between quotes.
--   number= "whole" | "detail"
--     Determines how numbers are highlighted. "detail" is the default.
--  .numberLines (or .number-lines)
--     [Please note that the leading dot is necessary!]
--     The code listing will include line numbers on the left.
--   numberWidth=width
--     Ensures that the line numbers will occupy at least width characters.
--     The highlighter may use more that width characters if this is
--     necessary to correctly display the line numbers.
--   operator= "group" | "full" | "detail"
--     Determines how operator character sequences will be highlighted.
--   pad=column
--     Ensures that ::RESOURCE data lines and documentation comments
--     will be padded up to column if they have less than column
--     characters. This may be useful when using contrasting backgrounds,
--     because it will ensure that the whole resource/comment
--     displays as a rectangle.
--   patch="<patches>"
--     A semicolon-separated list of style patches to be applied
--     to the code block.
--   patchfile=<filename>
--     <filename> will contain the style patch file applied to this code block.
--     Filename is relative to the file containing the code block.
--   size=<size>
--     Add style="font-size:<size>" to the <pre> block (HTML only).
--   source=<filename>
--     Read the code to highlight from <filename> instead of the code block.
--     Filename is relative to the file containing the code block.
--   special= "group" | "full" | "detail"
--     Determines the highlighting of special character sequences.
--   startFrom=nnn
--     When used with .numberLines, "nnn" will be the line number
--     of the first line in the listing.
--   string= "whole" | "detail"
--     Determines how strings are highlighted. "detail" is the default.
--   style=<style>
--     Enclose the code with a <div class="highlight-rexx-<style>"> tag.
--     Default is "dark".
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Dependencies                                                               --
--------------------------------------------------------------------------------

::Requires "BaseClassesAndRoutines.cls"
::Requires "Rexx.Parser.cls"
::Requires "Highlighter.cls"
::Requires "StylePatch.cls"

--------------------------------------------------------------------------------
-- Main routine                                                               --
--------------------------------------------------------------------------------

::Routine FencedCode Public

  Use Strict Arg filename, source, defaultStyle = "dark"

  tab = "09"X

  -- Forms to start a code block we are interested in
  OK.            = 0
  OK.["rexx"   ] = 1 -- "~~~rexx", and no attributes
  OK.["rexx "  ] = 1 -- "~~~rexx <attributes>"
  OK.["rexx{"  ] = 1 -- "~~~rexx{<attributes>}"
  OK.["rexx"tab] = 1 -- "~~~rexx<tab><attributes>"

  processed = .Array~new

  -- We need a WHILE condition because the source array may change
  Loop Label Outer lineNo = 1 By 1 While lineNo < source~items
    line = source[lineNo]

    -- A fenced code block starts with "```" or "~~~"
    If line[1,3] \== "```", line[1,3] \== "~~~" Then Iterate

    -- We may have more than three characters before the language name
    char    = line[1]
    attributes = Strip( line, "Leading", char )

    -- Remember how many backticks or twiddles we found
    chars = Length(line) - Length(attributes)

    -- End marker
    marker = Copies(char, chars)

    -- Allow whitespace after ``` or ~~~.
    attributes = Strip( attributes )

    -- It was not "rexx ", "rexx<tab>" or "rexx{<something>" after all.
    -- We should skip the whole code block, because it may contain
    -- rexx blocks inside (with less twiddles or backticks).
    If \attributes~startsWith("rexx") | \OK.[ attributes[1,5] ] Then Do
      Loop
        lineNo += 1
        If lineNo > source~items Then Exit MissingEndMarker()
        line = source[lineNo]
        If line == marker Then Iterate Outer
      End
    End

    -- Parse code block parameters
    options. = ParseOptions( filename, attributes, defaultStyle )

    -- Look for the end marker
    start  = lineNo
    lines  = source~items
    end    = start + 1
    Loop While end <= lines, source[end] \== marker
      end += 1
    End

    -- No end marker? That's an error
    If end > lines Then Exit MissingEndMarker()

    -- Get the highligthed version of our code block
    highlighted = ProcessACodeBlock( source, start, end, options. )

    -- Up to line (start-1) there is nothing to change
    processed~appendAll( source~section( 1, start - 1 ) )
    -- We now copy the highlighted lines
    processed~appendAll( highlighted )
    processed~delete( processed~last ) -- Last line is an artifact

    -- Now update our source...
    source = source~section( end + 1 )
    -- ... and update lineNo (remembering that LOOP will add 1 to it)
    lineNo = 0

  End

  -- Copy any remaining line in the source array
  Do line Over source
    processed~append(line)
  End

  Return processed

MissingEndMarker:
  Raise Syntax 88.900 -
    Additional("Missing end marker for code block starting at line "lineNo)

--------------------------------------------------------------------------------
-- ParseOptions -- Parse the options after "```rexx"                          --
--------------------------------------------------------------------------------

::Routine ParseOptions Private

  Use Strict arg filename, options, defaultStyle

  -- Default options
  Options.            = 0
  Options.operator    = "group"         -- All operators are displayed the same
  Options.special     = "group"         -- All specials are displayed the same
  Options.constant    = "full"          -- Flexibility with taken constants
  Options.assignment  = "group"         -- Assignments are displayed the same
  Options.number      = "detail"        -- Set number highlighting mode
  Options.string      = "detail"        -- Set string highlighting mode
  Options.style       = defaultStyle    -- Set default style
  Options.classprefix = "rx-"           -- Default HTML class prefix is "rx-"
  Options.["SOURCE"]  = ""              -- No external source by default
  Options.patch       = ""              -- No patch file by default
  Options.html        = 1               -- This is HTML highlighting
  Options.startFrom   = 1               -- Start at line 1

  -- Store the file path, for source=, patchfile=, etc.
  Options.path        = .File~new( filename )~parent

  -- Skip "rexx" and strip blanks
  options = Strip( SubStr(options,5) )

  -- No options? We are done
  If options == "" Then Return options.

  -- Options must start with a "{" character...
  If options[1] \== "{"     Then Exit BadOptions()
  -- ...and end with a "}" character.
  If \options~endsWith("}") Then Exit BadOptions()

  options = SubStr( options,2,Length(options)-2 )

  Loop While options \== ""
    Parse Var options option options
    If option~contains("=") Then Do
      Parse Var option option"="value
      c = value[1]
      If """'"~contains( c ) Then Do -- Values between quotes
        Parse Value value options With (c)value(c) options
      End
      lOption = Lower( option )
      Select Case lOption
        When "extraletters" Then Options.extraletters = value
        When "classprefix"  Then Options.classprefix  = value
        When "startfrom"    Then Options.startfrom    = value
        When "source"       Then Options.["SOURCE"]   = value
        When "pad"          Then Options.pad          = value
        When "numberwidth"  Then Options.numberwidth  = Integer(value,2,5)
        When "patchfile"    Then Options.patchfile    = value
        When "patch"        Then Options.patch        = value
        When "string"       Then Options.string       = value
        When "style"        Then Options.style        = value
        When "size"         Then Options.size         = value
        When "operator" Then
          Select Case Lower(value)
            When "group", "full", "detail" Then Options.operator   = Lower(value)
            Otherwise Exit BadValue()
          End
        When "special" Then
          Select Case Lower(value)
            When "group", "full", "detail" Then Options.special    = Lower(value)
            Otherwise Exit BadValue()
          End
        When "constant" Then
          Select Case Lower(value)
            When "group", "full", "detail" Then Options.constant   = Lower(value)
            Otherwise Exit BadValue()
          End
        When "assignment" Then
          Select Case Lower(value)
            When "group", "full", "detail" Then Options.assignment = Lower(value)
            Otherwise Exit BadValue()
          End
        Otherwise Exit BadOption()
      End
    End
    Else Do -- Options does not contain "="
      Select Case option
        When "unicode", "tutor"              Then Options.unicode     = .True
        When ".numberLines", ".number-lines" Then Options.numberLines = .True
        Otherwise Nop -- Exit BadOption()
      End
    End
  End
  Return options.

Integer: Procedure Expose lOption
  Use Arg value, min, max
  If DataType(value,"I"), value >= min, value <= max Then Return value
  Raise Syntax 88.900 Additional("Invalid value '"value"' for '"lOption"'. Expecting an integer between" min "and" max)

BadOption:
  Raise Syntax 88.900 Additional("Invalid option '"option"'")
BadValue:
  Raise Syntax 88.900 Additional("Invalid value '"value"'")
BadOptions:
  Raise Syntax 88.900 Additional("Invalid options '"options"'")

--------------------------------------------------------------------------------
-- ProcessACodeBlock                                                          --
--------------------------------------------------------------------------------

::Routine ProcessACodeBlock
  Use Strict Arg source, start, end, options.

  -- Process patch files, if any
  patches = .Nil
  If options.patch \== "" Then Do
    patches = .StylePatch~of( Options.patch )
  End
  Else If options.patchfile \== "" Then Do
    fn = options.path"/"options.patchfile
    patches = CharIn(fn,1,Chars(fn))~makeArray
    patches = .StylePatch~of( patches )
    Call Stream fn,"c","close"
  End

  fn = options.["SOURCE"]
  -- Implement ```rexx {source=filename}
  If fn \== "" Then Do
    fn = options.path"/"fn
    chars = CharIn(fn,1,Chars(fn))
    Call Stream fn,"c","close"
    array = chars~makeArray
    -- Compensate for makearray definition
    If chars~endsWith("0a"x) Then array~append("")
  End
  Else Do
    array = source~section( start + 1, end - start - 1)
  End

  highligthter = .Highlighter~new("", array, options.)

  Return highligthter~parse( patches )

MissingEndMarker:
  Raise Syntax 88.900 -
    Additional("Missing end marker '-->' for code block at line "start)
