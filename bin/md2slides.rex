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
/*                  orthogonal axes: -t/--theme (brand, one) and -mp/--master- */
/*                  pages (presentation, layered). Resolution by one rule:     */
/*                  brand vs .css file. Highlighting flag renamed to           */
/*                  --pandoc-highlight.                                        */
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
/* STRUCTURE and never names a font, a colour or a logo. The THEME (-t) brings */
/* the brand -- fonts, palette, footer strings, in :root variables; the       */
/* MASTER(s) (-mp) bring the presentation -- the rules that read those         */
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
  -- Read the source, extract the YAML front matter and the options          --
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
  -- the real parser and not by an imitation of one.                         --
  ------------------------------------------------------------------------------

  defaultOptions. = 0
  defaultOptions.default = ""
  defaultOptions.["CONTINUE"] = 1

  source = FencedCode( sourceFile, source, defaultTheme, defaultOptions. )

  ------------------------------------------------------------------------------
  -- Pandoc turns the Markdown into HTML. Header attributes survive as id,   --
  -- class and data-*, which is the whole reason the deck syntax needed no    --
  -- invention: it is Pandoc's attribute syntax throughout.                  --
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
  -- rules only, so they are never read for advance, floor, ceiling or band.
  themeCSS = ReadFile(themeSheet)
  advance  = MonoAdvance(themeCSS)
  floor    = MinCodeSize(themeCSS)
  ceiling  = MaxCodeSize(themeCSS)
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

  -- A theme whose floor sits above its ceiling has no band left to fit into,
  -- and the clamps would silently resolve it one way rather than the other.
  -- Better said out loud than decided by the order of two Ifs.
  If floor > ceiling Then
    .Error~Say( "md2slides: warning: theme '"theme"' declares a code floor of" -
                floor"px above its ceiling of" ceiling"px." )

  stage = FoldIntoSlides(flat, advance, floor, band, ceiling)

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
/* Pandoc hands us a flat sequence: h1, content, h1, content. A deck needs     */
/* those grouped, because the runtime shows and hides whole slides. Each h1    */
/* therefore opens a <section class="slide">, and the attributes the author    */
/* wrote on the heading move up onto that section, where the runtime looks     */
/* for them.                                                                  */
/*                                                                            */
/******************************************************************************/

::Routine FoldIntoSlides
  Use Strict Arg flat, advance, floor, band, ceiling

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
    out = out || RenderSlide(attrs, Squeeze(title), body, advance, floor, band, ceiling)
  End

  Return out

--------------------------------------------------------------------------------
-- Any run of whitespace becomes a single blank.                              --
--------------------------------------------------------------------------------

::Routine Squeeze
  Use Strict Arg text

  text = text~translate(" ", "0a"x || "0d"x || "09"x)
  Loop While text~pos("  ") > 0
    text = text~changeStr("  ", " ")
  End

  Return Strip(text)

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
/* rendering problem -- the stylesheet simply has no rule for it, the slide    */
/* animates with the default and nothing anywhere says a word. The author      */
/* who typed anim=fadeleft finds out in the lecture hall, if at all.           */
/*                                                                            */
/* So the name is checked at build time, where a typo is still cheap. The      */
/* two vocabularies are separate on purpose: a page cannot blur in and an      */
/* element cannot wash the accent colour across itself, and pretending they    */
/* share a namespace would only mean accepting names that do nothing.         */
/*                                                                            */
/* This is a WARNING, not a failure: the deck still builds, because a wrong    */
/* animation is a blemish and refusing to produce the deck minutes before a    */
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
  Use Strict Arg attrs, title, body, advance, floor, band, ceiling

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

  out = '  <section class="'names'" id="'id'"'marker''passThrough'>' || "0a"x

  -- Dividers carry no logo: they are a full-bleed field, not a content page.
  If role \== "section" Then
    out = out || '    <img class="deck-logo" src="%logo%" alt="">' || "0a"x

  If attrs~hasIndex("data-kicker") Then
    out = out || '    <p class="kicker">'attrs["data-kicker"]'</p>' || "0a"x

  -- A slide showing borrowed material overrides its own footer fields. That
  -- costs nothing here: Pandoc turns any attribute it does not recognise into
  -- a data-* one, and the pass-through above already forwards those onto the
  -- section without knowing what they mean. Only the licence is worth a look,
  -- since a mistyped one would be shown to an audience as written.
  If attrs~hasIndex("data-footer-license") Then
    Call CheckLicence Squeeze(attrs["data-footer-license"]), "on slide '"title"'"

  out = out || '    <h1 class="title">'title'</h1>' || "0a"x
  out = out || TransformBody(body, role, advance, floor, band, ceiling)

  -- Three empty slots, and not one field name among them. What each slot says
  -- is the identity's business and is filled in by the runtime, which is the
  -- only place where {page} exists at all. No slide-number is emitted either:
  -- the number is a footer field like any other.
  out = out || '    <footer class="deck-footer">' -
             || '<span class="footer-slot footer-left"></span>' -
             || '<span class="footer-slot footer-center"></span>' -
             || '<span class="footer-slot footer-right"></span>' -
             || '</footer>' || "0a"x
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
/*   4. Code blocks are fitted (see FitSize).                                 */
/*                                                                            */
/******************************************************************************/

