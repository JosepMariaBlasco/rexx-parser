/******************************************************************************/
/*                                                                            */
/* md2slides.rex - Markdown to interactive slide deck                         */
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
/* 20260815    0.1  First prototype (as md2deck.rex)                          */
/* 20260816    0.2  Renamed md2deck -> md2slides. Identity split into two     */
/*                  orthogonal axes: -t/--theme (brand, one) and              */
/*                  -mp/--master-pages (presentation, layered). Resolution    */
/*                  by one rule: brand vs .css file.                          */
/*                                                                            */
/******************************************************************************/
/*                                                                            */
/* Sibling of md2html and md2pdf. Where md2html produces a page and md2pdf a  */
/* paginated document, md2slides produces an INTERACTIVE deck: one HTML file  */
/* holding every slide, driven by the deck runtime (keys, fragments, timers,  */
/* jump popup).                                                               */
/*                                                                            */
/* It shares the whole common core, so nothing new is parsed here:            */
/*                                                                            */
/*   FencedCode  -> the Rexx Highlighter marks up the ~~~rexx blocks          */
/*   Pandoc      -> Markdown becomes HTML, attributes and all                 */
/*   md2slides   -> that flat HTML is FOLDED into <section class="slide">     */
/*                                                                            */
/* The folding is the only genuinely new step, and it is what this file is    */
/* about. Everything the author writes reaches it as ordinary Pandoc output:  */
/*                                                                            */
/*   # Title {#id .role kicker="..." anim=... wait-before=...}                */
/*                                                                            */
/* becomes an <h1> carrying id, class and data-* attributes, and those move   */
/* onto the <section> that the h1 opens. An h1 starts a slide; that is the    */
/* whole rule. No {.newpage} marker is needed -- the slides docclass dropped  */
/* that requirement in April, and this follows suit.                          */
/*                                                                            */
/* Identity is two orthogonal axes, and this file emits neither: it lays out  */
/* STRUCTURE and never names a font, a colour or a logo. The THEME (-t)       */
/* brings the brand -- fonts, palette, footer strings, in :root variables;    */
/* the MASTER(s) (-mp) bring the presentation -- the rules that read those    */
/* variables. Adding an institution is a theme; adding a kind of presentation */
/* is a master. Neither is a change here.                                     */
/*                                                                            */
/******************************************************************************/

  Call Time R

  CLIhelper = InitCLI()
  myName    = CLIhelper~name
  myHelp    = CLIhelper~help
  myArgs    = CLIhelper~args

  -- md2slides lives at <project>/bin/md2slides.rex, so the project root is two
  -- levels up. The shared css/pandoc/ style sheets (and anything else md2slides
  -- borrows from the project) are resolved against this, exactly as md2pdf
  -- does -- no duplicated copies under the md2slides home.
  rootDir   = .File~new(.context~package~name)~parentFile~parent
  rootDir   = ChangeStr("\", rootDir, "/")

  ------------------------------------------------------------------------------
  -- Ensure that we have access to pandoc                                     --
  ------------------------------------------------------------------------------

  Address COMMAND "pandoc -v" With Output Stem Discard. Error Stem Discard.
  If RC <> 0 Then
    Call Error myName "needs a working version of pandoc. Aborting..."

  ------------------------------------------------------------------------------
  -- Command line                                                            --
  ------------------------------------------------------------------------------

  theme        = "default"           -- Brand theme to build with (the -t axis).
  themeFromCLI = 0                    -- ...unless -t/--theme says otherwise.
  masters      = .Array~new          -- Presentation masters to layer, in order
                                     -- (the -mp axis). Empty means "let the
                                     -- theme's own master.css stand", resolved
                                     -- once the theme is known. Multi-valued:
                                     -- the flag order IS the cascade order.
  mastersFromCLI = 0                 -- ...true once -mp names at least one.
  home      = rootDir"/bin/md2slides" -- md2slides home: css/, assets/, masters/,
                                      -- js/, templates/ live under here. Anchored
                                      -- to the .rex location, not the CWD, so
                                      -- md2slides runs from any directory. An
                                      -- --assets flag overrides it.
  csl       = "rexxpub"               -- Citation Style Language style. A bare
                                      -- name resolves to csl/<name>.csl in the
                                      -- project; a path is used as-is. Citeproc
                                      -- is activated by the deck declaring a
                                      -- bibliography:, not by this option --
                                      -- --csl only chooses WHICH style.
  hlStyle   = ""                      -- Pandoc highlighting style for non-Rexx
                                      -- code. Precedence: --pandoc-highlight
                                      -- flag > theme's own --theme-pandoc-style
                                      -- > "pygments". Read from the project's
                                      -- shared css/pandoc/.
  args      = .Array~new

  argCount = myArgs~items
  i = 1
  Loop While i <= argCount
    arg = myArgs[i]
    Select Case arg
      When "-h", "--help" Then Do
        Call Help
        Exit 0
      End
      When "-t", "--theme" Then Do
        i = i + 1
        theme = myArgs[i]
        themeFromCLI = 1
      End
      When "-mp", "--master-pages" Then Do
        -- Repeatable, one master per occurrence; occurrences stack in the order
        -- they appear, because that order IS the CSS cascade. Three layers are
        -- '-mp base -mp economia -mp urgencia', base applied first. Repeating
        -- the flag (rather than a greedy list) keeps it unambiguous against the
        -- positional deck and destination, and needs no -- fence.
        i = i + 1
        masters~append(myArgs[i])
        mastersFromCLI = 1
      End
      When "--assets" Then Do
        i = i + 1
        home = myArgs[i]
      End
      When "--csl" Then Do
        -- Chooses the citation style, exactly as md2pdf does. A bare name
        -- (no path separator) resolves to the project's shared csl/<name>.css;
        -- an argument containing a separator is a path used as-is. This does
        -- NOT switch citations on -- that is the bibliography:'s job (below);
        -- it only overrides the default 'rexxpub' when a bibliography exists.
        i = i + 1
        csl = myArgs[i]
      End
      When "--pandoc-highlight" Then Do
        -- The Pandoc style that colours non-Rexx code tokens, read from the
        -- project's shared css/pandoc/<style>.css. Same set md2pdf offers.
        -- Used verbatim (no case-folding): the sheets are named as Pandoc
        -- names them, e.g. breezeDark.css, so the name must match the file.
        i = i + 1
        hlStyle = myArgs[i]
      End
      Otherwise Do
        If Left(arg, 1) == "-" Then
          Call Error "Unknown option '"arg"'. Try 'md2slides --help'."
        args~append(arg)
      End
    End
    i = i + 1
  End

  If args~items = 0 Then
    Call Error "No input file given. Try 'md2slides --help'."

  -- Accept the source with or without its .md extension: 'md2slides deck' and
  -- 'md2slides deck.md' both work, as long as deck.md is what exists on disk.
  sourceFile = args[1]
  If \SysIsFile(sourceFile), SysIsFile(sourceFile".md") Then
    sourceFile = sourceFile".md"

  If \SysIsFile(sourceFile) Then
    Call Error "Cannot find '"sourceFile"'. Aborting..."

  -- The target defaults to the source with its extension swapped for .html.
  If args~items > 1 Then target = args[2]
  Else Do
    base = FileSpec("Name", sourceFile)
    If base~caselessEndsWith(".md") Then
      base = Left(base, Length(base) - 3)
    target = base".html"
  End

  -- Resolve the style to a concrete path, exactly as md2pdf does: a name with
  -- no separator is a shared style under the project's csl/; anything with a
  -- separator is a path used as-is. The file is only required to exist if the
  -- deck actually turns citations on (checked once the front matter is read).
  If csl~contains("/") | csl~contains("\") Then cslPath = csl
  Else cslPath = rootDir"/csl/"Lower(csl)".csl"

  ------------------------------------------------------------------------------
  -- Read the source, extract the YAML front matter and the options           --
  ------------------------------------------------------------------------------

  source = .Array~new
  stream = .Stream~new(sourceFile)
  Loop While stream~lines > 0
    source~append(stream~lineIn)
  End
  stream~close

  yaml = YAMLFrontMatter(source)
  opts = ParseRexxPubYAML(yaml)

  -- ParseRexxPubYAML returns a StringTable, and a StringTable is NOT a
  -- Directory: they are siblings under MapCollection. Guarding these reads
  -- with isA(.Directory), as this file did until v83, made every one of them
  -- dead code -- the YAML was parsed correctly and then thrown away. Two of
  -- the three failures were invisible (the default style happened to equal
  -- what the sample deck asked for, and --ci supplies the identity anyway),
  -- which is exactly why it survived a release: only the <title> showed it.
  defaultTheme = "tokio-day"
  If opts~isA(.StringTable), opts["style"] \== .Nil Then defaultTheme = opts["style"]

  -- The identity, the title and the footer fields are deck-only notions, and
  -- ParseRexxPubYAML copies from a whitelist by design: it is shared with
  -- md2html, md2pdf and the CGI, none of which has an identity or a slide
  -- footer. So they are read from the rexxpub: block directly, and no shared
  -- file has to grow a slides-shaped hole to let them through.
  rexxpub = RexxPubBlock(yaml)

  -- Precedence, per axis: an explicit flag beats the document, which beats the
  -- default. The other way round would defeat the very use the two axes exist
  -- for -- building one deck under three themes, or three masters -- by
  -- silently ignoring the flag whenever the front matter happened to name one.
  -- The axes are independent: a deck may pin its theme on the command line and
  -- still take its masters from the front matter, or the reverse.
  If \themeFromCLI, rexxpub~hasIndex("theme") Then theme = rexxpub["theme"]

  -- master-pages in the front matter is a SPACE-SEPARATED SCALAR, same order
  -- semantics as the flag: first named is applied first in the cascade, e.g.
  --   master-pages: base economia urgencia
  -- It is a scalar, not a YAML sequence, on purpose: the front-matter parser
  -- shared across the pipelines (YAMLFrontMatter.cls) handles only scalar
  -- mappings, so a '- item' sequence would parse to nonsense rather than a
  -- list. When that parser is replaced by the full yaml.cls (tracked as urgent
  -- debt), this can accept a real sequence and the guard below becomes moot.
  If \mastersFromCLI, rexxpub~hasIndex("master-pages") Then Do
    mpValue = rexxpub["master-pages"]
    If \mpValue~isA(.String) Then
      Call Error "master-pages in the front matter must be a space-separated" -
                 "list on one line (e.g. 'master-pages: base economia')," -
                 "not a YAML sequence."
    Loop m Over mpValue~space~makeArray(" ")
      masters~append(m)
    End
  End

  ------------------------------------------------------------------------------
  -- Rexx fenced code blocks go through the Highlighter, exactly as in the    --
  -- other pipelines. This is why a ~~~rexx block in a deck is marked up by   --
  -- the real parser and not by an imitation of one.                          --
  ------------------------------------------------------------------------------

  defaultOptions. = 0
  defaultOptions.default = ""
  defaultOptions.["CONTINUE"] = 1

  source = FencedCode( sourceFile, source, defaultTheme, defaultOptions. )

  -- Slide markers -> raw <hr class="slide">. A flat deck (from odp2md's absolute
  -- layout) opens each slide with a `--- {.slide}` line instead of an <h1>, and
  -- FoldIntoSlides folds on that. But Pandoc does NOT read `--- {.slide}` as a
  -- thematic break: a `---` with a trailing attribute is plain text to Pandoc,
  -- so the marker would survive verbatim into the body. We rewrite it to a raw
  -- HTML `<hr class="slide">` block BEFORE Pandoc, which Pandoc passes through
  -- untouched, giving the fold an unambiguous, content-safe boundary (a bare
  -- `<hr>` an author drew inside a slide has no class and is never mistaken for
  -- a break). A deck that still folds by <h1> simply has no such lines, so this
  -- is a no-op there.
  source = SlideMarkers(source)

  ------------------------------------------------------------------------------
  -- Pandoc turns the Markdown into HTML. Header attributes survive as id,    --
  -- class and data-*, which is the whole reason the deck syntax needed no    --
  -- invention: it is Pandoc's attribute syntax throughout.                   --
  ------------------------------------------------------------------------------

  contents = .Array~new

  -- Citations follow the document, not a flag: a deck that declares a
  -- `bibliography:` in its front matter gets citeproc, and one that does not
  -- is left byte-for-byte untouched. This is what makes the cites sample run
  -- with a bare `md2slides deck-cites` -- the deck asks for citations, so it
  -- gets them, with the default `rexxpub` style unless --csl named another.
  -- The style is orthogonal: --csl only chooses WHICH CSL, never WHETHER.
  -- citeproc resolves [@key] against the `bibliography:` entry (which already
  -- reaches pandoc, same as <title> does), and the bibliography lands wherever
  -- the deck puts a `::: {#refs} :::` block -- its own final "References" slide.
  -- The source goes to pandoc on stdin, so pandoc has no idea which directory
  -- the deck lives in -- and a `bibliography:` named in the front matter is
  -- resolved relative to that directory by the author, not to our CWD. We hand
  -- pandoc the deck's own directory as a resource path so a relative
  -- bibliography (the normal case) is found. Harmless when there are no
  -- citations. md2pdf sidesteps this only because it feeds pandoc the file by
  -- path; we cannot, because the source is rewritten (fenced code) first.
  deckDir = FileSpec("Location", sourceFile)
  If deckDir == "" Then deckDir = "./"

  citeOpts = ' --resource-path="'deckDir'"'
  If yaml \== .Nil, yaml~isA(.StringTable), yaml~hasIndex("bibliography") Then Do
    -- The style file is only required to exist now that we know the deck cites.
    If \SysIsFile(cslPath) Then
      Call Error "CSL style '"csl"' not found (looked for '"cslPath"'). Aborting..."
    citeOpts = citeOpts' --citeproc --csl="'cslPath'"'
  End

  Address COMMAND 'pandoc --from markdown-smart+footnotes --to html5'citeOpts -
    With Input Using (source) Output Using (contents) Error Stem Discard.

  flat = contents~makeString("L", "0a"x)

  -- Make the deck truly self-contained for pictures. Pandoc leaves content
  -- images as <img src="img/<file>"> (relative refs into the deck's img/
  -- folder that odp2md exported). We inline each as a base64 data URI so the
  -- single .html carries its pictures with it - no img/ folder needed beside
  -- it. Only img/-relative sources are touched: the theme/runtime data URIs
  -- (logo SVGs, already embedded) and any absolute or http(s) src are left
  -- alone. deckDir is where the .md - and thus img/ - lives.
  flat = EmbedImages(flat, deckDir)

  ------------------------------------------------------------------------------
  -- Fold, assemble, write                                                    --
  ------------------------------------------------------------------------------

  -- The two identity axes are resolved here into one thing: an ordered list of
  -- CSS sheets. The theme comes first (it carries the :root variables every
  -- master reads through var()), then the masters in the order they were named,
  -- because that order IS the cascade. The whole list is concatenated inline
  -- into a single self-contained document -- never <link>s, never @import.
  --
  -- An argument is resolved by ONE distinction: is it a brand or a .css file?
  -- Everything else follows from that (see ResolveTheme / ResolveMaster).
  themeSheet = ResolveTheme(theme, deckDir, home)
  If themeSheet == "" Then
    Call Error "No theme for '"theme"'. A brand must exist under" -
               home"/assets/<brand>/theme.css; a .css argument must be findable."

  -- Masters. With none named, the theme's own master.css stands (the brand's
  -- default presentation); a brand that omits it falls back to assets/default/.
  -- With masters named, each is resolved independently and layered in order.
  masterSheets = .Array~new
  If masters~items = 0 Then Do
    stand = ResolveMasterStand(theme, themeSheet, deckDir, home)
    If stand \== "" Then masterSheets~append(stand)
  End
  Else Do
    Loop mp Over masters
      one = ResolveMaster(mp, deckDir, home)
      If one == "" Then
        Call Error "No master for '"mp"' (named on -mp / master-pages)."
      masterSheets~append(one)
    End
  End

  -- Metrics and footer contract live in the THEME: it owns :root. Masters carry
  -- rules only. The footer band height is layout geometry (fitHeight reserves
  -- it); the old advance/floor/ceiling were the code-fitter's, and the fitter is
  -- gone -- code size is a fixed value the theme declares (--theme-code-size),
  -- not something computed to fill a box.
  themeCSS = ReadFile(themeSheet)
  band     = FooterHeight(themeCSS)

  -- The effective sheet: theme first, then masters in cascade order, joined by
  -- newlines so the emitted <style> stays readable. This is the string the
  -- template receives; there is exactly one of it.
  identityCSS = themeCSS
  Loop ms Over masterSheets
    identityCSS = identityCSS || "0a"x || ReadFile(ms)
  End

  -- Pandoc highlighting style, resolved now that the theme is loaded.
  -- Precedence: an explicit --pandoc-highlight flag wins; else the theme's own
  -- --theme-pandoc-style (a dark theme can ask for a dark style so its token
  -- colours match its --theme-othercode-bg); else "pygments". This keeps the
  -- two grounds -- panel (theme) and token colours (style) -- from
  -- contradicting each other, because the theme owns both.
  If hlStyle == "" Then hlStyle = PandocStyle(themeCSS)
  hlSheet = rootDir"/css/pandoc/"hlStyle".css"
  If \SysIsFile(hlSheet) Then
    Call Error "Pandoc highlighting style '"hlStyle"' not found (looked for '"hlSheet"')."

  -- The theme asks for fields; the document supplies them. Checking one against
  -- the other is the whole of footer validation, and it is checked in this
  -- direction on purpose: whitelisting field NAMES would freeze the vocabulary,
  -- and a deck is entitled to invent a "course" or a "semester".
  fields = FooterFields(rexxpub)
  Call CheckFooter themeCSS, fields

  stage = FoldIntoSlides(flat, band, fields)

  -- No <h1> in the flat HTML means no slide ever opened: the input was empty,
  -- was not markdown (e.g. an .odp passed by mistake), or carried no headings.
  -- Writing a 200KB runtime-only deck in that case hides the mistake; say it.
  If stage~countStr("<section") = 0 Then
    Call Error "No slides produced from '"sourceFile"'. The input has no" -
               "level-1 headings -- is it Markdown? (An .odp must be converted" -
               "with odp2md first.) Aborting..."

  rexxThemes  = RexxThemes(rootDir)
  rexxOptions = RexxStyleOptions(rootDir, defaultTheme)

  html = Assemble(stage, identityCSS, home, defaultTheme, rexxpub, fields, theme, hlSheet, deckDir, rexxThemes, rexxOptions)

  Call WriteFile target, html

  Say myName": wrote" target "("Length(html) % 1024 "KB)"
  Exit 0

--------------------------------------------------------------------------------
-- Help                                                                       --
--------------------------------------------------------------------------------

Help:
  Say "md2slides -- Markdown to interactive slide deck"
  Say ""
  Say "Usage: [rexx] md2slides OPTIONS filename [destination]"
  Say ""
  Say "Options:"
  Say ""
  Say "-t, --theme name  Brand theme to build with (default: default). A bare"
  Say "                  name resolves to assets/<name>/theme.css; a .css"
  Say "                  argument is taken as a file (self > cwd > default),"
  Say "                  or, if absolute, exactly as given."
  Say "-mp, --master-pages name"
  Say "                  Presentation master to layer. Repeatable; occurrences"
  Say "                  stack in cascade order: '-mp base -mp economia' applies"
  Say "                  base first. A bare name resolves to masters/<name>.css;"
  Say "                  a .css argument is a file, as with --theme. Omitted:"
  Say "                  the theme's own master.css stands."
  Say "--assets dir      md2slides home dir (css/, assets/, masters/, js/,"
  Say "                  templates/; default: bin/md2slides)"
  Say "--csl name|path   Citation style (default: rexxpub). A bare name resolves"
  Say "                  to csl/<name>.csl in the project; a path is used as-is."
  Say "                  Citations turn on when the deck declares a bibliography:"
  Say "                  in its front matter -- it cites with [@key] and gathers"
  Say "                  them wherever it puts a ::: {#refs} ::: block. This flag"
  Say "                  only chooses the style; it does not switch citations on."
  Say "--pandoc-highlight name"
  Say "                  Pandoc style for non-Rexx code. Overrides the theme's"
  Say "                  own --theme-pandoc-style. If neither is set: pygments."
  Say "                  Any style in the project's css/pandoc/ (pygments,"
  Say "                  breezeDark, kate, tango, zenburn, ...)."
  Say "-h, --help        Display this help"
  Say ""
  Say "An h1 starts a slide. Roles, animations and timings are Pandoc"
  Say "attributes on that h1:"
  Say ""
  Say "  # Lists {#lists kicker=""Sequences""}"
  Say "  # The Rexx angle {.section}"
  Say "  # Lists vs. Tuples {.two-col anim=slide}"
  Say "  # Example {wait-before=0.9 wait-after=0.7}"
  Say ""
  Say "md2slides is part of the Rexx Parser package,"
  Say "see https://rexx.epbcn.com/rexx-parser/. It is distributed under"
  Say "the Apache 2.0 License (https://www.apache.org/licenses/LICENSE-2.0)."
  Say ""
  Return

--------------------------------------------------------------------------------
-- Error                                                                      --
--------------------------------------------------------------------------------

Error:
  .Error~Say(myName": "Arg(1))
  Exit 1

/******************************************************************************/
/*                                                                            */
/* FoldIntoSlides                                                             */
/* =============                                                              */
/*                                                                            */
/* Pandoc hands us a flat sequence: h1, content, h1, content. A deck needs    */
/* those grouped, because the runtime shows and hides whole slides. Each h1   */
/* therefore opens a <section class="slide">, and the attributes the author   */
/* wrote on the heading move up onto that section, where the runtime looks    */
/* for them.                                                                  */
/*                                                                            */
/******************************************************************************/

::Routine FoldIntoSlides
  Use Strict Arg flat, band, fields

  -- Two folding regimes. A FLAT deck (odp2md's absolute layout) opens each
  -- slide with a `<hr class="slide">` marker and carries no heading; a CLASSIC
  -- deck (authored by hand, or reflow mode) opens each slide with an <h1> that
  -- is both the boundary and the title. We pick by presence of the marker, so
  -- an existing <h1>-authored deck folds byte-for-byte as before.
  If flat~pos('<hr class="slide"') > 0 Then
    Return FoldByMarker(flat, band, fields)

  out = ""
  Parse Var flat . "<h1" rest              -- Discard anything before slide 1

  Loop While rest \== ""
    Parse Var rest tag ">" body
    Parse Var body title "</h1>" body
    Parse Var body body "<h1" rest

    -- Pandoc wraps long tags and headings across lines. Rexx's Strip removes
    -- blanks but not newlines, so whitespace is flattened here, once, rather
    -- than guarded against at every place an attribute is read.
    attrs = TagAttrs(Squeeze(tag))
    out = out || RenderSlide(attrs, Squeeze(title), body, band, fields)
  End

  Return out

--------------------------------------------------------------------------------
-- FoldByMarker - the FLAT regime. Each slide is the run of HTML between one  --
-- `<hr class="slide">` and the next. No <h1>, no title: the slide's own title--
-- is just another absolutely-positioned box inside the body. The <section>   --
-- keeps all the structural chrome (logo band, footer band, slide/id classes) --
-- so the runtime is happy, but paints no <h1 class="title"> of its own.      --
-- Slide-level attributes (roles, animations, timings) are NOT carried here:  --
-- in the flat layout they were deliberately dropped, to be recovered by the  --
-- later semantic pass with theme + master-page perspective.                  --
--------------------------------------------------------------------------------

::Routine FoldByMarker
  Use Strict Arg flat, band, fields

  out = ""
  -- Discard anything before the first marker (front matter, stray whitespace).
  Parse Var flat . '<hr class="slide"' rest

  Loop While rest \== ""
    -- The text between here and ">" is this marker's own attribute run (e.g.
    -- ` data-cm-w="25.4" data-cm-h="19.05" /`); the body runs to the next
    -- marker. Pandoc emits the raw block as `<hr class="slide" ... />` (self-
    -- closing); ">" ends the tag whichever attributes it carries.
    Parse Var rest hrAttrs ">" body
    Parse Var body body '<hr class="slide"' rest

    -- TWO marker regimes, told apart by the canvas override the marker carries.
    -- A marker with data-cm-w/h is odp2md's FLAT layout (absolute boxes in cm):
    -- it renders through RenderFlatSlide, no title band, body owns its geometry.
    -- A BARE marker (`--- {.slide}`, no cm) is the SEMANTIC regime: the author
    -- placed zones (:::title, :::footer-center, code) and wants the master's
    -- chrome -- title band, author footer -- with the title flowing from the
    -- body's own :::title, not extracted from an <h1>. The two regimes share a
    -- marker syntax but not a renderer; splitting here is what keeps "how you
    -- cut" (by marker) orthogonal to "what regime you render" (flat vs semantic).
    canvasAttrs = SlideCanvasAttrs(hrAttrs)
    If canvasAttrs == "" Then
      out = out || RenderMarkerSlide(body, band, fields)
    Else
      out = out || RenderFlatSlide(body, canvasAttrs, band, fields)
  End

  Return out

--------------------------------------------------------------------------------
-- SlideCanvasAttrs - pull the per-slide canvas override (data-cm-w/h) out of --
-- an <hr>'s raw attribute run and return it as a clean attribute string to   --
-- stamp on the <section> (or "" when the marker carried none). Only the      --
-- canvas keys are forwarded; the trailing "/" of the self-closing tag and any--
-- other stray token are dropped. The value is passed through verbatim - it is--
-- odp2md's own CmScalar output, already noise-free.                          --
--------------------------------------------------------------------------------

::Routine SlideCanvasAttrs
  Use Strict Arg raw

  w = AttrValue(raw, "data-cm-w")
  h = AttrValue(raw, "data-cm-h")
  If w == "" | h == "" Then Return ""
  Return ' data-cm-w="'w'" data-cm-h="'h'"'

--------------------------------------------------------------------------------
-- AttrValue - value of a name="..." attribute in a raw tag string, or "".      --
--------------------------------------------------------------------------------

::Routine AttrValue
  Use Strict Arg raw, name

  needle = name'="'
  p = raw~pos(needle)
  If p == 0 Then Return ""
  rest = raw~substr(p + needle~length)
  Parse Var rest val '"' .
  Return val

--------------------------------------------------------------------------------
-- RenderFlatSlide - a <section> for the flat regime: same chrome as          --
-- RenderSlide, minus the title <h1> and the attribute-driven role/anim/kicker--
-- machinery (there is no heading to carry them). Every slide is a plain "list"--
-- role page; the body is whatever absolute-positioned boxes Pandoc produced. --
--------------------------------------------------------------------------------

::Routine RenderFlatSlide
  Use Strict Arg body, canvasAttrs, band, fields

  -- canvasAttrs is the per-slide canvas override (data-cm-w/h) or "". It rides
  -- on the <section> so a later pass can size this one slide to its own ODP
  -- page; the deck default (front-matter canvas-cm-w/h -> --deck-w/h) already
  -- covers every slide, so today this attribute is carried, not yet consumed.
  parsed = SlideIdentity(body, fields)
  sectionStyle = parsed[1]
  chrome       = parsed[2]
  body         = parsed[3]

  out = '  <section class="slide flat" id="slide"'canvasAttrs''sectionStyle'>' || "0a"x
  out = out || TransformBody(body, "list")
  out = out || chrome
  out = out || '  </section>' || "0a"x || "0a"x

  Return out

--------------------------------------------------------------------------------
-- RenderMarkerSlide - a <section> for the SEMANTIC marker regime: the slide  --
-- cut by a bare `--- {.slide}` (no cm canvas). Same master chrome as         --
-- RenderSlide -- the "list" role, the author's three footer slots -- but it  --
-- emits NO <h1 class="title"> of its own: the title is a zone the author     --
-- placed in the body (:::title -> div.title), so it flows in as the first    --
-- block through TransformBody. Crucially the section is NOT marked `flat`:   --
-- flat is odp2md's absolute-cm regime, whose `.slide.flat > div > p` rule    --
-- zeroes semantic <p>s (it was silently hiding the :::title). Here the slide --
-- keeps the master's padding, title band and footer band, and the body is    --
-- ordinary flow. Role/anim/kicker machinery is absent because a bare marker  --
-- carries no attributes to drive it; when the model earns per-slide attrs on --
-- the marker, they parse here the way RenderSlide parses an <h1>'s.          --
--------------------------------------------------------------------------------

::Routine RenderMarkerSlide
  Use Strict Arg body, band, fields

  -- Resolve the per-slide identity: defaults from the deck YAML (fields),
  -- overridden by any :::presenter (etc.) zone the author placed in THIS slide.
  -- Returns the data-* attribute run for the <section> and the body with the
  -- consumed override zones removed (they are data, not visible prose).
  parsed = SlideIdentity(body, fields)
  sectionStyle = parsed[1]
  chrome       = parsed[2]
  body         = parsed[3]

  out = '  <section class="slide" id="slide"'sectionStyle'>' || "0a"x
  out = out || TransformBody(body, "list")
  out = out || chrome
  out = out || '  </section>' || "0a"x || "0a"x

  Return out

--------------------------------------------------------------------------------
-- SlideIdentity - resolve the identity fields for ONE slide and return them  --
-- as a data-* attribute run, together with the body stripped of the override --
-- zones it consumed.                                                         --
--                                                                            --
-- The model: the FORMAT of the footer is the master's CSS; the FIELDS are the--
-- document's; and a field has a per-DECK default (the YAML footer: block, in --
-- `fields`) that any single slide may override locally with a zone -- e.g. a --
-- guest inserting their own slide writes `::: presenter` / their name / `:::`--
-- and it wins for that slide only. The runtime supplies page/total; everything--
-- else is resolved HERE, at build, so the CSS only ever reads a finished value--
-- via attr(data-...). No footer is composed, placed or named by this code.   --
--                                                                            --
-- Zones handled (Pandoc renders `::: name` as <div class="name">...</div>):  --
--   presenter, affiliation, date  -> data-presenter / -affiliation / -date   --
-- The zone, once read, is removed from the body: it is a datum, not prose.   --
--------------------------------------------------------------------------------

