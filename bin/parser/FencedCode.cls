/******************************************************************************/
/*                                                                            */
/* FencedCode.cls - Highlight Rexx fenced code blocks                         */
/* ==================================================                         */
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
/* 20250706    0.2d Add support for detailed doc-comment highlighting         */
/* 20251114    0.3a Add support for Experimental features                     */
/* 20251125         Add support for Executor                                  */
/* 20251222    0.4a Add support for ```executor                               */
/* 20251228         Add support for default options                           */
/* 20251230         Add support for --continue                                */
/* 20260310    0.5  Add support for captions                                  */
/* 20260521         Add support for CMS                                       */
/* 20260522         Accept "rexxvm" as an alias for the "cms" attribute       */
/* 20260709    0.6  Mark explicit styles (for RexxHTTP)                       */
/* 20260821         Implement nested code blocks                              */
/* 20260831    0.7  Scan prose lines for `` `x`{.rexx ...} `` mentions        */
/* 20260912         Add program=.                                             */
/* 20260923         A fence can open after a list marker (`- ```rexx`)        */
/* 20260926         Add FenceWordIsKnown (for md2slides' WarnFenceWords)      */
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
-- * Please note that "rexx" has to be written in lowercase (i.e., "Rexx" or
--   "REXX" are not recognized).
-- * If you want to specify additional attributes, you may do so by enclosing
--   them between braces after the "rexx" marker. Blanks and/or tabs after
--   "rexx" and before the left brace are optional.
--
--     ```rexx {attributes}
--
-- [202511222] "executor" is also accepted as a language tag.
-- ```executor {attributes} is equivalent to ```rexx {executor attributes}
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
--   caption="text"
--     Add a caption to the code block. The caption text will be emitted
--     as a data-caption attribute on the outer <div>, and numberFigures.js
--     will convert it to a visible <figcaption> at render time.
--   classprefix= "rx-"
--     Define the class prefix used for HTML classes. Default is "rx-".
--   cms (or rexxvm)
--     Enables CMS (Classic Rexx) syntax, as parsed by the Rexx/VM
--     interpreter. "cms" and "rexxvm" are equivalent.
--   constant= "group" | "full" | "detail"
--     Determines how taken constants (strings or symbols taken as a
--     constant) will be highlighted.
--   doccomments= "detailed" | "block"
--     Determines whether doc-comment parts are individually highlighted.
--   executor
--     Enables Executor extensions
--   experimental
--     Enables Experimental features
--   extraletters= <string>
--     Allows symbols to contain characters present in <string>, which should
--     be specified between quotes.
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
--   program=<name> (or program="a name with blanks")
--     Marks this fence as one fragment of a larger logical program. Every
--     Rexx fence carrying the same name -- wherever it sits in the document
--     (side-by-side slide columns, several slides, or code interleaved with
--     prose in a paged article) -- is fused into ONE listing
--     and highlighted as a single unit, in order of appearance.
--     Stateful highlighting therefore survives the gaps between fragments
--     (a clause may even span two fragments) and line numbering flows across
--     them. Each fragment is then rendered back in its own place.
--     Fragments are grouped by a normalised key: any run of blanks and/or
--     dashes is collapsed to a single dash and the result is uppercased, so
--     "The Towers of Hanoi", "the-towers-of-hanoi" and "Towers  Of  Hanoi"
--     all name the same program. The name is kept verbatim as well (for a
--     future auto-caption). A value with blanks must be quoted, as usual.
--     The author writes nothing but the name: there is no marker, no cut
--     directive and no ordering attribute. Fragments are read in document
--     order, and the fence they sit in is the only thing that says where
--     each one is to be rendered.
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
--   style=<style>
--     Enclose the code with a <div class="highlight-rexx-<style>"> tag.
--     Default is "dark".
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Dependencies                                                               --
--------------------------------------------------------------------------------

package   = .context~package
myName    =  package~name
mypath    =  FileSpec( "Location", myName )
parentDir = .File~new( mypath"../" )~absolutePath

/******************************************************************************/
/* Dependencies                                                               */
/******************************************************************************/

package~loadPackage(parentDir"/Rexx.Parser.cls")

-- ProseMention(), for prose mentions
package~loadPackage(parentDir"/HLDrivers/HTML.Driver.cls")

::Requires "BaseClassesAndRoutines.cls"
::Requires "Highlighter.cls"
::Requires "StylePatch.cls"
::Requires "ANSI.ErrorText.cls"
::Requires "HTMLClasses.cls"

--------------------------------------------------------------------------------
-- Main routine                                                               --
--------------------------------------------------------------------------------

::Routine FencedCode Public

  Use Strict Arg filename, source, defaultStyle = "dark", defaultOptions. = 0

  tab = "09"X

  -- Forms to start a code block we are interested in
  OK.                = 0
  OK.["rexx"       ] = 1                -- "~~~rexx", and no attributes
  OK.["rexx "      ] = 1                -- "~~~rexx <attributes>"
  OK.["rexx{"      ] = 1                -- "~~~rexx{<attributes>}"
  OK.["rexx"tab    ] = 1                -- "~~~rexx<tab><attributes>"
  OK.["executor"   ] = 1                -- "~~~executor", and no attributes
  OK.["executor "  ] = 1                -- "~~~executor <attributes>"
  OK.["executor{"  ] = 1                -- "~~~executor{<attributes>}"
  OK.["executor"tab] = 1                -- "~~~executor<tab><attributes>"

  -- Continue when an error is found
  continue = defaultOptions.continue

  accum     = 0                         -- Accumulates read lines

  processed = .Array~new

  -- Prose mentions (`` `x`{.rexx ...} ``, outside fences) are tagged against
  -- the SAME HTMLClass a fenced block with no attributes of its own would
  -- get: we run the document's default options through the exact same
  -- ParseOptions/HTMLClasses path the main loop uses for each block below,
  -- once, up front. One source of truth (see HTMLClasses.cls's prose
  -- facade) -- a change to classprefix= or constant= in defaultOptions.
  -- keeps prose mentions in sync automatically.
  proseAttributes = ""
  If defaultOptions.default \== "" Then
    proseAttributes = "{"defaultOptions.default"}"
  proseOptions.  = ParseOptions( filename, proseAttributes, defaultStyle )
  proseHTMLClass = HTMLClasses( proseOptions. )

  -- program= : sibling code fences sharing a program= name are one logical
  -- listing, wherever they sit (slides columns, several slides, prose in a
  -- paged article = literate programming). The author's as-is name is kept for
  -- a future auto-caption; fences are grouped by a NORMALISED key (blank/dash
  -- runs -> single dash, uppercased -- see ProgramKey), so "The Towers of
  -- Hanoi" and "Towers-of-Hanoi" fold together.
  --
  -- This is STEP ONE, and it is self-contained: ProcessPrograms gathers each
  -- group's fragments, highlights the whole listing in ONE stateful pass, cuts
  -- the emitted block back into one block per fragment, and returns a `source`
  -- in which every program= fence has become an inert placeholder
  -- `<!--rxprogram:KEY:k AS-IS-->`. Nothing about programs is left for the main
  -- loop to know: STEP TWO below runs over a source with no program= fences in
  -- it and behaves exactly as it always did. The captured blocks are dropped
  -- into their placeholders in a final pass, BEFORE Pandoc -- blocks and
  -- placeholders live in the same array here, so the swap is array surgery.
  --
  -- The cut is made COLD: the listing is emitted as one continuous block and
  -- sliced afterwards by source line number. Nothing is ever reopened
  -- mid-emission, which is what used to strand empty line spans and mis-carried
  -- numbers at the head of a reopened block. See CutProgramBlocks.
  --
  -- A source with no program= fences is returned byte-for-byte unchanged, so
  -- every consumer (md2html, a paged article, ...) gets program= for free and
  -- pays nothing when it is not used.
  -- programBlocks.["KEY:k"] = array-of-lines for the k-th block of program KEY.
  -- programBlocks.!count is how many were captured: stems pass by reference, so
  -- this is how ProcessPrograms reports "there were programs" back to us.
  programBlocks.        = 0
  programBlocks.!count  = 0
  source = ProcessPrograms( filename, source, defaultStyle, defaultOptions., -
                            continue, programBlocks. )
  havePrograms = programBlocks.!count > 0

  -- We need a WHILE condition because the source array may change
  Loop Label Outer lineNo = 1 By 1 While lineNo < source~items
    line = source[lineNo]

    -- A fenced code block starts with "```" or "~~~", possibly indented when it
    -- lives inside a list item. We recognise the marker after leading blanks or
    -- tabs, and REMEMBER that indent: the block's code has to be de-indented by
    -- it before the Rexx parser sees it (so column 1 is real column 1), and the
    -- highlighted HTML has to be re-indented by the same amount on the way back,
    -- so Pandoc still attaches the block to its list item. See issue #2.
    --
    -- The fence can also open ON the line of its list item, after the marker:
    -- `- ```rexx`, `1. ```rexx`, `  - - ```rexx`. Pandoc reads that as a code
    -- block inside the item, whose lines are indented to the fence's column.
    -- FenceMarkerPrefix gives the length of what comes before the fence
    -- ("  - " is 4): the code is de-indented by that much, and the marker is
    -- given back on the first line of the highlighted HTML (blanks on the
    -- rest), so Pandoc still sees the item. Without this, the fence went by
    -- unseen, its closing ``` was taken for the opening of a non-rexx block,
    -- and every rexx fence after it on the page was swallowed as plain code.
    indent  = Length(line) - Length( Strip(line, "Leading") )
    bare    = SubStr(line, indent + 1)
    itemPrefix = ""
    If bare[1,3] \== "```", bare[1,3] \== "~~~" Then Do
      -- `-     ```rexx`: an indented code block that starts with a fence-like
      -- line. Its closing ``` must not be taken for an opening one.
      skip = FenceInIndentedItem( line )
      If skip \== "" Then Do
        Loop
          lineNo += 1
          If lineNo >= source~items Then Leave Outer
          If Strip( Strip(source[lineNo],"T"), "Leading" ) == skip Then Iterate Outer
        End
      End
      indent = FenceMarkerPrefix( line )
      If indent == 0 Then Iterate
      itemPrefix = Left( line, indent )
      bare = SubStr( line, indent + 1 )
    End

    -- We may have more than three characters before the language name
    char    = bare[1]
    attributes = Strip( bare, "Leading", char )

    -- Remember how many backticks or twiddles we found
    chars = Length(bare) - Length(attributes)

    -- End marker
    marker = Copies(char, chars)

    -- Allow whitespace after ``` or ~~~.
    attributes = Strip( attributes )

    executor = 0
    Select
      When attributes~startsWith("rexx"),     OK.[ attributes[1,5] ] Then Nop
      When attributes~startsWith("executor"), OK.[ attributes[1,9] ] Then
        executor = 1
      -- It was not "rexx " ("executor ", etc.), "rexx<tab>"
      -- or "rexx{<something>" after all.
      -- We should skip the whole code block, because it may contain
      -- rexx blocks inside (with less twiddles or backticks).
      Otherwise Do
        Loop
          lineNo += 1
          If lineNo > source~items Then Exit MissingEndMarker()
          line = source[lineNo]
          If Strip( Strip(line,"T"), "Leading" ) == marker Then Iterate Outer
        End
      End
    End

    -- Parse code block parameters
    If defaultOptions.default \== "" Then Do
      Parse Var attributes prefix"{"rest
      If rest == "" Then
        attributes ||= " {"defaultOptions.default"}"
      Else
        attributes = prefix"{"defaultOptions.default rest
    End
    options. = ParseOptions( filename, attributes, defaultStyle )
    If executor Then Options.["EXECUTOR"] = 1
    If continue Then Options.["CONTINUE"] = 1

    -- Look for the end marker
    start  = lineNo
    lines  = source~items
    end    = start + 1
    Loop While end <= lines, Strip( Strip(source[end],"T"), "Leading" ) \== marker
      end += 1
    End

    -- No end marker? That's an error
    If end > lines Then Exit MissingEndMarker()

    -- De-indent the block in place before highlighting: the Rexx parser must
    -- see the code at real column 1, not shifted right by the list indent.
    -- ProcessACodeBlock reads source[start+1 .. end-1] verbatim, so we strip
    -- exactly `indent` leading columns (blanks/tabs) from each of those lines.
    -- Nothing is stripped when indent = 0 (a top-level block), so the classic
    -- column-1 case is byte-for-byte unchanged.
    If indent > 0 Then
      Do i = start + 1 To end - 1
        source[i] = DeIndent( source[i], indent )
      End

    -- Get the highligthed version of our code block
    highlighted = ProcessACodeBlock( filename, source, start, end, accum, options. )

    -- Re-indent the highlighted HTML by the same amount, so Pandoc still reads
    -- the block as content of the enclosing list item (an un-indented block
    -- would detach and break the outline). indent = 0 leaves it untouched.
    If indent > 0 Then Do
      highlighted = OneLinePre( highlighted )
      pad = Copies(" ", indent)
      Do i = 1 To highlighted~items
        If i == 1, itemPrefix \== "" Then highlighted[i] = itemPrefix || highlighted[i]
        Else highlighted[i] = pad || highlighted[i]
      End
    End

    -- Up to line (start-1), lines are prose: scan them for `` `x`{.rexx ...} ``
    -- mentions (ScanProseMentions is a no-op on a line with none).
    Do line Over source~section( 1, start - 1 )
      processed~append( ScanProseMentions( line, proseHTMLClass, defaultStyle, proseOptions. ) )
    End

    -- We now copy the highlighted lines
    processed~appendAll( highlighted )
    processed~delete( processed~last ) -- Last line is an artifact

    -- Now update our source...
    source = source~section( end + 1 )
    -- ... and the accumulated line count ...
    accum += end
    -- ... and update lineNo (remembering that LOOP will add 1 to it)
    lineNo = 0

  End

  -- Copy any remaining line in the source array -- also prose, also scanned
  Do line Over source
    processed~append( ScanProseMentions( line, proseHTMLClass, defaultStyle, proseOptions. ) )
  End

  -- Final pass: swap each <!--rxprogram:KEY:k AS-IS--> placeholder for its
  -- captured block. Same substitution we do for a lone fence, to N destinations.
  -- Only runs when program= was present; else `processed` is returned as-is.
  If havePrograms Then processed = PlaceProgramBlocks( processed, programBlocks. )

  Return processed

MissingEndMarker:
  Raise Syntax 88.900 -
    Additional("Missing end marker for code block starting at line "lineNo)

--------------------------------------------------------------------------------
-- ScanProseMentions -- Highlight `x`{.rexx ...} mentions in a line of prose  --
--------------------------------------------------------------------------------
-- A prose mention is a Pandoc code span (a run of N backticks, content, the
-- same run of N backticks closing it) immediately followed by an attribute
-- span "{.rexx}" -- optionally with a MODIFIER and/or extra attributes after
-- the class ("{.rexx modifier attr ...}"), exactly as a fenced block carries
-- them after "rexx". The class token is always ".rexx"; the modifier, when
-- present, is one, two or three words from ProseModifierTable.
-- Per-mention style is one such attribute (`style=name`), just
-- like in a fence; there is no separate pin syntax.
--
-- We mirror Pandoc's own code-span rule: the closing run must have
-- EXACTLY the same length as the opening one, so a code span that itself
-- contains a shorter run of backticks (` ``x`y` `` `) is not split early,
-- and a doubled backtick used to quote a literal backtick (`` `x` ``) never
-- matches "{.rexx ...}" unless the author actually wrote the attribute
-- right after the true closing run -- exactly Pandoc's own behaviour, which
-- is what we are pre-empting here (we run before Pandoc ever sees the
-- line). A span whose content does not resolve to a published name (see
-- ProseElementTags) is left completely untouched, backticks and all --
-- vocabulary is FencedCode's to validate, but silently, since we have no
-- author-facing error channel for a line of prose (unlike a fenced block's
-- Syntax 88.900). This may change once there is a natural place to warn.
--
-- ARGUMENTS
--   line:      One line of prose (never a fence line; the caller only
--              invokes this on lines already known to be outside fences).
--   HTMLClass: The stem from HTMLClasses(), built once by the caller
--              against the document's default options.
--   style:     The highlight style ("dark", "light", ...) for the
--              micro-container -- the document's default, since a lone
--              mention has no per-block style= attribute to override it.
--
-- RETURNS the line with every recognised mention replaced by its
-- micro-container HTML (see HLDrivers/HTML.Driver.cls's ProseMention).
-- A line with no backtick is returned unchanged without further scanning.

--------------------------------------------------------------------------------
-- RawInline -- hand a mention's HTML to Pandoc as a raw inline               --
--                                                                            --
-- A mention's HTML goes back into a line of MARKDOWN, and Pandoc reads the   --
-- text between the tags as Markdown too. That silently rewrote the Rexx:     --
-- runs of blanks were collapsed to one, a backslash escaped the character    --
-- after it ("\{" became "{"), "\gulp" was taken for a TeX command and      --
-- dropped, and "*" or "_" inside a string could turn into emphasis. So       --
-- `saY    "x"` with blanks=all showed one blank, and the slide said the      --
-- opposite of what it was meant to show.                                     --
--                                                                            --
-- Pandoc's raw attribute, `...`{=html}, passes its content through as it  --
-- is.                                                                        --
-- The fence is one backtick longer than the longest run of backticks inside, --
-- which is the Markdown rule for a code span that contains backticks.        --
--------------------------------------------------------------------------------

::Routine RawInline Private
  Use Strict Arg html

  longest = 0
  run     = 0
  Loop i = 1 To html~length
    If html~substr(i, 1) == "`" Then Do
      run = run + 1
      longest = Max(longest, run)
    End
    Else run = 0
  End
  fence = Copies("`", longest + 1)

  Return fence || html || fence"{=html}"

