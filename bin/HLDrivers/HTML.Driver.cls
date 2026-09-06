/******************************************************************************/
/*                                                                            */
/* HTML.Highlighter.Driver.cls - LaTeX highlighter driver                     */
/* ======================================================                     */
/*                                                                            */
/* This program is part of the Rexx Parser package                            */
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
/* 20250101    0.1e First version                                             */
/* 20250120    0.1f Add size option                                           */
/* 20250328    0.2  Main dir is now rexx-parser instead of rexx[.]parser      */
/* 20250622    0.2d Change fg/bg char separator to ":"                        */
/* 20260310    0.5  Implement captions                                        */
/* 20260709    0.6  Mark explicit styles (for RexxHTTP)                       */
/* 20260831    0.7  Add ProseMention -- the inline micro-container for        */
/*                  `x`{.rexx-*} mentions in prose (FencedCode.cls)           */
/* 20260901    0.8  Restructure the emitted markup: a div wrapper, one <code> */
/*                  holding a <span> per line, each with its own anchor. The  */
/*                  shape is Pandoc's -- it is what allows the line number to */
/*                  sit outside the code ground -- but the class names are    */
/*                  ours, so no foreign stylesheet reaches our blocks.        */
/*                                                                            */
/******************************************************************************/

If \.environment~hasIndex( HTML.Highlighter ) Then
 .environment~HTML.Highlighter = .HTML.Highlighter

::Class HTML.Highlighter SubClass Highlighter.Driver Public

-- We store Options. and source too

::Method Init
  Expose Options. output
  Use Strict Arg Options., output
  self~init:super(Options., output)

-- What to print at the beginning

::Method Prolog
  Expose Options. blockID

  patch     = Options.!Patch
  HTMLClass = Options.!HTMLClass
  style     = Options.style

  /* Every block gets an id, and every line an anchor hanging off it. The id  */
  /* is what the numbering hooks on (a:first-child::before), what a deep link */
  /* to a single line points at, and, when the author patched the style, what */
  /* the inline <style> below is keyed to. Pandoc numbers its own blocks      */
  /* "cb1", "cb2"...; ours are "rx1", "rx2"..., so a document holding both    */
  /* kinds of block has no id collisions.                                     */
  blockID = "rx"NextBlockID()

  /* Build optional data-caption attribute                                    */
  If Options.["CAPTION"] \== "", Options.["CAPTION"] \== 0 Then
    captionAttr = ' data-caption="'Options.["CAPTION"]'"'
  Else captionAttr = ""

  /* Mark blocks whose style the author fixed via style=, so a downstream     */
  /* client-side style chooser can leave them alone (it only restyles         */
  /* blocks that did not declare a style).                                    */
  If Options.["STYLE-EXPLICIT"] = 1
    Then lockAttr = ' data-rexx-style-locked'
    Else lockAttr = ""

  /* The wrapper. It carries OUR classes only. The markup below is shaped like*/
  /* Pandoc's -- a span per line, an anchor per span -- because that shape is */
  /* what lets a number hang outside the code ground. The class NAMES are not */
  /* Pandoc's, deliberately: its stylesheets scope their rules by those names,*/
  /* not by "blocks Pandoc emitted", so wearing them would hand a sheet we do */
  /* not control the last word on our margins, overflow, line height and      */
  /* background. We copy the mechanism and keep the naming.                   */
  /*                                                                          */
  /* "rx-blockwrap" is the structural hook: it marks the element that OWNS the */
  /* block, as opposed to the theme class, which only names its colours. A     */
  /* numbered block needs it, because the number hangs outside the <pre> and   */
  /* so the <pre> cannot be the scrolling box -- the wrapper has to be. (Named */
  /* "blockwrap", not "block": "rx-block" is the taken-constant class of a     */
  /* block-instruction name (DO/LOOP/SELECT), a distinct, long-standing use.)  */
  divTag = '<div class="highlight-rexx-'style' rx-blockwrap" id="'blockID'"' -
           || captionAttr || lockAttr || '>'

  -- No patch? A simple div will do.
  If patch == .Nil Then Do
    self~Say( divTag )
  End
  Else If patch~getpatch[!Tag2Attr]~isEmpty Then Do
    self~Say( divTag )
  End
  -- We have a patch. We will emit an inline style, indexed to our
  -- block ID. This does not validate, but it works with all major
  -- browsers. A validating alternative would be to generate
  -- inline styles for all the affected spans.
  Else Do

    id = blockID
    self~Say( divTag )
    patch.    = patch~getpatch
    Tag2Attr. = patch.!Tag2Attr
    constant  = .EL.TAKEN_CONSTANT

    self~say( "<style>" )
    Do tail Over Tag2Attr.~allIndexes
      Select Case tail~length
        When 3 Then classes = HTMLClass[ constant, tail[3] ]
        When 5 Then classes = HTMLClass[ constant, tail[3], tail[5] ]
        Otherwise   classes = HTMLClass[ tail ]
      End
      lastClass = Word( classes, Words( classes ) )
      Parse Value Tag2Attr.tail With b i u  color":"background
      style = ""
      Do c Over (b i u)~makeArray(" ")
        Select Case c
          When "b" Then style ||= "font-weight:normal; "
          When "B" Then style ||= "font-weight:bold; "
          When "i" Then style ||= "font-style:normal; "
          When "I" Then style ||= "font-style:italic; "
          When "u" Then style ||= "text-decoration:none; "
          When "U" Then style ||= "text-decoration:underline; "
          Otherwise Nop
        End
      End
      If color      \== "" Then style ||= "color:#"color"; "
      If background \== "" Then style ||= "background-color:#"background"; "

      self~say( "#"id "."lastClass "{"style"}" )

    End
    self~say( "</style>" )
  End

  options.!inc = 1

  If options.size == 0 Then size = ""
  Else size = ' style="font-size:'options.size'"'

  /* "rx-numbered" is what the numbering rules key on, and "rx-w<n>" says how */
  /* many digits the widest number in this block has, so a stylesheet can     */
  /* widen the gutter for a listing that needs it. Both are new names: the    */
  /* old "number-lines" is deliberately NOT reused, because a stylesheet that */
  /* has not been migrated would otherwise fire its old rule against the new  */
  /* markup and print a stray separator. Not matching at all degrades to "no  */
  /* numbers", which is obvious; half-matching would not be.                  */
  If Options.numberLines
    Then preClass = ' class="rx-numbered rx-w'Options.!numberWidth'"'
    Else preClass = ""

  self~emit( '<pre'size||preClass'>' )

  /* One <code> for the whole block (not one per line). A block that does     */
  /* not start at line 1 seeds the line counter here, inline: the stylesheet  */
  /* resets the counter to zero and this overrides it for this block only.    */
  If Options.numberLines, Options.startFrom \= 1 Then
    codeStyle = ' style="counter-reset: rx-line 'Options.startFrom - 1';"'
  Else codeStyle = ""

  self~emit( '<code'codeStyle'>' )
  self~emit( self~lineTag( Options.startFrom ) )