::Routine SlideIdentity
  Use Strict Arg body, fields

  -- Deck-level defaults from the YAML footer: block.
  presenter   = IdentityDefault(fields, "presenter")
  affiliation = IdentityDefault(fields, "affiliation")
  date        = IdentityDefault(fields, "date")

  -- Per-slide overrides: a zone in THIS slide beats the deck default. Each
  -- call returns an array of (override-or-.Nil, body-with-zone-removed).
  r = ZoneOverride(body, "presenter")
  If r[1] \== .Nil Then presenter = r[1]
  body = r[2]
  r = ZoneOverride(body, "affiliation")
  If r[1] \== .Nil Then affiliation = r[1]
  body = r[2]
  r = ZoneOverride(body, "date")
  If r[1] \== .Nil Then date = r[1]
  body = r[2]

  -- Per-slide code size. The fitter is gone: code is a fixed size, but a slide
  -- with more code needs a smaller one to fit (Rony drops 10pt->8pt by hand in
  -- Impress between his slides 19 and 20). :::code-font-size lets the author say
  -- so, in a literal CSS value ("8pt", "12px"). It overrides --theme-code-size
  -- for THIS slide only, as a custom property on the section; the theme default
  -- covers every slide that stays silent. (Per-block override is deferred.)
  codeSize = ""
  r = ZoneOverride(body, "code-font-size")
  If r[1] \== .Nil Then codeSize = r[1]
  body = r[2]

  -- Per-slide title size, same pattern. Rony's heading is not one fixed size:
  -- content slides use 18pt, a topic/section slide (his slide 18) uses 32pt.
  -- :::title-font-size overrides --theme-title-size for THIS slide only.
  titleSize = ""
  r = ZoneOverride(body, "title-font-size")
  If r[1] \== .Nil Then titleSize = r[1]
  body = r[2]

  -- Per-slide prose base size, same pattern. The per-level cascade scales down
  -- from this; :::body-font-size overrides --theme-body-size for THIS slide.
  bodySize = ""
  r = ZoneOverride(body, "body-font-size")
  If r[1] \== .Nil Then bodySize = r[1]
  body = r[2]

  styleDecls = ""
  If codeSize  \== "" Then styleDecls = styleDecls'--theme-code-size: 'AttrEscape(codeSize)'; '
  If titleSize \== "" Then styleDecls = styleDecls'--theme-title-size: 'AttrEscape(titleSize)'; '
  If bodySize  \== "" Then styleDecls = styleDecls'--theme-body-size: 'AttrEscape(bodySize)'; '

  sectionStyle = ""
  If styleDecls \== "" Then
    sectionStyle = ' style="'Strip(styleDecls)'"'

  -- "today" resolves at build time to an ISO date. Any other value is the
  -- author's own text, left verbatim.
  If date == "today" Then date = ResolveToday()

  -- Emit the resolved identity as REAL ELEMENTS the master will place (it is
  -- document content, not a datum), plus the empty `chrome` anchor the master
  -- fills with images by CSS (opt 2a: the pipeline knows nothing of logos or
  -- seals; it only guarantees the anchor). affiliation/date also ride as data-*
  -- on nothing here -- they are cheap to carry as elements too if the master
  -- wants them; presenter is the one Rony's slide shows.
  chrome = ""
  If presenter \== "" Then
    chrome = chrome'    <div class="presenter">'presenter'</div>' || "0a"x
  If affiliation \== "" Then
    chrome = chrome'    <div class="affiliation">'affiliation'</div>' || "0a"x
  If date \== "" Then
    chrome = chrome'    <div class="date">'date'</div>' || "0a"x
  chrome = chrome'    <div class="chrome"></div>' || "0a"x

  Return .Array~of(sectionStyle, chrome, body)