::Routine ScanProseMentions Private
  Use Strict Arg line, HTMLClass, style, proseOptions.

  If \line~contains("`") Then Return line

  out  = ""
  rest = line

  Loop While rest \== ""
    tick = rest~pos("`")
    If tick == 0 Then Do  -- No more backticks: copy the remainder verbatim
      out ||= rest
      Leave
    End

    -- Copy everything up to the backtick run untouched
    out ||= SubStr(rest, 1, tick - 1)
    rest = SubStr(rest, tick)

    -- Measure the opening run
    openRun = Strip( rest, "Leading", "`" )
    n       = Length(rest) - Length(openRun)
    run     = Copies("`", n)

    -- Find the first closing run of the SAME length (Pandoc's own rule)
    body = openRun
    p    = 1
    Found = 0
    Loop While p <= Length(body)
      q = Pos(run, body, p)
      If q == 0 Then Leave
      -- A longer run of backticks at q does not count as this run's close
      If SubStr(body, q + n, 1) == "`" Then Do
        p = q + n
        Iterate
      End
      Found = 1
      Leave
    End

    If \Found Then Do -- Unterminated span: not our business, copy verbatim
      out ||= run
      rest = body
      Iterate
    End

    content   = SubStr(body, 1, q - 1)
    spanEnd   = SubStr(body, q + n)  -- immutable: right after the closing run
    afterSpan = spanEnd

    -- Is the span immediately followed by a Rexx attribute span? Two families
    -- share the "{.rexx" opening:
    --   {.rexx}           -- AUTO-PARSE: tokenise the fragment
    --   {.rexx modifier}  -- BY-ELEMENT: tag one manual mention
    -- Either may carry extra attributes after the class ({.rexx attr ...}).
    -- We capture the attribute body once (everything between the braces) and
    -- then classify, so the brace-matching guard (reject a stray "{" before
    -- the real close) is written in one place for both.
    tag = ""
    isRexxAttr = 0
    If afterSpan~startsWith("{.rexx") Then Do
      closeBrace = Pos("}", afterSpan)
      openBrace2 = Pos("{", afterSpan, 2)
      If closeBrace == 0 Then Nop            -- No closing brace: not a mention
      Else If openBrace2 \== 0, openBrace2 < closeBrace Then Nop -- stray "{"
      Else Do
        tag        = SubStr( afterSpan, 2, closeBrace - 2 )  -- drop "{" and "}"
        isRexxAttr = 1
        afterSpan  = SubStr( afterSpan, closeBrace + 1 )
      End
    End

    If \isRexxAttr Then Do -- Not a Rexx attribute span: copy verbatim
      out ||= run || content || run
      rest = spanEnd -- resume right after the closing run, untouched
      Iterate
    End

    -- Classify. The class token is ALWAYS ".rexx". What follows,
    -- blank-separated, is:
    --   ".rexx [modifier] [attr [attr ...]]"
    -- where an optional MODIFIER may precede the fence-style attributes. Every
    -- modifier lives in ProseModifierTable (the single vocabulary), keyed by its
    -- SPACE form -- one, two or three words: "method", "internal function",
    -- "external package function". The table entry's type (MODE / OPERATOR /
    -- ELEMENT / KLUDGE) drives the dispatch below.
    --
    -- The remaining words are the SAME options a fence carries (style=name,
    -- bool...), handed to the SAME ParseOptions -- no span-specific grammar.
    --
    -- We peel ".rexx" off, then match the modifier by LONGEST match, 3 -> 2 -> 1
    -- words, against the table. The first hit fixes the modifier and the rest are
    -- attributes. This is unambiguous: no real attribute is ever the 2nd or 3rd
    -- component of a table entry (attributes carry "=value" or are lone words the
    -- table never lists as a tail), so a 2-word modifier can never be mistaken
    -- for a 1-word modifier followed by an attribute. If no length hits, there is
    -- no modifier and the whole rest is attributes -- so `{.rexx style=dark}`
    -- still means "auto-parse, styled", keeping that path byte-compatible.
    Parse Var tag dotted rawRest
    modifierTable. = ProseModifierTable()
    modifier   = ""
    modifierEntry = .Nil
    extraAttrs = rawRest
    words = rawRest~makeArray(" ")          -- one item per blank-separated word
    Loop len = 3 To 1 By -1
      If words~items < len Then Iterate
      candidate = ""
      Loop i = 1 To len
        candidate = candidate words[i]
      End
      candidate = Strip( candidate )
      If modifierTable.~hasIndex( candidate ) Then Do
        modifier      = candidate
        modifierEntry = modifierTable.[ candidate ]
        -- Rebuild extraAttrs from the words after the matched run.
        extraAttrs = ""
        Loop i = len + 1 To words~items
          extraAttrs = extraAttrs words[i]
        End
        extraAttrs = Strip( extraAttrs )
        Leave
      End
    End

    -- Per-mention options. Start from a real COPY of the document's
    -- proseOptions. and, if the mention carries extra attributes, ADD them on
    -- top -- monotonic, like every other dialect path (on if set on the
    -- document OR here). A mention never turns an option off. The copy is
    -- essential: in ooRexx `a. = b.` shares the stem, so mutating it would
    -- leak this mention's attrs into proseOptions. and thus into every later
    -- mention on the same line. `~copy` gives an independent stem.
    --
    -- `style=` is cosechado from the parsed attrs into mentionStyle so it drives
    -- the highlight-rexx-<style> micro-container, exactly as `style=` drives the
    -- <div> wrapper in a fenced block. Absent, the document default stands.
    mentionStyle     = style
    mentionHTMLClass = HTMLClass
    If Strip(extraAttrs) == "" Then
      mentionOptions. = proseOptions.          -- no attrs: share is fine (read-only)
    Else Do
      mentionOptions. = proseOptions.~copy
      -- Reuse ParseOptions by prefixing a language word it knows to skip.
      addOptions. = ParseOptions( "prose-mention", "rexx {"extraAttrs"}", style )
      -- What this mention actually NAMED is whatever differs from the defaults,
      -- and that is what carries over. The test used to be "the value is 1",
      -- which is only true of the flag-shaped options (unicode, .numberLines,
      -- ...): every option that takes a VALUE -- blanks=, operator=, and the
      -- rest of that family -- was parsed here and then dropped on the floor,
      -- in silence. `Say A B`{.rexx .blanks} highlighted perfectly and marked
      -- nothing, which is the worst kind of answer: it looks like the feature
      -- is there and disagreeing with you.
      --
      -- Still monotonic: a mention can only set what it names, and what it does
      -- not name it takes from the document.
      baseOptions. = ParseOptions( "prose-mention", "rexx", style )
      Do idx Over addOptions.~allIndexes
        If addOptions.[idx] \== baseOptions.[idx] Then
          mentionOptions.[idx] = addOptions.[idx]
      End
      If addOptions.~hasIndex("STYLE-EXPLICIT") Then mentionStyle = addOptions.["STYLE"]
      -- An extra attribute may change the classes the highlighter emits (e.g. a
      -- dialect that adds element categories), so rebuild the class stem for this
      -- mention against the augmented options. Cheap and keeps one source of truth.
      mentionHTMLClass = HTMLClasses( mentionOptions. )
    End

    -- The class token must be exactly ".rexx" now. Anything else (".rexxFOO")
    -- is not a real class: leave it verbatim, a typo the author can see.
    If dotted \== ".rexx" Then Do
      out ||= run || content || run || "{"tag"}"
      rest = afterSpan
      Iterate
    End

    -- MODE modifier -> ModeChip refines an auto-parse (prefix / reference /
    -- comparison / assignment / expression), validating the modifier's domain
    -- and shouting in situ if it is misapplied.
    If modifierEntry \== .Nil, modifierEntry[1] == "MODE" Then Do
      out ||= RawInline( ModeChip( content, modifier, mentionStyle, mentionHTMLClass, mentionOptions. ) )
      rest = afterSpan
      Iterate
    End

    -- OPERATOR modifier -> an operator reached by name because its glyph cannot
    -- be span content. Resolves straight to its category, so a named operator and
    -- a fenced one of the same category share their colour. Today only "blank
    -- concatenation" (.EL.OP.BLANK), whose glyph is a space. SymbolChip strips its
    -- content, which would annihilate that space, so the blank emits its glyph
    -- (a single space) directly through ProseMention; any future visible-glyph
    -- operator would go through SymbolChip like the glyph-lookup path.
    If modifierEntry \== .Nil, modifierEntry[1] == "OPERATOR" Then Do
      If modifierEntry[2] == .EL.OP.BLANK Then
        out ||= RawInline( ProseMention( mentionStyle, mentionHTMLClass[ .EL.OP.BLANK ], " " ) )
      Else
        out ||= RawInline( SymbolChip( content, mentionStyle, mentionHTMLClass, modifierEntry[2] ) )
      rest = afterSpan
      Iterate
    End

    -- No modifier -> CLASSIFY, THEN (only if needed) PARSE. The cascade is
    -- ordered cheapest-first, and -- deliberately -- looks a token up BEFORE it
    -- ever pays for a parse.
    --
    -- Each lookup step fires ONLY on an EXACT match (the trimmed content IS the
    -- glyph / IS a single keyword / IS `::keyword` with no name). A longer
    -- fragment that merely BEGINS with a keyword (`Say "hi"`) or a directive
    -- with its name (`::Class Bar`) does not match any lookup and falls through
    -- to the parser, which colours it correctly. That "exact / no remainder"
    -- guard is what keeps the lookups from stealing the compositional cases the
    -- parser already handles better.
    --
    -- Order:
    --   (a) THE "=" CATCH: "=" has no default (OP.EQUAL vs ASG.EQUAL); raise our
    --       own helpful shout naming the two modifiers.
    --   (b) GLYPH LOOKUP: a lone operator/special char (ProseSymbolTable). Also
    --       catches "," which ooRexx would accept as an empty continued clause.
    --   (c) KEYWORD LOOKUP: the trimmed content is exactly one keyword
    --       instruction (dialect-sensitive) -> colour it rx-kw. This is the step
    --       that makes `Do`/`If`/`End`/`Select`... -- the clause keywords that do
    --       NOT parse alone -- colour truthfully instead of shouting.
    --   (d) COMPOUND-DIRECTIVE LOOKUP: the trimmed content is `::keyword` with no
    --       name (dialect-sensitive keyword set) -> the two-span dir+dkw chip.
    --       `::keyword name` (with a name) fails this and falls to the parser.
    --   (e) AUTO-PARSE: none of the above; hand the fragment to the inline
    --       highlighter. It PARSES for real, so an ill-formed fragment raises
    --       Syntax -- caught in RexxFragment and rendered as an in-situ shout.
    If modifier == "" Then Do
      trimmed = Strip( content )

      -- (a)
      If trimmed == "=" Then Do
        out ||= RawInline( ErrorChip( content, mentionStyle, -
          'Ambiguous operator "=";', -
          "add the comparison or assignment modifier." ) )
        rest = afterSpan
        Iterate
      End

      -- (b)
      Sym. = ProseSymbolTable()
      If Sym.~hasIndex( trimmed ) Then Do
        out ||= RawInline( SymbolChip( content, mentionStyle, mentionHTMLClass, Sym.[trimmed] ) )
        rest = afterSpan
        Iterate
      End

      -- (c) -- exact single keyword instruction. Upper() once; the set is
      -- upper-cased. A keyword never contains whitespace, so a multi-word
      -- fragment cannot match and correctly falls through to the parser.
      keywordSet = KeywordInstructionSet( mentionOptions. )
      If keywordSet~hasIndex( Upper( trimmed ) ) Then Do
        out ||= RawInline( SymbolChip( content, mentionStyle, mentionHTMLClass, .EL.KEYWORD ) )
        rest = afterSpan
        Iterate
      End

      -- (d) -- exact `::keyword` with no name. ParseCompoundDirective returns
      -- .Nil the moment a name or embedded whitespace follows the keyword, so
      -- `::Class Bar` falls through to the parser (which colours its name).
      If trimmed~startsWith("::") Then Do
        parsed = ParseCompoundDirective( trimmed )
        If parsed \== .Nil Then Do
          directiveSet = DirectiveKeywordSet( mentionOptions. )
          If directiveSet~hasIndex( Upper( parsed[2] ) ) Then Do
            out ||= RawInline( CompoundDirectiveChip( parsed[1], parsed[2], -
                                           mentionStyle, mentionHTMLClass ) )
            rest = afterSpan
            Iterate
          End
        End
      End

      -- (e)
      out ||= RawInline( RexxFragment( content, mentionStyle, mentionOptions. ) )
      rest = afterSpan
      Iterate
    End

    -- SEMANTIC assertion -> by-element. The modifier IS the public name
    -- (method, class, variable, the call forms, the kludges...).
    publicName = modifier

    -- KLUDGE: the compound `directive` (`::Method`). It is not one element but
    -- a two-element sequence (`::` + keyword), so it has no row in ProseTable
    -- (which maps a public name to ONE category). `{.rexx}` cannot help either:
    -- `::Method` alone is a directive missing its required name, so it does not
    -- parse. We split the content into `::` and the keyword by hand and emit a
    -- SINGLE chip holding two token spans -- `dir` then `dkw` -- both classes
    -- derived from the SAME HTMLClass stem the generic path uses, so there is
    -- still one source of truth. Content shape: `::` then optional whitespace
    -- then the keyword. Anything that does not fit is left verbatim (a typo the
    -- author can see), never a red shout: this path never parses.
    If publicName == "directive" Then Do
      parsed = ParseCompoundDirective( content )
      If parsed == .Nil Then Do -- malformed: leave the mention verbatim
        out ||= run || content || run || "{"tag"}"
        rest = afterSpan
        Iterate
      End
      dirText = parsed[1]        -- the "::" (plus any whitespace the author wrote)
      kwText  = parsed[2]        -- the directive keyword
      out ||= RawInline( CompoundDirectiveChip( dirText, kwText, mentionStyle, mentionHTMLClass ) )
      rest = afterSpan
      Iterate
    End

    -- KLUDGE: `exposed`. A variable's KIND (simple / compound / stem) is
    -- something the text sustains -- the auto-parse deduces it from the dot and
    -- the tails, exactly as for a non-exposed variable. What it CANNOT deduce is
    -- that the variable is EXPOSED, since a bare fragment has no Expose to
    -- declare it. So the author asserts only that one extra-textual fact with
    -- the single `exposed` modifier, and ExposedChip auto-parses to discover the
    -- kind, then relabels the base to its exposed colour (xvar/xstem; a
    -- compound's tail stays a normal var -- a documented limitation, since an
    -- isolated fragment cannot know which tails are exposed). Off-domain (the
    -- fragment is not a variable at all) it shouts, our own honest error.
    If publicName == "exposed" Then Do
      out ||= RawInline( ExposedChip( content, mentionStyle, mentionHTMLClass, mentionOptions. ) )
      rest = afterSpan
      Iterate
    End

    -- KLUDGE: a taken constant written as a STRING. A string in isolation is
    -- just a string, so neither {.rexx} (auto-parse sees a bare STRING -> rx-str)
    -- nor a by-element mention (one flat class over the whole content ->
    -- monochrome, quotes without their own rx-oquo/rx-cquo) reproduce what a
    -- FENCED block emits. Same family as the #directive and #exposed kludges: a
    -- per-element tag facing something that is several elements (quote + interior
    -- + optional suffix).
    --
    -- THE INSIGHT: a string literal's STRUCTURE -- the rx-oquo / rx-cquo
    -- on its quotes and rx-ssuf on its suffix -- is invariant to context. A
    -- fenced `::Method "X"`, `Call "X"`, or the bare `"X"` all tokenise the quotes
    -- and suffix identically; only the BASE class differs (rx-str / rx-xstr for a
    -- bare literal, rx-const rx-<cat> inside a real clause). And the base is what
    -- the author's tag asserts anyway (decision 2). So there is nothing to
    -- synthesise and nothing to trim: we auto-parse the string ALONE, then relabel
    -- its base (rx-str / rx-xstr) to the tag's class, keeping oquo/cquo/ssuf. This
    -- is why func-vs-proc, method-vs-class etc. need no distinct context here --
    -- ProseElementTags(publicName) already carries that distinction.
    --
    -- Only STRING-shaped content takes the kludge. The same tags also mark BARE
    -- names (`Length`{.rexx builtin function}, `Bark`{.rexx method}), which the
    -- generic by-element path handles correctly -- a bare name is one element, one
    -- flat class is right. So we branch here only when the author wrote a quoted
    -- string AND the public name is a string-capable taken constant.
    If IsStringShaped( content ), IsStringConstName( publicName ) Then Do
      out ||= RawInline( TakenConstantChip( content, mentionStyle, mentionHTMLClass, publicName, mentionOptions. ) )
      rest = afterSpan
      Iterate
    End

    tags = ProseElementTags( mentionHTMLClass, publicName )

    If tags == .Nil Then Do -- Unpublished name (typo?): leave verbatim
      out ||= run || content || run || "{"tag"}"
    End
    Else
      out ||= RawInline( ProseMention( mentionStyle, tags, content ) )

    rest = afterSpan
  End

  Return out

