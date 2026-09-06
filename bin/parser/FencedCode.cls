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
/* 20260831    0.7  Scan prose lines for `` `x`{.rexx-*} `` mentions          */
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

package = .context~package
myName  =  package~name
mypath  =  FileSpec( "Location", myName )
parentDir   = .File~new( mypath"../" )~absolutePath

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

  -- Prose mentions (`` `x`{.rexx-*} ``, outside fences) are tagged against
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

  -- We need a WHILE condition because the source array may change
  Loop Label Outer lineNo = 1 By 1 While lineNo < source~items
    line = source[lineNo]

    -- A fenced code block starts with "```" or "~~~", possibly indented when it
    -- lives inside a list item. We recognise the marker after leading blanks or
    -- tabs, and REMEMBER that indent: the block's code has to be de-indented by
    -- it before the Rexx parser sees it (so column 1 is real column 1), and the
    -- highlighted HTML has to be re-indented by the same amount on the way back,
    -- so Pandoc still attaches the block to its list item. See issue #2.
    indent  = Length(line) - Length( Strip(line, "Leading") )
    bare    = SubStr(line, indent + 1)
    If bare[1,3] \== "```", bare[1,3] \== "~~~" Then Iterate

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
      pad = Copies(" ", indent)
      Do i = 1 To highlighted~items
        highlighted[i] = pad || highlighted[i]
      End
    End

    -- Up to line (start-1), lines are prose: scan them for `` `x`{.rexx-*} ``
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

  Return processed

MissingEndMarker:
  Raise Syntax 88.900 -
    Additional("Missing end marker for code block starting at line "lineNo)