--------------------------------------------------------------------------------
-- IdentityDefault - one deck-level field from the YAML footer block, or "".  --
--------------------------------------------------------------------------------

::Routine IdentityDefault
  Use Strict Arg fields, name

  If \fields~isA(.StringTable)  Then Return ""
  If \fields~hasIndex(name)     Then Return ""
  value = fields[name]
  If value == .Nil              Then Return ""
  If \value~isA(.String)        Then Return ""
  Return value

--------------------------------------------------------------------------------
-- ZoneOverride - if the body contains a `<div class="NAME">...</div>` zone   --
-- (Pandoc's rendering of `::: NAME`), return its text content and the body   --
-- with that zone removed; otherwise return .Nil and the body unchanged. The  --
-- return is "override body", parsed by the caller with Parse Value ... With. --
-- Only the FIRST such zone is consumed (one identity value per field, and a  --
-- second would be an authoring error, not two presenters).                   --
--------------------------------------------------------------------------------

::Routine ZoneOverride
  Use Strict Arg body, name

  marker = '<div class="'name'"'
  p = body~pos(marker)
  If p = 0 Then Return .Array~of(.Nil, body)   -- no override; body untouched

  -- Isolate the zone. Pandoc emits `<div class="name">\n<p>text</p>\n</div>`.
  Parse Var body before (marker) inZone
  Parse Var inZone . ">" inner "</div>" after
  -- Strip an inner <p>...</p> wrapper and any tags, leaving the text.
  text = Squeeze(StripTags(inner))

  Return .Array~of(text, before || after)

--------------------------------------------------------------------------------
-- ResolveToday - the build date as ISO YYYY-MM-DD.                           --
--------------------------------------------------------------------------------

::Routine ResolveToday
  iso = Date("Sorted")                  -- YYYYMMDD
  Return Left(iso,4)"-"SubStr(iso,5,2)"-"Right(iso,2)

--------------------------------------------------------------------------------
-- StripTags - remove any HTML tags, leaving text content.                    --
--------------------------------------------------------------------------------

::Routine StripTags
  Use Strict Arg html

  out = ""
  rest = html
  Loop While rest \== ""
    p = rest~pos("<")
    If p = 0 Then Do
      out = out || rest
      Leave
    End
    out = out || Left(rest, p - 1)          -- text before the tag
    q = rest~pos(">", p)
    If q = 0 Then Leave                       -- malformed; stop
    rest = SubStr(rest, q + 1)                -- skip past the tag
  End
  Return out

::Routine Squeeze
  Use Strict Arg text

  text = text~translate(" ", "0a"x || "0d"x || "09"x)
  Loop While text~pos("  ") > 0
    text = text~changeStr("  ", " ")
  End

  Return Strip(text)

--------------------------------------------------------------------------------
-- SlideMarkers - rewrite each `--- {.slide}` line to a raw                   --
-- `<hr class="slide">` HTML block BEFORE Pandoc. Pandoc does not treat       --
-- `--- {.slide}` as a thematic break (a `---` with a trailing attribute is   --
-- plain text to it), so we turn it into raw HTML, which Pandoc passes through--
-- untouched. The marker must be on its own line; leading/trailing blanks are --
-- tolerated. A deck with no such lines is returned unchanged                 --
-- (the classic <h1> fold still applies).                                     --    
--                                                                            --
-- ATTRIBUTES. A bare marker is `--- {.slide}`; a marker MAY carry per-slide  --
-- attributes inside the braces, e.g. `--- {.slide data-cm-w="25.4" ...}` (the--
-- canonical-canvas per-slide override odp2md emits when a page's physical size--
-- differs from the deck default). Whatever sits between `.slide` and the     --
-- closing brace is copied verbatim onto the <hr>, so it reaches the folded   --
-- <section> and survives for a later pass to consume. The bare form stays    --
-- byte-identical to before (no trailing space when there is nothing to carry).--
--------------------------------------------------------------------------------

::Routine SlideMarkers
  Use Strict Arg source

  out = ""
  Loop line Over source~makeArray            -- String -> lines (splits on LF)
    s = Strip(line)
    If s~left(11) == "--- {.slide", s~right(1) == "}" Then Do
      -- the run between ".slide" and the final "}" is the attribute block
      attrs = s~substr(12)                   -- everything after "--- {.slide"
      attrs = attrs~left(attrs~length - 1)   -- drop the trailing "}"
      attrs = Strip(attrs)
      If attrs == "" Then
        out = out || '<hr class="slide" />' || "0a"x
      Else
        out = out || '<hr class="slide"' attrs '/>' || "0a"x
    End
    Else
      out = out || line || "0a"x
  End

  Return out

--------------------------------------------------------------------------------
-- Split an opening tag's attributes into a directory. Pandoc always quotes   --
-- its values, which is what makes this safe to do by hand.                   --
--------------------------------------------------------------------------------

::Routine TagAttrs
  Use Strict Arg tag

  attrs = .Directory~new
  Loop While tag~pos("=") > 0
    Parse Var tag name '="' value '"' tag
    attrs[Strip(name)~lower] = value
  End

  Return attrs

/******************************************************************************/
/*                                                                            */
/* The animation catalogue                                                    */
/* =======================                                                    */
/*                                                                            */
/* The catalogue is CLOSED, and it is closed here rather than in the CSS      */
/* because CSS has no way to complain. An unknown effect name is not a        */
/* rendering problem -- the stylesheet simply has no rule for it, the slide   */
/* animates with the default and nothing anywhere says a word. The author     */
/* who typed anim=fadeleft finds out in the lecture hall, if at all.          */
/*                                                                            */
/* So the name is checked at build time, where a typo is still cheap. The     */
/* two vocabularies are separate on purpose: a page cannot blur in and an     */
/* element cannot wash the accent colour across itself, and pretending they   */
/* share a namespace would only mean accepting names that do nothing.         */
/*                                                                            */
/* This is a WARNING, not a failure: the deck still builds, because a wrong   */
/* animation is a blemish and refusing to produce the deck minutes before a   */
/* talk would be a far worse one.                                             */
/*                                                                            */
/******************************************************************************/

::Routine PageAnims
  Return "fade slide fade-color cut"

::Routine ElementAnims
  Return "fade fade-up fade-down fade-left fade-right scale-in blur-in cut"

--------------------------------------------------------------------------------
-- Check one name against one vocabulary. `where` names the slide so the      --
-- author is told WHICH one to fix, not merely that something is wrong.       --
--------------------------------------------------------------------------------

::Routine CheckAnim
  Use Strict Arg name, catalogue, scope, where

  If name == "" Then Return
  If WordPos(name, catalogue) > 0 Then Return

  .Error~Say( "md2slides: warning: unknown" scope "animation" '"'name'"' -
              "on slide" '"'where'".' )
  .Error~Say( "                 known names:" catalogue )
  Return

--------------------------------------------------------------------------------
-- A duration is seconds, optionally with an explicit ms suffix. Anything     --
-- else reaches the runtime as NaN and silently leaves the default in place,  --
-- which is the same failure mode as a misspelt name, so it is caught here    --
-- for the same reason.                                                       --
--------------------------------------------------------------------------------

::Routine CheckAnimDuration
  Use Strict Arg value, where

  If value == "" Then Return
  probe = value~strip
  If probe~right(2)~lower == "ms" Then probe = probe~left(probe~length - 2)~strip
  If probe~dataType("N") Then Return

  .Error~Say( "md2slides: warning: anim-duration" || ' "'value'"' -
              "on slide" || ' "'where'"' "is not a number." )
  .Error~Say( "                 durations are seconds, e.g. 0.4 (or 400ms)." )
  Return

--------------------------------------------------------------------------------
-- Every data-anim inside a slide body belongs to a fragment, so the whole    --
-- body can be swept in one pass against the element vocabulary.              --
--------------------------------------------------------------------------------

::Routine CheckBodyAnims
  Use Strict Arg body, where

  rest = body
  Loop While rest~pos('data-anim="') > 0
    Parse Var rest . 'data-anim="' name '"' rest
    Call CheckAnim Squeeze(name), ElementAnims(), "element", where
  End

  rest = body
  Loop While rest~pos('data-anim-duration="') > 0
    Parse Var rest . 'data-anim-duration="' value '"' rest
    Call CheckAnimDuration Squeeze(value), where
  End

  Return

--------------------------------------------------------------------------------
-- The roles are the fixed master-page set. "list" is the default and needs   --
-- no class, which is why most slides carry no attributes at all.             --
--------------------------------------------------------------------------------

::Routine RenderSlide
  Use Strict Arg attrs, title, body, band, fields

  roles     = "title-slide section two-col business-card"
  classList = ""
  If attrs~hasIndex("class") Then classList = attrs["class"]

  role = "list"
  Loop w Over classList~makeArray(" ")
    If WordPos(w, roles) > 0 Then role = w
  End

  extras = ""
  Loop w Over classList~makeArray(" ")
    If WordPos(w, roles) = 0, w \== "" Then extras = extras w
  End

  names = "slide"
  If role \== "list" Then names = names role
  names = Strip(names extras)

  id = "slide"
  If attrs~hasIndex("id") Then id = attrs["id"]

  -- A divider is a navigation anchor; everything else is a page.
  If role == "section"
    Then marker = ' data-section="'title'"'
    Else marker = ' data-title="'title'"'

  -- Effect names are checked before anything is emitted: the deck still gets
  -- built, but the author hears about a typo now rather than on stage.
  If attrs~hasIndex("data-anim") Then
    Call CheckAnim Squeeze(attrs["data-anim"]), PageAnims(), "page", title
  If attrs~hasIndex("data-anim-duration") Then
    Call CheckAnimDuration Squeeze(attrs["data-anim-duration"]), title
  Call CheckBodyAnims body, title

  -- Everything the author wrote as data-* passes through untouched, so the
  -- runtime's vocabulary can grow without this routine ever knowing.
  passThrough = ""
  Loop k Over attrs~allIndexes
    If k~left(5) == "data-", k \== "data-kicker" Then
      passThrough = passThrough' 'k'="'attrs[k]'"'
  End

  -- Resolve deck-default identity, overridden by any :::presenter/etc. zone in
  -- this slide's body. The zones are consumed (data, not prose); the resolved
  -- values return as REAL elements (presenter, etc.) plus the empty `chrome`
  -- anchor, all placed inside the slide for the master's CSS to position.
  -- sectionStyle carries a per-slide --theme-code-size override, if any.
  parsed = SlideIdentity(body, fields)
  sectionStyle = parsed[1]
  chrome       = parsed[2]
  body         = parsed[3]

  out = '  <section class="'names'" id="'id'"'marker''passThrough''sectionStyle'>' || "0a"x

  If attrs~hasIndex("data-kicker") Then
    out = out || '    <p class="kicker">'attrs["data-kicker"]'</p>' || "0a"x

  out = out || '    <h1 class="title">'title'</h1>' || "0a"x
  out = out || TransformBody(body, role)
  out = out || chrome

  out = out || '  </section>' || "0a"x || "0a"x

  Return out

/******************************************************************************/
/*                                                                            */
/* TransformBody                                                              */
/* =============                                                              */
/*                                                                            */
/* Four adjustments, and no more. Pandoc's output is already almost what the  */
/* runtime wants; pretending otherwise would mean reimplementing Pandoc.      */
/*                                                                            */
/*   1. A paragraph holding nothing but a span becomes that span's paragraph. */
/*      This is how [Output:]{.label .fragment} reaches the runtime as a      */
/*      labelled, revealable paragraph while staying legal Pandoc Markdown.   */
/*   2. Column and card divs are gathered into their master-page container.   */
/*   3. A top-level list is wrapped in .body, the runtime's prose slot.       */
/*   4. Highlighted code blocks get the runtime's .code class (fixed size).   */
/*                                                                            */
/******************************************************************************/

::Routine TransformBody
  Use Strict Arg body, role

  -- The Highlighter wraps its output in div.highlight-rexx-STYLE, which names
  -- a THEME, not a slot. Add the runtime's structural class so the block sits
  -- in the code slot and takes the theme's fixed code size. (Code is no longer
  -- fitted: --theme-code-size is a declared value, not one computed to fill a
  -- box, so there is nothing to compute here.)
  body = AddCodeClass(body)

  body = HoistSpans(body)

  Select Case role
    When "two-col"       Then body = Gather(body, "col",  "columns")
    When "business-card" Then body = Cards(body)
    Otherwise Nop
  End

  -- A bare list is the slide's prose. Wrap it once, not per list.
  If body~pos("<ul>") > 0, body~pos('class="body"') = 0, -
     body~pos('class="col') = 0 Then Do
    Parse Var body pre "<ul>" mid
    n = LastPos("</ul>", mid)
    tail = mid~substr(n + 5)
    mid  = mid~left(n - 1)
    body = pre'<div class="body"><ul>'mid'</ul></div>'tail
  End

  Return body