--------------------------------------------------------------------------------
-- RexxFragment -- tokenise a `{.rexx}` inline fragment (auto-parse)          --
--------------------------------------------------------------------------------
-- The counterpart of a by-element mention: instead of tagging the content    --
-- with one manual class, we PARSE it -- the same engine a fenced block uses, --
-- reached through the "HTML-INLINE" driver, which emits the token spans with --
-- none of the block chrome (<div>/<pre>/<code>/anchors). The token stream is --
-- byte-for-byte what a fenced block would produce for the same source, so a  --
-- fragment and a listing of the same code colour identically.                --
--                                                                            --
-- WHERE THE LINE IS DRAWN. `{.rexx}` recovers everything the TEXT knows      --
-- about itself: a fragment that "holds" (fixes its tokens' roles -- a whole  --
-- clause, a complete directive) parses and colours truthfully. A fragment    --
-- that does NOT hold cannot be coldoured without inventing a context the     --
-- author did not write, so the parser raises Syntax and we do NOT guess --   --
-- we shout (below). What no completion can recover (exposed vs not; a Call   --
-- resolving internal/external/builtin) is extra-textual and stays the job of --
-- the by-element mentions, which supply exactly that.                        --
--                                                                            --
-- ARGUMENTS                                                                  --
--   content:      the fragment's source text (already un-escaped; the        --
--                 highlighter escapes as it emits).                          --
--   style:        the highlight style for the chip (document default, or a   --
--                 `style=name` attribute the author wrote after {.rexx}).    --
--   proseOptions: the document's prose options -- the SAME source of truth   --
--                 the by-element path uses, so classprefix=, constant= etc.  --
--                 stay in sync. We clone it and flip only mode to inline.    --
--                                                                            --
-- RETURNS a single HTML string: the chip, tokenised on success, red on fail. --

::Routine RexxFragment Private
  Use Strict Arg content, style, proseOptions.

  Signal On Syntax

  -- Clone the prose options and retarget them at the inline driver. We copy
  -- into a fresh stem so we never mutate the caller's one-shot proseOptions.
  fragOptions. = 0
  Do idx Over proseOptions.~allIndexes
    fragOptions.idx = proseOptions.idx
  End
  fragOptions.mode  = "HTML-INLINE"
  fragOptions.style = style

  source = .Array~of( content )
  highlighter = .Highlighter~new( "<{.rexx} fragment>", source, fragOptions. )
  tokens = highlighter~parse

  -- parse returns an array of output lines; inline emits no forced newlines,
  -- so for a one-line fragment this is a single element (a trailing "" may be
  -- appended by the emitter's Say -- drop empties and concatenate directly:
  -- a fragment is one continuous run of tokens, so the rare two-line fragment
  -- joins seamlessly with no separator to leak into the copy or the flow).
  html = ""
  Do piece Over tokens
    If piece == "" Then Iterate
    html ||= piece
  End

  -- Wrap in the same chip ProseMention uses, but the inner content is already
  -- tokenised HTML (not text to escape): class "rexx" only, the tokens carry
  -- their own rx-* classes.
  Return '<span class="highlight-rexx-'style'"><code class="rexx">' -
         || html || '</code></span>'