--------------------------------------------------------------------------------
-- ScanProseMentions -- Highlight `x`{.rexx-*} mentions in a line of prose    --
--------------------------------------------------------------------------------
-- A prose mention is a Pandoc code span (a run of N backticks, content, the  --
-- same run of N backticks closing it) immediately followed by an attribute   --
-- span "{.rexx-name}" or "{.rexx-name:style}" (the ":style" pinning form is  --
-- accepted by the scanner already -- see HTMLClasses.cls's ProseTable --     --
-- even though nothing publishes it as a v1 feature yet).                     --
--                                                                            --
-- We mirror Pandoc's own code-span rule (verified empirically against        --
-- Pandoc 3.1.3, see the design discussion): the closing run must have        --
-- EXACTLY the same length as the opening one, so a code span that itself     --
-- contains a shorter run of backticks (` ``x`y` `` `) is not split early,    --
-- and a doubled backtick used to quote a literal backtick (`` `x` ``) never  --
-- matches "{.rexx-...}" unless the author actually wrote the attribute       --
-- right after the true closing run -- exactly Pandoc's own behaviour, which  --
-- is what we are pre-empting here (we run before Pandoc ever sees the        --
-- line). A span whose content does not resolve to a published name (see      --
-- ProseElementTags) is left completely untouched, backticks and all --       --
-- vocabulary is FencedCode's to validate, but silently, since we have no     --
-- author-facing error channel for a line of prose (unlike a fenced block's   --
-- Syntax 88.900). This may change once there is a natural place to warn.     --
--                                                                            --
-- ARGUMENTS                                                                  --
--   line:      One line of prose (never a fence line; the caller only        --
--              invokes this on lines already known to be outside fences).    --
--   HTMLClass: The stem from HTMLClasses(), built once by the caller         --
--              against the document's default options.                       --
--   style:     The highlight style ("dark", "light", ...) for the            --
--              micro-container -- the document's default, since a lone       --
--              mention has no per-block style= attribute to override it.     --
--                                                                            --
-- RETURNS the line with every recognised mention replaced by its             --
-- micro-container HTML (see HLDrivers/HTML.Driver.cls's ProseMention).       --
-- A line with no backtick is returned unchanged without further scanning.    --

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
    --   {.rexx}   {.rexx:style}          -- AUTO-PARSE: tokenise the fragment
    --   {.rexx-name}  {.rexx-name:style} -- BY-ELEMENT: tag one manual mention
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

    -- Classify. "tag" is now the dotted attribute name without braces:
    --   ".rexx"  or ".rexx:style"        -> auto-parse
    --   ".rexx-name" or ".rexx-name:style" -> by-element
    -- Split the style pin (":style") first; it applies to either family.
    Parse Var tag dotted":"pinnedStyle

    mentionStyle = style
    If pinnedStyle \== "" Then mentionStyle = pinnedStyle

    If dotted == ".rexx" Then Do
      -- AUTO-PARSE: hand the fragment to the inline highlighter. It PARSES
      -- for real (same engine as a fenced block), so an ill-formed fragment
      -- raises Syntax -- caught here and rendered as an in-situ shout, the
      -- "via A" of the design: the fragment IS its own context, so no line
      -- number or source reconstruction, just the red chip.
      out ||= RexxFragment( content, mentionStyle, proseOptions. )
      rest = afterSpan
      Iterate
    End

    -- BY-ELEMENT: ".rexx-name" -> public name "name".
    If \dotted~startsWith(".rexx-") Then Do -- ".rexxFOO": not a real family
      out ||= run || content || run || "{"tag"}"
      rest = afterSpan
      Iterate
    End
    publicName = SubStr( dotted, 7 )  -- drop ".rexx-"

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
      dirClass = HTMLClass[ .EL.DIRECTIVE_START   ]
      kwClass  = HTMLClass[ .EL.DIRECTIVE_KEYWORD ]
      inner = '<span class="'dirClass'">'EscapeHTML(dirText)'</span>' -
           || '<span class="'kwClass'">'EscapeHTML(kwText)'</span>'
      out ||= '<span class="highlight-rexx-'mentionStyle'">' -
           || '<code class="rexx">'inner'</code></span>'
      rest = afterSpan
      Iterate
    End

    -- KLUDGE: `exposed-stem` and `exposed-compound`. A stem or compound is not
    -- a single element -- it is a base plus (for a compound) tails -- so tagging
    -- the whole thing with one class would flatten its internal structure. So
    -- we AUTO-PARSE it via {.rexx} (which tokenises the structure correctly, but
    -- as NON-exposed, since a bare fragment has no Expose to declare it) and
    -- then correct just the BASE: relabel its stem class to the exposed-stem
    -- class. Only the base -- an aisolated fragment cannot know which tails are
    -- exposed (see `exp.a.exp`, where the last tail is exposed too, but only the
    -- enclosing Expose reveals it). That is a documented product limitation.
    --
    -- SAFETY RULE (JMB): if the auto-parse did NOT make the first span a stem,
    -- something is wrong -- the fragment is not a stem/compound -- so we do not
    -- force anything: we emit an error chip, our own honest shout.
    If publicName == "exposed-stem" | publicName == "exposed-compound" Then Do
      out ||= ExposedStemChip( content, mentionStyle, HTMLClass, proseOptions. )
      rest = afterSpan
      Iterate
    End

    tags = ProseElementTags( HTMLClass, publicName )

    If tags == .Nil Then Do -- Unpublished name (typo?): leave verbatim
      out ||= run || content || run || "{"tag"}"
    End
    Else
      out ||= ProseMention( mentionStyle, tags, content )

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
-- VIA A -- the shout. A fenced block that fails to parse reproduces the line --
-- and its number (it lives in a listing, away from the reader). A fragment   --
-- needs neither: it sits in the prose, in front of the author, so the shout  --
-- is just a red inline chip showing the offending fragment. No line, no      --
-- number, no reconstruction. Minimum ceremony, maximum locality.             --
--                                                                            --
-- ARGUMENTS                                                                  --
--   content:      the fragment's source text (already un-escaped; the        --
--                 highlighter escapes as it emits).                          --
--   style:        the highlight style for the chip (document default, or a   --
--                 ":style" pin the author wrote after {.rexx}).              --
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
  -- VIA A: the fragment did not hold. Shout in situ -- red chip, the offending
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
-- ParseCompoundDirective -- split `::Method` into ("::", "Method")           --
--------------------------------------------------------------------------------
-- The content of a `{.rexx-directive}` mention: the literal `::` directive   --
-- start, then optional whitespace, then the directive keyword. We keep any   --
-- whitespace the author wrote GLUED to the "::" half, so the chip's copy     --
-- reproduces `::  Method` faithfully while the keyword span still styles only--
-- the word. This never PARSES (a lone `::Method` is not a valid program) --  --
-- it is a purely textual split, on purpose: the whole reason the compound    --
-- exists is that `{.rexx}` rejects it.                                       --
--                                                                            --
-- RETURNS a 2-element array (dirPart, keyword), or .Nil if the content does  --
-- not have the `::` + word shape (caller then leaves the mention verbatim).  --

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
-- ExposedStemChip -- exposed-stem / exposed-compound via auto-parse + fix    --
--------------------------------------------------------------------------------
-- A stem or compound has internal structure (base, tails), so we let {.rexx} --
-- tokenise it truthfully (RexxFragment), then relabel ONLY the base's stem   --
-- class to the exposed-stem class. A bare fragment cannot know which tails are--
-- exposed, so tails are left as the auto-parse coloured them -- a documented --
-- limitation.                                                                --
--                                                                            --
-- SAFETY (JMB's rule): if RexxFragment shouted (the fragment did not parse), --
-- we pass that error chip straight through. If it parsed but the FIRST span is --
-- not the stem class, the fragment was not a stem/compound, so we do not force --
-- anything -- we build our own error chip. We only relabel when we actually  --
-- see the stem class where the base must be.                                 --
--                                                                            --
-- Both classes are derived from HTMLClass (one source of truth): the normal  --
-- stem class (what the auto-parse emits for the base) and the exposed-stem   --
-- class (what we relabel it to).                                             --
--                                                                            --
-- RETURNS the finished chip HTML.                                            --

::Routine ExposedStemChip Private
  Use Strict Arg content, style, HTMLClass, proseOptions.

  chip = RexxFragment( content, style, proseOptions. )

  -- If the fragment did not parse, RexxFragment already produced the red error
  -- chip. Honour it -- do not try to relabel a shout.
  If chip~pos("rx-fragment-error") > 0 Then Return chip

  stemClass  = HTMLClass[ .EL.STEM_VARIABLE         ]  -- what the base parses as
  xstemClass = HTMLClass[ .EL.EXPOSED_STEM_VARIABLE ]  -- what we relabel it to

  -- The base is the FIRST token span, which sits immediately after the
  -- <code ...> opening (the very first <span ...> is the chip wrapper, not a
  -- token, so we anchor on the code open). It must carry exactly the stem class
  -- for us to relabel it; anything else means "not a stem/compound" -> error.
  codeOpen = chip~pos( '<code class="rexx">' )
  firstTokenSpan = 0
  If codeOpen > 0 Then
    firstTokenSpan = codeOpen + length( '<code class="rexx">' )
  marker = '<span class="'stemClass'">'
  If firstTokenSpan == 0 | chip~substr( firstTokenSpan, marker~length ) \== marker Then
    Return ErrorChip( content, style, -
      "Not a stem or compound variable", -
      "The {.rexx-exposed-*} fragment did not begin with a stem" )

  -- Relabel just this base span: swap the stem class for the exposed one.
  p = firstTokenSpan
  Return chip~substr(1, p - 1) -
      || '<span class="'xstemClass'">' -
      || chip~substr( p + marker~length )

--------------------------------------------------------------------------------
-- ErrorChip -- the red "shout" chip, shared by the error paths               --
--------------------------------------------------------------------------------
-- Same shape RexxFragment's Syntax handler emits: the offending text in a red--
-- chip, followed by one or two messages in their own span. Used where WE     --
-- detect the error (not the parser), so we supply the messages ourselves.    --

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
  Options.assignment  = "group"         -- Assignments are displayed the same
  Options.style       = defaultStyle    -- Set default style
  Options.classprefix = "rx-"           -- Default HTML class prefix is "rx-"
  Options.["SOURCE"]  = ""              -- No external source by default
  Options.patch       = ""              -- No patch file by default
  Options.["CAPTION"] = ""              -- No caption by default
  Options.html        = 1               -- This is HTML highlighting
  Options.startFrom   = 1               -- Start at line 1

  -- Store the file path, for source=, patchfile=, etc.
  Options.path        = .File~new( filename )~parent

  -- Skip "rexx" or "executor" and strip blanks
  If options[1] == "r" Then options = Strip( SubStr(options,5) )
  Else                      options = Strip( SubStr(options,9) )

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