-- At the beginning of every line of code...

::Method startLine
  Use Strict Arg lineNo

  self~say(  '</span>' )
  self~emit( self~lineTag( lineNo ) )

--------------------------------------------------------------------------------
-- The opening tags of a line: the line span, and the anchor that carries     --
-- its number. The anchor is empty -- it exists so that a stylesheet has a    --
-- per-line hook to hang the number off (a:first-child::before), and so that  --
-- a single line can be linked to. When the block is not numbered the anchor  --
-- is still emitted, hidden from assistive technology and out of the tab      --
-- order, so that numbered and unnumbered blocks share one structure.         --
--------------------------------------------------------------------------------

::Method lineTag Private
  Expose Options. blockID

  Use Strict Arg lineNo

  lineID = blockID"-"lineNo

  If Options.numberLines Then anchorAttrs = ""
  Else anchorAttrs = ' aria-hidden="true" tabindex="-1"'

  Return '<span id="'lineID'"><a href="#'lineID'"'anchorAttrs'></a>'

-- Print a highlighted element value

::Method Highlight
  Use Strict Arg category, subCategory, variant, tags, string
  self~emit( '<span class="'tags'">'EscapeHTML(string)'</span>' )

-- What to print at the end

::Method Epilog
  /* No newline before </code>: a trailing one would print as an extra empty  */
  /* line inside the <pre>. Pandoc closes the three tags abutted, and so do   */
  /* we, so that the two kinds of block are the same height for the same      */
  /* number of lines.                                                         */
  self~Say( "</span></code></pre></div>" )