Syntax:
  -- The fragment did not hold. Shout in situ -- red chip, the offending
  -- fragment shown, AND the parser's own complaint appended so the author sees
  -- exactly what the parser choked on. Deliberately ugly, not pretty: the goal
  -- is maximum information for debugging, not typography.
  --
  -- Two texts are appended when available: the GENERIC error text (the code's
  -- fixed wording, e.g. "Symbol expected.") and the SPECIFIC message (the
  -- contextualised one, e.g. "Symbol expected after PARSE keyword."). Both are
  -- guarded: on some edge cases the specific message is not delivered, so we
  -- emit whichever pieces exist and never assume the second one is there.
  -- Condition("O") is a Directory, so probe it with hasIndex/[] rather than
  -- hasMethod: the pieces we want are entries, not methods.
  co  = Condition("O")
  errText = ""
  detail  = ""
  If co \== .Nil Then Do
    -- Generic error text (first message).
    If co~hasIndex("ERRORTEXT"), co["ERRORTEXT"] \== .Nil Then errText = co["ERRORTEXT"]
    -- Specific, contextualised message (second message) -- may be absent on
    -- some edge cases, hence the guard; we never assume it is there.
    If co~hasIndex("MESSAGE"), co["MESSAGE"] \== .Nil Then detail = co["MESSAGE"]
  End
  Return ErrorChip( content, style, errText, detail )

--------------------------------------------------------------------------------
-- SymbolChip -- colour a lone glyph by its category (no name in between)     --
--------------------------------------------------------------------------------
-- The by-element emitter entered by CATEGORY rather than by public name: the
-- glyph-lookup path (ProseSymbolTable) and the symbol-domain modes resolve to
-- a category, and this turns it into the same chip a named mention would emit
-- -- HTMLClass[category] is the single source of truth for the class string,
-- so a glyph and a fenced token of the same category share their colour.

::Routine SymbolChip Private
  Use Strict Arg content, style, HTMLClass, category
  Return ProseMention( style, HTMLClass[ category ], Strip(content) )

--------------------------------------------------------------------------------
-- ModeChip -- apply one of the five auto-parse MODES, validating its domain  --
--------------------------------------------------------------------------------
-- Each mode refines how a fragment is coloured. Four of them (prefix,
-- reference, comparison, assignment) act on a SYMBOL and have a narrow domain:
-- applied off-domain, they shout in situ (an error the author sees), never
-- colour-wrong-in-silence. The fifth (expression) acts on a whole fragment:
-- it wraps the content in synthetic parentheses, auto-parses that, and -- on
-- success -- peels the parentheses it added back off.
--
-- (The blank concatenation operator was once a mode here; it is now a named
-- OPERATOR in ProseModifierTable -- a genuine operator, not a parse mode --
-- dispatched directly through SymbolChip before this routine is reached.)
--
-- The symbol modes resolve to a category and emit through SymbolChip, so they
-- share the glyph-lookup path's single source of truth for the class string.