::Routine TransformBody
  Use Strict Arg body, role, advance, floor, band, ceiling

  -- The Highlighter wraps its output in div.highlight-rexx-STYLE, which names
  -- a THEME, not a slot. Add the runtime's structural class so the block sits
  -- in the code slot and obeys the fitted size; without it --fit-size is
  -- computed and then read by nobody.
  body = body~changeStr('<div class="highlight-rexx-', -
                        '<div class="code highlight-rexx-')

  body = HoistSpans(body)
  body = FitBlocks(body, advance, floor, band, ceiling)

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
-- <p><span class="x">t</span></p>  ->  <p class="x">t</p>                    --
--------------------------------------------------------------------------------

::Routine HoistSpans
  Use Strict Arg body

  out = ""
  Loop While body~pos("<p><span ") > 0
    Parse Var body pre "<p><span " spanAttrs ">" text "</span></p>" body
    out = out || pre || "<p " || spanAttrs || ">" || text || "</p>"
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

/******************************************************************************/
/*                                                                            */
/* FitBlocks / FitSize                                                        */
/* ===================                                                        */
/*                                                                            */
/* Code is never wrapped on a slide: a broken statement may be a syntax error.*/
/* So the size is chosen at build time instead, from the longest line and the */
/* identity's monospaced advance. Switching --ci re-fits every block, which   */
/* is the point of keeping the metric in the identity stylesheet.             */
/*                                                                            */
/* The advance is a declared average, not a measured glyph width. Real        */
/* metrics need FontMetrics through BSF4ooRexx; this is the approximation     */
/* the PoC has used since v79, and it is honest about being one.              */
/*                                                                            */
/******************************************************************************/

::Routine FitBlocks
  Use Strict Arg body, advance, floor, band, ceiling

  -- How many lines still fit once the runtime has shrunk a block as far as it
  -- is allowed to. Derived, not guessed: the slide is 720 high, 42 goes to the
  -- top margin, about 110 to kicker plus title, and the footer band is however
  -- tall the identity declared it -- an identity with a two-line footer leaves
  -- less room for code, and the warning has to know that.
  maxLines = Trunc((568 - band) / (floor * 1.35))

  out = ""
  Loop While body~pos("<pre") > 0
    Parse Var body pre "<pre" tag ">" code "</pre>" body
    size = FitSize(code, advance, 944, floor, ceiling)

    -- Width is settled here; height is settled in the browser, where the
    -- identity's line-height and the rest of the slide are known. But a block
    -- past this many lines cannot fit at a readable size under ANY identity,
    -- and the author is better told now than left to find out from the back
    -- of the room.
    lines = code~countStr("0a"x) + 1
    If lines > maxLines Then
      .Error~Say( "md2slides: warning:" lines "lines of code will not fit a" -
                  "slide above" floor"px. Consider splitting it." )

    out = out || pre || "<pre" || tag || ' style="--fit-size: 'size'px">' -
              || code || "</pre>"
  End

  Return out || body

::Routine FitSize
  Use Strict Arg code, advance, box, floor, ceiling

  longest = 0
  Loop line Over code~makeArray("0a"x)
    cells = DisplayWidth(PlainText(line))
    If cells > longest Then longest = cells
  End

  If longest = 0 Then Return ceiling

  size = box / (longest * advance)

  -- The ceiling and the floor are the IDENTITY's, not this routine's. Until
  -- v83 both were written here as 20 and 11, and the floor in particular
  -- contradicted --theme-min-code-size outright: an identity declaring that its
  -- face stops being readable at 18px got blocks fitted to 11 anyway, and the
  -- runtime could not repair it because fitHeight only ever shrinks.
  If size > ceiling Then size = ceiling
  If size < floor   Then size = floor

  Return Format(size, , 1)

--------------------------------------------------------------------------------
-- How wide a line is on screen, in monospaced cells.                         --
--------------------------------------------------------------------------------