/******************************************************************************/
/* HTML.Inline.Highlighter -- the SAME engine, no block chrome                */
/* ===========================================================                */
/*                                                                            */
/* A `{.rexx}` mention is the parser tokenising a fragment of prose, exactly  */
/* as a fenced block does -- same parser, same Print loop, same Highlight     */
/* below. What a mention is NOT is a block: it has no <div> ground, no <pre>, */
/* no <code>, no per-line anchor. Those belong to a listing that owns a       */
/* rectangle on the slide; a mention is a run of tokens that flows inside a   */
/* line of prose, and its OWN wrapper (the <code class="rexx"> chip) is put   */
/* on by ProseMention, the single place that already wraps every mention.     */
/*                                                                            */
/* So this driver reuses the whole engine and overrides only the three        */
/* methods that emit block chrome: Prolog and Epilog fall silent, and         */
/* startLine emits a bare newline (the base class's default) instead of       */
/* closing one line span and opening the next with an anchor. Highlight,      */
/* Init, Emit, Say and the CSS machinery are inherited untouched -- the       */
/* tokens come out byte-for-byte as the block driver's do (<span class=       */
/* "rx-...">), which is the whole point: the fenced path was just ONE         */
/* consumer of the engine, and this is another, inline one. Nothing here      */
/* parses the block driver's output or knows its shape, so the two cannot     */
/* drift apart.                                                               */
/*                                                                            */
/* A fragment is conceptually one line, but the author may legitimately span  */
/* two (`If a=b Then c; Then Nop` written across a break): startLine keeps    */
/* the break as a newline so the tokens on the second line are not glued to   */
/* the first. The <code> is not display:block, so the newline collapses to a  */
/* space in normal flow -- present when it matters (source fidelity for a     */
/* copy), invisible when it does not.                                         */
/******************************************************************************/

::Class HTML.Inline.Highlighter SubClass HTML.Highlighter Public

::Method Prolog
  /* A mention has no block ground: emit nothing. ProseMention supplies the   */
  /* chip wrapper. */
  Nop

::Method startLine
  /* A bare newline between source lines (the abstract base's own default).   */
  /* No line span, no anchor -- those are a block's furniture. */
  Use Strict Arg lineNo
  self~say( "" )

::Method Epilog
  /* Nothing to close: Prolog opened nothing. */
  Nop

/******************************************************************************/
/* PROSE MENTIONS -- the micro-container for `x`{.rexx-*} outside fences      */
/* ===========================================================                */
/*                                                                            */
/* Called by FencedCode.cls's ScanProseMentions, once per recognised          */
/* mention, standalone -- there is no per-mention Highlighter.Driver          */
/* instance the way there is for a fenced block, so this cannot be a method   */
/* on HTML.Highlighter. It is the HTML-specific answer to "how does a prose   */
/* mention render"; a DocBook equivalent would emit <phrase role> instead,    */
/* the same way HLDrivers/DocBook.Driver.cls already does for fenced tokens.  */
/*                                                                            */
/* Each mention gets its OWN wrapper (never a shared ancestor): with the 25   */
/* Rexx themes all embedded in one slide deck, a shared ancestor's style      */
/* would collide with whichever fenced block's own style-div happened to be   */
/* declared later in the concatenated CSS -- see                              */
/* slides-refresh/revision-codigo-en-prosa.md sec. 2.4. One ancestor per      */
/* element makes that collision structurally impossible: there is only ever   */
/* the mention's own div-equivalent to match against.                         */
/*                                                                            */
/* The "rexx" fallback class is the SAME class the 26 stylesheets already     */
/* give a background+color in the same rule as <pre> (HTMLClass[] = "rexx"    */
/* is HTMLClasses()'s own default, so this is not a new convention) -- it     */
/* turns the mention into a small legible chip on any slide background and    */
/* under any chooser-driven theme switch, with no stylesheet changes at all.  */
/*                                                                            */
/******************************************************************************/

::Routine ProseMention Public
  Use Strict Arg style, tags, content
  Return '<span class="highlight-rexx-'style'"><code class="rexx 'tags'">' -
         || EscapeHTML(content) || '</code></span>'

--------------------------------------------------------------------------------
-- NextBlockID -- a counter that runs across every block of one document      --
--                                                                            --
-- Block ids have to be unique within the page, and a driver instance only    --
-- knows about its own block, so the counter cannot live in the instance. It  --
-- lives in .environment, the same place the driver system already keeps its  --
-- cross-instance state (see .CSS.Cache in Drivers.cls). One process builds   --
-- one document, so one counter per process is exactly the right scope.       --
--------------------------------------------------------------------------------

::Routine NextBlockID Private
  If .environment~hasIndex( Rexx.Parser.BlockID )
    Then n = .environment~Rexx.Parser.BlockID + 1
    Else n = 1
 .environment~Rexx.Parser.BlockID = n
  Return n

--------------------------------------------------------------------------------
-- EscapeHTML -- shared HTML-escaping for Highlight, ProseMention and, across --
-- the package boundary, FencedCode's RexxFragment (the {.rexx} error shout   --
-- escapes the offending fragment the same way). Public so that last caller   --
-- reaches it; it is a pure text utility with no driver state.                --
--------------------------------------------------------------------------------

::Routine EscapeHTML Public
  Use Strict Arg string
  Return string~changeStr( "&", "&amp;" ) -
               ~changeStr( ">", "&gt;"  ) -
               ~changeStr( "<", "&lt;"  )