::Routine ModeChip Private
  Use Strict Arg content, modifier, style, HTMLClass, proseOptions.

  trimmed = Strip( content )

  Select
    When modifier == "prefix" Then Do
      If trimmed == "+" Then Return SymbolChip( content, style, HTMLClass, .EL.OP.PREFIX.PLUS  )
      If trimmed == "-" Then Return SymbolChip( content, style, HTMLClass, .EL.OP.PREFIX.MINUS )
      Return ErrorChip( content, style, -
        "The prefix modifier only applies to + and -;", -
        "found """trimmed"""." )
    End

    When modifier == "reference" Then Do
      If trimmed == ">" Then Return SymbolChip( content, style, HTMLClass, .EL.OP.REFERENCE.GREATER_THAN )
      If trimmed == "<" Then Return SymbolChip( content, style, HTMLClass, .EL.OP.REFERENCE.LOWER_THAN   )
      Return ErrorChip( content, style, -
        "The reference modifier only applies to < and >;", -
        "found """trimmed"""." )
    End

    When modifier == "comparison" Then Do
      If trimmed == "=" Then Return SymbolChip( content, style, HTMLClass, .EL.OP.EQUAL )
      Return ErrorChip( content, style, -
        "The comparison modifier only applies to =;", -
        "found """trimmed"""." )
    End

    When modifier == "assignment" Then Do
      If trimmed == "=" Then Return SymbolChip( content, style, HTMLClass, .EL.ASG.EQUAL )
      Return ErrorChip( content, style, -
        "The assignment modifier only applies to =;", -
        "found """trimmed"""." )
    End

    When modifier == "expression" Then
      Return ExpressionChip( content, style, proseOptions. )

    Otherwise
      -- Unreachable: the caller only routes known modes here.
      Return ErrorChip( content, style, "Unknown modifier;", """"modifier""".")
  End

--------------------------------------------------------------------------------
-- ExpressionChip -- the "expression" mode: wrap in (), parse, peel the ()    --
--------------------------------------------------------------------------------
-- The residue the design cannot avoid: `a = b` alone is always an assignment
-- instruction, so to colour it as the comparison EXPRESSION the author wraps
-- it in the expression mode. We add synthetic parentheses, auto-parse `(...)`
-- (which forces expression context), and -- if it holds -- strip the two
-- parenthesis token spans we introduced, since the author did not write them.
-- If it does NOT hold, RexxFragment already produced the red shout for the
-- parenthesised form; we pass it through (the fragment genuinely did not parse
-- as an expression, which is exactly what the author needs to see).

::Routine ExpressionChip Private
  Use Strict Arg content, style, proseOptions.

  chip = RexxFragment( "(" || content || ")", style, proseOptions. )

  -- Did the parenthesised form shout? Then it is not an expression; honour it.
  If chip~pos("rx-fragment-error") > 0 Then Return chip

  -- The chip is: <span wrapper><code class="rexx">TOKENS</code></span> where
  -- TOKENS begins with the "(" span and ends with the ")" span we added. Peel
  -- exactly those two spans, leaving the interior tokens untouched.
  codeOpen  = '<code class="rexx">'
  codeClose = '</code>'
  op = chip~pos( codeOpen )
  cl = chip~pos( codeClose, op )
  If op == 0 | cl == 0 Then Return chip          -- shape we did not expect: leave as is

  head   = chip~substr( 1, op + codeOpen~length - 1 )   -- up to and incl. <code ...>
  tokens = chip~substr( op + codeOpen~length, cl - (op + codeOpen~length) )
  tail   = chip~substr( cl )                            -- </code></span>

  -- Drop the FIRST span (the "(") and the LAST span (the ")").
  firstEnd = tokens~pos( "</span>" )
  If firstEnd == 0 Then Return chip
  tokens = tokens~substr( firstEnd + length("</span>") )
  lastStart = tokens~lastPos( "<span" )
  If lastStart == 0 Then Return chip
  tokens = tokens~substr( 1, lastStart - 1 )

  Return head || tokens || tail

--------------------------------------------------------------------------------
-- ParseCompoundDirective -- split `::Method` into ("::", "Method")           --
--------------------------------------------------------------------------------
-- The content of a `{.rexx directive}` mention: the literal `::` directive
-- start, then optional whitespace, then the directive keyword. We keep any
-- whitespace the author wrote GLUED to the "::" half, so the chip's copy
-- reproduces `::  Method` faithfully while the keyword span still styles only
-- the word. This never PARSES (a lone `::Method` is not a valid program) --
-- it is a purely textual split, on purpose: the whole reason the compound
-- exists is that `{.rexx}` rejects it.
--
-- RETURNS a 2-element array (dirPart, keyword), or .Nil if the content does
-- not have the `::` + word shape (caller then leaves the mention verbatim).

-- CompoundDirectiveChip -- emit the two-span chip for a bare `::keyword`.
--------------------------------------------------------------------------------
-- Given the split (dirText, kwText) produced by ParseCompoundDirective, build
-- the single chip holding a `dir` span (the "::") then a `dkw` span (the
-- keyword), both classes drawn from the SAME HTMLClass stem the generic path
-- uses. Factored out so the two callers that need it -- the explicit
-- `{.rexx directive}` assertion and the bare `{.rexx}` auto-detect -- share
-- one emitter and never drift.

::Routine CompoundDirectiveChip Private
  Use Strict Arg dirText, kwText, style, HTMLClass
  dirClass = HTMLClass[ .EL.DIRECTIVE_START   ]
  kwClass  = HTMLClass[ .EL.DIRECTIVE_KEYWORD ]
  inner = '<span class="'dirClass'">'EscapeHTML(dirText)'</span>' -
       || '<span class="'kwClass'">'EscapeHTML(kwText)'</span>'
  Return '<span class="highlight-rexx-'style'">' -
       || '<code class="rexx">'inner'</code></span>'

--------------------------------------------------------------------------------
::Routine ParseCompoundDirective Private
  Use Strict Arg content

  -- Must start with "::"
  If content~length < 3 Then Return .Nil
  If content~substr(1, 2) \== "::" Then Return .Nil

  rest = content~substr(3)                 -- everything after the "::"

  -- Absorb leading whitespace into the "::" half.
  ws = ""
  Loop While rest \== ""
    c = rest~left(1)
    If c \== " ", c \== "09"x Then Leave
    ws ||= c
    rest = rest~substr(2)
  End

  -- What remains must be a single word (the keyword): non-empty, no embedded
  -- whitespace. A trailing name or subkeyword means the author wrote more than
  -- the bare `::Method` -- that is a different (probably `{.rexx}`) case.
  keyword = rest
  If keyword == "" Then Return .Nil
  If keyword~verify(" "||"09"x, "Match") \== 0 Then Return .Nil

  Return .Array~of( "::" || ws, keyword )

--------------------------------------------------------------------------------
-- ExposedChip -- the `exposed` modifier: auto-parse, then relabel the base   --
--------------------------------------------------------------------------------
-- One modifier for all three exposed kinds. We let {.rexx} tokenise the
-- fragment truthfully (as NON-exposed, since a bare fragment has no Expose),
-- read the kind from the FIRST token span, and relabel just the base to its
-- exposed colour:
--   simple   -- base is a simple variable (rx-var)  -> exposed simple (xvar)
--   stem     -- base is a stem (rx-stem)            -> exposed stem   (xstem)
--   compound -- base is a stem (rx-stem) + tails    -> exposed stem   (xstem),
--               tails left as parsed (a documented limitation: an isolated
--               fragment cannot know which tails are exposed).
--
-- SAFETY (JMB's rule): if RexxFragment shouted, pass it through. If the first
-- span is neither a simple variable nor a stem, the fragment is not a variable
-- at all, so we do NOT force anything -- we build our own error chip.
--
-- All classes come from HTMLClass (one source of truth).

::Routine ExposedChip Private
  Use Strict Arg content, style, HTMLClass, proseOptions.

  chip = RexxFragment( content, style, proseOptions. )

  -- If the fragment did not parse, RexxFragment already produced the red error
  -- chip. Honour it -- do not try to relabel a shout.
  If chip~pos("rx-fragment-error") > 0 Then Return chip

  varClass   = HTMLClass[ .EL.SIMPLE_VARIABLE          ]  -- rx-var
  stemClass  = HTMLClass[ .EL.STEM_VARIABLE            ]  -- rx-stem
  xvarClass  = HTMLClass[ .EL.EXPOSED_SIMPLE_VARIABLE  ]  -- xvar
  xstemClass = HTMLClass[ .EL.EXPOSED_STEM_VARIABLE    ]  -- xstem

  -- The base is the FIRST token span, right after the <code ...> opening.
  codeOpen = chip~pos( '<code class="rexx">' )
  firstTokenSpan = 0
  If codeOpen > 0 Then
    firstTokenSpan = codeOpen + length( '<code class="rexx">' )
  If firstTokenSpan == 0 Then
    Return ErrorChip( content, style, -
      "Not a variable;", "the exposed modifier needs a simple, stem or compound variable." )

  -- Which kind? A stem base (rx-stem) covers stem AND compound; a simple-var
  -- base (rx-var) covers the simple case. Anything else is not a variable.
  stemMarker = '<span class="'stemClass'">'
  varMarker  = '<span class="'varClass'">'
  If chip~substr( firstTokenSpan, stemMarker~length ) == stemMarker Then Do
    marker = stemMarker
    exposedClass = xstemClass
  End
  Else If chip~substr( firstTokenSpan, varMarker~length ) == varMarker Then Do
    marker = varMarker
    exposedClass = xvarClass
  End
  Else
    Return ErrorChip( content, style, -
      "Not a variable;", "the exposed modifier needs a simple, stem or compound variable." )

  -- Relabel just this base span: swap its class for the exposed one.
  p = firstTokenSpan
  Return chip~substr(1, p - 1) -
      || '<span class="'exposedClass'">' -
      || chip~substr( p + marker~length )

--------------------------------------------------------------------------------
-- IsStringShaped -- did the author write the content as a quoted string?     --
--------------------------------------------------------------------------------
-- The kludge fires only on STRING-shaped content; a bare name is one element and
-- the generic by-element path colours it correctly. True iff the trimmed content
-- opens with a single or double quote.

::Routine IsStringShaped Private
  Use Strict Arg content
  s = Strip( content )
  If s == "" Then Return 0
  q = s~left(1)
  Return q == '"' | q == "'"

--------------------------------------------------------------------------------
-- IsStringConstName -- is this public name a taken constant with a STRING form?
--------------------------------------------------------------------------------
-- The kludge applies to every taken-constant category that can be written as a
-- literal string. That is: the call forms (all internal/builtin/package/external
-- x function/subroutine plus their bare shortcuts, via IsCallPublicName), plus
-- the general taken constants whose name or value may be a string (method, class,
-- routine, requires, resource, resource delimiter, label, environment, constant
-- value, annotation value).
-- EXCLUDED are the symbol-only names -- user condition, annotation (name), and
-- namespace are single symbols taken as constants, never strings (the engine
-- raises "Symbol expected" on a quoted form); argument is an Executor extension
-- we do not build without a variant flag -- and names that are not taken
-- constants at all (variable, keyword, exposed, ...).
--
-- We decide by the modifier's element SUBCATEGORY, read from ProseModifierTable
-- -- the single vocabulary -- rather than a parallel name list, so a new call or
-- string-capable category is picked up here the moment it is published there,
-- and a modifier's SPACE form (e.g. "constant value") never needs restating.
--
-- Because a string literal's structure is context-invariant, EVERY name here is
-- handled by the same auto-parse-and-relabel; there is no per-name mold.

::Routine IsStringConstName Private
  Use Strict Arg publicName
  If IsCallPublicName( publicName ) Then Return 1
  Table.   = ProseModifierTable()
  entry    = Table.[ publicName ]
  If entry == .Nil Then Return 0
  If entry[1] \== "ELEMENT" Then Return 0
  If entry~items < 3 Then Return 0            -- needs a taken-constant subcategory
  Return .Set~of( .METHOD.NAME, .CLASS.NAME, .ROUTINE.NAME, -
                  .REQUIRES.PROGRAM.NAME, .RESOURCE.NAME, -
                  .RESOURCE.DELIMITER.NAME, .LABEL.NAME, .ENVIRONMENT.NAME, -
                  .CONSTANT.VALUE, .ANNOTATION.VALUE )~hasIndex( entry[3] )

--------------------------------------------------------------------------------
-- IsCallPublicName -- is this public name one of the call forms?             --
--------------------------------------------------------------------------------
-- The explicit call forms (internal/builtin/package/external/external package x
-- function/subroutine) plus the bare shortcuts, recognised by their element
-- subcategory in ProseModifierTable. Kept a separate predicate because the call
-- names are also what the generic path recognises for bare-name call mentions.

::Routine IsCallPublicName Private
  Use Strict Arg publicName
  Table.   = ProseModifierTable()
  entry    = Table.[ publicName ]
  If entry == .Nil Then Return 0
  If entry[1] \== "ELEMENT" Then Return 0
  If entry~items < 3 Then Return 0
  Return .Set~of( .INTERNAL.FUNCTION.NAME, .INTERNAL.SUBROUTINE.NAME, -
                  .BUILTIN.FUNCTION.NAME,  .BUILTIN.SUBROUTINE.NAME,  -
                  .PACKAGE.FUNCTION.NAME,  .PACKAGE.SUBROUTINE.NAME,  -
                  .EXTERNAL.FUNCTION.NAME, .EXTERNAL.SUBROUTINE.NAME, -
                  .EXTERNAL.PACKAGE.FUNCTION.NAME, -
                  .EXTERNAL.PACKAGE.SUBROUTINE.NAME )~hasIndex( entry[3] )

--------------------------------------------------------------------------------
-- CallSuffixValid -- is the (optional) suffix of a string constant legal?    --
--------------------------------------------------------------------------------
-- Called only for STRING-shaped content, so here we only ask about the suffix. A
-- string constant may carry a one-letter suffix. The superset is "BXYPGTU"
-- (Globals.cls, EL.STRING_SUFFIX). B and X are active always; Y/P/G/T/U are
-- TUTOR-only. The engine's own Scanner (Scanner.cls) switches the accepted set
-- from "BX" to "BXYPGTU" when .Options.Unicode == 1, i.e. when TUTOR-flavored
-- Unicode is on. We mirror that here: 'tutor' is 1 when the document (via YAML
-- prologue, CLI flag, or the fence) enabled unicode/TUTOR, carried in through
-- proseOptions.unicode. We validate against the same set the engine would.
--
-- The suffix is whatever the author wrote AFTER the closing quote (the LAST
-- quote matching the opening one). An empty suffix is valid (no suffix at all).
--
-- Validate up front (decision 1, JMB): an illegal suffix would make the engine
-- split the literal into two tokens, so we would relabel something that is not a
-- single constant. We refuse and shout instead. Returns 1 if valid, 0 if not.

::Routine CallSuffixValid Private
  Use Strict Arg content, tutor = 0
  s = Strip( content )
  quote   = s~left(1)
  closeAt = s~lastPos( quote )
  suffix  = s~substr( closeAt + 1 )
  If suffix == "" Then Return 1                  -- bare string, no suffix
  -- Same partition the engine's Scanner uses (Scanner.cls): "BX" without
  -- TUTOR, "BXYPGTU" with it. One letter per suffix, so a per-character set.
  If tutor Then valid = "BXYPGTU"
           Else valid = "BX"
  Return valid~caselessContains( suffix~upper ) & Length(suffix) == 1

--------------------------------------------------------------------------------
-- CallChip -- string-shaped taken-constant call via synthesise + trim + relabel
--------------------------------------------------------------------------------
-- The "beast". A string used as a call name is several elements (quote, body,
-- optional suffix), so we let the engine tokenise it truthfully by SYNTHESISING
-- the call context around it, then TRIM the scaffolding the synthesis added and
-- RELABEL the base class to what the author's tag asserts.
--
-- FORM (from the last word of publicName):
--   ...function   -> synthesise `NAME()`, parse, drop the two trailing rx-spe
--                    spans -- the `(` and `)` we added.
--   ...subroutine -> synthesise `Call NAME`, parse, drop the head we added:
--                    the rx-kw `Call` span and the following rx-ws span.
--   bare shortcut   -> subroutine form (readme: the bare shortcut is a subr).
--
-- SUFFIX CHECK (decision 1, JMB): validate the suffix BEFORE synthesising. An
-- illegal suffix would make the engine split the constant into two tokens, so
-- the trim would land mid-structure and emit plausible-but-wrong HTML. We shout
-- instead, our own honest error chip.
--
-- RELABEL (decision 2, JMB): the engine deduces the base class from the string
-- CONTENT ("DATE"->bif, "Date"->ext). But the author's TAG is the assertion, so
-- we swap the deduced base (rx-const rx-<cat>-<form>) for the tag's base from
-- ProseElementTags(publicName), while KEEPING each span's structural subclass
-- (rx-oquo/rx-cquo/rx-ssuf) intact.
--
-- SAFETY (JMB's rule, inherited from the exposed kludge): if the synthesis did
-- not produce the expected structure (parse shout, missing scaffolding, or the
-- token stream is not the uniform constant we expect), do NOT force anything --
-- emit an error chip, never plausible-but-wrong HTML.
--
-- RETURNS the finished chip HTML.

--------------------------------------------------------------------------------
-- TakenConstantChip -- string-shaped taken constant via auto-parse + relabel --
--------------------------------------------------------------------------------
-- A string literal's STRUCTURE is context-invariant: the rx-oquo / rx-cquo on
-- its quotes and the rx-ssuf on its suffix are the same whether the literal sits
-- inside `::Method "X"`, `Call "X"`, or stands alone as `"X"`. Only the BASE
-- class differs -- and the base is what the author's tag asserts (decision 2).
-- So we do NOT synthesise any context and we trim nothing: we auto-parse the
-- string ALONE (RexxFragment gives it rx-str, or rx-xstr when it has a suffix),
-- then relabel that base to the tag's class, keeping every structural subclass.
-- That is the whole kludge.
--
-- SUFFIX CHECK: validate the suffix first. An illegal suffix
-- makes the engine split the literal into two tokens (`"Whatever"S` -> str + a
-- separate symbol), so what we relabel would not be one constant. We refuse and
-- shout instead. B/X only (non-TUTOR); see CallSuffixValid.
--
-- RELABEL: swap the auto-parse base (rx-str / rx-xstr) for the
-- tag's base from ProseElementTags(publicName), keeping each span's structural
-- subclass (rx-oquo/rx-cquo/rx-ssuf). func-vs-proc, method-vs-class and every
-- other distinction comes from the tag, not from any synthesised context.
--
-- SAFETY (JMB's rule, from the exposed kludge): if the fragment does not parse,
-- or does not tokenise as a single string literal (no base span to relabel), we
-- do NOT force anything -- we emit an honest error chip.
--
-- RETURNS the finished chip HTML.

::Routine TakenConstantChip Private
  Use Strict Arg content, style, HTMLClass, publicName, proseOptions.

  -- The author's asserted base class (NOT the auto-parse's rx-str/rx-xstr).
  tagBase = ProseElementTags( HTMLClass, publicName )
  If tagBase == .Nil Then                    -- should not happen: dispatcher gated
    Return ErrorChip( content, style, -
      "Unknown constant form", "Public name '"publicName"' is not published" )

  -- Suffix check FIRST (decision 1): shout before relying on a single-literal parse.
  -- TUTOR/unicode widens the legal suffix set (BX -> BXYPGTU), mirroring the
  -- engine's Scanner. The flag rides in on proseOptions.unicode, set when the
  -- document enabled it via YAML prologue, CLI flag, or the fence's own {unicode}.
  tutor = ( proseOptions.unicode == .True )
  If \CallSuffixValid( content, tutor ) Then Do
    If tutor Then legal = "B, X, Y, P, G, T or U (TUTOR on)"
             Else legal = "B or X (TUTOR suffixes are off)"
    Return ErrorChip( content, style, -
      "Invalid string suffix", -
      "A string constant may only carry a" legal "suffix" )
  End

  -- Auto-parse the string ALONE. No context to synthesise, nothing to trim.
  chip = RexxFragment( content, style, proseOptions. )

  -- If it did not parse, honour the shout.
  If chip~pos("rx-fragment-error") > 0 Then
    Return ErrorChip( content, style, -
      "Not a valid string constant", -
      "The fragment did not parse as a single string literal" )

  -- Locate the token stream inside the chip's <code>.
  codeOpen = chip~pos( '<code class="rexx">' )
  If codeOpen == 0 Then
    Return ErrorChip( content, style, "Internal error", "No code element in chip" )
  bodyStart = codeOpen + Length( '<code class="rexx">' )
  codeClose = chip~pos( '</code>', bodyStart )
  If codeClose == 0 Then
    Return ErrorChip( content, style, "Internal error", "Unterminated code element" )
  pre  = chip~substr( 1, bodyStart - 1 )       -- <span wrapper><code ...>
  body = chip~substr( bodyStart, codeClose - bodyStart )
  post = chip~substr( codeClose )              -- </code></span>

  -- The base the auto-parse gave the literal (rx-str, or rx-xstr with a suffix).
  -- Relabel it to the tag's assertion, keeping the structural subclasses.
  engBase = FirstSpanBaseClass( body )
  If engBase == .Nil Then
    Return ErrorChip( content, style, "Not a constant", -
      "The fragment did not tokenise as a single string literal" )

  relabelled = RelabelBase( body, engBase, tagBase )

  Return pre || relabelled || post

--------------------------------------------------------------------------------
-- FirstSpanBaseClass -- the base class (minus structural subclass) of span #1--
--------------------------------------------------------------------------------
-- The trimmed body starts with the first token span of the constant. Its class
-- is the engine's base ("rx-const rx-<cat>-<form>") optionally followed by ONE
-- structural subclass (rx-oquo on the opening quote). We return just the base by
-- stripping a trailing rx-oquo/rx-cquo/rx-ssuf if present. .Nil if the body does
-- not start with a span we recognise.

::Routine FirstSpanBaseClass Private
  Use Strict Arg body
  head = '<span class="'
  If \body~startsWith( head ) Then Return .Nil
  q = body~pos( '"', head~length + 1 )
  If q == 0 Then Return .Nil
  cls = body~substr( head~length + 1, q - head~length - 1 )
  -- Strip a trailing structural subclass, if any.
  Do sub Over .Array~of("rx-oquo", "rx-cquo", "rx-ssuf")
    If cls~endsWith(" "sub) Then Return cls~substr( 1, cls~length - sub~length - 1 )
  End
  Return cls

--------------------------------------------------------------------------------
-- RelabelBase -- swap the engine's base class for the tag's, span by span    --
--------------------------------------------------------------------------------
-- Every span in `body` carries `engBase` as its base class, optionally followed
-- by a structural subclass (rx-oquo/rx-cquo/rx-ssuf). We replace each occurrence
-- of the base with `tagBase`, preserving the subclass. We only touch the class
-- attribute of spans whose class STARTS with engBase, so nothing else is hit.

::Routine RelabelBase Private
  Use Strict Arg body, engBase, tagBase
  out  = ""
  rest = body
  needle = 'class="'engBase
  Loop While rest \== ""
    p = rest~pos( needle )
    If p == 0 Then Do
      out ||= rest
      Leave
    End
    out ||= rest~substr( 1, p - 1 ) || 'class="'tagBase
    rest = rest~substr( p + needle~length )
  End
  Return out

--------------------------------------------------------------------------------
-- ErrorChip -- the red "shout" chip, shared by the error paths               --
--------------------------------------------------------------------------------
-- Same shape RexxFragment's Syntax handler emits: the offending text in a red
-- chip, followed by one or two messages in their own span. Used where WE
-- detect the error (not the parser), so we supply the messages ourselves.

::Routine ErrorChip Private
  Use Strict Arg content, style, generic, specific

  msg = ""
  If generic  \== "" Then msg ||= "***" || EscapeHTML(generic)
  If specific \== "", specific \== generic Then msg ||= "***" || EscapeHTML(specific)
  errorSpan = ""
  If msg \== "" Then
    errorSpan = '<span class="rx-fragment-error-msg"' -
             || ' style="color:#c00;font-weight:bold;">' || msg || '</span>'
  Return '<span class="highlight-rexx-'style'"><code class="rexx rx-fragment-error"' -
      || ' style="background-color:#c00;color:#fff;font-weight:bold;">' -
      || EscapeHTML(content) || '</code>' || errorSpan || '</span>'

--------------------------------------------------------------------------------
-- OneLinePre -- the lines of a <pre> joined into one, newlines as &#10;      --
--                                                                            --
-- An indented block (a listing inside a list item) is re-indented on its way --
-- back, so that Pandoc keeps it in the item. But Pandoc takes away only the  --
-- ITEM's indentation, and the fence is usually indented further than that:   --
-- in `  - Example` / `      ```rexx` the item's content starts at column 5, --
-- the fence at column 7. Every line of the <pre> after the first kept the    --
-- two extra blanks, and inside a <pre> blanks are content: lines 2 onwards   --
-- stood two columns to the right of line 1.                                  --
--                                                                            --
-- A <pre> written on ONE line has no second line to shift. Its line breaks   --
-- become &#10;, which a <pre> shows as line breaks, and which Pandoc passes  --
-- through untouched. Only the <pre>'s own lines are joined; the wrapper      --
-- around it stays as it was.                                                 --
--                                                                            --
-- Tabs become &#9; for the same reason. A literal tab in that one line made  --
-- Pandoc stop reading it as raw HTML: it re-read the listing as Markdown,    --
-- re-wrapped it, and took `*/ comment */` for emphasis (Rony's comment       --
-- slide, whose first line is `say 3<TAB>+ <TAB>/* ...`). The entity is the   --
-- same character once the browser has read it.                               --
--------------------------------------------------------------------------------

::Routine OneLinePre Private
  Use Strict Arg lines

  first = 0
  last  = 0
  Do i = 1 To lines~items
    If first == 0, lines[i]~pos("<pre") > 0 Then first = i
    If first > 0, lines[i]~pos("</pre>") > 0 Then Do
      last = i
      Leave
    End
  End
  If first == 0 | last <= first Then Return lines

  joined = lines[first]
  Do i = first + 1 To last
    joined = joined || "&#10;" || lines[i]
  End

  out = .Array~new
  Do i = 1 To first - 1
    out~append( lines[i] )
  End
  out~append( joined~changeStr("09"x, "&#9;") )
  Do i = last + 1 To lines~items
    out~append( lines[i] )
  End
  Return out

--------------------------------------------------------------------------------
-- FenceMarkerPrefix -- Where a fence opened after a list marker starts       --
--------------------------------------------------------------------------------
-- A code fence can open on the line of a list item, right after its marker:  --
-- `- ```rexx`, `* ~~~rexx`, `1. ```rexx`, `a) ```rexx`, `(2) ```rexx`,       --
-- `#. ```rexx`, and nested ones on one line (`- 1. ```rexx`). This returns   --
-- the length of everything before the fence -- leading blanks, the markers   --
-- and the blanks after each -- or 0 when the line is not such an opening.    --
--                                                                            --
-- Pandoc's rule for the blanks after a marker: one to four. Five or more     --
-- make the item's content an INDENTED code block (`-     ```rexx` shows the  --
-- backticks as code); that is not a fence, so it is 0 here too.             --
-- A marker is a bullet (- + *), or up to nine digits, one letter or '#'     --
-- followed by '.' or ')', or enclosed in '(' ')'. (Roman numerals beyond one --
-- letter are left out: an `iv.` item that opens a fence is not worth the     --
-- ambiguity with a word.)                                                    --

::Routine FenceMarkerPrefix Public
  Use Strict Arg line
  pos = Length(line) - Length( Strip(line, "Leading") ) + 1
  seen = 0
  Loop
    rest = SubStr(line, pos)
    If seen > 0, ( rest[1,3] == "```" | rest[1,3] == "~~~" ) Then Return pos - 1
    len = ListMarkerLength( rest )
    If len == 0 Then Return 0
    blanks = Verify( SubStr(rest, len + 1), " " ) - 1
    If blanks < 0 Then Return 0                -- nothing after the marker
    If blanks < 1 | blanks > 4 Then Return 0
    pos += len + blanks
    seen += 1
  End

--------------------------------------------------------------------------------
-- FenceInIndentedItem -- A fence five or more blanks after a list marker     --
--------------------------------------------------------------------------------
-- `-     ```rexx` is NOT a fence: after a list marker, five blanks or more    --
-- make the item's content an indented code block (Pandoc shows the          --
-- backticks as code). But its closing ``` looks like a fence of its own, and --
-- taken for one it swallowed the next real fence on the page. This returns  --
-- the fence run ("```") when the line is such an item, so that the caller   --
-- can skip to its closing line; "" otherwise. (md2slides warns about it.)   --

::Routine FenceInIndentedItem Public
  Use Strict Arg line
  s = Strip( line, "Leading" )
  len = ListMarkerLength( s )
  If len == 0 Then Return ""
  rest = SubStr( s, len + 1 )
  blanks = Verify( rest, " " ) - 1
  If blanks < 5 Then Return ""
  rest = SubStr( rest, blanks + 1 )
  If rest[1,3] \== "```", rest[1,3] \== "~~~" Then Return ""
  char = rest[1]
  run = Verify( rest, char ) - 1
  If run < 0 Then run = Length( rest )
  Return Copies( char, run )

-- The length of the list marker s starts with, or 0.
::Routine ListMarkerLength Private
  Use Strict Arg s
  If Pos( s[1], "-+*" ) > 0 Then Return 1
  paren = s[1] == "("
  If paren Then s = SubStr(s, 2)
  If s[1] == "#" Then n = 1
  Else Do
    n = Verify( s, "0123456789" ) - 1
    If n < 0 Then n = Length(s)
    If n > 9 Then Return 0
    If n == 0, DataType( s[1], "M" ) Then n = 1
  End
  If n == 0 Then Return 0
  close = s[n + 1]
  If paren Then Do
    If close \== ")" Then Return 0
    Return n + 2
  End
  If close \== ".", close \== ")" Then Return 0
  Return n + 1

--------------------------------------------------------------------------------
-- DeIndent -- Remove up to `n` leading whitespace columns from a line        --
--------------------------------------------------------------------------------
-- Strips at most `n` leading blank or tab characters, counting a tab as one  --
-- column (the emitter indents fenced blocks with blanks; tabs are tolerated  --
-- but not expected). A line with fewer than `n` leading blanks loses only    --
-- what it has, never any non-blank content. Used to bring a list-indented    --
-- code block back to real column 1 before the Rexx parser sees it.           --

::Routine DeIndent Private
  Use Strict Arg line, n
  removed = 0
  Loop While removed < n
    c = line[1]
    If c \== " ", c \== "09"x Then Leave
    line = SubStr(line, 2)
    removed += 1
  End
  Return line

--------------------------------------------------------------------------------
-- ParseOptions -- Parse the options after "```rexx"                          --
--------------------------------------------------------------------------------

::Routine ParseOptions Private

  Use Strict arg filename, options, defaultStyle

  -- Default options
  Options.            = 0
  Options.doccomments = "detailed"      -- Individually highlight sub-elements
  Options.operator    = "group"         -- All operators are displayed the same
  Options.special     = "group"         -- All specials are displayed the same
  Options.constant    = "full"          -- Flexibility with taken constants
  Options.blanks      = ""              -- Blanks are not marked by default
  Options.assignment  = "group"         -- Assignments are displayed the same
  Options.style       = defaultStyle    -- Set default style
  Options.classprefix = "rx-"           -- Default HTML class prefix is "rx-"
  Options.["SOURCE"]  = ""              -- No external source by default
  Options.patch       = ""              -- No patch file by default
  Options.["CAPTION"] = ""              -- No caption by default
  Options.["SPOT"]    = ""              -- No spotlight beats by default
  Options.html        = 1               -- This is HTML highlighting
  Options.startFrom   = 1               -- Start at line 1

  -- Store the file path, for source=, patchfile=, etc.
  Options.path        = .File~new( filename )~parent

  -- The options string may or may not be prefixed by the language word
  -- ("rexx" or "executor"): the per-block fence path passes it prefixed
  -- ("rexx {...}"), but the prose-mention facade passes the bare options
  -- ("{...}"). Detect and skip the language word only when it is actually
  -- there; otherwise the string already starts at the options.
  If      options~startsWith("rexx")     Then options = Strip( SubStr(options,5) )
  Else If options~startsWith("executor") Then options = Strip( SubStr(options,9) )
  Else                                        options = Strip( options )

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
        When "style"        Then Do
          Options.style              = value
          Options.["STYLE-EXPLICIT"] = 1  -- author asked for this style
        End
        When "size"         Then Options.size         = value
        When "caption"      Then Options.["CAPTION"]  = value
        -- spot= names the BEATS this listing takes part in, and which of
        -- its lines light up in each one: spot="init:2 salary:5-7,9".
        -- The value is not interpreted here: it travels verbatim to the HTML
        -- as data-spot and the runtime resolves it. Deliberate -- the same
        -- spelling has to work for blocks Pandoc emits (python, output, plain
        -- text), which never pass through this routine, so ONE parser at the
        -- far end is the only way both kinds can behave alike.
        When "spot"         Then Options.["SPOT"]     = value
        When "doccomments"  Then
          Select Case Lower(value)
            When "detailed", "block"       Then Options.doccomments   = Lower(value)
            Otherwise Exit BadValue()
          End
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
        -- blanks= makes the blanks of a listing visible, each one drawn as an
        -- open box. It is a granularity, like operator= above, and not a
        -- switch: "data" marks the blanks that MEAN something -- the ones
        -- inside a literal, which are the data, and the blank concatenation
        -- operator, which is an operator -- while indentation and the air
        -- around an = are left alone. "all" marks every blank there is.
        --
        -- Only the parser can draw that line, which is the whole point: an
        -- editor shows every blank or none, because it has no idea which of
        -- them the program can see.
        When "blanks" Then
          Select Case Lower(value)
            When "data", "all"             Then Options.blanks     = Lower(value)
            Otherwise Exit BadValue()
          End
        -- Keep FenceKeyIsKnown, below, in step with this list.
        Otherwise Exit BadOption()
      End
    End
    Else Do -- Options does not contain "="
      Select Case option
        When "unicode", "tutor"              Then Options.unicode      = .True
        When "experimental"                  Then Options.experimental = .True
        When "executor"                      Then Options.executor     = .True
        When "cms", "rexxvm"                 Then Do
          Options.cms      = .True
          Options.cmslevel = 3
        End
        When ".numberLines", ".number-lines" Then Options.numberLines  = .True
        -- The bare form is the default granularity. It is spelled with a dot
        -- as well because the very same word has to work on a fence Pandoc
        -- handles (~~~output {.blanks}), where it arrives as a CSS class: the
        -- author writes one thing for both kinds of block.
        When ".blanks", "blanks"             Then Options.blanks       = "data"
        -- Keep FenceWordIsKnown, below, in step with this list.
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
-- FenceWordIsKnown - is `word`, a lone word (no "=") inside the braces of a  --
-- ```rexx or ```executor fence, one that ParseOptions acts on?               --
--                                                                            --
-- Any other lone word is dropped there in silence: a Rexx listing is made by --
-- the highlighter, not by Pandoc, so a class such as `.fragment` never       --
-- reaches the HTML. What such a word would have meant depends on the         --
-- pipeline, and so does whether to tell the author: md2slides does           --
-- (WarnFenceWords), because its classes animate. Same strict comparison as   --
-- the Select in ParseOptions: `.NumberLines` is not `.numberLines`.          --
--------------------------------------------------------------------------------

::Routine FenceWordIsKnown Public
  Use Strict Arg word
  known = "unicode tutor experimental executor cms rexxvm" -
          ".numberLines .number-lines .blanks blanks"
  Return WordPos(word, known) > 0

--------------------------------------------------------------------------------
-- FenceKeyIsKnown - is `key`, the name of a key=value option on a ```rexx    --
-- fence or a Rexx prose mention, one that ParseOptions acts on?              --
--                                                                            --
-- Any other key is an error there (88.900, "Invalid option"): a pipeline     --
-- that would rather drop it, and say so, asks here first (md2slides,          --
-- StripForeignOptions: `level=2` on a mention stopped the build). Keep it in --
-- step with the Select in ParseOptions, plus program= (ProcessPrograms takes --
-- it off before ParseOptions runs). Case is ignored, as there.               --
--------------------------------------------------------------------------------
::Routine FenceKeyIsKnown Public
  Use Strict Arg key
  known = "extraletters classprefix startfrom source pad numberwidth" -
          "patchfile patch style size caption spot doccomments operator" -
          "special constant assignment blanks program"
  Return WordPos(Lower(key), known) > 0

--------------------------------------------------------------------------------
-- ProcessACodeBlock                                                          --
--------------------------------------------------------------------------------

::Routine ProcessACodeBlock
  Use Strict Arg filename, source, start, end, accum, options.

  If options.continue Then Signal On Syntax

  -- Process patch files, if any
  patches = .Nil
  If options.patch \== "" Then Do
    patches = .StylePatch~of( Options.patch )
  End
  Else If options.patchfile \== "" Then Do
    fn = options.path"/"options.patchfile
    patches = File2Array(fn)
    patches = .StylePatch~of( patches )
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
    highligthter = .Highlighter~new(options.["SOURCE"], array, options.)
  End
  Else Do
    array = source~section( start + 1, end - start - 1)
    newFN = filename "[lines "||(start+accum)"-"||(end+accum)"]"
    highligthter = .Highlighter~new(newFN, array, options.)
  End

  Return highligthter~parse( patches )

MissingEndMarker:
  Raise Syntax 88.900 -
    Additional("Missing end marker '-->' for code block at line "start)

Syntax:
  -- This trap will only be activated if the --continue option has
  -- been specified. Our task here is complex, because we are most
  -- probably in the middle of some HTML tags, which we don't control
  -- and can't close.

  res = .Array~new

  res~append("<pre style='font-weight: bold; background-color: red; color: #fff;'>")
  res~append("Code could not be displayed because of the following error:")

  co         = condition("O")
  additional = Condition("A")
  extra = additional~lastitem
  line  = extra~position
  Parse Value co~code With major"."minor
  res~append( Right(line,6) "*-*" extra~sourceline )
  -- Try to reconstruct the line number if we have enough information
  name = extra~name
  majorMessagePrinted = 0
  If Right(name,1) == "]" Then Do
    Parse Var name name1" [lines "start"-"end"]"
    If name == name1" [lines "start"-"end"]" Then Do
      majorMessagePrinted = 1
      res~ append( "Error" major "in" name1", line" (start+line)": " ErrorText(major) )
    End
  End
  If \majorMessagePrinted Then
    res~append( "Error" major "in" extra~name", line" line": " ErrorText(major) )
  res~append( "Error" co~code": " Ansi.ErrorText( co~code, additional ) )

  If options.itrace == 1 Then Do
    res~append( "" )
    res~append( "Trace follows" )
    res~append( Copies("-",80) )

    Loop line Over co~stackFrames~makeArray
      res~append( line )
    End
  End

  res~append("</pre>")
  res~append("")

  Return res

--------------------------------------------------------------------------------
-- ProcessPrograms -- STEP ONE: resolve every program= group, whole           --
--------------------------------------------------------------------------------
--
-- Runs over the raw source BEFORE the per-block loop, and finishes the job:
-- when it returns, no program= fence is left in the source, so STEP TWO (the
-- main loop) never learns that the feature exists.
--
-- For each group of sibling fences sharing a program= name:
--
--   1. COLLECT. Gather the fragments in document order and concatenate their
--      bodies into one listing. Nothing is inserted between them -- no marker
--      line, no metacharacter, nothing. The seams are remembered instead, as
--      the source line number each fragment starts at (BuildProgramSource).
--   2. HIGHLIGHT. Send the whole listing to the highlighter in ONE stateful
--      pass, as a single continuous block. A clause that spans a seam (a
--      trailing-comma continuation, a block comment) is therefore resolved
--      the only way it can be: by parsing the program as what it is, one
--      program. If it does not parse, it does not parse -- the error travels
--      exactly as it would for any single fence.
--   3. CUT COLD. The emission is 1:1 and in order -- one line span per source
--      line -- so the block can be sliced afterwards at the remembered seams
--      and each slice given its own chrome (CutProgramBlocks). Nothing is
--      ever reopened mid-emission, which is what the old design did and what
--      stranded empty line spans and mis-carried numbers at the head of a
--      reopened block.
--   4. PARK. Each slice is stashed under "KEY:k" for the caller's final pass,
--      and the fragment's fence is replaced, in the source, by an inert
--      placeholder `<!--rxprogram:KEY:k AS-IS-->`. The AS-IS tail carries the
--      author's verbatim name for a future auto-caption.
--
-- Fences are grouped by NORMALISED key (see ProgramKey), so "The Towers of
-- Hanoi" and "Towers-of-Hanoi" are one program. A source with no program=
-- fence is returned unchanged, and nothing above ever runs.
--------------------------------------------------------------------------------
::Routine ProcessPrograms Private
  Use Strict Arg filename, source, defaultStyle, defaultOptions., continue, blocks.

  -- Locate every rexx/executor fence carrying program=, grouped by key in
  -- first-seen order.
  --   groups.KEY = array of [startLine, endLine, indent] fragments, in order
  --   asis.KEY   = the author's as-is name (first fragment wins), for captions
  groups. = 0
  asis.   = ""
  order   = .Array~new

  n      = source~items
  lineNo = 1
  Loop While lineNo <= n
    line   = source[lineNo]
    indent = Length(line) - Length( Strip(line, "Leading") )
    bare   = SubStr(line, indent + 1)
    If bare[1,3] \== "```", bare[1,3] \== "~~~" Then Do
      -- Skip `-     ```x` ... ``` whole (see FenceInIndentedItem).
      skip = FenceInIndentedItem( line )
      If skip \== "" Then Do
        lineNo += 1
        Loop While lineNo <= n, Strip( Strip(source[lineNo],"T"), "Leading" ) \== skip
          lineNo += 1
        End
      End
      lineNo += 1
      Iterate
    End
    char       = bare[1]
    attributes = Strip( bare, "Leading", char )
    chars      = Length(bare) - Length(attributes)
    marker     = Copies(char, chars)
    attributes = Strip( attributes )

    -- Only rexx/executor fences are of interest here.
    isRexx = attributes~caselessStartsWith("rexx") | -
             attributes~caselessStartsWith("executor")

    -- Find the block's end marker.
    endNo = lineNo + 1
    Loop While endNo <= n, Strip( Strip(source[endNo],"T"), "Leading" ) \== marker
      endNo += 1
    End
    If endNo > n Then Leave                 -- unterminated: leave for step two

    If isRexx Then Do
      nameAsIs = ProgramName( attributes )
      If nameAsIs \== "" Then Do
        key = ProgramKey( nameAsIs )
        If groups.key == 0 Then Do
          groups.key = .Array~new
          asis.key   = nameAsIs             -- first fragment fixes the caption
          order~append( key )
        End
        frag = .Array~new
        frag~append( lineNo )
        frag~append( endNo )
        frag~append( indent )
        groups.key~append( frag )
      End
    End
    lineNo = endNo + 1
  End

  If order~items == 0 Then Return source    -- no programs: no-op

  -- One program at a time: build it, highlight it whole, cut it cold.
  Do key Over order
    frags = groups.key
    seams = .Array~new
    programSource = BuildProgramSource( source, frags, seams )

    -- The master fence governs the whole listing: its attributes are the
    -- program's attributes, program= itself removed.
    master     = frags[1]
    mStart     = master[1]
    attributes = FenceAttributes( source[mStart] )
    executor   = attributes~caselessStartsWith("executor")
    attributes = StripProgram( attributes )

    If defaultOptions.default \== "" Then Do
      Parse Var attributes prefix"{"rest
      If rest == "" Then
        attributes ||= " {"defaultOptions.default"}"
      Else
        attributes = prefix"{"defaultOptions.default rest
    End
    options. = ParseOptions( filename, attributes, defaultStyle )
    If executor Then Options.["EXECUTOR"] = 1
    If continue Then Options.["CONTINUE"] = 1

    -- One pass, one program. `accum` is set so that an error message counts
    -- from the master fence, the only fragment whose line numbers are real.
    highlighted = ProcessACodeBlock( filename, programSource, 1, -
                                     programSource~items, mStart - 1, options. )

    -- Drop the trailing artifact line(s), as the main loop does for a fence.
    Do While highlighted~items > 0, -
             Strip( highlighted[ highlighted~items ] ) == ""
      highlighted~delete( highlighted~items )
    End

    pieces = CutProgramBlocks( highlighted, seams, options. )
    Do k = 1 To pieces~items
      blocks.[key":"k] = pieces[k]
      blocks.!count    = blocks.!count + 1
    End
  End

  -- Rewrite the source: every fragment's fence becomes its placeholder.
  action. = 0            -- action.[start] = "KEY k"
  jump.   = 0            -- jump.[start]   = endLine (to skip the fragment)
  Do key Over order
    frags = groups.key
    Do k = 1 To frags~items
      f = frags[k]
      s = f[1]
      jump.s   = f[2]
      action.s = key k
    End
  End

  out    = .Array~new
  lineNo = 1
  Loop While lineNo <= n
    If action.lineNo \== 0 Then Do
      Parse Var action.lineNo key k
      -- Placeholder format: "<!--rxprogram:KEY:k AS-IS-->". KEY never has a
      -- blank (ProgramKey guarantees it), so the first blank-delimited token
      -- is KEY:k and the remainder -- which MAY contain blanks or colons -- is
      -- the as-is caption text, kept for a future auto-caption. The fence's
      -- own indent is preserved: PlaceProgramBlocks re-indents by it.
      line   = source[lineNo]
      indent = Length(line) - Length( Strip(line, "Leading") )
      out~append( Left("",indent) || "<!--rxprogram:"key":"k" "asis.key"-->" )
      lineNo = jump.lineNo + 1
    End
    Else Do
      out~append( source[lineNo] )
      lineNo += 1
    End
  End
  Return out

--------------------------------------------------------------------------------
-- BuildProgramSource -- the fragments of one program, as one fenced listing  --
--------------------------------------------------------------------------------
-- Returns an array shaped like an ordinary fenced block -- opening fence, the
-- bodies of every fragment back to back, closing fence -- ready for
-- ProcessACodeBlock. `program=` is stripped from the fence; no marker of any
-- kind is inserted between fragments, because the seams are carried out of
-- band instead: `seams` is filled with the 1-based source line number each
-- fragment starts at (fragment 1 always starts at line 1), which is what
-- CutProgramBlocks slices on.
--
-- Each fragment is de-indented by ITS OWN indent, so a listing split between
-- a top-level fence and one nested in a list item still reaches the parser at
-- real column 1. The blocks are re-indented on the way out, per placeholder.
--------------------------------------------------------------------------------
::Routine BuildProgramSource Private
  Use Strict Arg source, frags, seams

  master = frags[1]
  fence  = source[ master[1] ]

  indent  = Length(fence) - Length( Strip(fence, "Leading") )
  bare    = SubStr(fence, indent + 1)
  char    = bare[1]
  rest    = Strip(bare, "Leading", char)
  chars   = Length(bare) - Length(rest)
  fenceCh = Copies(char, chars)

  out = .Array~new
  out~append( fenceCh || StripProgram( Strip(rest) ) )

  srcLine = 0
  Do k = 1 To frags~items
    f       = frags[k]
    fIndent = f[3]
    seams~append( srcLine + 1 )           -- where fragment k starts
    Do i = f[1] + 1 To f[2] - 1
      line = source[i]
      If fIndent > 0 Then line = DeIndent( line, fIndent )
      out~append( line )
      srcLine += 1
    End
  End
  out~append( fenceCh )
  Return out

--------------------------------------------------------------------------------
-- FenceAttributes -- a fence line's attribute string, indent and fence       --
-- characters removed ("   ```rexx {n}" -> "rexx {n}").                       --
--------------------------------------------------------------------------------
::Routine FenceAttributes Private
  Use Strict Arg fence
  indent = Length(fence) - Length( Strip(fence, "Leading") )
  bare   = SubStr(fence, indent + 1)
  Return Strip( Strip( bare, "Leading", bare[1] ) )
--------------------------------------------------------------------------------
-- ProgramName - the AS-IS value of program= in a fence's attribute string,
-- or "". This is the author's text verbatim (original spacing and case), the
-- form kept for a future auto-caption ("The Towers of Hanoi, 1/4"). The
-- grouping key is a SEPARATE, normalised derivation -- see ProgramKey.
--
-- A value containing blanks MUST be quoted (single or double), exactly as any
-- other attribute whose value has blanks; an unquoted value ends at the first
-- blank/tab/"}". A quoted value spans to its matching closing quote, so
-- blanks inside are preserved.
--------------------------------------------------------------------------------
::Routine ProgramName Private
  Use Strict Arg attrs
  p = attrs~caselessPos("program=")
  If p == 0 Then Return ""
  rest = SubStr(attrs, p + 8)             -- past "program="
  If rest == "" Then Return ""
  q = rest[1]
  If q == '"' | q == "'" Then Do          -- quoted: read to the matching quote
    body = SubStr(rest, 2)
    e    = body~pos(q)
    If e == 0 Then Return Strip(body)      -- unterminated quote: take the rest
    Return SubStr(body, 1, e - 1)
  End
  -- Unquoted: read to the first blank / tab / "}".
  val = ""
  Do i = 1 To Length(rest)
    c = rest[i]
    If c == " " | c == "}" | c == "09"x Then Leave
    val ||= c
  End
  Return val

--------------------------------------------------------------------------------
-- ProgramKey - the grouping key derived from an as-is program= value.
-- Fences whose as-is names normalise to the same key are ONE logical program.
-- Rule (Rexx symbol semantics): any run of blanks and/or dashes collapses to
-- a single dash, then the whole thing is uppercased. So "The Towers of
-- Hanoi", "Towers-of-Hanoi" and "Towers - of  Hanoi" (were the stem the same)
-- fold together; the key never contains a blank, which lets it ride in the
-- internal placeholder ahead of the as-is text, blank-separated.
--------------------------------------------------------------------------------
::Routine ProgramKey Private
  Use Strict Arg asis
  key = asis~space(1)                      -- collapse blank runs to one blank
  -- Collapse any mix of blanks and dashes (now single blanks + literal dashes)
  -- into single dashes.
  key = key~translate("-", " ")            -- blanks -> dashes
  Do While key~contains("--");  key = key~changeStr("--", "-");  End
  key = Strip(key, "Both", "-")            -- no leading/trailing dash
  Return key~upper

--------------------------------------------------------------------------------
-- StripProgram - an attribute string with program=VALUE removed (tidily).
-- Handles both quoted values (program="The Towers of Hanoi") and unquoted
-- ones (program=demo): a quoted value is consumed up to and including its
-- matching closing quote, an unquoted one up to the first blank/tab/"}".
--------------------------------------------------------------------------------
::Routine StripProgram Private
  Use Strict Arg attrs
  p = attrs~caselessPos("program=")
  If p == 0 Then Return attrs
  before = SubStr(attrs, 1, p - 1)
  rest   = SubStr(attrs, p + 8)           -- past "program="
  q = 1
  If rest \== "", (rest[1] == '"' | rest[1] == "'") Then Do
    -- Quoted: skip the opening quote, find the matching close, consume through it.
    quo  = rest[1]
    body = SubStr(rest, 2)
    e    = body~pos(quo)
    If e == 0 Then q = Length(rest) + 1    -- unterminated: swallow the rest
    Else           q = e + 2               -- +1 for opening quote, +1 past close
  End
  Else Do
    -- Unquoted: up to the first blank / tab / "}".
    Do i = 1 To Length(rest)
      c = rest[i]
      If c == " " | c == "}" | c == "09"x Then Leave
      q = i + 1
    End
  End
  after = SubStr(rest, q)
  res = Strip(before) || " " || Strip(after)
  res = res~changeStr("{ ", "{")
  res = res~changeStr(" }", "}")
  Do While res~contains("  ");  res = res~changeStr("  ", " ");  End
  Return Strip(res)

--------------------------------------------------------------------------------
-- CutProgramBlocks -- slice one emitted block into N, cold                   --
--------------------------------------------------------------------------------
-- The listing was emitted as ONE continuous block. The highlighter's emission
-- is 1:1 and in order -- exactly one line span per source line, whatever
-- state crosses line boundaries -- so the block can be cut afterwards, by
-- source line number, with no help from the emitter and nothing reopened.
--
-- The shape to cut is fixed by the driver: the opening <div> (plus an
-- optional inline <style>, when the author patched the style) occupies lines
-- of its own; "<pre...><code...>" is glued to the FIRST line span; and
-- "</code></pre></div>" is glued to the LAST. Highlighted code can never
-- contain "<code" or "</code>", since EscapeHTML turns every "<" into "&lt;",
-- so those are unambiguous landmarks rather than a guess.
--
-- Two things are rebuilt per slice, not copied:
--
--   * THE LINE COUNTER. Continuous numbering across the seams used to be a
--     side effect of reopening the block. Here each slice states its own
--     origin: "counter-reset: rx-line <first line number> - 1" on its <code>.
--     Slice 1 restates what the driver already emitted (the author's
--     startFrom), so it comes out byte-identical.
--   * THE BLOCK ID. One emitted block carries one id, and a document may not
--     repeat an id. Slice 1 keeps the id the driver assigned; the rest draw
--     fresh ones from the same document-wide counter, and their line spans
--     are rebranded with them, so "id of line = id of block, a dash, the
--     number" holds for every slice (see RebrandBlock).
--
-- Returns an array of arrays-of-lines, one per fragment, in order. If the
-- emitted shape is not recognised, the block is returned whole and uncut --
-- one fragment gets the listing rather than the output being mangled.
--------------------------------------------------------------------------------
::Routine CutProgramBlocks Private
  Use Strict Arg highlighted, seams, options.

  -- Landmarks.
  codeIdx = 0
  Do i = 1 To highlighted~items
    If highlighted[i]~contains("<code") Then Do
      codeIdx = i
      Leave
    End
  End
  If codeIdx == 0 Then Return .Array~of( highlighted )

  closeIdx = 0
  Do i = codeIdx To highlighted~items
    If highlighted[i]~contains("</code>") Then Do
      closeIdx = i
      Leave
    End
  End
  If closeIdx == 0 Then Return .Array~of( highlighted )

  p = highlighted[codeIdx]~pos('<span id="')
  If p == 0 Then Return .Array~of( highlighted )
  q = highlighted[closeIdx]~pos('</code>')

  head        = highlighted~section( 1, codeIdx - 1 )   -- <div>, maybe <style>
  openChrome  = Left( highlighted[codeIdx], p - 1 )     -- <pre...><code...>
  closeChrome = SubStr( highlighted[closeIdx], q )      -- </code></pre></div>

  -- The code lines, one per source line, in order, chrome peeled off both ends.
  code = .Array~new
  If closeIdx == codeIdx Then
    code~append( SubStr( highlighted[codeIdx], p, q - p ) )
  Else Do
    code~append( SubStr( highlighted[codeIdx], p ) )
    Do i = codeIdx + 1 To closeIdx - 1
      code~append( highlighted[i] )
    End
    code~append( Left( highlighted[closeIdx], q - 1 ) )
  End

  -- Anything after the closing chrome is block-level trailer: replicated on
  -- every slice, since every slice is a block in its own right.
  tail = highlighted~section( closeIdx + 1 )

  masterID = BlockIDOf( head )
  nLines   = code~items

  pieces = .Array~new
  Do k = 1 To seams~items
    from = seams[k]
    If k < seams~items Then to = seams[k+1] - 1
    Else                    to = nLines
    If to > nLines Then to = nLines

    piece = .Array~new

    -- An empty fragment (a fence with no lines in it) gets an empty block
    -- rather than a stray slice of its neighbour's code.
    If from > nLines | to < from Then Do
      pieces~append( piece )
      Iterate
    End

    If k == 1 Then newID = masterID
    Else            newID = "rx"NextBlockID()

    Do line Over head
      piece~append( RebrandBlock( line, masterID, newID ) )
    End

    body = code~section( from, to - from + 1 )
    Do b = 1 To body~items
      body[b] = RebrandBlock( body[b], masterID, newID )
    End
    body[1]          = SetLineCounter( openChrome, options., -
                                       Options.startFrom + from - 1 ) || body[1]
    body[body~items] = body[body~items] || closeChrome
    piece~appendAll( body )

    piece~appendAll( tail )
    pieces~append( piece )
  End

  Return pieces

--------------------------------------------------------------------------------
-- BlockIDOf -- the block id the driver put on the wrapper ("rx7"), or "".    --
--------------------------------------------------------------------------------
::Routine BlockIDOf Private
  Use Strict Arg head
  Do line Over head
    p = line~pos('id="')
    If p > 0 Then Do
      Parse Value SubStr(line, p) With 'id="'id'"'
      Return id
    End
  End
  Return ""

--------------------------------------------------------------------------------
-- RebrandBlock -- move one emitted line from block `oldID` to block `newID`
-- Rewrites the wrapper id, the line span ids, the anchors that point at them,
-- and the id-keyed selectors of an inline patch <style>. A no-op when the two
-- ids are the same, which is the common case (slice 1 keeps its own id).
--------------------------------------------------------------------------------
::Routine RebrandBlock Private
  Use Strict Arg line, oldID, newID
  If newID == oldID Then Return line
  If oldID == ""    Then Return line
  line = line~changeStr( 'id="'oldID'"',     'id="'newID'"'     )
  line = line~changeStr( 'id="'oldID'-',     'id="'newID'-'     )
  line = line~changeStr( 'href="#'oldID'-',  'href="#'newID'-'  )
  line = line~changeStr( "#"oldID" ",        "#"newID" "        )
  Return line

--------------------------------------------------------------------------------
-- SetLineCounter -- restate a slice's numbering origin on its <code> tag.
-- `firstNum` is the number its first line must show. An unnumbered block, or
-- one starting at 1, needs no counter-reset and gets a bare <code>, which is
-- exactly what the driver emits in that case.
--------------------------------------------------------------------------------
::Routine SetLineCounter Private
  Use Strict Arg chrome, options., firstNum
  c = chrome~caselessLastPos("<code")
  If c == 0 Then Return chrome
  e = chrome~pos(">", c)
  If e == 0 Then Return chrome
  If Options.numberLines, firstNum \= 1 Then
    codeTag = '<code style="counter-reset: rx-line 'firstNum - 1';">'
  Else codeTag = '<code>'
  Return Left(chrome, c - 1) || codeTag || SubStr(chrome, e + 1)

--------------------------------------------------------------------------------
-- PlaceProgramBlocks -- replace every <!--rxprogram:KEY:k AS-IS--> line in
-- `processed` with the lines of blocks.["KEY:k"]. The placeholder's inner
-- text is "KEY:k AS-IS": KEY:k is the first blank-delimited token (the lookup
-- key, blank-free by construction) and the remainder is the as-is caption,
-- ignored here (this is the reassembly step, not the caption step). A
-- placeholder with no captured block (shouldn't happen: 1:1 by construction)
-- is left as-is. Returns the rebuilt array.
--------------------------------------------------------------------------------
::Routine PlaceProgramBlocks Private
  Use Strict Arg processed, blocks.

  out = .Array~new
  Do line Over processed
    t = Strip(line)
    If t~startsWith("<!--rxprogram:"), t~endsWith("-->") Then Do
      inner = t~substr(15, t~length - 14 - 3)   -- between "<!--rxprogram:" and "-->"
      Parse Var inner key .                      -- first token = KEY:k (blank-free)
      If blocks.[key] \== 0 Then Do
        -- Preserve the placeholder's own indent on every emitted line.
        indent = Length(line) - Length( Strip(line, "Leading") )
        pad    = Left("", indent)
        block  = blocks.[key]
        -- An indented slice has the same trouble as any indented block: see
        -- OneLinePre.
        If indent > 0 Then block = OneLinePre( block )
        Do bl Over block
          If indent > 0 Then out~append( pad || bl )
          Else               out~append( bl )
        End
        Iterate
      End
    End
    out~append( line )
  End
  Return out