/******************************************************************************/
/*                                                                            */
/* Rexx's Length counts BYTES, and the fitter was using it to decide how wide  */
/* a line of code would be. In UTF-8 those are different questions: the Rexx   */
/* sample line in the torture deck is 79 bytes and 57 cells, so it was fitted  */
/* as if it were 39% longer than it looks.                                    */
/*                                                                            */
/* What follows is an APPROXIMATION and is meant to be read as one, in the     */
/* same spirit as --theme-mono-advance being a declared average rather than real */
/* glyph metrics. It decodes UTF-8 to code points -- which is where nearly all */
/* the error was -- and then applies a small width table:                      */
/*                                                                            */
/*   - combining marks and variation selectors take no cell of their own, so   */
/*     a Devanagari matra does not widen the line it modifies;                 */
/*   - CJK, Hangul, fullwidth forms and emoji take two cells;                  */
/*   - a code point immediately after ZERO WIDTH JOINER takes none, so the     */
/*     common joined sequences (families, professions) count as one glyph      */
/*     rather than as their parts.                                            */
/*                                                                            */
/* What it does NOT do is real grapheme clustering, and it does not pretend    */
/* to: that needs a Unicode database, not a table in a build script. Sequences */
/* joined by anything other than ZWJ will still be over-counted, which errs    */
/* towards a smaller, safe size rather than towards a line that wraps.         */
/*                                                                            */
/******************************************************************************/