--------------------------------------------------------------------------------
-- Give every highlighted BLOCK the runtime's structural class.               --
--                                                                            --
-- The class cannot be matched together with the tag ('<div class="high...'), --
-- because Pandoc reorders attributes when it re-emits raw HTML: the block's  --
-- own id now comes first, so the div reaches us as '<div id="rx1" class=...'.--
-- We therefore look for the class attribute alone and then walk BACK to the  --
-- tag that owns it -- which is also what tells a block apart from a prose    --
-- MENTION, since a mention carries the very same class on a <span> and must  --
-- not be given a block's geometry.                                           --
--------------------------------------------------------------------------------

::Routine AddCodeClass
  Use Strict Arg body

  marker = 'class="highlight-rexx-'
  out    = ""

  Loop While body~pos(marker) > 0
    at   = body~pos(marker)
    tag  = body~lastPos("<", at)             -- the tag that owns the attribute
    head = body~left( at - 1 )               -- everything before the attribute
    body = body~substr( at + Length(marker) )

    If tag > 0, Lower( head~substr(tag, 5) ) == "<div "
      Then out ||= head'class="code highlight-rexx-'
      Else out ||= head||marker
  End

  Return out || body

--------------------------------------------------------------------------------
-- <p><span class="x">t</span></p>  ->  <p class="x">t</p>                    --
--                                                                            --
-- ONLY when the <p> holds exactly ONE span and nothing else. A <p> that      --
-- wraps two spans joined by a <br> (a multi-line box label, "Security,<br>   --
-- Debugging") must be left alone: hoisting the first span's attrs onto the   --
-- <p> and stripping its </span> would mis-nest the second span (a stray      --
-- </span>, an unclosed <span>) and the box renders blank. So a match whose   --
-- captured text still contains a tag (< ) is NOT collapsed - it is emitted   --
-- verbatim and we move past it.                                              --
--------------------------------------------------------------------------------

::Routine HoistSpans
  Use Strict Arg body

  out = ""
  Loop While body~pos("<p><span ") > 0
    Parse Var body pre "<p><span " spanAttrs ">" text "</span></p>" rest
    If text~pos("<") > 0 Then Do
      -- more than one element inside this <p> (e.g. a <br> and a second span):
      -- not a lone span, leave the whole opener intact and advance past it.
      out = out || pre || "<p><span " || spanAttrs || ">"
      body = text || "</span></p>" || rest
    End
    Else Do
      out = out || pre || "<p " || spanAttrs || ">" || text || "</p>"
      body = rest
    End
  End

  Return out || body

--------------------------------------------------------------------------------
-- Wrap every top-level div carrying class `what` in a single container.      --
-- Divs nest (Pandoc puts a sourceCode div inside a column), so the closing   --
-- tag has to be matched by counting, not by searching.                       --
--------------------------------------------------------------------------------

::Routine Gather
  Use Strict Arg body, what, container

  first = body~pos('<div class="'what)
  If first = 0 Then Return body

  last = first
  Loop While body~substr(last, 12 + Length(what))~pos('<div class="'what) = 1
    last = MatchDiv(body, last)
    -- Skip the whitespace Pandoc leaves between sibling divs
    Loop While last <= Length(body), Pos(body~substr(last, 1), " "||"0a"x||"09"x) > 0
      last = last + 1
    End
  End

  head = body~left(first - 1)
  mid  = body~substr(first, last - first)
  tail = body~substr(last)

  Return head'<div class="'container'">'mid'</div>'tail

--------------------------------------------------------------------------------
-- Position just past the </div> that closes the <div> starting at `from`.    --
--------------------------------------------------------------------------------

::Routine MatchDiv
  Use Strict Arg body, from

  depth = 0
  i = from
  Loop While i <= Length(body)
    If body~substr(i, 5) == "<div " | body~substr(i, 5) == "<div>" Then Do
      depth = depth + 1
      i = i + 4
    End
    Else If body~substr(i, 6) == "</div>" Then Do
      depth = depth - 1
      i = i + 6
      If depth = 0 Then Return i
    End
    Else i = i + 1
  End

  Return i

--------------------------------------------------------------------------------
-- Contact cards. Inside a card the first line is the name, the second the    --
-- role and the rest are details -- a convention, so that a card needs no     --
-- markup beyond the div that opens it.                                       --
--------------------------------------------------------------------------------

::Routine Cards
  Use Strict Arg body

  body = Gather(body, "card", "cards")

  out = ""
  Loop While body~pos('<div class="card">') > 0
    -- Two adjacent variables in a template split on a blank, not on the rest
    -- of the string, so the card is cut out by position instead.
    Parse Var body pre '<div class="card">' card
    n    = card~pos("</div>")
    body = card~substr(n + 6)
    card = card~left(n - 1)

    inner = ""
    seq = "name role"
    k = 1
    Loop While card~pos("<p>") > 0
      Parse Var card . "<p>" text "</p>" card
      If k <= 2 Then cls = Word(seq, k)
      Else cls = "detail"
      inner = inner'<p class="'cls'">'text'</p>'
      k = k + 1
    End

    out = out || pre || '<div class="vcard">' || inner || '</div>'
  End

  Return out || body


--------------------------------------------------------------------------------
-- PandocStyle: the identity's preferred Pandoc highlighting theme, or        --
-- "pygments" if it declares none. A dark identity names a dark theme here so --
-- its token colours sit well on its own --theme-othercode-bg.                --
--------------------------------------------------------------------------------

::Routine PandocStyle
  Use Strict Arg css

  If css~pos("--theme-pandoc-style:") = 0 Then Return "pygments"
  Parse Var css . "--theme-pandoc-style:" value ";" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- RexxThemes: every Rexx highlighter theme, concatenated for embedding.      --
--                                                                            --
-- A deck is a single self-contained file, so it cannot lazy-load stylesheets --
-- the way the CGI does. Instead every theme is embedded, and the in-deck     --
-- chooser switches between them by rewriting the highlight-rexx-<style>      --
-- class. The themes are the project's own flattened/rexx-*.css -- read from  --
-- there, never copied -- so md2slides and md2pdf share one set. (A "thin" deck--
-- carrying only a chosen few could be added later; for now it embeds all.)   --
--------------------------------------------------------------------------------

::Routine RexxThemes
  Use Strict Arg rootDir

  -- The nested css/rexx-*.css, NOT css/flattened/. The flattened copies exist
  -- only to work around the back-level Chromium in pagedjs-cli, which has no
  -- CSS nesting; md2pdf needs them for that reason. A deck is viewed in an
  -- ordinary browser, so it takes the canonical nested source. test1 is a
  -- development scratch theme and is not shipped.
  dir = rootDir"/css"
  files = .Array~new
  Call SysFileTree dir"/rexx-*.css", "files.", "FO"

  css = ""
  Do i = 1 To files.0
    If ThemeName(files.i) == "test1" Then Iterate
    css ||= Minify(files.i)
  End

  Return css

--------------------------------------------------------------------------------
-- Minify: read a CSS file and drop the lines that carry no style -- blank    --
-- lines and whole-line comments -- then collapse the survivors' runs of      --
-- whitespace to single spaces with space(). These sheets are mostly licence  --
-- headers, section banners and deep indentation; with 25 of them embedded in --
-- every deck that is a lot of dead weight. A line goes if, once stripped, it --
-- is empty, or it is a comment that both opens and closes on that line       --
-- (/* ... */) with nothing after the close -- the inner-"*/" guard keeps a   --
-- line like "/* a */ real { }" intact. CSS ignores insignificant whitespace, --
-- so collapsing it is safe here.                                             --
--------------------------------------------------------------------------------

::Routine Minify
  Use Strict Arg fn

  b = .MutableBuffer~new
  Do line Over .File~readLines(fn)
    t = line~strip
    If t == "" Then Iterate
    If t~startsWith("/*"), t~endsWith("*/"), t~length > 4 Then Do
      inner = t~substr(3, t~length - 4)
      If inner~pos("*/") = 0 Then Iterate
    End
    b~append(line" ")
  End

  Return b~string~space

--------------------------------------------------------------------------------
-- ThemeName: the <style> part of a .../rexx-<style>.css path.                --
--------------------------------------------------------------------------------

::Routine ThemeName
  Use Strict Arg path

  leaf = FileSpec("Name", path)             -- rexx-<style>.css
  Return leaf~substr(6, Length(leaf) - 9)   -- strip "rexx-" and ".css"

--------------------------------------------------------------------------------
-- RexxStyleOptions: the <option> list for the in-deck code-style chooser,    --
-- one per shipped theme, in alphabetical order, with the deck's default      --
-- marked selected. Kept in step with RexxThemes: same source, same blacklist.--
--------------------------------------------------------------------------------

::Routine RexxStyleOptions
  Use Strict Arg rootDir, defaultTheme

  dir = rootDir"/css"
  files = .Array~new
  Call SysFileTree dir"/rexx-*.css", "files.", "FO"

  names = .Array~new
  Do i = 1 To files.0
    style = ThemeName(files.i)
    If style == "test1" Then Iterate
    names~append(style)
  End
  names~sortWith(.CaselessComparator~new)

  out = ""
  Do style Over names
    sel = ""
    If style == defaultTheme Then sel = " selected"
    out ||= '<option value="'style'"'sel'>'style'</option>' || "0a"x
  End

  Return out

/******************************************************************************/
/*                                                                            */
/* The footer                                                                 */
/* ==========                                                                 */
/*                                                                            */
/* One split governs all of this: the FORMAT belongs to the identity and the  */
/* FIELDS belong to the document. WU says its footer carries the institute on */
/* the left, the page number in the middle and the presenter on the right;    */
/* the deck says who the presenter is. Before v83 the presenter's name was    */
/* written into ci-wu.css as generated content, which meant that giving the   */
/* same talk under the same identity required editing the identity.           */
/*                                                                            */
/* Nothing is interpolated here. The build collects the values and hands them */
/* to the runtime, which is the only place where {page} exists -- numbering   */
/* was taken away from the generator in v81 precisely because hand-written    */
/* numbers drift. What the build does own is the CHECKING, because a warning  */
/* is only useful before the deck reaches a lecture hall.                     */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- The rexxpub: block, or an empty table. Everything below tolerates a deck   --
-- with no front matter at all, which is a legitimate way to write one.       --
--------------------------------------------------------------------------------

::Routine RexxPubBlock
  Use Strict Arg yaml

  empty = .StringTable~new

  If yaml == .Nil              Then Return empty
  If \yaml~isA(.StringTable)   Then Return empty
  If \yaml~hasIndex("rexxpub") Then Return empty

  rexxpub = yaml["rexxpub"]
  If \rexxpub~isA(.StringTable) Then Return empty

  Return rexxpub

--------------------------------------------------------------------------------
-- The footer: sub-block, as an open bag of author-defined values.            --
--------------------------------------------------------------------------------

::Routine FooterFields
  Use Strict Arg rexxpub

  fields = .StringTable~new

  If \rexxpub~hasIndex("footer") Then Return fields

  declared = rexxpub["footer"]
  If \declared~isA(.StringTable) Then Return fields

  Loop name Over declared~allIndexes
    value = declared[name]
    If value == .Nil            Then Iterate
    If \value~isA(.String)      Then Iterate   -- a nested block is not a field
    fields[Lower(name)] = value
  End

  If fields~hasIndex("license") Then
    Call CheckLicence fields["license"], "in the front matter"

  Return fields

--------------------------------------------------------------------------------
-- The deck-level values, as attributes for the stage element.                --
--------------------------------------------------------------------------------

::Routine FooterAttrs
  Use Strict Arg fields

  out = ""
  Loop name Over fields~allIndexes
    out = out' data-footer-'name'="'AttrEscape(fields[name])'"'
  End

  Return out

--------------------------------------------------------------------------------
-- The identity declares the height of the band its footer sits in.           --
--------------------------------------------------------------------------------

::Routine FooterHeight
  Use Strict Arg css

  If css~pos("--theme-footer-height:") = 0 Then Return 64
  Parse Var css . "--theme-footer-height:" value "px" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- The slot templates the identity declared, as written.                      --
--------------------------------------------------------------------------------

::Routine CITemplate
  Use Strict Arg css, slot

  marker = "--theme-footer-"slot":"
  If css~pos(marker) = 0 Then Return ""
  Parse Var css . (marker) value ";" .

  value = Strip(Squeeze(value))
  If Length(value) >= 2 Then Do
    If Left(value,1) == '"', Right(value,1) == '"' Then
      value = SubStr(value, 2, Length(value) - 2)
  End

  Return value

--------------------------------------------------------------------------------
-- Every field the identity asks for must have a supplier.                    --
--------------------------------------------------------------------------------

::Routine CheckFooter
  Use Strict Arg css, fields

  -- Supplied by the runtime on every slide, so never the document's job.
  builtIn = "page total-pages totalPages"

  Loop slot Over "left center right"~makeArray(" ")
    -- Fields inside [ ] are optional BY DECLARATION: bracketing them is how an
    -- identity says "if there is one". Only what is left after the groups are
    -- removed is genuinely required, and only that is worth a warning.
    template = ""
    rest     = CITemplate(css, slot)
    Loop While rest~pos("[") > 0
      Parse Var rest before "[" . "]" rest
      template = template || before
    End
    template = template || rest

    Loop While template~pos("{") > 0
      Parse Var template . "{" name "}" template
      name = Strip(name)
      If name == ""                     Then Iterate
      If WordPos(name, builtIn) > 0     Then Iterate
      If fields~hasIndex(Lower(name))   Then Iterate

      -- Not a failure: the deck is still built, with a gap where the value
      -- would have gone. A slide may well supply the field itself, which is
      -- how borrowed material carries a credit the rest of the deck lacks.
      .Error~Say( "md2slides: warning: the" slot "footer slot asks" -
                  "for {"name"}, which the document does not set." )
    End
  End

  Return

--------------------------------------------------------------------------------
-- Licence names, self-documenting on purpose: a footer has to tell a reader  --
-- what they may do, and "copyleft" tells them nothing they can act on.       --
--------------------------------------------------------------------------------

::Routine KnownLicences

  Return "cc-by cc-by-sa cc-by-nc cc-by-nc-sa cc-by-nd cc-by-nc-nd cc0" -
         "public-domain all-rights-reserved gfdl apache-2.0"

::Routine CheckLicence
  Use Strict Arg value, where

  If value == "" Then Return
  If WordPos(value, KnownLicences()) > 0 Then Return

  -- A pinned version is legal: cc-by-sa-3.0 is a name we know, at its 3.0.
  -- The full name is tried first, or apache-2.0 would be read as a version
  -- of something called "apache".
  base = value
  p    = value~lastPos("-")
  If p > 1 Then Do
    tail = SubStr(value, p + 1)
    If DataType(tail, "N") Then base = Left(value, p - 1)
  End
  If WordPos(base, KnownLicences()) > 0 Then Return

  -- Only a slug-shaped value is a probable typo. Anything carrying a space or
  -- a capital is prose -- a jurisdiction port, a publisher's own wording --
  -- and its author gets it through untouched and unpestered.
  If \IsSlug(value) Then Return

  .Error~Say( "md2slides: warning: unknown licence '"value"'" where"." -
              "It will be shown exactly as written." )

  Return

::Routine IsSlug
  Use Strict Arg value

  Return Verify(value, "abcdefghijklmnopqrstuvwxyz0123456789-.") == 0

--------------------------------------------------------------------------------
-- Attribute values reach the browser through HTML, so they are escaped.      --
--------------------------------------------------------------------------------

::Routine AttrEscape
  Use Strict Arg text

  text = text~changeStr("&", "&amp;")
  text = text~changeStr('"', "&quot;")
  text = text~changeStr("<", "&lt;")
  text = text~changeStr(">", "&gt;")

  Return text

/******************************************************************************/
/*                                                                            */
/* Assemble                                                                   */
/* ========                                                                   */
/*                                                                            */
/* One self-contained file: the deck has to survive being emailed, opened     */
/* from a memory stick and shown on a machine with no network. Everything     */
/* the runtime needs is inlined.                                              */
/*                                                                            */
/******************************************************************************/

::Routine Assemble
  Use Strict Arg stage, identityCSS, home, theme, rexxpub, fields, brand, hlSheet, deckDir, rexxThemes, rexxOptions

  title = "Slide deck"
  If rexxpub~hasIndex("title") Then title = rexxpub["title"]

  -- The deck's own field values ride on the stage, where every slide can see
  -- them. A slide that sets the same field shadows it; that one rule is the
  -- whole of "override per slide", and there is no second mechanism for it.
  stageAttrs = FooterAttrs(fields)

  -- Logos are no longer a pipeline concept. A logo is just an image: a master
  -- may paint one (or several, or none) as a CSS background on whatever zone it
  -- likes, and an author may drop an image into the Markdown with any name they
  -- choose. There is no %logo% slot, no per-brand logo.txt, no privileged
  -- "deck-logo" element -- the presentation owns its imagery through the master
  -- CSS, exactly as it owns its geometry.
  html = ReadFile(home"/templates/deck.template")

  -- Non-Rexx ("other") code highlighting. Pandoc marks the tokens with
  -- skylighting classes (.op, .st, .kw...) but emits no CSS for them, so a
  -- theme sheet must supply the colours -- exactly as md2pdf loads
  -- css/pandoc/<style>.css. The sheet is read from the project's shared
  -- css/pandoc/ (hlSheet, already validated), so md2slides offers the same
  -- theme set as md2pdf without duplicating a single file. pycode.css is
  -- loaded AFTER it so the identity's --theme-othercode-bg wins the panel ground
  -- over anything the theme might set. The Rexx block is untouched by all
  -- this: it goes through the Highlighter (themes.css) and never carries a
  -- .sourceCode class.
  pandocCSS = ""
  If SysIsFile(hlSheet) Then pandocCSS = ReadFile(hlSheet)

  -- CANONICAL CANVAS. runtime.css defaults the render canvas to 1280x720px,
  -- but the flat (odp2md) layout places boxes in literal cm against the ODP's
  -- own page. When the deck front matter declares that page (canvas-cm-w/h, in
  -- cm), the stage must BE that page or the cm boxes stop short of the edge
  -- (28cm -> 1058px inside a 1280px stage = 82.7% wide). We convert cm to px at
  -- the CSS reference 96dpi (1cm = 96/2.54 = 37.795px, the same factor the
  -- browser renders a `28cm` box at, so boxes and stage share one scale) and
  -- emit a :root override AFTER runtime.css, where the cascade lets it win.
  -- Omitted when the deck declares no canvas (classic decks, factory input):
  -- runtime.css's 1280x720 then stands unchanged.
  canvasOverride = DeckCanvasCSS(rexxpub)
  -- The font override must beat the THEME (which sets --theme-font-prose/mono),
  -- and the theme sheet loads as identityCSS AFTER runtime.css. So the deck
  -- fonts ride at the END of identityCSS, last in the cascade, where they win.
  -- The canvas override has no such contest (themes never set --deck-w/h) and
  -- stays with runtime.css.
  fontsOverride = DeckFontsCSS(rexxpub)

  html = html~caselessChangeStr("%title%",   title)
  html = html~caselessChangeStr("%runtimeCSS%", ReadFile(home"/css/runtime.css") -
                                             || canvasOverride)
  html = html~caselessChangeStr("%identityCSS%",      identityCSS || fontsOverride)
  html = html~caselessChangeStr("%extraCSS%",   ReadFile(home"/css/bcard.css") -
                                             || ReadFile(home"/css/overlay.css") -
                                             || ReadFile(home"/css/anim.css") -
                                             || pandocCSS -
                                             || ReadFile(home"/css/pycode.css"))
  html = html~caselessChangeStr("%themesCSS%",  rexxThemes)
  html = html~caselessChangeStr("%rexxStyleOptions%", rexxOptions)
  html = html~caselessChangeStr("%runtimeJS%",  ReadFile(home"/js/runtime.js"))
  html = html~caselessChangeStr("%chooserJS%",  ReadFile(home"/js/chooser.js"))
  html = html~caselessChangeStr("%jumpJS%",     ReadFile(home"/js/jump.js"))
  html = html~caselessChangeStr("%stage%",      stage)
  html = html~caselessChangeStr("%stageAttrs%", stageAttrs)

  Return html

--------------------------------------------------------------------------------
-- DeckCanvasCSS - a :root override setting --deck-w/--deck-h to the deck's     --
-- physical page size (front-matter canvas-cm-w/h, in cm) converted to px, or   --
-- "" when the deck declares no canvas. Emitted after runtime.css so it wins    --
-- the cascade. cm->px at 96dpi (the CSS reference the browser uses to render a --
-- `Ncm` length), so the stage and the cm-positioned boxes share one scale and  --
-- the flat layout reaches the slide's own edges. Rounded to an integer px      --
-- (runtime.css multiplies --deck-w by 1px; a fractional deck size buys no      --
-- fidelity the box cm don't already carry and keeps the value clean).          --
--------------------------------------------------------------------------------

::Routine DeckCanvasCSS
  Use Strict Arg rexxpub

  If \rexxpub~hasIndex("canvas-cm-w") Then Return ""
  If \rexxpub~hasIndex("canvas-cm-h") Then Return ""
  cmW = rexxpub["canvas-cm-w"]
  cmH = rexxpub["canvas-cm-h"]
  If \cmW~dataType("N") | \cmH~dataType("N") Then Return ""

  pxPerCm = 96 / 2.54
  pxW = (cmW * pxPerCm)~format(, 0)     -- round to integer px
  pxH = (cmH * pxPerCm)~format(, 0)

  Return "0a"x || ":root { --deck-w:" pxW"; --deck-h:" pxH"; }" || "0a"x

--------------------------------------------------------------------------------
-- DeckFontsCSS - a :root override setting --deck-font-prose / --deck-font-mono --
-- to the deck's dominant faces (front-matter font-prose / font-mono), or "" per --
-- key when absent. Emitted after runtime.css so it wins the cascade, exactly    --
-- like DeckCanvasCSS. The base font rides here, once per deck, instead of the    --
-- emitter stamping font-family on every run: prose text inherits                 --
-- --deck-font-prose, the code registers (<pre>/<code>/.output) use              --
-- --deck-font-mono. Each family is quoted and given a generic fallback           --
-- (sans-serif / monospace) so a deck that resolves no face still renders sane,   --
-- and a face the machine lacks degrades to the right generic. The names come     --
-- from the ODP verbatim (e.g. IBM Plex Sans, Tahoma, Courier New).               --
--------------------------------------------------------------------------------

::Routine DeckFontsCSS
  Use Strict Arg rexxpub

  decls = ""
  If rexxpub~hasIndex("font-prose") Then Do
    fp = rexxpub["font-prose"]
    If fp \== "" Then decls = decls "--theme-font-prose: '"fp"', sans-serif;"
  End
  If rexxpub~hasIndex("font-mono") Then Do
    fm = rexxpub["font-mono"]
    If fm \== "" Then decls = decls "--theme-font-mono: '"fm"', monospace;"
  End
  If decls == "" Then Return ""
  Return "0a"x || ":root {" decls "}" || "0a"x

--------------------------------------------------------------------------------
-- Identity resolution: one distinction, two worlds.                          --
--                                                                            --
-- Every -t / -mp argument is either a BRAND (a bare name) or a FILE (ends in --
-- .css). That single test decides everything; nothing else is memorised.     --
--                                                                            --
--   BRAND  -t wu      -> home/assets/wu/theme.css   (or master.css)          --
--   FILE   -t x.css   -> cascade: self > cwd > assets/default/               --
--   FILE   -t /p/x.css-> that path only, no cascade                          --
--                                                                            --
-- A routine returns the resolved path, or "" when nothing was found; the     --
-- caller turns "" into the right complaint.                                  --
--------------------------------------------------------------------------------

::Routine ResolveTheme
  Use Strict Arg name, deckDir, home

  If IsCSSFile(name) Then Return ResolveFile(name, "theme", deckDir, home)

  -- Brand world: the theme is assets/<brand>/theme.css. Absent means the user
  -- named a brand that is not there -- the caller complains, we just report "".
  brandSheet = home"/assets/"name"/theme.css"
  If SysIsFile(brandSheet) Then Return brandSheet
  Return ""

--------------------------------------------------------------------------------
-- A master named on -mp, resolved on its own.                                --
--------------------------------------------------------------------------------

::Routine ResolveMaster
  Use Strict Arg name, deckDir, home

  If IsCSSFile(name) Then Return ResolveFile(name, "master", deckDir, home)

  -- Brand world for a master: two shelves are searched, in order. First the
  -- shared pool masters/<name>.css (this is what -mp base economia means -- the
  -- named presentation layers, not a brand's own sheet); then, as a
  -- convenience, a brand's own master.css when the -mp argument happens to name
  -- a brand rather than a pooled master.
  pooled = home"/masters/"name".css"
  If SysIsFile(pooled) Then Return pooled

  brandMaster = home"/assets/"name"/master.css"
  If SysIsFile(brandMaster) Then Return brandMaster
  Return ""

--------------------------------------------------------------------------------
-- The master that stands when no -mp is given: the theme's own default       --
-- presentation. A brand keeps it in assets/<brand>/master.css; a brand that  --
-- ships none borrows assets/default/. A file-world theme has no brand folder --
-- to hold a default master, so it stands on the default brand's master.      --
--------------------------------------------------------------------------------

::Routine ResolveMasterStand
  Use Strict Arg name, themeSheet, deckDir, home

  If \IsCSSFile(name) Then Do
    brandMaster = home"/assets/"name"/master.css"
    If SysIsFile(brandMaster) Then Return brandMaster
  End

  defMaster = home"/assets/default/master.css"
  If SysIsFile(defMaster) Then Return defMaster
  Return ""

--------------------------------------------------------------------------------
-- File world: a relative .css cascades self (next to the deck) > cwd >       --
-- assets/default/; an absolute path is taken as given, with no cascade. The  --
-- 'axis' argument only shapes the assets/default/ fallback name.             --
--------------------------------------------------------------------------------

::Routine ResolveFile
  Use Strict Arg name, axis, deckDir, home

  -- Absolute path: exactly there, nothing implied.
  If IsAbsolute(name) Then Do
    If SysIsFile(name) Then Return name
    Return ""
  End

  -- Relative: next to the deck, then the current directory, then the default
  -- brand folder as a last resort (so a deck may say -t accent.css and have it
  -- resolved against a house sheet shipped with the product).
  self = deckDir || name
  If SysIsFile(self) Then Return self

  If SysIsFile(name) Then Return name

  fallback = home"/assets/default/"name
  If SysIsFile(fallback) Then Return fallback
  Return ""

--------------------------------------------------------------------------------
-- The two tiny tests the whole scheme turns on.                              --
--------------------------------------------------------------------------------

::Routine IsCSSFile
  Use Strict Arg name
  Return name~caselessEndsWith(".css")

::Routine IsAbsolute
  Use Strict Arg name
  If name~pos("/") = 1 Then Return 1          -- POSIX absolute
  If name~length >= 2, name~substr(2, 1) == ":" Then Return 1   -- Windows C:
  Return 0

--------------------------------------------------------------------------------
-- Small file helpers                                                        --
--------------------------------------------------------------------------------

::Routine ReadFile Public
  Use Strict Arg fn

  s = .Stream~new(fn)
  s~open("read")
  text = s~charIn(1, s~chars)
  s~close

  Return text

::Routine WriteFile Public
  Use Strict Arg fn, text

  s = .Stream~new(fn)
  s~open("write replace")
  s~charOut(text)
  s~close

  Return

::Routine EmbedImages Public
  Use Strict Arg html, deckDir

  -- Inline every <img src="img/<file>"> as a base64 data URI, so the deck
  -- carries its content pictures inside the single .html. odp2md exports the
  -- ODP's pictures to <deckDir>/img/ and the .md links them as img/<file>;
  -- Pandoc passes those through as relative <img src>. We rewrite only those:
  -- a src that does not start with "img/" (an already-embedded data: URI, an
  -- absolute path, an http(s) URL) is left untouched.
  If deckDir == "" Then deckDir = "./"
  If deckDir~right(1) \== "/" Then deckDir = deckDir"/"

  MARK = 'src="img/'
  out  = ""
  rest = html
  Loop Forever
    p = rest~pos(MARK)
    If p == 0 Then Do
      out = out || rest                     -- no more images: flush the tail
      Leave
    End

    -- Emit everything up to (not including) the 'img/' in this src, then the
    -- literal 'src="' so the attribute stays intact.
    out  = out || rest~substr(1, p - 1) || 'src="'
    -- Position just after 'src="img/' ... actually after 'src="' so we can read
    -- the whole relative path starting at 'img/'.
    after = rest~substr(p + MARK~length - 4)   -- starts at 'img/<file>"...'
    q     = after~pos('"')                     -- closing quote of the src value
    If q == 0 Then Do                          -- malformed; emit rest verbatim
      out  = out || after
      Leave
    End
    relPath = after~substr(1, q - 1)           -- img/<file>
    rest    = after~substr(q + 1)              -- everything after the close quote

    dataUri = DataUriFor(deckDir || relPath)
    If dataUri == "" Then out = out || relPath || '"'      -- unreadable: keep ref
                     Else out = out || dataUri  || '"'
  End

  Return out

/******************************************************************************/
/* DataUriFor - a file's contents as a base64 data: URI, or "" if unreadable. */
/* MIME comes from the extension; unknown extensions fall back to             */
/* application/octet-stream, which browsers still render for common images.   */
/******************************************************************************/

::Routine DataUriFor Public
  Use Strict Arg path

  If \ SysIsFile(path) Then Return ""
  bytes = .File~readChars(path)             -- whole binary in one call
  If bytes == .Nil Then Return ""
  mime  = MimeForExt(path)
  Return "data:" || mime || ";base64," || bytes~encodeBase64

/******************************************************************************/
/* MimeForExt - image MIME type for a path's extension.                       */
/******************************************************************************/

::Routine MimeForExt Public
  Use Strict Arg path
  dot = path~lastPos(".")
  ext = ""
  If dot > 0 Then ext = path~substr(dot + 1)~lower
  Select Case ext
    When "png"          Then Return "image/png"
    When "jpg", "jpeg"  Then Return "image/jpeg"
    When "gif"          Then Return "image/gif"
    When "svg"          Then Return "image/svg+xml"
    When "webp"         Then Return "image/webp"
    When "bmp"          Then Return "image/bmp"
    When "tif", "tiff"  Then Return "image/tiff"
    Otherwise                Return "application/octet-stream"
  End

::Requires "parser/BaseClassesAndRoutines.cls"
::Requires "parser/ErrorHandler.cls"
::Requires "parser/CLISupport.cls"
::Requires "parser/FencedCode.cls"
::Requires "parser/YAMLFrontMatter.cls"
::Requires "parser/RexxPubOptions.cls"