::Routine DisplayWidth
  Use Strict Arg text

  width  = 0
  joined = 0
  i      = 1
  n      = Length(text)

  Loop While i <= n
    b = C2D(SubStr(text, i, 1))
    Select
      When b < 128  Then Do; cp = b;       len = 1; End
      When b >= 240 Then Do; cp = b - 240; len = 4; End
      When b >= 224 Then Do; cp = b - 224; len = 3; End
      When b >= 192 Then Do; cp = b - 192; len = 2; End
      -- A stray continuation byte means the text is not well-formed UTF-8.
      -- Count it as one cell and carry on: this is a fitter, not a validator.
      Otherwise Do; cp = -1; len = 1; End
    End

    Loop k = 1 To len - 1
      If i + k > n Then Leave
      cp = cp * 64 + (C2D(SubStr(text, i + k, 1)) // 64)
    End
    i = i + len

    If cp < 0 Then Do; width = width + 1; Iterate; End

    If cp == 8205 Then Do              -- ZERO WIDTH JOINER
      joined = 1
      Iterate
    End

    If InRanges(cp, ZeroWidthRanges()) Then Iterate

    If joined Then Do                  -- already paid for by what it joins
      joined = 0
      Iterate
    End

    If InRanges(cp, WideRanges()) Then width = width + 2
    Else                                width = width + 1
  End

  Return width

::Routine InRanges
  Use Strict Arg cp, ranges

  Loop i = 1 To Words(ranges) By 2
    If cp >= X2D(Word(ranges, i)), cp <= X2D(Word(ranges, i + 1)) Then Return 1
  End

  Return 0

--------------------------------------------------------------------------------
-- Marks that ride on the previous glyph rather than taking a cell.           --
--------------------------------------------------------------------------------

::Routine ZeroWidthRanges

  r =   "0300 036F"                     -- combining diacriticals
  r = r "0483 0489"                     -- Cyrillic
  r = r "0591 05BD 05BF 05BF 05C1 05C2 05C4 05C5 05C7 05C7"
  r = r "0610 061A 064B 065F 0670 0670 06D6 06DC 06DF 06E4"
  r = r "06E7 06E8 06EA 06ED"           -- Hebrew and Arabic
  r = r "0900 0902 093A 093A 093C 093C 0941 0948 094D 094D"
  r = r "0951 0957 0962 0963"           -- Devanagari
  r = r "200B 200F"                     -- zero-width space, joiners, marks
  r = r "20D0 20F0"                     -- combining marks for symbols
  r = r "FE00 FE0F"                     -- variation selectors

  Return r

--------------------------------------------------------------------------------
-- Code points that take two cells in a monospaced face.                      --
--------------------------------------------------------------------------------

::Routine WideRanges

  r =   "1100 115F"                     -- Hangul Jamo
  r = r "2E80 303E 3041 33FF"           -- CJK radicals, kana, punctuation
  r = r "3400 4DBF"                     -- CJK extension A
  r = r "4E00 9FFF"                     -- CJK unified ideographs
  r = r "A000 A4CF"                     -- Yi
  r = r "AC00 D7A3"                     -- Hangul syllables
  r = r "F900 FAFF"                     -- CJK compatibility
  r = r "FE30 FE6F FF00 FF60 FFE0 FFE6" -- fullwidth forms
  r = r "1F300 1F9FF"                   -- emoji
  r = r "20000 3FFFD"                   -- CJK extensions B and beyond

  Return r

--------------------------------------------------------------------------------
-- The text a reader sees, stripped of everything written to produce it.      --
--------------------------------------------------------------------------------

::Routine PlainText
  Use Strict Arg line

  -- First the markup the highlighter wrapped around the text.
  plain = ""
  Loop While line~pos("<") > 0
    Parse Var line before "<" . ">" line
    plain = plain || before
  End
  plain = plain || line

  -- Then the entities. An entity is ONE character on screen however many it
  -- takes to spell, and Pandoc writes &#39; for every apostrophe -- so a line
  -- of Python with a dozen quoted keys measured half as long again as it was,
  -- and every such block was fitted far smaller than it needed to be. Masked
  -- until now because the sample lines were short enough to hit the ceiling.
  out = ""
  Loop While plain~pos("&") > 0
    Parse Var plain before "&" rest
    p = rest~pos(";")
    -- A bare ampersand in prose is not an entity. Entities are short, so a
    -- distant semicolon means the & stands for itself.
    If p = 0 | p > 10 Then Do
      out   = out || before"&"
      plain = rest
      Iterate
    End
    out   = out || before"x"
    plain = SubStr(rest, p + 1)
  End

  Return out || plain

--------------------------------------------------------------------------------
-- The identity declares the advance of its monospaced face.                  --
--------------------------------------------------------------------------------

::Routine MinCodeSize
  Use Strict Arg css

  If css~pos("--theme-min-code-size:") = 0 Then Return 14
  Parse Var css . "--theme-min-code-size:" value "px" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- The identity declares the advance of its monospaced face.                  --
--------------------------------------------------------------------------------

::Routine MaxCodeSize
  Use Strict Arg css

  If css~pos("--theme-max-code-size:") = 0 Then Return 20
  Parse Var css . "--theme-max-code-size:" value "px" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- The identity declares the advance of its monospaced face.                  --
--------------------------------------------------------------------------------

::Routine MonoAdvance
  Use Strict Arg css

  If css~pos("--theme-mono-advance:") = 0 Then Return 0.6
  Parse Var css . "--theme-mono-advance:" value ";" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- PandocStyle: the identity's preferred Pandoc highlighting theme, or        --
-- "pygments" if it declares none. A dark identity names a dark theme here so  --
-- its token colours sit well on its own --theme-othercode-bg.                 --
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
-- chooser switches between them by rewriting the highlight-rexx-<style>       --
-- class. The themes are the project's own flattened/rexx-*.css -- read from    --
-- there, never copied -- so md2slides and md2pdf share one set. (A "thin" deck  --
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
-- Minify: read a CSS file and drop the lines that carry no style -- blank     --
-- lines and whole-line comments -- then collapse the survivors' runs of       --
-- whitespace to single spaces with space(). These sheets are mostly licence   --
-- headers, section banners and deep indentation; with 25 of them embedded in  --
-- every deck that is a lot of dead weight. A line goes if, once stripped, it  --
-- is empty, or it is a comment that both opens and closes on that line        --
-- (/* ... */) with nothing after the close -- the inner-"*/" guard keeps a    --
-- line like "/* a */ real { }" intact. CSS ignores insignificant whitespace,  --
-- so collapsing it is safe here.                                              --
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
/* to the runtime, which is the only place where {page} exists -- numbering    */
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

  -- The logo belongs to the BRAND, not to the presentation: a deck is not less
  -- a WU deck for being shown with dark code, or under a different master. The
  -- file has a fixed name, logo.txt, inside the brand folder, so an institution
  -- can find it without knowing our conventions. Search order: first next to
  -- the deck (a brand travelling with its deck as <brand>.logo, kept for that
  -- case), then the brand folder assets/<brand>/logo.txt, then the default.
  logo     = ""
  localLogo = deckDir || brand".logo"
  brandLogo = home"/assets/"brand"/logo.txt"
  defLogo   = home"/assets/default/logo.txt"
  If      SysIsFile(localLogo) Then logo = ReadFile(localLogo)
  Else If SysIsFile(brandLogo) Then logo = ReadFile(brandLogo)
  Else If SysIsFile(defLogo)   Then logo = ReadFile(defLogo)
  logo = Squeeze(Strip(logo))

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

  html = html~caselessChangeStr("%title%",   title)
  html = html~caselessChangeStr("%runtimeCSS%", ReadFile(home"/css/runtime.css"))
  html = html~caselessChangeStr("%identityCSS%",      identityCSS)
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
  html = html~caselessChangeStr("%logo%",       logo)

  Return html

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
-- The master that stands when no -mp is given: the theme's own default        --
-- presentation. A brand keeps it in assets/<brand>/master.css; a brand that   --
-- ships none borrows assets/default/. A file-world theme has no brand folder  --
-- to hold a default master, so it stands on the default brand's master.       --
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
-- File world: a relative .css cascades self (next to the deck) > cwd >        --
-- assets/default/; an absolute path is taken as given, with no cascade. The   --
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

::Requires "BaseClassesAndRoutines.cls"
::Requires "ErrorHandler.cls"
::Requires "CLISupport.cls"
::Requires "FencedCode.cls"
::Requires "YAMLFrontMatter.cls"
::Requires "RexxPubOptions.cls"
