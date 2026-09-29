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
/* 20260815    0.6  First prototype                                           */
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
/* STRUCTURE and never names a font, a colour or a logo. The SKIN (-t)        */
/* brings the brand -- fonts, palette, footer strings, in :root variables;    */
/* the MASTER(s) (-mp) bring the presentation -- the rules that read those    */
/* variables. Adding an institution is a skin; adding a kind of presentation  */
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

  Address COMMAND "pandoc -v" With Output Stem pandocV. Error Stem Discard.
  If RC <> 0 Then
    Call Error myName "needs a working version of pandoc. Aborting..."

  ------------------------------------------------------------------------------
  -- Command line                                                             --
  ------------------------------------------------------------------------------

  skin        = DefaultSkinName()     -- The skin sheet (the -s axis): a FILE,
  skinFromCLI = 0                    -- ...unless -s/--skin says otherwise.
  masters      = .Array~new          -- Presentation masters to layer, in order
                                     -- (the -mp axis). Empty means "the default
                                     -- master sheet", resolved like any other.
                                     -- Multi-valued: the flag order IS the
                                     -- cascade order.
  mastersFromCLI = 0                 -- ...true once -mp names at least one.
  imgDirs      = .Array~new          -- Extra picture folders for the DECK (the
                                     -- --img axis), searched in the order given
                                     -- after the deck's own img/. Repeatable.
                                     -- Decks only: a skin or master keeps its
                                     -- own img/ beside itself.
  imgFromCLI   = 0                   -- ...true once --img names at least one.
  pictureSize  = ""                  -- --picture-size: the longest side a
                                     -- picture may keep (see PictureSize).
                                     -- "" = not given; the front matter or
                                     -- the default decides.
  home      = rootDir"/bin/md2slides" -- md2slides home: the PRODUCT's own parts
                                      -- (templates/deck.template, the five
                                      -- css/, js/runtime.js) live here and
                                      -- nowhere else. Anchored to the .rex
                                      -- location, not the CWD, so md2slides
                                      -- runs from any directory. NOT an option:
                                      -- a program's own machinery is not a
                                      -- thing the caller gets to relocate.
  csl       = "rexxpub"               -- Citation Style Language style. A bare
                                      -- name resolves to csl/<name>.csl in the
                                      -- project; a path is used as-is. Citeproc
                                      -- is activated by the deck declaring a
                                      -- bibliography:, not by this option;
                                      -- --csl only chooses WHICH style.
  hlStyle   = ""                      -- Pandoc highlighting style for non-Rexx
                                      -- code. Precedence: --pandoc-highlight
                                      -- flag > skin's own --skin-pandoc-style
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
      When "-s", "--skin" Then Do
        i = i + 1
        skin = myArgs[i]
        skinFromCLI = 1
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
      When "--img" Then Do
        -- Repeatable, one folder per occurrence, searched in the order given
        -- AFTER the deck's own img/. It adds to the pool, it does not replace
        -- it: a deck normally has pictures of its own AND wants a shared one,
        -- and a flag that swapped the folder would force the author's own
        -- pictures out of their deck to get at the shared one.
        i = i + 1
        imgDirs~append(myArgs[i])
        imgFromCLI = 1
      End
      When "--picture-size" Then Do
        -- The longest side, in pixels, a picture keeps in the deck; "no"
        -- embeds every picture as it is. Beats picture-size: in the front
        -- matter, like every flag here.
        i = i + 1
        pictureSize = myArgs[i]
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

  -- The target defaults to the source with its extension swapped for .html,
  -- and the deck's fallback title is that same bare name (see Assemble).
  deckName = DeckName(sourceFile)
  If args~items > 1 Then target = args[2]
  Else target = deckName".html"

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

  -- The file as written, kept for warnings: every later stage rewrites the
  -- source, and a warning is only useful if it can say WHERE.
  original = source~copy

  -- A deck is UTF-8, and only UTF-8: the page says so (<meta charset>), Pandoc
  -- reads it so, and there is no other encoding a slide could be in that both
  -- would agree on. A line that is not UTF-8 is reported, with the character
  -- it most likely was, instead of coming out as a '?' in a box on the slide.
  Call CheckEncoding original

  yaml = CheckedYAMLFrontMatter(source, sourceFile)
  If yaml == "" Then Exit 1             -- Invalid YAML, already reported
  If yaml == .Nil Then Do
    at = MisplacedFrontMatter(source)
    If at > 0 Then
      Call Warn "line" at "starts a 'rexxpub:' front matter block, but front" -
        "matter is read only when its '---' is the very first line of the" -
        "file. This one is ignored -- skin, footer, animation and all. Move" -
        "anything above it (a comment, a blank line) to after it."
    Else Do
      Parse Value BrokenFrontMatter(source) With at what
      If at > 0 Then
        Call Warn "line" at "is '"what"', and a 'rexxpub:' block follows it," -
          "but front matter opens and closes with exactly three dashes, '---'." -
          "As it is, the whole block is ignored -- skin fields, footer, timer," -
          "animation and all. Write '---' on that line."
    End
  End
  Else Do
    Loop dup Over DuplicateKeys(source)
      Parse Var dup at first key
      Call Warn "line" at "sets '"key":' again (it is already set at line" -
        first", in the same block). The front matter keeps the last value, so" -
        "the one at line" first "is lost. If line" at "was meant for another" -
        "key, give it that name; if not, remove one of the two."
    End
  End
  opts = ParseRexxPubYAML(yaml)

  -- ParseRexxPubYAML returns a StringTable, and a StringTable is NOT a
  -- Directory: they are siblings under MapCollection. Guarding these reads
  -- with isA(.Directory), as this file did until v83, made every one of them
  -- dead code -- the YAML was parsed correctly and then thrown away. Two of
  -- the three failures were invisible (the default style happened to equal
  -- what the sample deck asked for, and --ci supplies the identity anyway),
  -- which is exactly why it survived a release: only the <title> showed it.
  defaultSkin = "tokio-day"
  If opts~isA(.StringTable), opts["style"] \== .Nil Then defaultSkin = opts["style"]

  -- The identity, the title and the footer fields are deck-only notions, and
  -- ParseRexxPubYAML copies from a whitelist by design: it is shared with
  -- md2html, md2pdf and the CGI, none of which has an identity or a slide
  -- footer. So they are read from the rexxpub: block directly, and no shared
  -- file has to grow a slides-shaped hole to let them through.
  rexxpub = RexxPubBlock(yaml)

  -- Precedence, per axis: an explicit flag beats the document, which beats the
  -- default. The other way round would defeat the very use the two axes exist
  -- for -- building one deck under three skins, or three masters -- by
  -- silently ignoring the flag whenever the front matter happened to name one.
  -- The axes are independent: a deck may pin its skin on the command line and
  -- still take its masters from the front matter, or the reverse.
  If \skinFromCLI, rexxpub~hasIndex("skin") Then skin = rexxpub["skin"]

  -- master-pages: in the front matter names the masters, in the flag's order:
  -- the first named is applied first in the cascade. One sheet is a plain
  -- value; several are a YAML list, in block or flow style:
  --   master-pages: base.css
  --   master-pages: [base.css, accent.css]
  --   master-pages:
  --     - base.css
  --     - my accent.css          <- a name may have blanks in it
  -- A plain value is ONE name, blanks and all: "base.css accent.css" is a
  -- single file with a blank in its name, not two (the one-line form of the
  -- old front-matter reader, which had no lists, is gone -- v214).
  If \mastersFromCLI, rexxpub~hasIndex("master-pages") Then Do
    names = FrontMatterNames(rexxpub["master-pages"], "master-pages")
    If names == .Nil Then Exit 1                -- reported
    Loop m Over names
      masters~append(m)
    End
  End

  -- img: in the front matter is the twin of --img, and takes the same forms as
  -- master-pages:. Without it the flag alone would decide where a deck's
  -- pictures come from, and deck.md would no longer rebuild the same deck --
  -- the one thing the front matter exists to prevent.
  If \imgFromCLI, rexxpub~hasIndex("img") Then Do
    names = FrontMatterNames(rexxpub["img"], "img")
    If names == .Nil Then Exit 1                -- reported
    Loop d Over names
      imgDirs~append(d)
    End
  End

  -- Pictures bigger than a slide can show are reduced on the way in (see
  -- ShrinkPicture): the flag beats picture-size: in the front matter, which
  -- beats the default. The reduced copies are kept beside the deck, so only
  -- the first build pays for them.
  If pictureSize == "", rexxpub~hasIndex("picture-size") Then
    pictureSize = rexxpub["picture-size"]
  .local["MD2SLIDES.PICTUREMAX"]   = PictureSize(pictureSize)
  .local["MD2SLIDES.PICTURECACHE"] = FileSpec("Location", -
    .File~new(sourceFile)~absolutePath)".md2slides-cache"

  ------------------------------------------------------------------------------
  -- Rexx fenced code blocks go through the Highlighter, exactly as in the    --
  -- other pipelines. This is why a ~~~rexx block in a deck is marked up by   --
  -- the real parser and not by an imitation of one.                          --
  ------------------------------------------------------------------------------

  defaultOptions. = 0
  defaultOptions.default = ""
  defaultOptions.["CONTINUE"] = 1

  -- A key=value the highlighter does not know (`level=2` on a mention) stops
  -- it with a Rexx traceback. Such options are taken off here, and reported.
  source = StripForeignOptions(source)
  source = FencedCode( sourceFile, source, defaultSkin, defaultOptions. )
  source = BlankBeforeListings(source)

  -- Slide markers -> raw <hr class="slide">. A marker-opened deck opens each
  -- slide with a `--- {.slide}` line instead of an <h1>, and FoldIntoSlides
  -- folds on that. But Pandoc does NOT read `--- {.slide}` as a
  -- thematic break: a `---` with a trailing attribute is plain text to Pandoc,
  -- so the marker would survive verbatim into the body. We rewrite it to a raw
  -- HTML `<hr class="slide">` block BEFORE Pandoc, which Pandoc passes through
  -- untouched, giving the fold an unambiguous, content-safe boundary (a bare
  -- `<hr>` an author drew inside a slide has no class and is never mistaken for
  -- a break). A deck that still folds by <h1> simply has no such lines, so this
  -- is a no-op there.
  -- ':::' blocks are balanced per slide BEFORE Pandoc sees them. A block left
  -- open is closed at the end of its slide, and a ':::' that closes nothing is
  -- dropped. Without this, what an unbalanced deck looks like depends on the
  -- Pandoc version: 3.1 shows the fence as text, 3.9 closes it silently at the
  -- END OF THE FILE -- swallowing every later slide into the block -- and says
  -- so only on its stderr, which we do not show. Rony (3.9) got no warning at
  -- all for a deck that warned here (3.1). The warnings are read from the file
  -- as written, so they carry its line numbers; the fix-up is applied to the
  -- rewritten source, which is what Pandoc is given.
  Call WarnFenceBalance original
  Call WarnSpanBrackets original
  source = BalanceFences(source)
  source = CardLines(source)
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

  Address COMMAND 'pandoc' PandocOptions()citeOpts -
    With Input Using (source) Output Using (contents) Error Stem Discard.

  flat = contents~makeString("L", "0a"x)

  -- Translate author sugar to custom properties. Pandoc turns `::: {.contents
  -- scale=0.83}` into <div class="contents" data-scale="0.83">; here we rewrite
  -- the sugar attributes (data-scale, ...) into style="--contents-scale: 0.83".
  -- The author never types a CSS custom property; the generator does. Adding a
  -- new piece of sugar is one line in SugarMap, not a new code path -- so the
  -- next convenience we invent costs a table row, not a parser branch.
  Call CheckIndents flat
  -- Timing words have short forms (.afterPrev, .withPrev) and any case; they
  -- are spelled out here, once, so nothing downstream knows about them. A
  -- near miss (.afterPrevios) is reported: unknown, it would do nothing.
  flat = TimingAliases(flat)
  flat = TranslateSugar(flat)
  flat = TranslateLevel(flat)
  flat = TranslateFlow(flat)
  flat = TranslateOffset(flat)
  -- caption= on a code block, and the caption of a picture: as in the article
  -- pipelines (numberFigures.js), but done here, at build (v214).
  flat = Captions(flat, opts)

  -- Key caps inside a transcript. Only blocks that asked for it (.keys) are
  -- touched: an output block is a claim that the program printed exactly this,
  -- and rewriting one from underneath the author would weaken the claim
  -- everywhere to serve the few blocks that are a keyboard session.
  flat = MarkKeys(flat)

  -- Visible blanks in an output block. A Rexx listing gets these from the
  -- highlighter, which knows which blanks the program can see (blanks= in
  -- FencedCode); an output block never goes through it, and does not need it:
  -- everything a program printed is data, so in here every blank is marked.
  flat = MarkBlanks(flat)

  -- Make the deck truly self-contained for pictures. Pandoc leaves content
  -- images as <img src="img/<file>"> (relative refs into the deck's own img/
  -- folder). We inline each as a base64 data URI so the
  -- single .html carries its pictures with it - no img/ folder needed beside
  -- it. Only img/-relative sources are touched: the skin/runtime data URIs
  -- (logo SVGs, already embedded) and any absolute or http(s) src are left
  -- alone. deckDir is where the .md - and thus img/ - lives.
  --
  -- THE CONTRACT, in two sentences:
  --
  --   img/ is always relative to the FILE THAT NAMES IT.
  --   img/ means "embed me"; anything else means "leave me alone".
  --
  -- The deck's markdown resolves img/ against the deck's directory; a master
  -- resolves its own url(img/...) against the master's directory (see
  -- ReadSheet below). No namespace, no prefixes, no priorities -- two files in
  -- two folders may both name img/rexx.svg and mean different pictures. It is
  -- how url() works in real CSS, so it surprises nobody.
  -- The extra picture folders (--img / img:), resolved the way a sheet's path
  -- is: relative means beside the deck first and then the current directory,
  -- absolute means exactly there. A folder that is not there is an error and
  -- not a shrug -- the author named it, and the alternative is a deck built
  -- without the pictures they asked for.
  imgPool = .Array~new
  Loop d Over imgDirs
    resolved = ResolveImgDir(d, deckDir)
    If resolved == "" Then
      Call Error "No picture folder '"d"' (named on --img / img:)." -
                 WhereLooked(d, deckDir)
    imgPool~append(resolved)
  End

  flat = EmbedImages(flat, deckDir, imgPool)

  -- An <img> that is still a relative reference after that is a picture the
  -- built deck will go looking for beside the .html and not find. Say so.
  Call WarnLooseImages flat
  discard = WarnStrayFences(flat, original)
  discard = WarnIndentedAfterFence(original)
  discard = WarnFenceAfterMarker(original)
  discard = WarnFenceWords(original)
  discard = WarnHtmlSlips(original)

  ------------------------------------------------------------------------------
  -- Fold, assemble, write                                                    --
  ------------------------------------------------------------------------------

  -- The two identity axes are resolved here into one thing: an ordered list of
  -- CSS sheets. The skin comes first (it carries the :root variables every
  -- master reads through var()), then the masters in the order they were named,
  -- because that order IS the cascade. The whole list is concatenated inline
  -- into a single self-contained document -- never <link>s, never @import.
  --
  -- A sheet is a FILE, named by path. There is no brand vocabulary and no
  -- shelf to search: md2slides ships no skins and no masters, so there is
  -- nothing for a bare name to mean (see ResolveSheet).
  skinSheet = ResolveSheet(skin, deckDir)
  If skinSheet == "" Then
    Call Error "No skin sheet '"skin"'." WhereLooked(skin, deckDir)

  -- Masters. Named on -mp they are resolved independently and layered in the
  -- order given, because that order IS the cascade. Named nowhere, the default
  -- master sheet stands -- and unlike the skin, its absence is not fatal: a
  -- deck may legitimately be all skin and no master.
  masterSheets = .Array~new
  If masters~items = 0 Then Do
    stand = ResolveSheet(DefaultMasterName(), deckDir)
    If stand \== "" Then masterSheets~append(stand)
  End
  Else Do
    Loop mp Over masters
      one = ResolveSheet(mp, deckDir)
      If one == "" Then
        Call Error "No master sheet '"mp"' (named on -mp / master-pages)." -
                   WhereLooked(mp, deckDir)
      masterSheets~append(one)
    End
  End

  -- Metrics and footer contract live in the SKIN: it owns :root. Masters carry
  -- rules only. The footer band height is layout geometry (fitHeight reserves
  -- it); the old advance/floor/ceiling were the code-fitter's, and the fitter is
  -- gone -- code size is a fixed value the skin declares (--skin-code-size),
  -- not something computed to fill a box.
  skinCSS = ReadSheet(skinSheet, "skin")
  band     = FooterHeight(skinCSS)

  -- The effective sheet: skin first, then masters in cascade order, joined by
  -- newlines so the emitted <style> stays readable. This is the string the
  -- template receives; there is exactly one of it.
  identityCSS = skinCSS
  Loop ms Over masterSheets
    identityCSS = identityCSS || "0a"x || ReadSheet(ms, "master")
  End

  -- Pandoc highlighting style, resolved now that the skin is loaded.
  -- Precedence: an explicit --pandoc-highlight flag wins; else the skin's own
  -- --skin-pandoc-style (a dark skin can ask for a dark style so its token
  -- colours match its --skin-othercode-bg); else "pygments". This keeps the
  -- two grounds -- panel (skin) and token colours (style) -- from
  -- contradicting each other, because the skin owns both.
  If hlStyle == "" Then hlStyle = PandocStyle(skinCSS)
  hlSheet = rootDir"/css/pandoc/"hlStyle".css"
  If \SysIsFile(hlSheet) Then
    Call Error "Pandoc highlighting style '"hlStyle"' not found (looked for '"hlSheet"')."

  -- The skin asks for fields; the document supplies them. Checking one against
  -- the other is the whole of footer validation, and it is checked in this
  -- direction on purpose: whitelisting field NAMES would freeze the vocabulary,
  -- and a deck is entitled to invent a "course" or a "semester".
  fields = FooterFields(rexxpub, SlideSkinTag(skinSheet))
  -- A field written with no value (`address-2:`) is declared, and empty: the
  -- YAML reader leaves such keys out, so they are found in the file itself.
  Call EmptyFields fields, original, SlideSkinTag(skinSheet)
  -- Add the fields the build knows on its own: today and now, and the source
  -- file's own date/time and name (file-date, file-time, file-name,
  -- file-name-full, file-path). An author-declared field of the same name
  -- wins (AutoFields never overwrites), so a deck can pin file-date by hand.
  Call AutoFields fields, sourceFile
  -- Resolve the six margin-box templates (header/footer x left/center/right)
  -- once: the skin's --skin-{header,footer}-{left,center,right} default,
  -- overridden by the front-matter header:/footer: blocks. They ride in `fields`
  -- under reserved __box-* keys so the single `fields` argument that already
  -- reaches SlideIdentity carries them too -- no new argument threaded through
  -- FoldIntoSlides/RenderSlide. A per-slide :::header-left zone still wins over
  -- these, resolved in SlideIdentity.
  Call ResolveBoxes fields, skinCSS, rexxpub
  Call CheckFooter skinCSS, fields

  stage = FoldIntoSlides(flat, band, fields)

  -- Give bare fragments the deck's default effect (front-matter anim: element:
  -- effect:). Done once on the whole stage, where rexxpub is in scope, so
  -- TransformBody and its callers stay unchanged. A fragment that names its own
  -- anim keeps it; only the unmarked ones -- every `::: incremental` item --
  -- take the deck default. No-op when the deck declares no default effect.
  stage = HoistContainerTiming(stage)
  stage = ApplyAppear(stage)
  stage = ApplyDefaultAnim(stage, DeckDefaultAnim(rexxpub))
  stage = ApplyDefaultPageAnim(stage, DeckDefaultPageAnim(rexxpub))

  -- No <h1> in the flat HTML means no slide ever opened: the input was empty,
  -- was not markdown, or carried no headings (and no `--- {.slide}` markers).
  -- Writing a 200KB runtime-only deck in that case hides the mistake; say it.
  If stage~countStr("<section") = 0 Then
    Call Error "No slides produced from '"sourceFile"'. The input opened no" -
               "slides -- is it Markdown with level-1 headings or" -
               "`--- {.slide}` markers? Aborting..."

  rexxSkins  = RexxSkins(rootDir)
  rexxStyleData = RexxStyleData(rootDir, defaultSkin)

  -- rexxpub: listings: / figures: -- the same options, and the same CSS, as
  -- md2html and md2pdf (RexxPubOptions.cls).
  captionCSS = BuildCaptionOverrides(opts)["overrideCSS"]
  html = Assemble(stage, identityCSS, home, defaultSkin, rexxpub, fields, hlSheet, deckDir, rexxSkins, rexxStyleData, deckName, captionCSS)

  -- Every picture is in by now (deck, skin and masters). Embedding used to be
  -- expensive to DO -- you had to base64 a file by hand -- and that pain was
  -- the only thing keeping deck sizes down. With a directory it is a drag and
  -- drop, so the brake has to be put back explicitly.
  Call CheckImageBudget
  Call ReportPictureSizes

  -- Last, so every warning of the build is in: the ones above included.
  html = html~caselessChangeStr("%buildWarnings%", BuildWarningsJSON())

  -- The about page (key a, or from F1): what this deck is and how it was made.
  -- Only what the deck lets out is written into the file -- a group turned
  -- off in about: is not hidden, it is absent.
  about = .StringTable~new
  about["source"]  = sourceFile
  about["target"]  = target
  about["args"]    = myArgs
  about["skin"]    = skinSheet
  about["masters"] = masterSheets
  about["pandoc"]  = pandocV.1
  about["root"]    = rootDir
  about["seconds"] = Format(Time("E"), , 1)
  html = html~caselessChangeStr("%about%", AboutJSON(rexxpub, about))
  html = html~caselessChangeStr("%timer%", TimerJSON(rexxpub, stage))

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
  Say "-s, --skin path   Skin sheet: colours, fonts and metrics (:root). A"
  Say "                  relative path is looked for beside the deck, then in"
  Say "                  the current directory; an absolute one is used as"
  Say "                  given. Omitted: skin-default.css, found the same way."
  Say "-mp, --master-pages path"
  Say "                  Master sheet: geometry and chrome. Repeatable;"
  Say "                  occurrences stack in cascade order, so '-mp base.css"
  Say "                  -mp accent.css' applies base first. Resolved like"
  Say "                  --skin. Omitted: master-default.css, if it is there."
  Say "--img path        Another folder of pictures for this deck. Repeatable;"
  Say "                  the deck's own img/ is searched first, then these in"
  Say "                  the order named, and the first hit wins. Resolved like"
  Say "                  --skin. Decks only: a skin or master keeps its own"
  Say "                  img/ beside itself."
  Say "--picture-size n|no"
  Say "                  The longest side, in pixels, a picture keeps (default"
  Say "                  1920, what a slide shows full screen on a 1080p"
  Say "                  screen). Bigger ones are reduced with ImageMagick, if"
  Say "                  it is installed; 'no' embeds every picture as it is."
  Say "                  Same as picture-size: in the front matter."
  Say "--csl name|path   Citation style (default: rexxpub). A bare name resolves"
  Say "                  to csl/<name>.csl in the project; a path is used as-is."
  Say "                  Citations turn on when the deck declares a bibliography:"
  Say "                  in its front matter -- it cites with [@key] and gathers"
  Say "                  them wherever it puts a ::: {#refs} ::: block. This flag"
  Say "                  only chooses the style; it does not switch citations on."
  Say "--pandoc-highlight name"
  Say "                  Pandoc style for non-Rexx code. Overrides the skin's"
  Say "                  own --skin-pandoc-style. If neither is set: pygments."
  Say "                  Any style in the project's css/pandoc/ (pygments,"
  Say "                  breezeDark, kate, tango, zenburn, ...)."
  Say "-h, --help        Display this help"
  Say ""
  Say "An h1 starts a slide. Roles, animations and timings are Pandoc"
  Say "attributes on that h1:"
  Say ""
  Say "  # Lists {#lists kicker=""Sequences""}"
  Say "  # The Rexx angle {.section}"
  Say "  # Lists vs. Tuples {anim=slide}"
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

  -- Two folding regimes. A MARKER-opened deck opens each slide with a
  -- `<hr class="slide">` marker and carries no heading (its title, if any, is a
  -- :::title zone); a CLASSIC deck opens each slide with an <h1> that is both
  -- the boundary and the title. We pick by presence of the marker, so an
  -- existing <h1>-authored deck folds byte-for-byte as before.
  If flat~pos('<hr class="slide"') > 0 Then Do
    Call WarnBeforeFirstSlide flat~left(flat~pos('<hr class="slide"') - 1)
    -- The two regimes do not mix, and mixing them used to be silent: a
    -- `# Heading` in a marker-opened deck opens no slide. It lands as an <h1>
    -- inside the slide above it, attributes and all, and the build succeeds.
    If flat~pos("<h1") > 0 Then
      Call Warn "this deck opens its slides with '--- {.slide}', so a" -
        "'# heading' in it does not open a slide: it is shown inside the" -
        "slide before it. Open that slide with '--- {.slide ...}' and give" -
        "it a '::: title' zone instead."
    Return FoldByMarker(flat, band, fields)
  End

  out = ""
  Parse Var flat before "<h1" rest         -- Discard anything before slide 1
  If rest \== "" Then Call WarnBeforeFirstSlide before

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
-- FoldByMarker - the marker regime. Each slide is the run of HTML between one--
-- `<hr class="slide">` and the next. No <h1>: a marker-opened slide carries  --
-- no heading, so its title (if any) is a `:::title` zone the author places in--
-- the body, surfaced by RenderMarkerSlide. The <section> keeps the master's  --
-- structural chrome (footer band, slide/id classes) so the runtime is happy. --
--------------------------------------------------------------------------------

::Routine FoldByMarker
  Use Strict Arg flat, band, fields

  out  = ""
  used = .Set~new
  n    = 0
  -- Discard anything before the first marker (front matter, stray whitespace).
  Parse Var flat . '<hr class="slide"' rest

  Loop While rest \== ""
    -- The text between here and ">" is this marker's own attribute run; the body
    -- runs to the next marker. Pandoc emits the raw block as `<hr class="slide"
    -- ... />` (self-closing); ">" ends the tag whichever attributes it carries.
    Parse Var rest hrAttrs ">" body
    Parse Var body body '<hr class="slide"' rest

    -- A per-slide master selector (`--- {.slide .master}`) rides as data-master
    -- on the marker; lift it onto the slide's class.
    masterClass = SlideMasterClass(hrAttrs)
    n  = n + 1
    id = MarkerSlideId(AttrValue(hrAttrs, "id"), body, n, used)
    out = out || RenderMarkerSlide(body, band, fields, masterClass, id, -
                                   MarkerDataAttrs(hrAttrs))
  End

  Return out

--------------------------------------------------------------------------------
-- WarnBeforeFirstSlide - what comes before the first slide is not shown.     --
--                                                                            --
-- Both folds start at the first slide opener and drop whatever came before   --
-- it. That is right for what is invisible there (whitespace, an HTML         --
-- comment), but anything else is something the author meant to see, and it  --
-- went without a word. It hid two of Rony's mistakes: a front matter opened  --
-- with `--` and one behind a UTF-8 BOM both became plain text above slide 1, --
-- and the deck built as if there were no front matter at all.                --
--                                                                            --
-- A deck with no opener at all is not this routine's business: the build    --
-- stops on it later ("No slides produced").                                  --
--------------------------------------------------------------------------------

::Routine WarnBeforeFirstSlide Public
  Use Strict Arg before

  -- HTML comments are the author's own notes: invisible, and meant to be.
  rest = before
  Loop While rest~pos("<!--") > 0
    Parse Var rest head "<!--" . "-->" tail
    rest = head tail
  End
  If Squeeze(rest) == "" Then Return

  -- Quote the start of what is lost, so the author can find it. Something
  -- with no text is named for what it is: a picture by its file, anything
  -- else by its tag.
  text = Squeeze(HtmlUnescape(StripTags(rest)))
  Select
    When text \== "" Then Do
      If text~length > 60 Then text = text~left(57)"..."
      what = '"'text'"'
    End
    When rest~pos("<img") > 0 Then Do
      Parse Var rest "<img" img ">" .
      -- An img/ picture is already embedded by now: its src is the data.
      src = AttrValue(img, "src")
      If src~startsWith("data:") | src == "" Then what = "a picture"
      Else what = "a picture ("src")"
    End
    Otherwise
      Parse Value Squeeze(rest) With "<" tag ">" .
      what = "an element (<"Word(tag, 1)~strip("T", "/")">)"
  End

  Call Warn "there is something before the first slide, and it is not" -
    "shown:" what". If it was meant as front matter, it must start with" -
    "'---' on line 1; if it was meant for the deck, open a slide above it."
  Return

--------------------------------------------------------------------------------
-- SlideMasterClass - pull the per-slide master selector (data-master) out of --
-- an <hr>'s raw attribute run and return it as a class run to append to the  --
-- <section>'s class (" master", or "" when the marker named none). This is   --
-- the author's `--- {.slide .master}` come home: SlideMarkers parked the     --
-- class on the <hr> as data-master to keep the fold's literal split intact;  --
-- here it becomes a real CSS class on the slide, where the master's          --
-- `.slide.master` rules can shape this one molde. Multiple classes are kept  --
-- space-separated, verbatim.                                                 --
--------------------------------------------------------------------------------

::Routine SlideMasterClass
  Use Strict Arg raw

  m = AttrValue(raw, "data-master")
  If m == "" Then Return ""
  Return " "Strip(m)

--------------------------------------------------------------------------------
-- WarnStrayFences - a ':::' line that Pandoc did not read as a block.        --
--                                                                            --
-- A fence Pandoc does not understand is not an error to Pandoc: the line,    --
-- and everything up to the next blank line, becomes an ordinary paragraph    --
-- that starts with ':::'. The commonest cause is a name followed by          --
-- attributes, `::: incremental {anim=fade}`, where Pandoc wants the name     --
-- inside the braces: `::: {.incremental anim=fade}`. The deck then shows the --
-- colons on screen, and nothing in it is revealed, with no word at build     --
-- time.                                                                      --
--------------------------------------------------------------------------------

::Routine WarnStrayFences Public
  Use Strict Arg html, original = (.Array~new)

  n    = 0
  rest = html
  done = 0                                   -- chars of html consumed so far
  -- Openers the fence ledger has already explained (WarnFenceBalance: which
  -- bracket, which attribute) are not reported again here in general terms.
  -- Rony saw the specific warning followed by this generic one, which named
  -- every cause but the real one.
  known = .Set~new
  If original~items > 0 Then
    Loop bk Over FenceLedger(original)~broken
      known~put(bk~line)
    End
  Loop While rest~pos("<p>:::") > 0
    at = rest~pos("<p>")
    Parse Var rest "<p>" line "</p>" after
    done = done + (rest~length - after~length)
    rest = after
    If line~left(3) \== ":::" Then Iterate
    Parse Value Squeeze(line) With first second .
    -- Where: the slide is counted in the HTML (openers before this point),
    -- and the line is found in the file as written, inside that slide.
    -- Looked for by its first TWO words first: a slide has several lines
    -- that start with ':::', and `::: incremental` left open on line 333
    -- was reported at the `::: title` of line 329 when only ':::' was
    -- matched. The one-word fallback is for a bare ':::' (the second word
    -- is then already the text that followed it, on the next line).
    slide = SlideNumberAt(html, done)
    where = 0
    If second \== "" Then where = StrayFenceLine(original, slide, first second)
    If where == 0 Then where = StrayFenceLine(original, slide, first)
    If where > 0, known~hasIndex(where) Then Iterate
    If where > 0 Then place = "line" where "(slide" slide"): "
    Else If slide > 0 Then place = "slide" slide": "
    Else place = ""
    Call Warn place"'"first"...' was not read as a ':::' block, so it is" -
      "shown as text. A name with attributes goes inside the braces:" -
      "'::: {.name attr=value}', not '::: name {attr=value}'; a bare" -
      "':::' closes a block, it cannot open one; a '{' or '[' left open on" -
      "the line keeps it from being a block; and a block that is opened" -
      "but never closed is shown as text from its opener on."
    n = n + 1
  End
  Return n

--------------------------------------------------------------------------------
-- CheckEncoding - warn about every line of the deck that is not clean UTF-8. --
--                                                                            --
-- Three things are reported, one warning per line:                          --
--                                                                            --
--   bytes that are not UTF-8  the file, or that line, was saved in another   --
--                             encoding -- on Windows, nearly always 1252,    --
--                             so the byte is named as the 1252 character it  --
--                             is there ('85'x is an ellipsis);               --
--   U+FFFD                    the replacement character: something already   --
--                             lost a character before md2slides saw it;      --
--   double encoding           an en dash read as 1252 and saved again as     --
--                             UTF-8 (C3A2 E282AC ...), or an o-umlaut        --
--                             (C383 C2B6).                                   --
--                                                                            --
-- md2slides does not repair any of them: it cannot know which reading was   --
-- meant, and a deck that silently changes its own characters is worse than  --
-- one that says where they went wrong.                                       --
--------------------------------------------------------------------------------

::Routine CheckEncoding Public
  Use Strict Arg lines

  bad = 0
  Loop i = 1 To lines~items
    line = lines[i]
    If line~verify(xRange("00"x, "7F"x)) == 0 Then Iterate   -- plain ASCII
    at = Utf8Invalid(line)
    If at > 0 Then Do
      b = line~substr(at, 1)
      -- (the byte abutted to the quote would read as a binary string: '...'b)
      Call Warn "line" i": byte '" || b~c2x || "'x (column" at") is not UTF-8." -
        "md2slides" -
        "reads a deck as UTF-8 only; this line, or the file, was saved in" -
        "another encoding -- in Windows-1252 that byte is" Cp1252Name(b)"." -
        "Save the deck as UTF-8 (in Notepad: Save As, Encoding: UTF-8) and" -
        "retype the character if it still looks wrong."
      bad = bad + 1
      Iterate
    End
    If line~pos("EFBFBD"x) > 0 Then Do
      Call Warn "line" i "holds the replacement character (U+FFFD, shown as" -
        "a question mark in a box): a character was lost before md2slides" -
        "read the file, when something opened it with the wrong encoding." -
        "Retype the character that belongs there."
      bad = bad + 1
      Iterate
    End
    seen = DoubleEncoded(line)
    If seen \== "" Then Do
      Call Warn "line" i "looks double-encoded: '"seen"' is what UTF-8 text" -
        "becomes when it is read as Windows-1252 and saved again (an en dash" -
        "turns into '"'C3A2E282ACE2809C'x"', an o-umlaut into" -
        "'"'C383C2B6'x"'). Retype those characters."
      bad = bad + 1
    End
  End
  Return bad

-- The column of the first byte that breaks UTF-8, or 0 if the line is valid.
::Routine Utf8Invalid Public
  Use Strict Arg s

  i = 1
  n = s~length
  Loop While i <= n
    c = s~substr(i, 1)~c2d
    Select
      When c < 128 Then Do; i = i + 1; Iterate; End
      When c >= 194 & c <= 223 Then need = 1
      When c >= 224 & c <= 239 Then need = 2
      When c >= 240 & c <= 244 Then need = 3
      Otherwise Return i                       -- 80-C1, F5-FF never lead
    End
    If i + need > n Then Return i
    Do k = 1 To need
      t = s~substr(i + k, 1)~c2d
      If t < 128 | t > 191 Then Return i
    End
    -- Overlong and surrogate forms are not UTF-8 either.
    t = s~substr(i + 1, 1)~c2d
    If c == 224, t < 160 Then Return i
    If c == 237, t > 159 Then Return i
    If c == 240, t < 144 Then Return i
    If c == 244, t > 143 Then Return i
    i = i + need + 1
  End
  Return 0

-- The first run that looks like UTF-8 read as 1252 and re-saved, or "".
-- C3A2 E282AC leads every double-encoded punctuation mark (dashes, quotes,
-- the ellipsis); C383 followed by a two-byte sequence leads every
-- double-encoded accented letter.
::Routine DoubleEncoded Public
  Use Strict Arg s

  p = s~pos("C3A2E282AC"x)
  If p > 0 Then Return s~substr(p, 5 + Utf8Len(s~substr(p + 5, 1)))
  p = s~pos("C383"x)
  If p > 0, p + 2 <= s~length Then Do
    next = s~substr(p + 2, 1)~c2d
    If next >= 194, next <= 197 Then Return s~substr(p, 4)
  End
  Return ""

::Routine Utf8Len
  Use Strict Arg b
  If b == "" Then Return 0
  c = b~c2d
  If c < 128 Then Return 1
  If c < 224 Then Return 2
  If c < 240 Then Return 3
  Return 4

-- How a byte reads in Windows-1252, for the message.
::Routine Cp1252Name Public
  Use Strict Arg b

  names. = ""
  names.["80"] = "a euro sign";             names.["85"] = "an ellipsis (...)"
  names.["91"] = "an opening single quote"; names.["92"] = "an apostrophe"
  names.["93"] = "an opening double quote"; names.["94"] = "a closing double quote"
  names.["95"] = "a bullet";                names.["96"] = "an en dash"
  names.["97"] = "an em dash";              names.["99"] = "a trademark sign"
  x = b~c2x
  If names.x \== "" Then Return names.x
  c = b~c2d
  If c >= 160 Then Return "'"x2c(UnicodeToUtf8(c))"'"   -- Latin-1 range
  Return "a control code"

-- UTF-8 bytes (as hex) for a code point below 800 hex.
::Routine UnicodeToUtf8
  Use Strict Arg cp
  If cp < 128 Then Return d2x(cp, 2)
  Return d2x(192 + cp % 64, 2) || d2x(128 + cp // 64, 2)

--------------------------------------------------------------------------------
-- FenceLedger - how the ':::' blocks of a deck open and close, slide by      --
-- slide.                                                                     --
--                                                                            --
-- A block belongs to the slide it is opened in: `--- {.slide}` ends every    --
-- block still open, whatever Pandoc would have made of it. Returns a         --
-- Directory:                                                                 --
--                                                                            --
--   unclosed  Array of Directories {line, slide, text}: an opener that       --
--             reached the end of its slide (or of the file) still open.      --
--   stray     Array of Directories {line, slide}: a bare ':::' with no open  --
--             block to close.                                                --
--   closeAt   Directory: line number of a slide marker (or lines~items + 1,  --
--             the end of the file) -> how many blocks are open there.        --
--                                                                            --
-- Lines inside a code fence (``` or ~~~, any length, indented or not) are    --
-- not looked at, so a ':::' printed in a listing is left alone. A fence is   --
-- CommonMark's: a run of three or more backticks or tildes, closed by a run  --
-- of the same character at least as long with nothing after it; a backtick   --
-- fence's info string cannot hold a backtick, which is what keeps an inline  --
-- raw span (``...``{=html}) from being taken for one.                        --
-- A ':::' line is Pandoc's: indented at most three blanks; three or more     --
-- colons alone close, three or more colons followed by anything open.        --
--------------------------------------------------------------------------------

::Routine FenceLedger Public
  Use Strict Arg lines

  unclosed = .Array~new
  stray    = .Array~new
  broken   = .Array~new                      -- openers Pandoc will not read
  odd      = .Array~new                      -- ...or reads, but not as meant
  closeAt  = .Directory~new
  open     = .Queue~new                      -- stack of {line, slide, text}
  slide    = 0
  fenceCh  = ""                              -- "`" or "~" while in code
  fenceLen = 0

  Loop i = 1 To lines~items + 1
    If i > lines~items Then line = "--- {.slide}"   -- the end closes, too
    Else line = lines[i]
    s = Strip(line)

    If fenceCh \== "" Then Do
      If s \== "", s~verify(fenceCh) == 0, s~length >= fenceLen Then fenceCh = ""
      Iterate
    End
    run = FenceRun(s)
    If run > 0 Then Do
      ch = s~left(1)
      info = s~substr(run + 1)
      If ch == "~" | \info~contains("`") Then Do
        fenceCh  = ch
        fenceLen = run
        Iterate
      End
    End

    If s~left(11) == "--- {.slide" | i > lines~items Then Do
      Loop While open~items > 0
        unclosed~append(open~pull)
      End
      closeAt[i] = CountOpenAt(unclosed, slide)
      slide = slide + 1
      Iterate
    End

    lead = line~length - line~strip("L")~length
    If lead > 3 | s~left(3) \== ":::" Then Iterate
    colons = s~verify(":") - 1
    If colons < 0 Then colons = s~length
    rest = Strip(s~substr(colons + 1))
    If rest == "" Then Do
      If open~items > 0 Then open~pull
      Else Do
        d = .Directory~new
        d~line = i; d~slide = slide
        stray~append(d)
      End
    End
    Else Do
      d = .Directory~new
      d~line = i; d~slide = slide; d~text = s
      -- An opener Pandoc cannot read (a '{' never closed, an attribute it
      -- does not understand: `{.contents .scale=0.75}`) is not a fence at
      -- all: it is a paragraph, and the ':::' meant to close it will close
      -- something else, or nothing. One Pandoc reads in an unexpected way
      -- (a single word, taken whole as the name of a class) does open.
      v = OpenerProblem(rest)
      d~problem = v~problem; d~fix = v~fix; d~odd = v~odd
      If d~problem \== "", \d~odd Then broken~append(d)
      Else Do
        If d~odd Then odd~append(d)
        open~push(d)
      End
    End
  End

  -- Oldest first reads better than the stack's order.
  unclosed = unclosed~sortWith(.LedgerOrder~new)

  r = .Directory~new
  r~unclosed = unclosed
  r~stray    = stray
  r~broken   = broken
  r~odd      = odd
  r~closeAt  = closeAt
  Return r

::Routine CountOpenAt
  Use Strict Arg unclosed, slide
  n = 0
  Loop u Over unclosed
    If u~slide == slide Then n = n + 1
  End
  Return n

::Routine FenceRun
  -- Length of the run of backticks or tildes a line starts with, if it is
  -- three or more; 0 otherwise.
  Use Strict Arg s
  ch = s~left(1)
  If ch \== "`", ch \== "~" Then Return 0
  run = s~verify(ch) - 1
  If run < 0 Then run = s~length
  If run < 3 Then Return 0
  Return run

::Class LedgerOrder
::Method compare
  Use Strict Arg a, b
  Return a~line - b~line

--------------------------------------------------------------------------------
-- WarnFenceBalance - say where the deck's ':::' blocks do not balance.       --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- BracketProblem - what is wrong with the braces or brackets of one piece    --
-- of a line, or "". Rony: a ':::' block that "does not work" is often a '{'  --
-- or '[' that was never closed, and the message should say THAT, not talk    --
-- about misplaced ':::' lines.                                               --
--------------------------------------------------------------------------------

::Routine BracketProblem Public
  Use Strict Arg text
  Loop pair Over .Array~of("{}", "[]")
    o = pair~left(1); c = pair~right(1)
    depth = 0
    Loop k = 1 To text~length
      ch = text~substr(k, 1)
      If ch == o Then depth += 1
      Else If ch == c Then Do
        depth -= 1
        If depth < 0 Then Return "it has a '"c"' with no '"o"' before it"
      End
    End
    If depth > 0 Then Return "its '"o"' is never closed with a '"c"'"
  End
  Return ""

--------------------------------------------------------------------------------
-- OpenerProblem - what keeps Pandoc from reading a ':::' opener the way it  --
-- was written. `rest` is the line after its colons. Returns a Directory:    --
--                                                                            --
--   problem  "" when all is well; else what is wrong, worded to follow      --
--            "because".                                                      --
--   fix      one sentence for the author: what to fix.                       --
--   odd      1 when Pandoc still opens a block, reading the whole of a      --
--            single word as a class name (`::: {.scale=0.75}` is a block of  --
--            class "{.scale=0.75}"); 0 when the line is shown as text.       --
--                                                                            --
-- Rony: `::: {.contents .scale=0.75 }` got the long message about ':::'     --
-- lines in general, with no word about the dot that did it. Pandoc's        --
-- grammar, as measured on 3.1: an opener is one word (no blanks), or        --
-- '{...}', and nothing after either but colons. Between the braces:         --
-- '#name', '.name', '-', and 'name=value'; a name starts with a letter and  --
-- goes on with letters, digits and "-_:."; a value is quoted ("..." or      --
-- '...', closed) or runs to the next blank or '}', and may be empty. Tokens --
-- need no blank between them ('#a#b' is two). Letters include any non-ASCII --
-- byte. When the braces do not parse, Pandoc falls back to the one-word     --
-- form if there are no blanks; when they parse but something follows the   --
-- '}', it does not ('{.a}{.b}' is text).                                     --
--------------------------------------------------------------------------------

::Routine OpenerProblem Public
  Use Strict Arg rest

  r = .Directory~new
  r~problem = ""; r~fix = ""; r~odd = 0
  t = rest~strip
  -- Colons after the opener are decoration ('::: {.a} :::', '::: title :::').
  If t~right(1) == ":" Then Do
    k = t~reverse~verify(":")
    If k > 0 Then Do
      u = t~left(t~length - k + 1)
      If u~right(1) == " " | u~right(1) == "09"x | u~right(1) == "}" Then t = u~strip
    End
  End
  oneWord = (t~verify(" " || "09"x, "M") == 0)

  If t~left(1) \== "{" Then Do
    If oneWord Then Return r
    Parse Var t name more
    more = more~strip
    If more~left(1) == "{" Then Do
      inner = more~substr(2)~strip("T", "}")~strip
      r~problem = "the name '"name"' comes before the braces"
      r~fix = "A name with attributes goes inside them: '::: {."name inner"}'."
    End
    Else Do
      r~problem = "it has more than one word outside braces"
      r~fix = "Write one name ('::: name'), or put everything in braces:" -
        "'::: {.name attr=value}'."
    End
    Return r
  End

  -- Between the braces, token by token.
  n = t~length; k = 2
  Loop Forever
    Do While k <= n, (t~substr(k, 1) == " " | t~substr(k, 1) == "09"x); k += 1; End
    If k > n Then Do
      r~problem = "its '{' is never closed with a '}'"
      r~fix = "Fix the bracket, not the ':::' lines."
      Leave
    End
    c = t~substr(k, 1)
    If c == "}" Then Do
      after = t~substr(k + 1)~strip
      If after == "" Then Return r
      If after~left(1) == "}" Then
        r~problem = "it has a '}' with no '{' before it"
      Else If after~left(1) == "{" Then
        r~problem = "it has two '{...}' groups; everything goes inside one"
      Else
        r~problem = "there is text after its '}' ('"after"'); only colons" -
          "may follow it"
      r~fix = "Fix the bracket, not the ':::' lines."
      Return r                               -- read to '}': no second chance
    End
    tokEnd = k
    Do While tokEnd <= n, t~substr(tokEnd, 1) \== " ", t~substr(tokEnd, 1) \== "09"x, -
      t~substr(tokEnd, 1) \== "}"
      tokEnd += 1
    End
    tok = t~substr(k, tokEnd - k)
    If c == "-" Then Do; k += 1; Iterate; End   -- {-}: unnumbered
    If c == "." | c == "#" Then Do
      e = OpenerName(t, k + 1)
      what = "class"; If c == "#" Then what = "identifier"
      If e == k + 1 Then Do
        r~problem = "'"tok"' is not a" what": the name after the '"c"'" -
          "must start with a letter"
        r~fix = "Fix the attribute, not the ':::' lines."
        Leave
      End
      If t~substr(e, 1) == "=" Then Do
        r~problem = "'"tok"' has a '"c"' in front, which makes it a" what "name," -
          "and a" what "name takes no value"
        r~fix = "An attribute is written without the '"c"':" -
          "'"tok~substr(2)"'. Fix the attribute, not the ':::' lines."
        Leave
      End
      k = e
      Iterate
    End
    e = OpenerName(t, k)
    If e == k Then Do
      r~problem = "'"tok"' is not something Pandoc reads between braces, where" -
        "only '.class', '#identifier' and 'name=value' go, and a name starts" -
        "with a letter"
      r~fix = "Fix the attribute, not the ':::' lines."
      Leave
    End
    name = t~substr(k, e - k)
    If t~substr(e, 1) \== "=" Then Do
      j = e
      Do While j <= n, (t~substr(j, 1) == " " | t~substr(j, 1) == "09"x); j += 1; End
      If t~substr(j, 1) == "=" Then Do
        r~problem = "an attribute takes no blanks around its '=' ('"name"=...')"
        r~fix = "Fix the attribute, not the ':::' lines."
        Leave
      End
      r~problem = "'"tok"' is neither a class nor an attribute: a class is" -
        "written '."name"', an attribute '"name"=value'"
      r~fix = "Fix the attribute, not the ':::' lines."
      Leave
    End
    k = e + 1                                -- the value
    q = t~substr(k, 1)
    closed = 0
    If q == '"' | q == "'" Then Do
      j = k + 1
      Do While j <= n
        If t~substr(j, 1) == "\" Then j += 2
        Else If t~substr(j, 1) == q Then Do; closed = 1; Leave; End
        Else j += 1
      End
      If closed Then k = j + 1
    End
    If \closed Then
      Do While k <= n, t~substr(k, 1) \== " ", t~substr(k, 1) \== "09"x, -
        t~substr(k, 1) \== "}"
        k += 1
      End
  End
  -- A single word Pandoc still takes, whole, for a class name.
  If oneWord Then r~odd = 1
  Return r

-- Where a Pandoc attribute name that starts at k ends (k itself: no name).
::Routine OpenerName
  Use Strict Arg t, k
  c = t~substr(k, 1)
  If c == "" Then Return k
  If \(c~datatype("M") | c~c2d >= 128) Then Return k
  j = k + 1
  Loop While j <= t~length
    c = t~substr(j, 1)
    If c~datatype("A") | c~c2d >= 128 | Pos(c, "-_:.") > 0 Then j += 1
    Else Leave
  End
  Return j

--------------------------------------------------------------------------------
-- WarnSpanBrackets - attributes on a span that Pandoc cannot read because a  --
-- bracket is missing: `[text]{.afterPrevious` (no '}') or `[text{.static}`   --
-- (no ']'). Either way the attributes come out as text on the slide and the  --
-- span is not a span. Code (fenced blocks, `inline code`) is skipped; a      --
-- ':::' line is the fence ledger's to judge.                                 --
--------------------------------------------------------------------------------

::Routine WarnSpanBrackets Public
  Use Strict Arg lines

  n = 0; slide = 0
  fenceCh = ""; fenceLen = 0
  Loop i = 1 To lines~items
    line = lines[i]
    s = Strip(line)
    If fenceCh \== "" Then Do
      If s \== "", s~verify(fenceCh) == 0, s~length >= fenceLen Then fenceCh = ""
      Iterate
    End
    run = FenceRun(s)
    If run > 0 Then Do
      fenceCh = s~left(1); fenceLen = run
      Iterate
    End
    If s~left(11) == "--- {.slide" Then Do; slide += 1; Iterate; End
    If s~left(3) == ":::" Then Iterate
    If s~pos("{") == 0 Then Iterate

    -- Inline code out of the way: `...`{.rexx} keeps its braces, loses its text.
    t = ""
    rest = line
    Loop While rest~pos("`") > 0
      Parse Var rest pre "`" code "`" rest
      t = t || pre || "``"
    End
    t = t || rest

    where = "line" i "(slide" slide"): "
    -- `]{` whose '}' never comes.
    k = t~pos("]{")
    Do While k > 0
      If t~pos("}", k + 2) == 0 Then Do
        Call Warn where"'"t~substr(k + 1)~left(40)~strip"' opens a '{' that is" -
          "never closed with a '}', so Pandoc shows the attributes as text and" -
          "the span does nothing. Close it: [text]{.name}."
        n += 1
        Leave
      End
      k = t~pos("]{", k + 2)
    End
    -- `{.` or `{#` not right after ']' ')' or '`', with a '[' still open.
    k = t~pos("{")
    Do While k > 0
      nx = t~substr(k + 1)~strip("L")~left(1)
      pv = t~substr(Max(1, k - 1), 1)
      If k > 1, (nx == "." | nx == "#"), pv \== "]", pv \== ")", pv \== "`" Then Do
        pre = t~left(k - 1)
        If pre~countStr("[") > pre~countStr("]") Then Do
          Call Warn where"'"pre~substr(pre~lastPos("["))~left(40)~strip"...'" -
            "opens a '[' that is never closed with a ']' before its '{...}', so" -
            "the attributes apply to nothing and show as text. Close it:" -
            "[text]{.name}."
          n += 1
          Leave
        End
      End
      k = t~pos("{", k + 1)
    End
  End
  Return n

::Routine WarnFenceBalance Public
  Use Strict Arg lines

  ledger = FenceLedger(lines)
  Loop bk Over ledger~broken
    Call Warn "line" bk~line "(slide" bk~slide"): '"bk~text"' is not read as a" -
      "':::' block, because" bk~problem". Pandoc shows the line as text, and" -
      "the ':::' meant to close it closes something else, or nothing." bk~fix
  End
  Loop bk Over ledger~odd
    Call Warn "line" bk~line "(slide" bk~slide"): '"bk~text"' opens a block," -
      "but Pandoc takes all of '"bk~text~substr(bk~text~verify(":"))~strip"'" -
      "for the name of one class, because" bk~problem"; so nothing written" -
      "in it takes effect." bk~fix
  End
  Loop u Over ledger~unclosed
    Call Warn "line" u~line "(slide" u~slide"): '"u~text"' is opened but" -
      "never closed with a ':::' line before the slide ends. md2slides closes" -
      "it at the end of the slide; if that is not where you meant it to end," -
      "add the ':::' where you did. (Pandoc, left to itself, would show it as" -
      "text in some versions, and in others close it only at the end of the" -
      "FILE, pulling every later slide into this block.)"
  End
  Loop t Over ledger~stray
    cause = ""
    Loop bk Over ledger~broken
      If bk~slide == t~slide, bk~line < t~line Then cause = bk
    End
    If cause \== "" Then
      Call Warn "line" t~line "(slide" t~slide"): this ':::' closes nothing," -
        "most likely because the block it was meant to close, on line" -
        cause~line", never opened: "cause~problem" (see above). It is ignored."
    Else
      Call Warn "line" t~line "(slide" t~slide"): this ':::' closes nothing --" -
        "every block opened in this slide is already closed. It is ignored;" -
        "delete it, or look above it for a block that should have been opened."
  End
  Return ledger~unclosed~items + ledger~stray~items

--------------------------------------------------------------------------------
-- BalanceFences - the source with its ':::' blocks balanced per slide:       --
-- the closers a slide is missing are added before the next slide starts      --
-- (and at the end of the file), and a ':::' that closes nothing is dropped.  --
-- What Pandoc then sees does not depend on its version. Returns a string,    --
-- one line per LF, as the next stages expect.                                --
--------------------------------------------------------------------------------

::Routine BalanceFences Public
  Use Strict Arg source

  If source~isA(.Array) Then flat = source~makeString("L", "0a"x)
  Else flat = source
  lines = flat~makeArray("0a"x)

  ledger = FenceLedger(lines)
  If ledger~unclosed~items + ledger~stray~items == 0 Then Return flat

  drop = .Set~new
  Loop t Over ledger~stray
    drop~put(t~line)
  End

  out = .MutableBuffer~new
  Loop i = 1 To lines~items + 1
    n = ledger~closeAt[i]
    If n \== .Nil, n > 0 Then Do
      out~append("0a"x)
      Loop n
        out~append(":::", "0a"x, "0a"x)
      End
    End
    If i > lines~items Then Leave
    If drop~hasIndex(i) Then out~append("0a"x)
    Else out~append(lines[i], "0a"x)
  End
  Return out~string

--------------------------------------------------------------------------------
-- WarnIndentedAfterFence - the first line of a ':::' block indented four or  --
-- more spaces past the fence. Markdown reads that as a CODE BLOCK, so the    --
-- line is shown as literal text -- and when it held a Rexx mention or a      --
-- fenced listing, what is shown is the HTML the highlighter had already made  --
-- of it. Rony indented a `::: fragment`'s content by four to get some space  --
-- and got a slide full of <span class="highlight-rexx...">.                  --
--                                                                            --
-- Only the FIRST non-blank line after the opener is checked: there no list   --
-- can be in progress, so four spaces there mean a code block and nothing     --
-- else (deeper in a block, an indented line may be a list's continuation,    --
-- which is fine and common). Returns the number of warnings.                 --
--------------------------------------------------------------------------------
::Routine WarnIndentedAfterFence Public
  Use Strict Arg lines

  n     = 0
  slide = 0
  Loop i = 1 To lines~items
    raw = lines[i]~changeStr("09"x, "    ")
    s   = Strip(raw)
    If s~left(11) == "--- {.slide" | lines[i]~left(2) == "# " Then slide = slide + 1
    If s~left(3) \== ":::" Then Iterate
    name = Strip(s, "L", ":")
    If name == "" Then Iterate                     -- a closer, not an opener
    col = raw~length - raw~strip("L")~length       -- the fence's own indentation
    j = i + 1
    Loop While j <= lines~items, Strip(lines[j]) == ""
      j = j + 1
    End
    If j > lines~items Then Leave
    next = lines[j]~changeStr("09"x, "    ")
    deep = next~length - next~strip("L")~length
    If deep < col + 4 Then Iterate
    If Strip(next)~left(3) == ":::" Then Iterate  -- a nested fence, indented or not
    place = "line" j
    If slide > 0 Then place = place "(slide" slide")"
    Call Warn place": indented" deep "spaces right after the ':::' on line" i", so" -
      "Markdown reads it as a code block and shows it as literal text (a Rexx" -
      "mention or listing there shows as its HTML). Unindent it; for space" -
      "on the slide, put indent= on the block instead."
    n = n + 1
  End
  Return n

--------------------------------------------------------------------------------
-- WarnFenceAfterMarker - a code fence five or more blanks after a list       --
-- marker: `-     ```rexx`.                                                  --
--                                                                            --
-- After a list marker Markdown allows one to four blanks. Five or more make  --
-- the item's content an INDENTED code block, which starts one blank after    --
-- the marker: the backticks, the word rexx and the closing backticks all     --
-- show on the slide as code, unhighlighted (Rony's "Repetition, 1"). The     --
-- fix is one blank after the marker, and the code lined up with the fence:   --
--                                                                            --
--   - ```rexx                                                                --
--     DO 3                                                                   --
--     END                                                                    --
--     ```                                                                    --
--                                                                            --
-- Returns how many were found.                                               --
--------------------------------------------------------------------------------

::Routine WarnFenceAfterMarker Public
  Use Strict Arg lines

  n     = 0
  slide = 0
  Loop i = 1 To lines~items
    raw = lines[i]~changeStr("09"x, "    ")
    s   = Strip(raw)
    If s~left(11) == "--- {.slide" | lines[i]~left(2) == "# " Then slide = slide + 1
    Parse Var s marker rest
    If \IsListMarker(marker) Then Iterate
    after = s~substr(marker~length + 1)
    blanks = after~length - after~strip("L")~length
    If blanks < 5 Then Iterate
    fence = after~strip("L")~left(3)
    If fence \== "```", fence \== "~~~" Then Iterate
    place = "line" i
    If slide > 0 Then place = place "(slide" slide")"
    Call Warn place": the code fence is" blanks "blanks after the list marker" -
      "'"marker"', so Markdown reads it as an indented code block and shows" -
      "the fence itself as code, unhighlighted. Put one blank after the" -
      "marker ("marker fence"...) and line the code and the closing fence up" -
      "with the opening one."
    n = n + 1
  End
  Return n

--------------------------------------------------------------------------------
-- WarnFenceWords - a class (or any lone word) on a ```rexx fence that the    --
-- highlighter does not use: ```` ```rexx {.fragment} ````.                   --
--                                                                            --
-- A Rexx listing is made by the highlighter (FencedCode), not by Pandoc, and --
-- it keeps only its own options: every other lone word is dropped, so the   --
-- class never reaches the HTML and the listing is not a fragment. It stays   --
-- that way on purpose: a fragment is md2slides' idea, not a listing's, and   --
-- the place for it is the block the listing sits in:                         --
--                                                                            --
--   ::: fragment                                                             --
--   ```rexx                                                                  --
--   ...                                                                      --
--   ```                                                                      --
--   :::                                                                      --
--                                                                            --
-- FenceWordIsKnown (FencedCode) says which words are the highlighter's.      --
-- Words with "=" are not checked here: an unknown one is already an error.   --
-- Returns how many were found.                                               --
--------------------------------------------------------------------------------

::Routine WarnFenceWords Public
  Use Strict Arg lines

  n     = 0
  slide = 0
  i     = 0
  Loop While i < lines~items
    i    = i + 1
    line = lines[i]
    s    = Strip(line)
    If s~left(11) == "--- {.slide" | line~left(2) == "# " Then slide = slide + 1
    bare = s
    If bare~left(3) \== "```", bare~left(3) \== "~~~" Then Do
      prefix = FenceMarkerPrefix(line)             -- `- ```rexx`
      If prefix == 0 Then Iterate
      bare = SubStr(line, prefix + 1)
    End
    char   = bare[1]
    info   = Strip(bare, "L", char)
    marker = Copies(char, bare~length - info~length)
    info   = Strip(info)
    -- Skip the block, whatever its language: a fence inside it is code.
    j = i + 1
    Loop While j <= lines~items, Strip(lines[j]) \== marker
      j = j + 1
    End
    opener = i
    i = j
    Parse Var info lang rest
    Parse Var lang lang "{" more
    If more \== "" Then rest = "{"more rest
    If lang \== "rexx", lang \== "executor" Then Iterate
    rest = Strip(rest)
    If rest~left(1) \== "{" | rest~right(1) \== "}" Then Iterate
    body = rest~substr(2, rest~length - 2)      -- as ParseOptions: first { to last }
    bad = ""
    Loop While body \== ""
      Parse Var body word body
      If word~contains("=") Then Do
        Parse Var word . "=" value
        q = value~left(1)
        If q == '"' | q == "'", value~countStr(q) < 2 Then
          Parse Var body . (q) body               -- the rest of a quoted value
        Iterate
      End
      If FenceWordIsKnown(word) Then Iterate
      bad = bad word
    End
    If bad == "" Then Iterate
    place = "line" opener
    If slide > 0 Then place = place "(slide" slide")"
    bad  = Strip(bad)
    what = "'"bad~changeStr(" ", "', '")"'"
    wrap = ""
    Loop w Over bad~makeArray(" ")
      If Pos(w~left(1), ".#") == 0 Then w = "."w  -- `fragment` -> `.fragment`
      wrap = wrap w
    End
    wrap = Strip(wrap)
    Call Warn place": ignored on '"marker || lang"':" what". A Rexx listing is" -
      "made by the highlighter, which keeps only its own options, so this" -
      "never reaches the slide. If it is meant for the listing (a fragment," -
      "a timing word), put the listing inside a block: '::: {"wrap"}' before" -
      "the fence and ':::' after it."
    n = n + 1
  End
  Return n

--------------------------------------------------------------------------------
-- WarnHtmlSlips - two slips in the HTML (or the attributes) of a deck that   --
-- the browser forgives in silence, so the deck builds and looks wrong.       --
--                                                                            --
-- Both are from Rony's test3.md (27-Sep), where blue and red never showed:   --
--                                                                            --
--   - style='color=blue'. A CSS declaration is `name: value`; one with no    --
--     colon is dropped by the browser, and nothing is coloured. Checked in   --
--     raw HTML (style='...') and in Pandoc attributes ({style="..."}).       --
--   - `strings<span>` for `strings</span>`. A <span> left open runs on to    --
--     the end of its paragraph, painting everything after it. Counted per    --
--     paragraph (up to a blank line), and reported at the line of the first  --
--     one that is never closed.                                              --
--                                                                            --
-- Code is not looked at: a fenced block, a `code span` and an HTML comment   --
-- may show any HTML they like. Returns the number of warnings.               --
--------------------------------------------------------------------------------

::Routine WarnHtmlSlips Public
  Use Strict Arg lines

  n        = 0
  slide    = 0
  fenceCh  = ""                              -- "`" or "~" while in a block
  fenceLen = 0
  comment  = .False                          -- inside <!-- ... -->
  open     = .Array~new                      -- line of each <span> still open
  bare     = .Array~new                      -- ...and whether it was a bare one
  styles   = .Directory~new                  -- bad declaration -> where, fix
  code     = .Directory~new                  -- a code span open across lines
  code~ticks = ""
  order    = .Array~new                      -- ...in the order first seen
  Loop i = 1 To lines~items + 1
    If i > lines~items Then line = ""        -- the end closes the paragraph
    Else line = lines[i]
    s = Strip(line)

    If fenceCh \== "" Then Do
      If s \== "", s~verify(fenceCh) == 0, s~length >= fenceLen Then fenceCh = ""
      Iterate
    End
    fence = s
    If FenceRun(fence) == 0 Then Do
      prefix = FenceMarkerPrefix(line)       -- `- ```rexx`
      If prefix > 0 Then fence = SubStr(line, prefix + 1)
    End
    run = FenceRun(fence)
    If run > 0 Then Do
      ch = fence~left(1)
      If ch == "~" | \fence~substr(run + 1)~contains("`") Then Do
        n = n + SpanReport(open, bare, slide)
        code~ticks = ""
        fenceCh = ch; fenceLen = run
        Iterate
      End
    End

    If s~left(11) == "--- {.slide" | line~left(2) == "# " Then Do
      n = n + SpanReport(open, bare, slide)
      code~ticks = ""
      slide = slide + 1
      Iterate
    End
    If s == "" Then Do                       -- a paragraph ends
      n = n + SpanReport(open, bare, slide)
      code~ticks = ""                        -- and so does any code span
      Iterate
    End

    -- What is text here: no comment, no code span.
    text = ""
    rest = line
    Loop While rest \== ""
      If comment Then Do
        If rest~pos("-->") == 0 Then Leave
        Parse Var rest . "-->" rest
        comment = .False
        Iterate
      End
      c = rest~pos("<!--")
      If c > 0 Then Do
        text = text || NoCodeSpans(rest~left(c - 1), code)
        rest = rest~substr(c + 4)
        comment = .True
        Iterate
      End
      text = text || NoCodeSpans(rest, code)
      rest = ""
    End

    where = "line" i
    If slide > 0 Then where = where "(slide" slide")"

    -- style=: every declaration needs its colon.
    rest = text
    Loop Forever
      p = rest~caselessPos("style=")
      If p == 0 Then Leave
      q = rest~substr(p + 6, 1)
      rest = rest~substr(p + 6)
      If q \== '"', q \== "'" Then Iterate
      Parse Var rest (q) value (q) rest
      bad = ""
      Loop decl Over value~makeArray(";")
        d = Strip(decl)
        If d == "" | d~pos(":") > 0 Then Iterate
        bad = d
        Leave
      End
      If bad == "" Then Iterate
      fix = ""
      If bad~pos("=") > 0 Then Do
        Parse Var bad name "=" val
        fix = " Write '"Strip(name)": "Strip(val)"'."
      End
      -- One warning per mistake, not per line: test3.md made the same one
      -- fifty times, and fifty warnings bury the one that matters.
      key = Lower(bad~space(0))
      If \styles~hasIndex(key) Then Do
        d = .Directory~new
        d~where = where; d~bad = bad; d~fix = fix; d~count = 0
        styles[key] = d
        order~append(key)
      End
      styles[key]~count = styles[key]~count + 1
    End

    -- <span> and </span>, in order.
    rest = text
    Loop Forever
      o = rest~caselessPos("<span")
      c = rest~caselessPos("</span>")
      If o > 0 Then Do                      -- "<span" is a tag, not "<spanner"
        after = rest~substr(o + 5, 1)
        If after \== ">", after \== " ", after \== "" Then Do
          rest = rest~substr(o + 5)
          Iterate
        End
      End
      If o == 0, c == 0 Then Leave
      If o > 0, (c == 0 | o < c) Then Do
        open~append(i)
        bare~append(rest~substr(o, 6)~lower == "<span>")
        rest = rest~substr(o + 5)
      End
      Else Do
        If open~items > 0 Then Do
          open~delete(open~items); bare~delete(bare~items)
        End
        rest = rest~substr(c + 7)
      End
    End
  End

  Loop key Over order
    d = styles[key]
    also = ""
    If d~count > 1 Then also = " (and" d~count - 1 "more times)"
    Call Warn d~where || also": style='"d~bad"' is not CSS: there is no" -
      "colon, and the browser drops a declaration that has none, without a" -
      "word. A declaration is 'name: value'."d~fix
    n = n + 1
  End
  Return n

-- Report the spans a paragraph left open: one warning, at the first of them.
::Routine SpanReport
  Use Strict Arg open, bare, slide
  If open~items == 0 Then Return 0
  where = "line" open[1]
  If slide > 0 Then where = where "(slide" slide")"
  many = open~items
  what = "a '<span>' that is never closed; the browser closes it"
  If many > 1 Then what = many "'<span>' tags that are never closed; the" -
    "browser closes them"
  hint = ""
  If bare~hasItem(.True) Then hint = " A bare '<span>' is often a closing" -
    "tag with its slash missing: '</span>'."
  Call Warn where": this paragraph has" what "at its end, so whatever a" -
    "span does (a colour, a size) reaches every word after it."hint
  open~empty; bare~empty
  Return 1

-- A line without its code spans (`...`, ``...``): what is in them is code.
-- A span may run on to the next line of its paragraph (`<span` at the end of
-- one line, `class="x">` on the next), so the run still open is kept in
-- state~ticks between calls; the caller clears it when the paragraph ends.
::Routine NoCodeSpans
  Use Strict Arg line, state
  out = ""
  Loop While line \== ""
    If state~ticks \== "" Then Do           -- inside a span: find its end
      q = line~pos(state~ticks)
      If q == 0 Then Return out
      line = line~substr(q + state~ticks~length)
      state~ticks = ""
      Iterate
    End
    p = line~pos("`")
    If p == 0 Then Leave
    run = line~substr(p)~verify("`") - 1
    If run < 0 Then run = line~length - p + 1
    out  = out || line~left(p - 1)
    state~ticks = Copies("`", run)
    line = line~substr(p + run)
  End
  Return out || line

--------------------------------------------------------------------------------
-- StripForeignOptions - key=value options the highlighter does not take, on  --
-- a ```rexx fence or a Rexx mention (`code`{.rexx ...}), taken off before    --
-- FencedCode sees them.                                                      --
--                                                                            --
-- FencedCode stops at an unknown key ("Invalid option 'level'"), and in a    --
-- deck that came out as a Rexx traceback (Rony, 27-Sep: level=2 on a         --
-- mention, anim= on a fence). What md2slides means by such a word -- a level, --
-- an animation -- belongs to the span or the block the code sits in, so it   --
-- is dropped, the author is told where it goes, and the deck is built. Lone  --
-- words are not touched: FencedCode already drops the ones it does not know  --
-- (and WarnFenceWords reports them on a fence). A bad VALUE of a known key   --
-- (blanks=al) is still the highlighter's to report.                          --
-- Returns the lines, changed where something was taken off.                  --
--------------------------------------------------------------------------------

::Routine StripForeignOptions Public
  Use Strict Arg lines

  out    = .Array~new
  slide  = 0
  marker = ""                                   -- inside a fence: its marker
  Loop i = 1 To lines~items
    line = lines[i]
    s    = Strip(line)
    If marker \== "" Then Do
      If s == marker Then marker = ""
      out~append(line)
      Iterate
    End
    If s~left(11) == "--- {.slide" | line~left(2) == "# " Then slide = slide + 1
    place = "line" i
    If slide > 0 Then place = place "(slide" slide")"

    -- A fence opener: ```rexx {...}, perhaps after a list marker
    at = 0
    If s~left(3) == "```" | s~left(3) == "~~~" Then at = line~pos(s~left(3))
    Else Do
      prefix = FenceMarkerPrefix(line)
      If prefix > 0 Then at = prefix + 1
    End
    If at > 0 Then Do
      bare   = line~substr(at)
      char   = bare[1]
      info   = Strip(bare, "L", char)
      marker = Copies(char, bare~length - info~length)
      Parse Var info lang .
      Parse Var lang lang "{" .
      If lang == "rexx" | lang == "executor" Then Do
        o = line~pos("{", at)
        c = line~lastPos("}")
        If o > 0, c > o Then Do
          kept = ForeignOptions(line~substr(o + 1, c - o - 1), place, -
                   "'"marker || lang"'")
          line = line~left(o) || kept || line~substr(c)
        End
      End
      out~append(line)
      Iterate
    End

    -- Mentions: `...`{.rexx ...}
    p = 1
    Loop Forever
      m = line~pos("`{.rexx", p)
      If m == 0 Then Leave
      o = m + 1
      c = line~pos("}", o)
      If c == 0 Then Leave
      If line~substr(o + 1, c - o - 1)~pos("{") > 0 Then Do; p = o + 1; Iterate; End
      kept = ForeignOptions(line~substr(o + 1, c - o - 1), place, "a Rexx mention")
      line = line~left(o) || kept || line~substr(c)
      p = o + kept~length + 2
    End
    out~append(line)
  End

  Return out

-- ForeignOptions - the inside of one pair of braces without the key=value
-- options the highlighter does not know, which are reported. Quoted values
-- (caption="a b") are kept whole.
::Routine ForeignOptions
  Use Strict Arg body, place, what

  kept = ""
  bad  = .Array~new
  rest = body
  Loop While Strip(rest) \== ""
    rest = Strip(rest, "L")
    Parse Var rest word rest
    If word~contains("=") Then Do
      Parse Var word key "=" value
      q = value~left(1)
      If q == '"' | q == "'", value~countStr(q) < 2 Then Do
        Parse Var rest more (q) rest
        word = word more || q
      End
      If \FenceKeyIsKnown(key) Then Do
        bad~append(word)
        Iterate
      End
    End
    kept = kept word
  End
  If bad~items == 0 Then Return body

  list = "'"bad~makeString("L", "', '")"'"
  all  = bad~makeString("L", " ")
  If what~left(1) == "'" Then
    where = "put the listing inside a block that carries it: '::: {"all"}'" -
            "before the fence and ':::' after it."
  Else
    where = "put it on a span around the mention: '[`...`{.rexx}]{"all"}'."
  Call Warn place": ignored on" what":" list". The Rexx highlighter takes" -
    "only its own options (style=, blanks=, caption=, spot=...), and this" -
    "would have stopped the build. If it is meant for what the code sits" -
    "in," where
  Return Strip(kept)

-- A list marker: - + *, or up to nine digits, one letter or '#' followed by
-- '.' or ')', or enclosed in '(' ')'.
::Routine IsListMarker
  Use Strict Arg w
  If w == "-" | w == "+" | w == "*" Then Return .True
  If w~left(1) == "(" Then Do
    If w~right(1) \== ")" Then Return .False
    body = w~substr(2, w~length - 2)
  End
  Else Do
    If Pos(w~right(1), ".)") == 0 Then Return .False
    body = w~left(w~length - 1)
  End
  If body == "#" Then Return .True
  If body~length == 1, body~datatype("M") Then Return .True
  Return body \== "" & body~length <= 9 & body~verify("0123456789") == 0

--------------------------------------------------------------------------------
-- SlideNumberAt - which slide a position in the flat HTML belongs to: the    --
-- number of slide openers (markers, or failing those <h1>s) before it.       --
--------------------------------------------------------------------------------

::Routine SlideNumberAt Public
  Use Strict Arg html, position

  before = html~left(Min(position, html~length))
  If html~pos('<hr class="slide"') > 0
    Then Return before~countStr('<hr class="slide"')
    Else Return before~countStr('<h1')

--------------------------------------------------------------------------------
-- StrayFenceLine - the line of the file, inside slide `slide`, that starts   --
-- with `first` (the stray fence as Pandoc left it: one word, or the first    --
-- two, blanks squeezed). 0 if it cannot be found.                            --
-- Slides are counted by their openers in the file as written; code is        --
-- skipped, so a `---` or a `#` inside a listing is not taken for one.        --
--------------------------------------------------------------------------------

::Routine StrayFenceLine Public
  Use Strict Arg lines, slide, first

  markers = 0
  Loop line Over lines
    If Strip(line)~left(11) == "--- {.slide" Then markers = 1
  End

  count = 0
  fence = ""
  Loop i = 1 To lines~items
    s = Strip(lines[i])
    If fence \== "" Then Do
      If s~left(3) == fence Then fence = ""
      Iterate
    End
    If s~left(3) == "```" | s~left(3) == "~~~" Then Do
      fence = s~left(3)
      Iterate
    End
    If markers Then Do
      If s~left(11) == "--- {.slide" Then count = count + 1
    End
    Else If lines[i]~left(2) == "# " Then count = count + 1
    If count == slide, Squeeze(s)~startsWith(first) Then Return i
    If count > slide Then Return 0
  End

  Return 0

--------------------------------------------------------------------------------
-- MisplacedFrontMatter - the line of a '---' that opens a rexxpub: block     --
-- somewhere other than line 1, or 0.                                         --
--                                                                            --
-- Front matter counts only at the top of the file. Anywhere else it was      --
-- ignored in silence -- and Pandoc, which accepts a metadata block anywhere, --
-- swallowed it too, so not even a stray line on a slide gave it away. A deck --
-- that opened with a comment lost its footer, its skin and its animation     --
-- defaults, and built without a word.                                        --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- BrokenFrontMatter - "line text" of a dash line that was meant to open or   --
-- close a rexxpub: front matter and is not '---', or "0".                    --
--                                                                            --
-- Rony (27-Sep): line 1 of a deck was '--'. No front matter was read, the    --
-- block went to Pandoc as text before the first slide, which a deck drops,   --
-- and the only sign was a footer warning about a field he had set. Caught:   --
-- line 1 a line of dashes (-, en or em dashes, blanks) that is not '---',    --
-- with 'rexxpub:' next; or line 1 right and the closing line wrong.          --
--------------------------------------------------------------------------------

::Routine BrokenFrontMatter Public
  Use Strict Arg source

  If source~items < 2 Then Return "0"
  first = Strip(source[1])
  If first \== "---", \DashLine(first) Then Return "0"
  -- the block must be a rexxpub: one
  Loop j = 2 To source~items
    next = Strip(source[j])
    If next == "" Then Iterate
    If \next~caselessStartsWith("rexxpub:") Then Return "0"
    Leave
  End
  If j > source~items Then Return "0"
  If first \== "---" Then Return "1" first
  -- line 1 is right: then the closing line is the broken one
  Loop i = j + 1 To source~items
    s = Strip(source[i])
    If s == "---" | s == "..." Then Return "0"
    If DashLine(s) Then Return i s
  End
  Return "0"

-- A line of dashes -- '-', or the en and em dashes an editor may turn them   --
-- into -- and blanks, that is not a front matter delimiter.                  --
::Routine DashLine
  Use Strict Arg s
  If s == "" | s == "---" Then Return 0
  t = s~changeStr("E28094"x, "")~changeStr("E28093"x, "")
  Return t~space(0)~strip("B", "-") == ""

--------------------------------------------------------------------------------
-- DuplicateKeys - the keys the front matter sets twice in the same block.    --
--                                                                            --
-- YAML keeps the LAST value of a repeated key, silently. Rony (27-Sep) had   --
-- copied his skin-mu-... lines to make the WU ones and renamed only some:    --
-- skin-mu-address-1 and four more came twice, and the Modul University card  --
-- said WU. Returns an array of "line first key" (file line numbers), in      --
-- order. Keys compare ignoring case, as the rest of the front matter reads   --
-- them. A light scan, not a parser: comments, list items and the lines of a  --
-- | or > block are passed over.                                              --
--------------------------------------------------------------------------------

::Routine DuplicateKeys Public
  Use Strict Arg source

  out = .Array~new
  If source~items < 3 Then Return out
  If Strip(source[1]) \== "---" Then Return out
  indents = .Array~new                  -- a stack of open blocks: indent...
  keys    = .Array~new                  -- ...and the keys seen in each
  block   = -1                          -- inside a | or > scalar deeper than this
  Loop i = 2 To source~items
    line = source[i]~changeStr("09"x, " ")
    s = Strip(line)
    If s == "---" | s == "..." Then Leave
    If s == "" | s~left(1) == "#" Then Iterate
    ind = Verify(line, " ") - 1
    If block >= 0 Then Do
      If ind > block Then Iterate
      block = -1
    End
    -- a list item: its mapping, if any, is a new block one level in
    If s == "-" | s~left(2) == "- " Then Do
      Loop While indents~items > 0, indents[indents~items] >= ind
        indents~delete(indents~items); keys~delete(keys~items)
      End
      s   = Strip(s~substr(2))
      ind = ind + 2
      If s == "" Then Iterate
    End
    -- key: value
    c = s~pos(":")
    If c < 2 Then Iterate
    If c < s~length, s~substr(c + 1, 1) \== " " Then Iterate
    key = Lower(s~left(c - 1)~strip("B", '"')~strip("B", "'"))
    value = Strip(s~substr(c + 1))
    Loop While indents~items > 0, indents[indents~items] > ind
      indents~delete(indents~items); keys~delete(keys~items)
    End
    open = (indents~items == 0)
    If \open Then open = (indents[indents~items] < ind)
    If open Then Do
      indents~append(ind); keys~append(.Directory~new)
    End
    seen = keys[keys~items]
    If seen~hasIndex(key) Then out~append(i seen[key] key)
    Else seen[key] = i
    If value~left(1) == "|" | value~left(1) == ">" Then block = ind
  End
  Return out

-- A '---' inside a code fence is not front matter: it is an example of one,
-- as in the RexxPub slides that explain it (doc/rexxpub/slides, v221c). So
-- fences are passed over the way FenceLedger does it, and so is a '---'
-- indented four blanks or more, which is an indented code block.

::Routine MisplacedFrontMatter Public
  Use Strict Arg source

  fenceCh  = ""                              -- "`" or "~" while in code
  fenceLen = 0
  Loop i = 2 To source~items - 1
    s = Strip(source[i])
    If fenceCh \== "" Then Do
      If s \== "", s~verify(fenceCh) == 0, s~length >= fenceLen Then fenceCh = ""
      Iterate
    End
    run = FenceRun(s)
    If run > 0 Then Do
      ch = s~left(1)
      If ch == "~" | \s~substr(run + 1)~contains("`") Then Do
        fenceCh  = ch
        fenceLen = run
        Iterate
      End
    End
    If s \== "---" Then Iterate
    line = source[i]~changeStr("09"x, "    ")
    If line~length - line~strip("L")~length > 3 Then Iterate
    Loop j = i + 1 To source~items
      next = Strip(source[j])
      If next == "" Then Iterate
      If next~caselessStartsWith("rexxpub:") Then Return i
      Leave
    End
  End

  Return 0

--------------------------------------------------------------------------------
-- AttrTokens - an attribute run split on blanks, but not on blanks inside    --
-- double quotes: `.slide kicker="Part One" #p1` is three tokens, not four.   --
-- The quotes are kept, so a token reads back exactly as it was written.      --
--------------------------------------------------------------------------------

::Routine AttrTokens Public
  Use Strict Arg run

  tokens  = .Array~new
  current = ""
  quoted  = 0
  Loop i = 1 To run~length
    c = run~substr(i, 1)
    If c == '"' Then quoted = \quoted
    If c == " ", \quoted Then Do
      If current \== "" Then tokens~append(current)
      current = ""
    End
    Else current = current || c
  End
  If current \== "" Then tokens~append(current)

  Return tokens

--------------------------------------------------------------------------------
-- CardLines - on a business-card slide, every line of the card is a line.    --
--                                                                            --
-- A card is written the way one is printed, one line under the other:       --
--                                                                            --
--     Prof. Rony G. Flatscher                                                --
--     Modul University Vienna                                                --
--     rony.flatscher@modul.ac.at                                             --
--                                                                            --
-- To Markdown, lines with no blank line between them are ONE paragraph, and  --
-- the card showed the whole address as one long name. Everyone who wrote a   --
-- card wrote it this way. So, before Pandoc, each such line is given a hard  --
-- line break (a trailing backslash), and Cards splits the paragraph there.   --
-- Blank lines between the lines still work, as they always did.             --
--                                                                            --
-- Only the card's own lines are touched: the prose of a business-card slide  --
-- and the inside of its ::: card zones. A ::: title zone, or any other, is   --
-- left alone, and so is code.                                                --
--------------------------------------------------------------------------------

::Routine CardLines Public
  Use Strict Arg source

  lines  = source~makeArray
  inCard = 0
  stack  = .Array~new
  fence  = ""
  out    = ""

  Loop i = 1 To lines~items
    line = lines[i]
    s    = Strip(line)

    -- Code is never touched.
    If fence \== "" Then Do
      If s~left(fence~length) == fence Then fence = ""
      out = out || line || "0a"x
      Iterate
    End
    If s~left(3) == "```" | s~left(3) == "~~~" Then Do
      fence = s~left(3)
      out = out || line || "0a"x
      Iterate
    End

    -- A slide opener decides whether this is a card slide.
    If s~left(11) == "--- {.slide" | line~left(2) == "# " Then Do
      inCard = WordPos(".business-card", Translate(s, "  ", "{}")) > 0
      stack  = .Array~new
      out = out || line || "0a"x
      Iterate
    End

    -- ::: opens or closes a zone.
    If s~left(3) == ":::" Then Do
      rest = Strip(Strip(s, "L", ":"))
      If rest == "" Then Do
        If stack~items > 0 Then stack~delete(stack~items)
      End
      Else Do
        rest = Translate(rest, "  ", "{}")
        If WordPos("card", rest) > 0 | WordPos(".card", rest) > 0
          Then stack~append("card")
          Else stack~append("other")
      End
      out = out || line || "0a"x
      Iterate
    End

    -- A line of the card, followed by another: break it there.
    eligible = inCard & (stack~items == 0 | stack~lastItem == "card")
    If eligible, s \== "", i < lines~items Then Do
      next = Strip(lines[i + 1])
      If next \== "", next~left(3) \== ":::", line~right(1) \== "\" Then
        line = line"\"
    End
    out = out || line || "0a"x
  End

  Return out

--------------------------------------------------------------------------------
-- MarkerDataAttrs - the key=value attributes written on a marker, as the     --
-- data-* directory a heading's attributes become in Pandoc's hands. The      --
-- marker's own bookkeeping (class, data-master, id) is not among them. A key --
-- already spelled data-* is kept as it is. Values may be quoted or bare; a   --
-- value with blanks in it must be quoted: kicker="Part One".                 --
--------------------------------------------------------------------------------

::Routine MarkerDataAttrs
  Use Strict Arg raw

  attrs = .Directory~new
  Loop word Over AttrTokens(Squeeze(raw))
    If word~pos("=") = 0 Then Iterate
    Parse Var word name "=" value
    name = name~lower
    If WordPos(name, "class data-master id") > 0 Then Iterate
    If value~left(1) == '"', value~right(1) == '"', value~length >= 2 Then
      value = value~substr(2, value~length - 2)
    If name~left(5) \== "data-" Then name = "data-"name
    attrs[name] = value
  End

  Return attrs

--------------------------------------------------------------------------------
-- MarkerSlideId - the id of a marker-opened slide, unique in the deck.       --
--                                                                            --
-- Every marker slide used to be id="slide". The id is not decoration: the    --
-- runtime writes it into the address bar as the slide changes, and reads it  --
-- back on load. With one id for all, the address always said #slide, and     --
-- reloading the deck -- F5 in the middle of a talk -- went back to slide 1.  --
--                                                                            --
-- The id is, in order: the one written on the marker (`--- {.slide #intro}`);--
-- else one made from the slide's ::: title, the way Pandoc makes a heading's --
-- (so a marker deck and a heading deck name their slides alike, and the name --
-- survives reordering); else "slide-N". A name already taken gets -1, -2...  --
-- as Pandoc does.                                                            --
--------------------------------------------------------------------------------

::Routine MarkerSlideId
  Use Strict Arg explicit, body, n, used

  id = Strip(explicit)
  If id == "" Then Do
    attr = TitleAttr(body)
    If attr \== "" Then Do
      Parse Var attr ' data-title="' title '"'
      id = Slug(title)
    End
  End
  If id == "" Then id = "slide-"n

  base = id
  k = 0
  Loop While used~hasIndex(id)
    k  = k + 1
    id = base"-"k
  End
  used~put(id)

  Return id

--------------------------------------------------------------------------------
-- Slug - Pandoc's identifier rule, near enough: lower case, blanks become    --
-- hyphens, punctuation other than _ - . goes, and so does everything before  --
-- the first letter. Bytes above 127 are kept: they are the letters of a      --
-- UTF-8 title, which Pandoc keeps too. Input may be attribute-escaped.       --
--------------------------------------------------------------------------------

::Routine Slug
  Use Strict Arg text

  text = Squeeze(HtmlUnescape(text))~lower

  -- UTF-8 punctuation is punctuation too, and Pandoc drops it: a title with a
  -- dash in it, "Step 3 — Built Up", must not put %E2%80%94 in the address.
  -- Without Unicode tables the letters cannot all be told from the rest, so
  -- the two ranges that titles actually use are dropped: General Punctuation
  -- (U+2000-U+206F: dashes, curly quotes, ellipsis, bullets), and the
  -- Latin-1 signs U+00A0-U+00BF (no-break space, guillemets, inverted marks,
  -- the middle dot) except the ordinal indicators and the micro sign.
  text = text~changeStr("c2a0"x, " ")
  keep = "abcdefghijklmnopqrstuvwxyz0123456789_-."
  out = ""
  i = 1
  Loop While i <= text~length
    c = text~substr(i, 1)
    Select
      When c == " "                     Then out = out"-"
      When keep~pos(c) > 0              Then out = out || c
      When c == "e2"x, text~substr(i + 1, 1) >= "80"x, -
           text~substr(i + 1, 1) <= "81"x Then i = i + 2
      When c == "c2"x Then Do
        d = text~substr(i + 1, 1)
        If d == "aa"x | d == "b5"x | d == "ba"x Then out = out || c || d
        i = i + 1
      End
      When c2d(c) > 127                 Then out = out || c
      Otherwise Nop
    End
    i = i + 1
  End

  -- Everything up to the first letter goes, as in Pandoc.
  Loop While out \== "", "abcdefghijklmnopqrstuvwxyz"~pos(out~left(1)) = 0, -
             c2d(out~left(1)) <= 127
    out = out~substr(2)
  End

  Return out

--------------------------------------------------------------------------------
-- AttrValue - value of a name="..." attribute in a raw tag string, or "".    --
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
-- RenderMarkerSlide - a <section> for a marker-opened slide (cut by a        --
-- `--- {.slide}`). Same master chrome as RenderSlide -- the "list" role, the --
-- author's three footer slots -- but it emits NO <h1 class="title"> of its   --
-- own: the title is a zone the author placed in the body (:::title ->        --
-- div.title), so it flows in as the first block through TransformBody. The   --
-- slide keeps the master's padding, title band and footer band, and the body --
-- is ordinary flow. Role/anim/kicker machinery is absent because a bare      --
-- marker carries no attributes to drive it; when the model earns per-slide   --
-- attrs on the marker, they parse here the way RenderSlide parses an <h1>'s. --
--------------------------------------------------------------------------------

::Routine RenderMarkerSlide
  Use Strict Arg body, band, fields, masterClass = "", id = "slide", -
    dataAttrs = (.Directory~new)

  -- Resolve the per-slide identity: defaults from the deck YAML (fields),
  -- overridden by any :::presenter (etc.) zone the author placed in THIS slide.
  -- Returns the data-* attribute run for the <section> and the body with the
  -- consumed override zones removed (they are data, not visible prose).
  -- The role first: SlideIdentity treats a business card's fields apart.
  role = "list"
  Loop w Over masterClass~makeArray(" ")
    If WordPos(w, SlideRoles()) > 0 Then role = w
  End
  parsed = SlideIdentity(body, fields, role, id)
  sectionStyle = parsed[1]
  chrome       = parsed[2]
  body         = parsed[3]

  -- masterClass is the per-slide molde selector (" master", or "") the author
  -- named on the marker; it joins the fixed "slide" class so the master's
  -- `.slide.master` CSS shapes this one slide.
  -- The title is a zone the author placed (:::title); expose it as data-title so
  -- the jump overlay can label this slide by name. Not consumed: it stays prose.
  titleAttr = TitleAttr(body)

  -- A role named on the marker is a role, exactly as on a heading: the same
  -- fixed set, the last one written wins. Before this, `--- {.slide
  -- .business-card}` reached the <section> as a bare class and nothing else,
  -- so the cards were never built; and `--- {.slide .section}` was labelled
  -- data-title, so the go dialog did not list it as a section and Ctrl+Left /
  -- Ctrl+Right skipped it. Both looked right in the HTML and were wrong on
  -- stage.
  If role == "section", titleAttr \== "" Then
    titleAttr = ' data-section='titleAttr~substr(Length(' data-title=') + 1)
  sectionName = OwnSlideAttrs(dataAttrs, role, id)
  If sectionName \== "" Then titleAttr = ' data-section="'AttrEscape(sectionName)'"'

  -- The attributes written on the marker reach the slide as data-*, exactly
  -- as Pandoc delivers those of a heading: `--- {.slide anim=fade
  -- wait-before=1}` is the same slide as `# T {anim=fade wait-before=1}`.
  -- They used to be dropped, so in a marker deck no slide could choose its
  -- page transition or build itself from the clock -- silently.
  where = id
  If dataAttrs~hasIndex("data-anim") Then
    Call CheckAnim Squeeze(dataAttrs["data-anim"]), PageAnims(), "page", where
  If dataAttrs~hasIndex("data-anim-duration") Then
    Call CheckAnimDuration Squeeze(dataAttrs["data-anim-duration"]), where
  Call CheckBodyAnims body, where
  body = TableColumns(body, where)
  passThrough = ""
  Loop k Over dataAttrs~allIndexes~sort
    If k == "data-kicker" Then Iterate      -- content, not an attribute
    passThrough = passThrough' 'k'="'AttrEscape(dataAttrs[k])'"'
  End

  out = '  <section class="slide'masterClass'" id="'id'"'titleAttr''passThrough''sectionStyle'>' || "0a"x

  -- kicker= on the marker is the small line above the title, exactly as on a
  -- heading: `--- {.slide kicker="Sequences"}` is `# T {kicker="Sequences"}`.
  -- It comes first, before the ::: title zone, which is where the master
  -- expects it.
  If dataAttrs~hasIndex("data-kicker") Then
    out = out || '    <p class="kicker">'AttrEscape(dataAttrs["data-kicker"])'</p>' || "0a"x

  out = out || TransformBody(body, role)
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
-- and it wins for that slide only. The runtime supplies page/total;          --
-- everything else is resolved HERE, at build, so the CSS only ever reads a   --
-- finished value via attr(data-...). No footer is composed, placed or named  --
-- by this code.                                                              --
--                                                                            --
-- Zones handled (Pandoc renders `::: name` as <div class="name">...</div>):  --
--   presenter, affiliation, date, and any other field the deck has (v214),   --
--   but not the names of md2slides' own zones and blocks (IsReservedZone).   --
-- The zone, once read, is removed from the body: it is a datum, not prose.   --
--------------------------------------------------------------------------------

::Routine SlideIdentity
  Use Strict Arg body, fields, role = "list", where = ""

  -- FIELDS: deck-level values that fill {placeholders}. Start from the declared
  -- and automatic fields (already in `fields`), then let a per-slide zone for
  -- any of them win for THIS slide -- e.g. a guest slide writes `::: presenter`
  -- / their name / `:::`. The classic presenter/affiliation/date are just three
  -- such fields now; a deck may define any others (version, course, ...).
  local = .StringTable~new
  Loop k Over fields~allIndexes
    If Left(k, 2) == "__" Then Iterate       -- box templates, not fields
    local[k] = fields[k]
  End
  -- Per-slide field overrides: a `::: name` zone sets field `name` for this
  -- slide. presenter, affiliation and date always can, declared or not (a
  -- guest's slide in someone else's deck); since v214 so can every other field
  -- the deck has (`::: course`, `::: version`...), except the names md2slides
  -- already uses for a zone or a block, which keep their own meaning.
  names = "presenter affiliation date"
  Loop k Over local~allIndexes~sort
    If WordPos(k, names) > 0 Then Iterate
    If IsReservedZone(k) Then Iterate
    names = names k
  End
  Loop fld Over names~makeArray(" ")
    r = ZoneOverride(body, fld)
    If r[1] \== .Nil Then local[fld] = r[1]
    body = r[2]
  End
  -- "today" as a field value resolves to the ISO build date (kept for the
  -- classic `date: today`); AutoFields already seeds {today} itself.
  If local~hasIndex("date"), local["date"] == "today" Then local["date"] = ResolveToday()

  -- The slide's own text may use the fields too (Rony, 26-Sep: a link that
  -- differs per skin, `[Regulations]({regulations})` with
  -- `skin-mu-regulations:` and `skin-wu-regulations:` in the front matter).
  -- On a business card a field with no value leaves nothing, and a line of
  -- the card left with nothing goes too (v220, Rony: address-1..3, not all
  -- used on every card).
  If role == "business-card" Then body = CardFields(body, local, where)
  body = BodyFields(body, local)

  -- BOXES: the six margin boxes. Deck/skin templates ride in `fields` under
  -- __box-<edge>-<side>; a per-slide zone (:::header-left ... :::footer-right)
  -- overrides ONE box for this slide only. Then expand {placeholders}.
  box = .StringTable~new
  Loop edge Over "header footer"~makeArray(" ")
    Loop side Over "left center right"~makeArray(" ")
      name = edge"-"side
      tmpl = ""
      If fields~hasIndex("__box-"name) Then tmpl = fields["__box-"name]
      -- per-slide override zone, e.g. `::: footer-center`
      r = ZoneOverride(body, name)
      If r[1] \== .Nil Then tmpl = r[1]
      body = r[2]
      box[name] = ExpandFields(tmpl, local)
    End
  End

  -- Per-slide font-size zones (:::title/body/code-font-size) are GONE -- the
  -- scalable-group vocabulary (`::: {.contents scale=N}`, per-slide master class)
  -- replaced them, so a slide adds nothing to its <section> style here.
  sectionStyle = ""

  -- Emit the header and footer as fixed margin regions the runtime CSS places
  -- (six boxes, Paged-Media style), plus the empty `chrome` anchor the master
  -- fills with images by CSS (the pipeline knows nothing of logos or seals; it
  -- only guarantees the anchor). An empty box is still emitted (so the CSS grid
  -- of three columns is stable) but carries no text.
  chrome = MarginRegion("header", box) || MarginRegion("footer", box) -
           '    <div class="chrome"></div>' || "0a"x

  Return .Array~of(sectionStyle, chrome, body)

--------------------------------------------------------------------------------
-- IsReservedZone - a name md2slides uses for a zone or a block of its own:   --
-- a field of the same name cannot be set per slide with `::: name`, because  --
-- that block already means something else (`::: title` is a marker slide's   --
-- title; `::: row` a row of columns).                                        --
--------------------------------------------------------------------------------

::Routine IsReservedZone Public
  Use Strict Arg name
  reserved = "title subtitle card background layers refs notes" -
             "header-left header-center header-right" -
             "footer-left footer-center footer-right" -
             "fragment incremental nonincremental static contents plain" -
             "tight row label output keys"
  If WordPos(name, reserved) > 0 Then Return 1
  If name~startsWith("col-") Then Return 1
  Return 0

--------------------------------------------------------------------------------
-- MarginRegion - the HTML for one edge (header or footer) as three boxes.     --
-- Emitted on every slide so the CSS three-column grid is always there; an      --
-- empty box is an empty <div>, which simply shows nothing.                     --
--------------------------------------------------------------------------------

::Routine MarginRegion
  Use Strict Arg edge, box

  out = '    <div class="margin 'edge'">' || "0a"x
  Loop side Over "left center right"~makeArray(" ")
    content = box[edge"-"side]
    out = out'      <div class="m-'side'">'content'</div>' || "0a"x
  End
  Return out'    </div>' || "0a"x

--------------------------------------------------------------------------------
-- ExpandFields - replace every {name} in a template with fields[name], or with --
-- "" when the field is unknown/empty. {page} and {pages} are left ALONE: the   --
-- runtime fills those live (they differ per slide and change on renumbering),  --
-- so the placeholder must survive to the DOM.                                  --
-- [ ... ] around a field is an OPTIONAL GROUP (CheckFooter does not warn for  --
-- what is in one): `{presenter}[ · v{version}]` shows " · v1.2" when there is  --
-- a version and nothing at all when there is not. The brackets never reach    --
-- the slide (they used to stay, as `[ · ]`; found 26-Sep). A group whose      --
-- fields are all empty goes; one with a runtime field ({page}...) stays, as   --
-- it cannot be known here. Brackets with no field inside are just text.       --
--------------------------------------------------------------------------------

::Routine ExpandFields
  Use Strict Arg tmpl, fields

  -- Runtime-filled placeholders pass through untouched.
  runtime = "page pages total-pages totalpages" LiveFields()

  -- Optional groups first: each [ ... ] holding a {field} is expanded on its
  -- own, and kept (without its brackets) only if some field in it has a value.
  If tmpl~pos("[") > 0 Then Do
    work = ""
    rest = tmpl
    Loop While rest~pos("[") > 0
      p = rest~pos("[")
      q = rest~pos("]", p)
      If q == 0 Then Leave
      group = rest~substr(p + 1, q - p - 1)
      work ||= rest~left(p - 1)
      rest = rest~substr(q + 1)
      If group~pos("{") == 0 Then Do        -- no field in it: plain text
        work ||= "["group"]"
        Iterate
      End
      keep = 0
      g = group
      Loop While g~pos("{") > 0
        Parse Var g . "{" nm "}" g
        k = Lower(Strip(nm))
        If WordPos(k, runtime) > 0 Then keep = 1
        Else If fields~hasIndex(k) Then
          If fields[k] \== "" Then keep = 1
      End
      If keep Then work ||= ExpandFields(group, fields)
    End
    tmpl = work || rest
  End

  out  = ""
  rest = tmpl
  Loop While rest~pos("{") > 0
    Parse Var rest before "{" name "}" rest
    out = out || before
    key = Strip(name)
    Select
      When key == "" Then out = out                 -- stray "{}" -> nothing
      When WordPos(Lower(key), runtime) > 0 Then     -- leave for the runtime
        out = out || "{" || name || "}"
      When fields~hasIndex(Lower(key)) Then
        out = out || fields[Lower(key)]
      Otherwise out = out                            -- unknown field -> empty
    End
  End
  Return out || rest

--------------------------------------------------------------------------------
-- BodyFields - the {fields} of the front matter, in the slide's own text.    --
--                                                                            --
-- The margin boxes always had them; a slide's text did not, and a link that  --
-- depends on the skin (the regulations of the house the talk is given for)   --
-- had no way to be written once (Rony, 26-Sep). Now `{regulations}` in the   --
-- text, and `[Regulations]({regulations})` as a link, are the field's value. --
--                                                                            --
-- Only a field the deck DECLARES (or the build knows: today, file-name...)   --
-- is replaced. Braces are ordinary text in a slide -- Rony's strings have    --
-- `{niX }` in them -- so an unknown {name} stays exactly as written, unlike  --
-- in a margin box, which is a template. Code is never touched: <code>, <pre> --
-- (a listing shows the program, not the deck's fields). Pandoc writes a link --
-- target {name} as %7Bname%7D; that is looked for too.                       --
--                                                                            --
-- In the text the value goes in as it is, HTML and all, as in the margins    --
-- (`&ndash;`, `<br>`). Inside a tag -- a link target, a title="" -- it is an --
-- attribute value, and a quote or a < in it is escaped.                      --
--------------------------------------------------------------------------------

::Routine BodyFields Public
  Use Strict Arg body, fields

  If body~pos("{") == 0, body~caselessPos("%7B") == 0 Then Return body

  runtime = "page pages total-pages totalpages" LiveFields()
  out = .MutableBuffer~new
  p = 1
  Loop Forever
    -- next candidate: a "{" or a "%7B", whichever comes first
    b1 = body~pos("{", p)
    b2 = body~caselessPos("%7B", p)
    If b1 == 0, b2 == 0 Then Leave
    If b1 == 0 Then at = b2
    Else If b2 == 0 Then at = b1
    Else at = Min(b1, b2)
    encoded = (at == b2)
    If encoded Then Do; open = 3; close = "%7D"; End
    Else Do; open = 1; close = "}"; End

    -- a protected region (code) opened before `at` and not yet closed: jump
    -- past its end and go on from there
    skip = CodeEnd(body, p, at)
    If skip > 0 Then Do
      out~append(body~substr(p, skip - p))
      p = skip
      Iterate
    End

    e = body~caselessPos(close, at + open)
    name = ""
    If e > 0 Then name = body~substr(at + open, e - at - open)
    key = Lower(Strip(name))
    ok = key \== "" & e > 0
    If ok Then ok = Verify(key, "abcdefghijklmnopqrstuvwxyz0123456789-_.") == 0
    If ok, \fields~hasIndex(key), WordPos(key, runtime) == 0 Then
      If SkinOnlyField(fields, key) Then Do
        -- declared, but only for other skins: say so, once, and write nothing
        If \.local~hasIndex("MD2SLIDES.SKINONLY."key) Then Do
          .local["MD2SLIDES.SKINONLY."key] = 1
          Call Warn "{"key"} is only declared for other skins (skin-...-"key":)" -
            "and has no value under this one; add a plain '"key":' as the" -
            "default."
        End
        out~append(body~substr(p, at - p))
        p = e + close~length
        Iterate
      End
    If ok Then ok = fields~hasIndex(key) & WordPos(key, runtime) == 0
    If ok Then ok = key~left(2) \== "__"
    If \ok Then Do
      out~append(body~substr(p, at + open - p))
      p = at + open
      Iterate
    End

    value = fields[key]
    -- inside a tag (between a < and its >): an attribute value
    lt = body~lastPos("<", at); gt = body~lastPos(">", at)
    If lt > gt Then value = value~changeStr('"', "&quot;")~changeStr("<", "&lt;")
    out~append(body~substr(p, at - p), value)
    p = e + close~length
  End
  out~append(body~substr(p))
  Return out~string

-- SkinOnlyField - is there a skin-<tag>-<key> field, but no <key> itself?   --
::Routine SkinOnlyField
  Use Strict Arg fields, key
  Loop name Over fields~allIndexes
    If name~startsWith("skin-"), name~endsWith("-"key), -
       name~length > key~length + 6 Then Return 1
  End
  Return 0

-- CodeEnd - if a <code>, <pre>, <script> or <style> element is open at `at`  --
-- (opened at or after `from`, or before it and still open), the position    --
-- just past its closing tag; 0 when `at` is in ordinary text.               --
::Routine CodeEnd
  Use Strict Arg body, from, at
  Loop tag Over "code pre script style"~makeArray(" ")
    o = body~lastPos("<"tag, at)
    Do While o > 0
      c = body~substr(o + tag~length + 1, 1)
      If c == ">" | c == " " Then Leave     -- <code> or <code class=...>, not <codex
      If o == 1 Then Do; o = 0; Leave; End
      o = body~lastPos("<"tag, o - 1)
    End
    If o == 0 Then Iterate
    cl = body~pos("</"tag">", o)
    If cl == 0 Then Iterate
    If cl < at Then Iterate                   -- closed before `at`
    Return cl + tag~length + 3
  End
  Return 0

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
  -- Unwrap Pandoc's <p>...</p> -- two paragraphs are two lines -- and keep
  -- the rest of the markup, as a template in the front matter keeps it:
  -- `{page}/{pages}<br>Cf. rexxref.pdf` lost its <br> here, and the two
  -- lines ran into one (Rony, 27-Sep).
  text = inner~strip
  text = text~changeStr("</p>" || "0a"x || "<p>", "<br>")
  text = text~changeStr("<p>", "")~changeStr("</p>", "")
  text = Squeeze(text)

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

--------------------------------------------------------------------------------
-- TitleAttr - derive a ` data-title="..."` run from the first `:::title` zone
-- in a slide body, or "" if the slide has none. Pandoc renders `::: title` as
-- <div class="title">...</div>; we read the text of that first div, flatten it
-- to plain text (a title may carry <br> or an inline mention span), squeeze
-- whitespace and escape it for an attribute. The zone is NOT consumed: the
-- title stays visible prose in the body; data-title is only a duplicate datum
-- so the jump overlay (runtime.js) can label the slide by its title instead of
-- "Slide N". Slides in the marker regime carry no <h1>, so this is the
-- one place their title is known at build time.
--------------------------------------------------------------------------------

::Routine TitleAttr
  Use Strict Arg body

  p = body~pos('<div class="title">')
  If p = 0 Then Return ""

  -- Find the matching </div>, counting nested <div>s so a title that wraps
  -- other divs still closes correctly.
  inner = SubStr(body, p + Length('<div class="title">'))
  depth = 1
  scan  = inner
  text  = ""
  Loop While depth > 0
    nextOpen  = scan~pos("<div")
    nextClose = scan~pos("</div>")
    If nextClose = 0 Then Leave                 -- malformed; stop
    If nextOpen \= 0, nextOpen < nextClose Then Do
      text = text || Left(scan, nextOpen + 3)   -- keep through "<div"
      scan = SubStr(scan, nextOpen + 4)
      depth = depth + 1
    End
    Else Do
      text = text || Left(scan, nextClose - 1)
      scan = SubStr(scan, nextClose + Length("</div>"))
      depth = depth - 1
    End
  End

  -- Pandoc's text is already HTML: an "&" in the title arrives as "&amp;".
  -- Escaping that again gave data-title="Rexx &amp;amp; Co", and the go dialog
  -- showed "Rexx &amp; Co". Decode first, then escape once.
  title = Squeeze(HtmlUnescape(StripTags(text)))
  If title == "" Then Return ""
  Return ' data-title="'AttrEscape(title)'"'

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
-- ATTRIBUTES AND CLASSES. A bare marker is `--- {.slide}`; a marker MAY carry--
-- more inside the braces, of two kinds, in Pandoc's own attribute syntax:    --
--                                                                            --
--   * per-slide ATTRIBUTES (name="value"): copied verbatim onto the <hr>, so --
--     a later pass can act on them. None is interpreted today; the mechanism --
--     is here for per-slide attributes the model earns later.                --
--   * extra CLASSES (`.name`), e.g. `--- {.slide .master}` -- a per-slide    --
--     MASTER selector: the author names a slide "molde" and the master's CSS --
--     shapes `.slide.master` (title size, band, etc.) without the author     --
--     repeating those metrics slide by slide. The pipeline does NOT interpret--
--     the name; it only carries it, so the master owns what each molde means.--
--                                                                            --
-- The class does NOT go into the <hr>'s own `class` (that must stay exactly  --
-- `"slide"` so FoldByMarker's literal `<hr class="slide"` split keeps casing).
-- It rides as `data-master="..."`, a plain attribute, which a later pass     --
-- lifts onto the <section>'s class where the master CSS reads it.            --
-- The bare form stays byte-identical to before (no trailing space when there --
-- is nothing to carry).                                                      --
--------------------------------------------------------------------------------

::Routine SlideMarkers
  Use Strict Arg source

  out = ""
  Loop line Over source~makeArray            -- String -> lines (splits on LF)
    s = Strip(line)
    If s~left(11) == "--- {.slide", s~right(1) == "}" Then Do
      -- the run between ".slide" and the final "}" holds classes and attributes
      inner = s~substr(12)                   -- everything after "--- {.slide"
      inner = inner~left(inner~length - 1)   -- drop the trailing "}"
      inner = Strip(inner)

      -- Split the run into `.class` tokens and everything else (attributes and
      -- the self-closing "/"). Classes fold into one data-master value; the
      -- rest is preserved verbatim, in order.
      classes = ""
      attrs   = ""
      Do word Over AttrTokens(inner)
        If word == "" Then Iterate
        If word~left(1) == "." Then
          classes = classes word~substr(2)
        Else If word~left(1) == "#", word~length > 1 Then
          attrs = attrs 'id="'word~substr(2)'"'   -- Pandoc's {#id}, spelled out
        Else
          attrs = attrs word
      End
      classes = Strip(classes)
      attrs   = Strip(attrs)

      carry = ""
      If classes \== "" Then carry = ' data-master="'classes'"'
      If attrs   \== "" Then carry = carry' 'attrs

      out = out || '<hr class="slide"'carry' />' || "0a"x
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

-- How the marks of a spot beat come in, named on its empty trigger (v224).
::Routine MarkAnims
  Return "fade pen cut"

--------------------------------------------------------------------------------
-- SpotTrigger - is the tag around position `at` of `html` the empty trigger  --
-- of a spot beat: data-spot=, nothing inside, and not an arrow (an arrow is  --
-- empty too, but it has itself to show)?                                     --
--------------------------------------------------------------------------------

::Routine SpotTrigger
  Use Strict Arg html, at

  start = html~lastPos("<", at)
  close = html~pos(">", at)
  If start == 0 | close == 0 Then Return .False
  tag = html~substr(start, close - start + 1)
  If tag~pos('data-spot="') == 0 Then Return .False
  Parse Var tag "<" tname " " .
  If WordPos(Lower(tname), "p span") == 0 Then Return .False  -- an <img> is empty too
  If WordPos("arrow", AttrValue(tag, "class")) > 0 Then Return .False
  next = html~pos("<", close)
  If next == 0 Then Return .False
  If Strip(html~substr(close + 1, next - close - 1)~translate(" ", "0a0d09"x)) \== "" Then Return .False
  Return html~substr(next, 2) == "</"

--------------------------------------------------------------------------------
-- CheckBodyWaits - wait-before=, wait-after= and wait= where they do nothing. --
--                                                                            --
-- On a fragment they time a step that comes by itself (v224): wait-before=   --
-- is the pause before a .afterPrev step, wait-after= the pause after a step  --
-- before the one that follows by itself. Two places where they did nothing,  --
-- without a word (Rony, 28-Sep):                                             --
--                                                                            --
--   - on something that is not a step at all (no .fragment, no timing word,  --
--     no spot=): nothing is revealed, so nothing waits;                      --
--   - wait-before= (or wait=) on a step that comes with a press: a press     --
--     shows its step at once -- the presenter always wins.                   --
--------------------------------------------------------------------------------

::Routine CheckBodyWaits
  Use Strict Arg body, where

  said = .Set~new
  at   = 1
  Loop Forever
    at = body~pos(" data-wait", at)
    If at == 0 Then Leave
    Parse Value body~substr(at + 1) With attr "=" .
    at = at + 10
    If WordPos(attr, "data-wait data-wait-before data-wait-after") == 0 Then Iterate
    start = body~lastPos("<", at)
    close = body~pos(">", at)
    If start == 0 | close == 0 Then Iterate
    tag     = body~substr(start, close - start + 1)
    classes = AttrValue(tag, "class")
    step    = WordPos("fragment", classes) > 0 | tag~pos('data-spot="') > 0 -
            | WordPos("afterPrevious", classes) > 0 | WordPos("withPrevious", classes) > 0
    key  = attr~substr(6)                    -- wait, wait-before, wait-after
    Parse Var tag "<" name " " .
    If \step Then Do
      If said~hasIndex(start) Then Iterate
      said~put(start)
      Call Warn "slide" '"'where'":' key"= on a <"name"> that is not revealed" -
        "step by step (no .fragment, no timing word, no spot=), so it waits" -
        "for nothing. On a whole slide, it goes on the slide's own line."
      Iterate
    End
    If key == "wait-after" | WordPos("afterPrevious", classes) > 0 Then Iterate
    If said~hasIndex(start) Then Iterate
    said~put(start)
    Call Warn "slide" '"'where'":' key"= on a step that comes with a press:" -
      "a press shows it at once, so it waits for nothing. To have it come" -
      "by itself after the pause, add .afterPrev."
  End
  Return

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

  -- The empty trigger of a spot beat ([]{spot=trap anim=pen}) animates the
  -- beat's marks, not itself (v224), and marks have their own three ways.
  at = 1
  Loop Forever
    at = body~pos('data-anim="', at)
    If at == 0 Then Leave
    Parse Value body~substr(at) With 'data-anim="' name '"'
    at = at + 11
    If SpotTrigger(body, at) Then
      Call CheckAnim Squeeze(name), MarkAnims(), "spot mark", where
    Else
      Call CheckAnim Squeeze(name), ElementAnims(), "element", where
  End
  Call CheckBodyWaits body, where

  rest = body
  Loop While rest~pos('data-anim-duration="') > 0
    Parse Var rest . 'data-anim-duration="' value '"' rest
    Call CheckAnimDuration Squeeze(value), where
  End

  -- How an incremental table is built. A misspelt value would silently give
  -- the default, which looks like the option does not work.
  Loop name Over .Array~of("head", "steps")
    rest   = body
    needle = 'data-'name'="'
    Loop While rest~pos(needle) > 0
      Parse Var rest . (needle) value '"' rest
      If WordPos(value, TableSteps(name)) > 0 Then Iterate
      .Error~Say( "md2slides: warning:" name'="'value'"' "on slide" -
                  '"'where'"' "is not known, so the default is used." )
      .Error~Say( "                 known values:" TableSteps(name) )
    End
  End

  Return

--------------------------------------------------------------------------------
-- The roles are the fixed master-page set. "list" is the default and needs   --
-- no class, which is why most slides carry no attributes at all.             --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- OwnSlideAttrs -- data-section and data-title are md2slides' own: they say  --
-- which slides open a section, and what the timer and the go dialog (g) call --
-- a slide. Every other attribute the author writes passes through as data-*, --
-- so section= on an ordinary slide made it look like a section opener, and   --
-- renamed the timer's section (inventory of v213). Now section= on a         --
-- .section slide is the section's name (shorter than its title, say), and    --
-- anywhere else it is reported and dropped; title= is reported and dropped.  --
-- Removes both from 'attrs'; returns the section name given, or "".          --
--------------------------------------------------------------------------------

::Routine OwnSlideAttrs Public
  Use Strict Arg attrs, role, where

  name = ""
  If attrs~hasIndex("data-section") Then Do
    If role == "section" Then name = attrs["data-section"]
    Else .Error~Say("md2slides: warning: section= on slide" '"'where'"' -
      "names a section, but this slide does not open one; it is ignored." -
      "A slide opens a section with the class .section.")
    attrs~remove("data-section")
  End
  If attrs~hasIndex("data-title") Then Do
    .Error~Say("md2slides: warning: title= on slide" '"'where'"' "is ignored:" -
      "the title of a slide is its heading, or its '::: title' zone.")
    attrs~remove("data-title")
  End
  Return name

::Routine SlideRoles
  -- (two-col, the old fixed two-column slide, went in v214: `::: row` with
  -- `::: col-N` does it, and as a role it did nothing. As a plain class it
  -- still reaches the <section>, for a master that wants it.)
  Return "title-slide section business-card"

::Routine RenderSlide
  Use Strict Arg attrs, title, body, band, fields

  roles     = SlideRoles()
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

  -- A divider is a navigation anchor; everything else is a page. The section
  -- is named after the title, or after section= when the author gives one.
  sectionName = OwnSlideAttrs(attrs, role, title)
  If sectionName == "" Then sectionName = title
  If role == "section"
    Then marker = ' data-section="'sectionName'"'
    Else marker = ' data-title="'title'"'

  -- Effect names are checked before anything is emitted: the deck still gets
  -- built, but the author hears about a typo now rather than on stage.
  If attrs~hasIndex("data-anim") Then
    Call CheckAnim Squeeze(attrs["data-anim"]), PageAnims(), "page", title
  If attrs~hasIndex("data-anim-duration") Then
    Call CheckAnimDuration Squeeze(attrs["data-anim-duration"]), title
  Call CheckBodyAnims body, title
  body = TableColumns(body, title)

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
  -- sectionStyle is empty now that the per-slide -font-size zones are gone; the
  -- <section> carries no inline style. Kept in the emit for shape/uniformity.
  parsed = SlideIdentity(body, fields, role, title)
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
  -- a SKIN, not a slot. Add the runtime's structural class so the block sits
  -- in the code slot and takes the skin's fixed code size. (Code is no longer
  -- fitted: --skin-code-size is a declared value, not one computed to fill a
  -- box, so there is nothing to compute here.)
  body = AddCodeClass(body)

  body = HoistSpans(body)

  -- `::: incremental` marks a whole list at once: Pandoc renders it as a
  -- <div class="incremental"> (and tags every <ul>/<ol> inside with the same
  -- class). MarkIncrementalItems turns each descendant <li> into a fragment, in
  -- document order, so the author writes one fence instead of `.fragment` on
  -- every bullet. A single item opts out with `{.static}`. This runs BEFORE the
  -- hoist so the items it creates get the same nested-list treatment below.
  body = MarkIncrementalItems(body)

  -- A fragment written on a bullet -- `- [text]{.fragment}` -- attaches in
  -- Pandoc to the item's INLINE content (a <span>), not to the <li> box. In a
  -- nested list the child <ul> is a sibling of that span, OUTSIDE it, so hiding
  -- the parent fragment would leave its sub-bullets showing. HoistListItemFragments
  -- lifts the span's class (and its data-anim) onto the <li>, so the fragment is
  -- the whole item, children included: hide the parent and its subtree goes with
  -- it. Same spirit as HoistSpans -- Pandoc almost gets it right; we give the
  -- last nudge.
  body = HoistListItemFragments(body)
  -- What HoistListItemFragments does not see: `.plain` on an item (no bullet
  -- for it), and an item's fragment or timing in a loose list (<li><p>...).
  body = HoistItemWords(body)

  Select Case role
    When "business-card" Then body = Cards(body)
    Otherwise Nop
  End

  -- Wrap the slide's PROSE in .body, so prose text takes --skin-body-size no
  -- matter where it sits. The old rule wrapped only a single <ul> run and bailed
  -- out entirely when the slide held columns -- so prose that came as bare <p>,
  -- or ANY prose on a slide that also had a :::row, fell through to the slide's
  -- base font-size and rendered smaller than its siblings (the "paragraph after
  -- the row is a different size" bug). The model was wrong: .body is meant to be
  -- "the slide's prose", not "the one central list". WrapProse makes it that:
  -- every top-level prose run (contiguous <p>/<ul>/<ol>) gets its own .body;
  -- structural blocks (title, row, code, output, chrome, cards) are left alone.
  body = WrapProse(body)

  Return body

--------------------------------------------------------------------------------
-- WrapProse - wrap each contiguous run of top-level PROSE in <div class=body>.
--
-- Pandoc emits the slide body as top-level blocks, one per line-start: <p>,
-- <ul>, <ol> are prose; <div class="title|row|code...|chrome">, <pre>, the
-- highlighted code div and the cards are structure. We walk the blocks, group
-- consecutive prose blocks, and wrap each group once. Structure passes through
-- untouched and BREAKS a run, so prose before and after a :::row become two
-- separate .body wrappers, each correctly sized -- which is exactly the fix.
-- Idempotent: a block already inside a .body (or any wrapper) is not at top
-- level here, so it is never re-wrapped.
--------------------------------------------------------------------------------
::Routine WrapProse
  Use Strict Arg body

  lines = body~makeArray("0a"x)      -- one block starts per line at column 0
  out   = ""
  run   = ""                          -- accumulated prose awaiting its wrapper
  mode  = "TOP"                       -- TOP | PROSE | STRUCT (inside a block)
  depth = 0                           -- open-tag depth while inside a block

  Do line Over lines
    Select
      When mode == "STRUCT" Then Do
        out ||= line || "0a"x
        depth += CountOpens(line) - CountCloses(line)
        If depth <= 0 Then mode = "TOP"
      End

      When mode == "PROSE" Then Do
        -- Inside a multi-line prose block (a list): keep collecting until it
        -- closes, then return to TOP still holding the run (more prose may
        -- follow and share the same .body).
        run ||= line || "0a"x
        depth += CountOpens(line) - CountCloses(line)
        If depth <= 0 Then mode = "TOP"
      End

      Otherwise Do   -- mode == "TOP": decide what THIS block is
        trimmed = line~strip("L")
        Select
          When trimmed == "" Then
            -- Blank between blocks: keep with the run if one is building.
            If run \== "" Then run ||= line || "0a"x
                          Else out ||= line || "0a"x

          When trimmed~left(3) == "<p>" | trimmed~left(4) == "<ul>" | -
               trimmed~left(4) == "<ol>" Then Do
            run ||= line || "0a"x
            d = CountOpens(line) - CountCloses(line)
            If d > 0 Then Do; mode = "PROSE"; depth = d; End
          End

          Otherwise Do
            -- Structural block: flush pending prose, then pass it through.
            If run \== "" Then Do
              out ||= '<div class="body">' || "0a"x || run || '</div>' || "0a"x
              run = ""
            End
            out ||= line || "0a"x
            -- A :::contents is TRANSPARENT to the flow: its children are ordinary
            -- blocks that deserve the same wrapping as at slide level. So its
            -- OPENING does not send us opaque -- we stay in TOP and keep wrapping
            -- the prose inside. We simply don't count its <div> into depth; its
            -- matching </div> then arrives later as a lone close in TOP and is
            -- emitted with no effect (d <= 0, so no STRUCT). Structures INSIDE
            -- the contents (row, code, output) still open and close their own
            -- depth normally, so they stay opaque as before. Every other
            -- structural block stays opaque: its inner prose is handled by its
            -- own slot rules (columns size their own <p>, code is code).
            --
            -- A div that only ANIMATES or PLACES what it holds -- `::: fragment`,
            -- or one with just a style, which is where indent= goes -- is
            -- transparent for the same reason. It used to be opaque, so a list
            -- inside `::: fragment` never got its .body: smaller than the same
            -- list one fence away, and without the list spacing and the
            -- per-level sizes.
            If TransparentDiv(trimmed) Then Nop
            Else Do
              d = CountOpens(line) - CountCloses(line)
              If d > 0 Then Do; mode = "STRUCT"; depth = d; End
            End
          End
        End
      End
    End
  End

  If run \== "" Then
    out ||= '<div class="body">' || "0a"x || run || '</div>' || "0a"x

  Return out

--------------------------------------------------------------------------------
-- TransparentDiv - does this line open a div WrapProse should look through?  --
-- One whose classes are all in TransparentClasses, or level-N (or that has  --
-- none at all: a bare div carries attributes, not a role).                   --
--------------------------------------------------------------------------------

::Routine TransparentDiv
  Use Strict Arg line

  If line~left(4) \== "<div" Then Return 0
  If line~left(5) \== "<div ", line~left(5) \== "<div>" Then Return 0
  gt  = line~pos(">")
  If gt == 0 Then Return 0
  tag = line~left(gt)
  If tag~pos('class="') == 0 Then Return 1
  Parse Var tag . 'class="' classes '"'
  Loop w Over classes~space~makeArray(" ")
    If WordPos(w, TransparentClasses()) > 0 Then Iterate
    -- level=N lands as a level-N class: it sizes and marks, it holds nothing.
    If w~startsWith("level-"), w~substr(7)~dataType("W") Then Iterate
    Return 0
  End
  Return 1

-- The classes that only animate a block, time it, or change how its list
-- looks. A div that carries nothing else is looked through by WrapProse, so
-- the list inside it gets its .body -- the size, spacing and per-level fonts
-- of every other list. Missing from here, a `::: {.fragment .withPrevious}`
-- came out at the slide's base size while the `::: fragment` above it was
-- body-sized: Rony's "the font-size of .withPrevious may be wrongly changed".
::Routine TransparentClasses
  Return "contents fragment withPrevious afterPrevious afterClick plain tight static"

--------------------------------------------------------------------------------
-- Count opening / closing block-level tags on one line. Good enough for the
-- one-block-per-line HTML Pandoc emits: we only need to know when a structural
-- <div>/<pre> that opened on this line has not yet closed.
--------------------------------------------------------------------------------
::Routine CountOpens
  Use Strict Arg s
  -- With or without attributes: Pandoc writes <ul class="incremental"> in an
  -- incremental block, and counting only '<ul>' while every '</ul>' counted
  -- threw the depth off -- the scale of the group around it was popped early,
  -- and a scale= or level= after the list no longer saw it (Rony, 27-Sep).
  n = CountMatches(s, "<div")
  Loop t Over .Array~of("pre", "ul", "ol", "p")
    n += CountMatches(s, "<"t">") + CountMatches(s, "<"t" ")
  End
  Return n

::Routine CountCloses
  Use Strict Arg s
  Return CountMatches(s, "</div>") + CountMatches(s, "</pre>") + -
         CountMatches(s, "</ul>") + CountMatches(s, "</ol>") + -
         CountMatches(s, "</p>")

::Routine CountMatches
  Use Strict Arg s, needle
  n = 0; p = 1
  Do Forever
    p = s~pos(needle, p)
    If p = 0 Then Leave
    n += 1; p += needle~length
  End
  Return n

--------------------------------------------------------------------------------
-- Author sugar -> CSS custom properties.                                     --
--                                                                            --
-- The runtime is driven by custom properties (--contents-scale, ...), but a  --
-- custom property in style="" is plumbing: `{style="--contents-scale:0.83"}` --
-- is a horrible thing to ask an author to type. So the author writes a plain --
-- attribute -- `::: {.contents scale=0.83}` -- and Pandoc hands us           --
-- <div ... data-scale="0.83">. TranslateSugar rewrites those into a style="".--
--                                                                            --
-- SugarMap is the whole vocabulary: author name -> custom property. It is the--
-- ONE place that grows. A new convenience is a new row here; the mechanism   --
-- below never changes. That is the point -- once we trade plumbing for       --
-- legibility we will want to do it again and again, and each time should cost--
-- a line, not a branch.                                                      --
--                                                                            --
-- SCALE COMPOSES BY MULTIPLICATION, and we do it HERE, not in CSS: a 0.9     --
-- nested in a 0.8 must render at 0.72, but CSS custom properties cannot      --
-- multiply an inherited value by a local one (self-reference is forbidden).  --
-- So we keep a stack of the scale in force and emit each group's PRODUCT     --
-- outright. The author writes 0.9; the generator writes 0.72. Composition is --
-- ours to compute -- exactly the kind of work we take on so the author does  --
-- not have to. Other sugars are per-tag and need no stack; scale is special  --
-- because it is the one that accumulates through nesting.                    --
--------------------------------------------------------------------------------
::Routine SugarMap
  map = .StringTable~new
  map["scale"]  = "--contents-scale"   -- shrink a whole contents/row's text
  map["indent"] = "margin-inline-start" -- push a block in from the left edge
  Return map

-- Walk the HTML, carrying a stack of the multiplied scale in force. Each     --
-- .contents/.row that opens multiplies its own scale into the stack top and  --
-- emits the product; the div's close pops it. Non-scale sugar is per-tag.    --
::Routine TranslateSugar
  Use Strict Arg html

  scales = .Array~new           -- stack of accumulated scale factors
  depths = .Array~new           -- the block-depth at which each push happened
  depth  = 0                    -- running open-block depth

  out = ""
  -- The slides are not folded yet: one opens at each marker, or at each <h1>
  -- in a deck opened by headings. Counted only to say where a warning is.
  opener = "<h1"
  If html~pos('<hr class="slide"') > 0 Then opener = '<hr class="slide"'
  slide = 0
  Do line Over html~makeArray("0a"x)
    trimmed = line~strip("L")
    slide += line~countStr(opener)

    -- scale= must be a positive number: "abc" stopped the build (arithmetic
    -- on a word, below), and 0 or -1 would have made the text vanish or turn
    -- over. A bad one is reported and dropped; the block keeps the scale
    -- around it.
    own = SugarValue(line, "scale")
    If own \== "", \PositiveNumber(own) Then Do
      place = ""
      If slide > 0 Then place = "slide" slide": "
      .Error~Say("md2slides: warning:" place"scale="own "is not a" -
        "positive number (like 0.8); it is ignored.")
      line = DropSugar(line, "scale")
    End

    -- A group is a div whose CLASS LIST holds `contents` or `row`, wherever
    -- the word sits: `::: {.incremental .plain .contents scale=0.7}` reaches
    -- us as class="incremental plain contents", and used to be missed (its
    -- scale applied, but a block nested in it did not compose with it).
    isGroup = 0
    If trimmed~pos("<div") == 1 Then Do
      classes = " "SugarValue(line, "class")" "
      isGroup = (classes~pos(" contents ") > 0) | (classes~pos(" row ") > 0)
      -- scale= on any other block -- `::: {.fragment scale=0.85}` -- makes it
      -- a scaled group too. It did nothing (Rony, 27-Sep): the size rules only
      -- reach text inside a .contents or a .row, and inside one its 0.85
      -- stood in for the 0.85 around it instead of multiplying it. `contents`
      -- means nothing else, so the block takes the class and joins the stack.
      If \isGroup, SugarValue(line, "scale") \== "" Then Do
        gt = line~pos(">")
        cp = line~pos('class="')
        If cp > 0, cp < gt Then line = line~left(cp + 6) || "contents " || line~substr(cp + 7)
        Else line = line~left(gt - 1) || ' class="contents"' || line~substr(gt)
        isGroup = 1
      End
    End

    -- The scale in force OUTSIDE this tag. A level=N block measures its indent
    -- in it (see LevelRules): the bullets it lines up with are out there, at
    -- that scale, whatever scale= the block itself carries.
    inherited = 1
    If scales~items > 0 Then inherited = scales[scales~items]
    level = SugarValue(line, "level")

    If isGroup Then Do
      -- pull this group's own scale (if any) and compute the product
      own = SugarValue(line, "scale")
      If own \== "" Then Do
        prod = inherited * own
        line = SugarToStyle(line, "scale", prod)   -- emit the PRODUCT
        scales~append(prod)
      End
      Else
        scales~append(inherited)                    -- no local scale: carry it
      depths~append(depth)
    End

    -- any OTHER (per-tag) sugar on this line is translated as-is, on the tag
    -- that carries it: a line is often more than one tag, `- [x]{indent=2em}`
    -- being '<li><span data-indent="2em">x</span></li>' (see SugarPerTag)
    line = SugarPerTag(line)

    -- The anchor goes on the tag that asked for the level, too. On the first
    -- tag of the line it landed on the <li> around `- [x]{level=2}`, and an
    -- <li> with a style is no longer one MarkItems makes a step of: in an
    -- incremental list the item came in with its parent (Rony, 27-Sep).
    If level \== "", trimmed~pos("<") == 1 Then Do
      Parse Value TagWith(line, "level") With lt gt
      If lt > 0 Then
        line = line~left(lt - 1) || -
          AddStyle(line~substr(lt, gt - lt + 1), "--level-anchor: "inherited";") || -
          line~substr(gt + 1)
    End

    out ||= line || "0a"x

    -- track depth; when a group we pushed for closes, pop its scale
    depth += CountOpens(line) - CountCloses(line)
    Do While depths~items > 0
      If depth > depths[depths~items] Then Leave
      scales~delete(scales~items)
      depths~delete(depths~items)
    End
  End

  Return out~left(out~length - 1)

--------------------------------------------------------------------------------
-- level=N - render a block "as if it sat at outline level N".                --
--                                                                            --
-- A stray line of Rexx syntax is not part of any list, so it takes the body  --
-- size and hugs the left edge. Rony wanted it to READ as a nested bullet     --
-- (indented, a touch smaller, its own marker) without wrapping it in a real  --
-- list. level=N does that on any :::, the same way indent= and scale= do.    --
--                                                                            --
-- A real nested list carries THREE things at once, and level=N reproduces    --
-- all three:                                                                 --
--   1. font-size  -- the outline cascade. runtime.css sets it structurally   --
--      (.body ul ul {0.82em} ...): a between-level ratio that COMPOUNDS down  --
--      the tree, so the effective size vs. level 1 is 1 / .82 / .73 / .64.    --
--      There is no nested <ul> here to make the em compound on its own, so    --
--      the generator resolves the PRODUCT and emits it -- exactly what        --
--      scale= already does, and for the same reason (CSS cannot multiply an   --
--      inherited value by a local one). LevelCascade owns the one copy of     --
--      those ratios; a contract test pins it to the CSS so the two cannot     --
--      drift.                                                                 --
--   2. indent -- a real ul carries padding-left:1.1em PER LEVEL (runtime.css).--
--      N levels is N*1.1em, but each em is the em OF ITS LEVEL, already        --
--      shrunk. Here the whole block renders at the level-N em, so 1.1em would  --
--      under-indent: we divide the base indent by the effective factor to get  --
--      back to the level-1 em the ancestors were measured in. (This is the     --
--      "divide by the accumulated factor" the design flagged.)                 --
--   3. marker -- the browser's default disc/circle/square cycles by STRUCTURAL --
--      depth, which we don't have. So we set list-style-type explicitly per    --
--      level. Only takes effect if the block is itself a list; a bare <p> at   --
--      level N simply has no marker, which is correct.                         --
--                                                                            --
-- font-size rides var(--contents-scale) so level= and scale= compose; the    --
-- generator already folded scale nesting into that property upstream.        --
--------------------------------------------------------------------------------

::Routine TranslateLevel
  Use Strict Arg html

  out = ""
  Do line Over html~makeArray("0a"x)
    n = SugarValue(line, "level")
    -- A level that is not a whole number from 1 up would do nothing, silently
    -- (found 26-Sep): it is reported. Past 6 it is 6 -- sizes stop changing at
    -- 4 and markers at 3, so nothing is lost -- and there are rules up to 6.
    If n \== "", \(n~dataType("W") & n >= 1) Then Do
      Call Warn "level="n "is not a level (1, 2, 3...); ignored."
      n = ""
    End
    written = n
    If n \== "", n > 6 Then n = 6
    -- On the tag that carries the level (see TagWith): the first class="" on
    -- the line, or its last ">", could be another tag's.
    If n \== "" Then Do
      Parse Value TagWith(line, "level") With lt gt
      If lt > 0 Then
        line = line~left(lt - 1) || -
          LevelToClass(line~substr(lt, gt - lt + 1), n, written) || -
          line~substr(gt + 1)
    End
    out ||= line || "0a"x
  End
  Return out~left(out~length - 1)

-- BlankBeforeListings - a blank line between a paragraph and the highlighted --
-- listing written right under it.                                            --
--                                                                            --
-- "Example" on the line above a ```rexx fence reached Pandoc as text followed --
-- by FencedCode's raw <div>, and Pandoc made the text a bare line -- no <p>,  --
-- so no .body, no size and no level= indent -- where the same line above an  --
-- ```output fence, which Pandoc reads itself, is a paragraph (Rony, 27-Sep:  --
-- with level=2 "Output:" was indented and "Example" was not). Only a listing --
-- at the left margin: inside a list item the text above it is the item's,    --
-- and a blank line there would make the whole list a loose one.              --
::Routine BlankBeforeListings Public
  Use Strict Arg source
  out  = .Array~new
  prev = ""
  Loop line Over source
    If line~startsWith('<div class="highlight-'), prev~strip \== "" Then
      out~append("")
    out~append(line)
    prev = line
  End
  Return out

--------------------------------------------------------------------------------
-- flow=N - a long list flowed into N columns (Rony, 27-Sep: the 67 BIFs in   --
-- five columns, RexxUtil's functions in three).                              --
--                                                                            --
--     ::: {.plain flow=5}              ::: {.incremental flow=3 fill=rows}   --
--     - `ABBREV()`                     - ...                                 --
--                                                                            --
-- By default the list fills column by column, top to bottom, like his two   --
-- slides; fill=rows fills row by row. The ::: gets the class `flow` (and    --
-- `flow-rows`) and --flow: N, and runtime.css does the rest: CSS columns,   --
-- which balance the heights, or a grid. In an incremental block the items   --
-- come in the order they are read in. (`cols=` was taken: it is the         --
-- proportions of a table's columns.)                                        --
--------------------------------------------------------------------------------

::Routine TranslateFlow Public
  Use Strict Arg html

  If html~pos('flow="') == 0 Then Return html

  out = ""
  Do line Over html~makeArray("0a"x)
    Parse Value TagWith(line, "flow") With lt gt
    If lt > 0 Then Do
      tag  = line~substr(lt, gt - lt + 1)
      n    = SugarValue(tag, "flow")
      fill = Lower(SugarValue(tag, "fill"))
      tag  = DropSugar(DropSugar(tag, "flow"), "fill")
      If \(n~dataType("W") & n >= 1) Then
        Call Warn "flow="n "is not a number of columns (2, 3...); ignored."
      Else Do
        If WordPos(fill, "rows columns") == 0, fill \== "" Then Do
          Call Warn "fill="fill "is not rows or columns; the list fills" -
                    "column by column."
          fill = ""
        End
        classes = "flow"
        If fill == "rows" Then classes = "flow flow-rows"
        cp = tag~pos('class="')
        If cp > 0 Then tag = tag~left(cp + 6) || classes" " || tag~substr(cp + 7)
        Else tag = tag~left(tag~length - 1)' class="'classes'">'
        tag = AddStyle(tag, "--flow: "n";")
      End
      line = line~left(lt - 1) || tag || line~substr(gt + 1)
    End
    out ||= line || "0a"x
  End
  Return out~left(out~length - 1)

--------------------------------------------------------------------------------
-- offset= - pictures in a cascade (v225; Rony's ODP collection, 29-Sep:      --
-- five screenshots each a little right of and below the one before).        --
--                                                                            --
--     ::: {.layers offset="40px 30px"}                                       --
--     ![](img/a.png)                                                         --
--                                                                            --
--     ![](img/b.png){.fragment .afterPrevious}                               --
--     :::                                                                    --
--                                                                            --
-- Each picture after the first is moved that much further right and down    --
-- than the one before it. One length moves it that much both ways. The      --
-- ::: gets the class `offset` and --layers-dx/--layers-dy, and runtime.css   --
-- does the rest: the pictures share one grid cell, so the cascade stays IN   --
-- FLOW and the block is as big as the whole cascade (what comes under it     --
-- comes under the last picture, not under the first). Only on ::: layers;   --
-- only lengths, and not %, which in a grid cell would refer to the cell      --
-- itself.                                                                    --
--------------------------------------------------------------------------------

::Routine TranslateOffset Public
  Use Strict Arg html

  If html~pos('offset="') == 0 Then Return html

  out = ""
  Do line Over html~makeArray("0a"x)
    Parse Value TagWith(line, "offset") With lt gt
    If lt > 0 Then Do
      tag  = line~substr(lt, gt - lt + 1)
      spec = SugarValue(tag, "offset")
      tag  = DropSugar(tag, "offset")
      Parse Value spec~changeStr(",", " ") With dx dy extra
      If dy == "" Then dy = dx
      Parse Var tag . 'class="' classes '"'
      If WordPos("layers", classes) == 0 Then
        Call Warn 'offset="'spec'" only works on a ::: layers block; ignored.'
      Else If \OffsetLength(dx) | \OffsetLength(dy) | extra \== "" Then
        Call Warn 'offset="'spec'" is not one or two lengths (40px,' -
                  '1.5em, 1cm...); ignored.'
      Else Do
        cp = tag~pos('class="')
        tag = tag~left(cp + 6) || "offset " || tag~substr(cp + 7)
        tag = AddStyle(tag, "--layers-dx: "dx"; --layers-dy: "dy";")
      End
      line = line~left(lt - 1) || tag || line~substr(gt + 1)
    End
    out ||= line || "0a"x
  End
  Return out~left(out~length - 1)

-- OffsetLength - is `v` a length offset= takes: 0, or a non-negative number --
-- with a unit of length (no %: see TranslateOffset).                         --
::Routine OffsetLength Public
  Use Strict Arg v
  If v == "0" Then Return 1
  Do unit Over .Array~of("px", "em", "rem", "cm", "mm", "pt", "in")
    If \v~caselessEndsWith(unit) Then Iterate
    n = v~left(v~length - unit~length)
    If n == "" Then Return 0
    Return n~dataType("N") & n >= 0 & n~verify("0123456789.") == 0
  End
  Return 0

-- TagWith - "lt gt": where the opening tag that carries the sugar attribute  --
-- `name` (data-name="..." or name="...") begins and ends in `line`, or "0 0". --
::Routine TagWith Public
  Use Strict Arg line, name
  Do variant Over ("data-"name, name)
    p = line~pos(" "variant'="')
    If p == 0 Then Iterate
    lt = line~lastPos("<", p)
    gt = line~pos(">", p)
    If lt > 0, gt > 0 Then Return lt gt
  End
  Return 0 0

-- SugarPerTag - SugarToStyle on each opening tag of a line, one at a time.   --
-- SugarToStyle reads its argument as ONE tag and writes the style before its --
-- last ">": given '<li><span data-indent="2em">x</span></li>' whole, it wrote --
-- '</li style="...">', which does nothing.                                   --
::Routine SugarPerTag Public
  Use Strict Arg line
  If line~pos('="') == 0 Then Return line
  out = .MutableBuffer~new
  p = 1
  Loop Forever
    lt = line~pos("<", p)
    If lt == 0 Then Leave
    gt = line~pos(">", lt)
    If gt == 0 Then Leave
    tag = line~substr(lt, gt - lt + 1)
    If tag~left(2) \== "</", tag~left(2) \== "<!" Then tag = SugarToStyle(tag)
    out~append(line~substr(p, lt - p), tag)
    p = gt + 1
  End
  out~append(line~substr(p))
  Return out~string

-- Turn a tag's data-level="N" into a `level-N` CLASS, not an inline style.    --
--                                                                            --
-- An inline font-size on the group div does NOT work: the .body inside carries--
-- its own `font-size: var(--skin-body-size)` and RESETS it, and the outline   --
-- and scale rules target the child ul/p with a specificity a div style cannot --
-- beat. So the size has to land on `.contents.level-N > .body` and the marker --
-- on the ul, at the right specificity -- which is a CLASS plus a CSS rule (the --
-- LevelRules stylesheet), not an inline declaration. This is why level= is a  --
-- class where scale=/indent= are inline: those set a custom property the child --
-- rules already read, level= must OUT-rank those same child rules.            --
::Routine LevelToClass
  Use Strict Arg tag, n, written = (n)

  work = tag
  -- drop the data-level / level attribute now it is consumed
  Do variant Over ("data-level", "level")
    work = work~changeStr(' 'variant'="'written'"', "")
  End

  -- add the level-N class to the existing class="..." (there always is one on a
  -- :::group; if somehow not, add it)
  cp = work~pos('class="')
  If cp > 0 Then Do
    ins = cp + 7
    Return work~substr(1, ins-1)'level-'n' 'work~substr(ins)
  End
  gt = work~lastPos(">")
  Return work~substr(1, gt-1)' class="level-'n'"'work~substr(gt)

--------------------------------------------------------------------------------
-- LevelRules - the CSS that makes `.level-N` render as outline level N.       --
--                                                                            --
-- Emitted into the deck's <style> (like the rest of the runtime), one rule    --
-- block per level 1..maxLevel actually used. Each level sets, at a specificity--
-- that beats .body and the outline/scale child rules:                        --
--   - font-size on `.contents.level-N > .body` (the block where size lives),  --
--     as the resolved compound * var(--contents-scale) so scale= still rides; --
--   - margin-inline-start on the children (lists, paragraphs, code, tables)--
--     so their text starts where a level-N item's text does, measured at the --
--     scale of the context (--level-anchor, written by TranslateSugar);      --
--   - list-style-type on the inner ul/ol (the marker of that level).         --
-- The compound factors and the 1.1em come from LevelCascade -- one source,    --
-- pinned to runtime.css by a contract test.                                  --
--------------------------------------------------------------------------------

::Routine LevelRules Public
  Use Strict Arg maxLevel = 6
  baseIndent = 1.1                          -- one ul's padding-left, in em
  css = ""
  Do n = 1 To maxLevel
    factor = LevelCascade(n)
    marker = LevelMarker(n)
    -- (History: the indent was once N * 1.1 / fN on the enclosing div, whose
    -- em is not the text's -- level=2 landed 45px past a real level-2 bullet.)
    above = 0
    Do k = 1 To n - 1
      above = above + LevelCascade(k)
    End
    sz = "font-size: calc(var(--skin-body-size, 1em) *" factor -
         "* var(--contents-scale, 1)); "
    -- THE INDENT. Everything at level N lines up on one vertical line: where
    -- the TEXT of a real level-N item starts. That is past the padding of every
    -- list down to level N, each 1.1em of its own level's size:
    --   K = 1.1 * (f1 + ... + fN)          body-size units
    -- and it is measured at the scale of the CONTEXT, --level-anchor, which the
    -- generator writes on every level= block (TranslateSugar): the scale in
    -- force outside the block. Not the block's own: `{level=1 scale=0.7}` under
    -- a level-1 bullet has to start where that bullet's text starts, and the
    -- bullet is not shrunk (Rony, 26-Sep: a table there sat 9px short once it
    -- was indented at all). Without an anchor (a hand-built page) the block's
    -- own scale stands in, which is right whenever the block sets none.
    --   - a list (or the .body holding it) brings its own level-N padding,
    --     1.1em of its own size, so its margin is K minus that;
    --   - a paragraph, a code block, a table has no padding of its own: K.
    -- Unscaled, the list margin is 1.1 * (f1 + ... + f(N-1)), zero at level 1:
    -- the old em-based rule, which scale= then shrank along with the text.
    K = Em(baseIndent * (above + factor))
    at = "calc(var(--skin-body-size, 1em) *" K "* var(--level-anchor, var(--contents-scale, 1))"
    -- The size lands on the SAME consumers the contents-scale cascade targets  --
    -- (runtime.css): a wrapped body, OR a bare ul/ol/p that WrapProse left     --
    -- unwrapped (the .plain case), each also reachable through one .fragment.   --
    -- We must cover both because a level= block may or may not get a .body,     --
    -- exactly like a scaled one.                                               --
    -- Anchor on `.level-N` alone, not `.contents.level-N`. level=N is written on
    -- whatever block the author reaches for -- a `:::contents`, but just as often
    -- a bare `:::fragment` (Rony's Branch slides: `{.fragment level=2}`), where
    -- the class lands as `class="level-2 fragment"` with no .contents ancestor.
    -- Tying the rule to .contents made every such case a no-op (level-1 bullet,
    -- no indent, no size) -- the reported bug.
    --
    -- The class is DOUBLED (`.level-N.level-N`) on purpose. The generic content
    -- rules in runtime.css that also hit these children -- e.g.
    -- `.slide .contents > .fragment > ul` -- carry three classes + a type
    -- (0,3,1). A single `.slide .level-N > ul` is only (0,2,1) and would LOSE
    -- the cascade, so level= set the marker/indent but the generic size won,
    -- leaving level-1 and level-2 the same size. Doubling the class buys the
    -- third class back (0,3,1), tying the specificity; level rules are emitted
    -- AFTER runtime.css, so the tie breaks in level='s favour -- exactly what
    -- the old `.contents.level-N` did, but now independent of a .contents
    -- ancestor. (Honest specificity, not !important.)
    g = ".slide .level-"n".level-"n
    css ||= g" > .body,"           g" > .fragment > .body," -
            g" > ul,"             g" > ol,"  g" > p," -
            g" > .fragment > ul," g" > .fragment > ol," g" > .fragment > p {" -
            sz"margin-inline-start:" at "- "baseIndent"em); }" "0a"x
    -- A PARAGRAPH at level N (Rony: `Output:` in a `.plain level=2`) has no
    -- list to bring the level's padding: the whole K. One inside the .body
    -- (whose margin already stops short by one padding) adds that padding
    -- back: 1.1em of its own size.
    css ||= g" > p," g" > .fragment > p {" -
            "margin-inline-start:" at"); }" "0a"x
    css ||= g" > .body > p," g" > .fragment > .body > p {" -
            "margin-inline-start:" baseIndent"em; }" "0a"x
    -- CODE, OUTPUT and TABLES keep their own sizes (--skin-code-size, and 0.9
    -- of the body for a table) and are indented to the same K (Rony: a ```rexx
    -- in `{.fragment level=2}` stayed at the left edge, 23-Sep; a table in
    -- `{.incremental level=1}` did, 26-Sep). A code block is 100% wide by
    -- default (runtime.css), which the margin would push past the right edge:
    -- auto fills what is left. A table is as wide as its cells already.
    css ||= g" > .code,"  g" > .fragment > .code," -
            g" > pre,"    g" > .fragment > pre," -
            g" > figure.listing," g" > .fragment > figure.listing {" -
            "margin-inline-start:" at"); width: auto; }" "0a"x
    css ||= g" > table,"  g" > .fragment > table {" -
            "margin-inline-start:" at"); }" "0a"x
    -- `:not(.plain *)`: a list inside a .plain block keeps no marker, level=
    -- or not. The level rule outranks `.slide .plain ul` on specificity, so
    -- without this `{.fragment level=1 .plain}` showed its bullet anyway.
    -- Only a BULLETED list takes the level's bullet: a numbered one keeps its
    -- numbers (Rony, 28-Sep: `1.` items in a level=2 block came out as circles).
    css ||= g" ul:not(.plain *) {" -
            "list-style-type:" marker"; }" "0a"x
    -- A list NESTED inside the block is one level deeper, and so on down
    -- (Rony, 24-Sep: `* Exception` under a `level=2` item came out with the
    -- level-2 circle and a level-2 step, 0.82, where a real level 3 has the
    -- square and the L3/L2 step, 0.89). The marker rule above reaches every
    -- list in the block, and runtime.css sizes a nested list by its depth
    -- under the .body (.body ul ul is 0.82em whatever level the block
    -- stands for). Each depth gets its own level's marker and step; the
    -- selectors grow more specific with depth, so the deepest match wins.
    -- Three depths reach level 4 from any block, and level 4 is where the
    -- steps and markers stop changing.
    -- A numbered list counts as a level too (Rony, 28-Sep), so the depth is
    -- counted in :is(ul, ol); only a bulleted list takes the level's bullet.
    sub = g
    Do d = 1 To 3
      sub = sub" :is(ul, ol)"
      step = LevelCascade(n + d) / LevelCascade(n + d - 1)
      css ||= sub" :is(ul, ol) {" -
              "font-size:" Em(step)"em; }" "0a"x
      css ||= sub" ul:not(.plain *) {" -
              "list-style-type:" LevelMarker(n + d)"; }" "0a"x
    End
  End
  Return css

-- A number of em for a rule: three decimals at most, no trailing zeros.
::Routine Em
  Use Strict Arg v
  Return v~format(, 3)~strip("T", "0")~strip("T", ".")

--------------------------------------------------------------------------------
-- LevelCascade - the effective font-size of outline level N vs. level 1.     --
--                                                                            --
-- THE SINGLE SOURCE for the outline ratios. runtime.css writes them          --
-- structurally as between-level steps; here we hold the SAME steps and        --
-- return their running product, because level=N has no nested <ul> to let the --
-- em compound by itself. Level 1 is 1. Level 4 is the floor and every deeper  --
-- level stays there, matching the CSS (.body ul ul ul ul is the last step).   --
--                                                                            --
-- Between-level steps (corpus medians, identical to runtime.css:195-197):    --
--   L2/L1 = 0.82   L3/L2 = 0.89   L4/L3 = 0.88   L5+ = flat                   --
-- Effective vs L1: 1.00 / 0.82 / 0.7298 / 0.6422 ...                          --
--                                                                            --
-- A contract test reads THIS routine and the CSS and fails if they diverge.  --
--------------------------------------------------------------------------------

::Routine LevelCascade Public
  Use Strict Arg n
  steps = .Array~of(0.82, 0.89, 0.88)        -- L2/L1, L3/L2, L4/L3
  factor = 1
  Do i = 2 To n
    idx = i - 1
    If idx > steps~items Then Leave           -- floor: no step past level 4
    factor = factor * steps[idx]
  End
  Return factor~format(, 4)~strip("T", "0")~strip("T", ".")

-- The list marker at outline level N, as browsers draw a real nested list:
-- disc, circle, then square at level 3 and at every level below it. (It
-- used to cycle back to disc at level 4; a real level-4 bullet is a square.)
::Routine LevelMarker Public
  Use Strict Arg n
  Return Word( "disc circle square", Min( n, 3 ) )

--------------------------------------------------------------------------------
-- CheckIndents - indent= must be a CSS length. A bare number, or a typo in   --
-- the unit, reaches the browser as an invalid declaration and is dropped     --
-- without a word: the block simply does not move. So say it at build time,   --
-- and say on which slide.                                                    --
--------------------------------------------------------------------------------

::Routine CheckIndents Public
  Use Strict Arg html

  rest = html
  done = 0
  Loop While rest~pos('data-indent="') > 0
    Parse Var rest pre 'data-indent="' value '"' after
    done = done + (rest~length - after~length)
    rest = after
    If IsCssLength(value) Then Iterate
    slide = SlideNumberAt(html, done)
    If slide > 0 Then place = "slide" slide": "
    Else place = ""
    Call Warn place'indent="'value'" is not a length, so the block is not' -
      "indented. Give a number and a unit: indent=1cm, indent=2em," -
      "indent=40px, indent=5%."
  End
  Return 0

--------------------------------------------------------------------------------
-- IsCssLength - a number followed by a CSS unit, or a bare 0.                --
--------------------------------------------------------------------------------

::Routine IsCssLength Public
  Use Strict Arg value

  v = value~strip~lower
  If v == "0" Then Return 1
  units = "cm mm q in pt pc px em rem ex ch lh vw vh vmin vmax %"
  Loop u Over units~makeArray(" ")
    If v~length <= u~length Then Iterate
    If v~right(u~length) \== u Then Iterate
    n = v~left(v~length - u~length)
    If n~verify("0123456789.-+") > 0 Then Iterate
    If n~dataType("N") Then Return 1
  End
  Return 0

-- The flags md2slides hands to Pandoc, in one place: a test that needs "what
-- Pandoc gives md2slides" calls this instead of retyping the flags, so the two
-- cannot drift apart (a test helper once did, and hid a bug behind it).
--
-- --preserve-tabs: Pandoc otherwise turns every tab in a code block into
--   blanks, so an output block could never show a tab, marked or not.
-- --columns=1000: Pandoc measures pipe-table rows against --columns (72 by
--   default). A table with any row longer than that gets a <colgroup> of
--   percentage widths, and the browser then stretches it to the full width of
--   whatever holds it -- while a table with short rows stays as wide as its
--   contents. Two tables written the same way came out one wide and one
--   tight, depending on nothing but the length of a cell (Rony's Operator /
--   Meaning table). On a slide the source line length means nothing, so the
--   limit is pushed out of the way and every table sizes to its contents;
--   .slide table { max-width: 100% } in runtime.css keeps a really wide one
--   wrapping instead of overflowing the canvas.
-- --wrap=none: Pandoc otherwise re-flows the HTML it emits at --columns, and
--   a line break may fall INSIDE a tag: `<span\nclass="static">`. Every
--   detector here reads the flat HTML line by line, so a marker split across
--   two lines is a marker not seen -- the demo deck had a `{.static}` item
--   that animated anyway for exactly this reason. With no re-flow, a tag is
--   always whole. (This does not change the HTML, only where its lines end;
--   nothing inside <pre> is touched either way.)
::Routine PandocOptions Public
  Return "--from markdown-smart+footnotes --to html5 --preserve-tabs" -
         "--wrap=none --columns=1000"

-- Read one sugar attribute's raw value from a tag (data-NAME or NAME), or "".
::Routine SugarValue
  Use Strict Arg tag, name
  Do variant Over ("data-"name, name)
    needle = variant'="'
    p = tag~pos(needle)
    If p == 0 Then Iterate
    vstart = p + needle~length
    vend   = tag~pos('"', vstart)
    If vend == 0 Then Iterate
    Return tag~substr(vstart, vend - vstart)
  End
  Return ""

-- Rewrite mapped sugar on ONE tag into an appended/merged style="".
-- Two modes:
--   SugarToStyle(tag)                  -> translate every mapped sugar as-is
--   SugarToStyle(tag, name, override)  -> translate `name` using `override` as
--                                         its value (used for the scale product)
::Routine SugarToStyle
  Use Strict Arg tag, only = "", override = ""
  map = SugarMap()

  decls = ""
  work  = tag
  Do name Over map~allIndexes
    If only \== "", name \== only Then Iterate   -- targeted mode: this name only
    prop = map[name]
    Do variant Over ("data-"name, name)
      needle = variant'="'
      p = work~pos(needle)
      If p == 0 Then Iterate
      vstart = p + needle~length
      vend   = work~pos('"', vstart)
      If vend == 0 Then Iterate
      value  = work~substr(vstart, vend - vstart)
      emit   = value
      If only \== "", override \== "" Then emit = override
      decls  = decls || prop': 'emit'; '
      work   = work~changeStr(' 'needle||value'"', "")
    End
  End

  If decls == "" Then Return tag       -- no sugar: byte-identical

  decls = decls~strip
  sp = work~pos('style="')
  If sp > 0 Then Do
    ins = sp + 7
    Return work~substr(1, ins-1) || decls' ' || work~substr(ins)
  End
  gt = work~lastPos(">")
  Return work~substr(1, gt-1)' style="'decls'"'work~substr(gt)

--------------------------------------------------------------------------------
-- Captions (v214) -- what numberFigures.js does in the article pipelines,    --
-- done at build:                                                             --
--   - a code block with caption= (FencedCode, or Pandoc for other            --
--     languages, leaves it as data-caption on the block's <div>, or on its   --
--     <pre> for a language Pandoc does not highlight) is wrapped             --
--     in <figure class="listing"> with a <figcaption>, above the code or     --
--     below it (listings: caption-position:);                                --
--   - the <figcaption> Pandoc gives a picture stays below it, or goes above  --
--     (figures: caption-position:).                                          --
-- With number-figures: true, listings and figures are numbered, each on its  --
-- own, through the deck: "Listing 2: ", in the deck's lang: (or the label:   --
-- given). Unlike an article, a deck does not number unless asked: a slide    --
-- is shown one at a time, and "Listing 7" says little on it.                 --
-- A listing inside a `::: fragment` is wrapped inside it, so its caption     --
-- arrives with it. A listing or a picture that is itself a fragment gives    --
-- its step to the figure (v220, HoistBox): same result.                      --
--------------------------------------------------------------------------------

::Routine Captions Public
  Use Strict Arg html, opts

  number = 0
  If opts~isA(.StringTable) Then number = (opts["number-figures"] == 1)
  listPos   = CaptionOpt(opts, "listing-caption-position", "above")
  listLabel = CaptionOpt(opts, "listing-label", "")
  figPos    = CaptionOpt(opts, "figure-caption-position", "below")
  figLabel  = CaptionOpt(opts, "figure-label", "")
  lang      = CaptionOpt(opts, "language", "en")
  If listLabel == "" Then listLabel = CaptionLabel("listing", lang)
  If figLabel  == "" Then figLabel  = CaptionLabel("figure",  lang)

  -- Listings: <div ... data-caption="..."> ... </div>
  needle = ' data-caption="'
  out = .MutableBuffer~new
  n = 0; p = 1
  Loop
    at = html~pos(needle, p)
    If at == 0 Then Leave
    -- The block is the element whose tag CARRIES the attribute. Pandoc puts
    -- it on a <div class="sourceCode"> for a language it highlights, but on
    -- the bare <pre> for one it does not (```output, plain text). Taking
    -- "the last <div before it" instead wrapped whatever div was open around
    -- a <pre>: a ::: fragment (the caption showed before its listing), a
    -- ::: col-N (the column went inside the figure), the title...
    start = html~lastPos("<", at)
    vEnd  = html~pos('"', at + needle~length)
    tag   = ""
    If start >= p Then Parse Value html~substr(start + 1, at - start) With tag " "
    If vEnd == 0 | (tag \== "div" & tag \== "pre") Then Do  -- not a block: leave it
      out~append(html~substr(p, at + 1 - p)); p = at + 1
      Iterate
    End
    text  = html~substr(at + needle~length, vEnd - at - needle~length)
    If tag == "div" Then close = MatchDiv(html, start)
    Else Do
      close = html~pos("</pre>", start)
      If close == 0 Then Do
        out~append(html~substr(p, at + 1 - p)); p = at + 1
        Iterate
      End
      close += Length("</pre>")
    End
    block = html~substr(start, close - start)
    block = block~changeStr(needle || text'"', "", 1)
    -- The figure is the box on the slide, caption and all (v220; v219 for
    -- file boxes only). So what makes it a box on the slide -- its id (an
    -- arrow's end), its step and timing, anim=, group=, level= -- moves up
    -- from the block to the figure: a ```output {.fragment caption=...}
    -- showed its caption a step before its lines.
    box   = HoistBox(block)
    block = box[4]
    If box[5] Then Do
      -- A file box (v219): the name goes INSIDE the box, on top, always, and
      -- is not a numbered listing.
      fig = "<figure"box[1]' class="'Space("listing file" box[2])'"'box[3]">" -
            || "<figcaption>"text"</figcaption>"block"</figure>"
      out~append(html~substr(p, start - p), fig)
      p = close
      Iterate
    End
    figOpen = "<figure"box[1]' class="'Space("listing" box[2])'"'box[3]">"
    n += 1
    cap = "<figcaption>"
    If number Then cap ||= '<span class="figure-number">'listLabel"&nbsp;"n":&ensp;</span>"
    cap ||= text"</figcaption>"
    If listPos == "below" Then fig = figOpen || block || cap"</figure>"
    Else                       fig = figOpen || cap || block"</figure>"
    out~append(html~substr(p, start - p), fig)
    p = close
  End
  out~append(html~substr(p))
  html = out~string

  -- Figures: Pandoc's <figure> (no class) with a <figcaption>. Pandoc puts
  -- the picture's id on the figure ('<figure id="x">': a literal "<figure>"
  -- missed those, so they were neither numbered nor moved), but its classes
  -- and attributes on the <img>.
  out = .MutableBuffer~new
  n = 0; p = 1
  Loop
    at = html~pos("<figure", p)
    If at == 0 Then Leave
    gt = html~pos(">", at)
    If gt == 0 Then Leave
    open = html~substr(at, gt + 1 - at)
    -- Not a figure tag at all ("<figures"), or one built above (a listing or
    -- a file box: those carry a class): leave it.
    If (open \== "<figure>" & \open~startsWith("<figure ")) | TagClasses(open) \== "" Then Do
      out~append(html~substr(p, gt + 1 - p)); p = gt + 1
      Iterate
    End
    e = html~pos("</figure>", gt)
    If e == 0 Then Leave
    body = html~substr(gt + 1, e - gt - 1)
    e = e + Length("</figure>")
    -- The picture's step and timing, anim=, group=, level=, move up to the
    -- figure, as a listing's do: the caption comes with the picture.
    i1 = body~pos("<img")
    If i1 > 0 Then Do
      i2 = body~pos(">", i1)
      img = SplitTag(body~substr(i1, i2 + 1 - i1), 0, 0)
      body = body~left(i1 - 1) || img[4] || body~substr(i2 + 1)
      open = open~left(open~length - 1)
      If img[2] \== "" Then open ||= ' class="'img[2]'"'
      open ||= img[3]">"
    End
    c1  = body~pos("<figcaption")
    If c1 > 0 Then Do
      c2  = body~pos("</figcaption>", c1) + Length("</figcaption>")
      cap = body~substr(c1, c2 - c1)
      n += 1
      If number Then Do
        cg  = cap~pos(">")
        cap = cap~left(cg)'<span class="figure-number">'figLabel"&nbsp;"n":&ensp;</span>" -
              || cap~substr(cg + 1)
      End
      If figPos == "above" Then body = cap || body~left(c1 - 1) || body~substr(c2)
      Else                      body = body~left(c1 - 1) || cap || body~substr(c2)
    End
    out~append(html~substr(p, at - p), open || body"</figure>")
    p = e
  End
  out~append(html~substr(p))
  Return out~string

-- The class words of an opening tag ('<pre id="x" class="output file">').
::Routine TagClasses
  Use Strict Arg tag
  Parse Var tag . ' class="' classes '"'
  Return classes

-- HoistBox - what goes up from a captioned listing to its <figure>.          --
--                                                                            --
-- The figure is the box on the slide, caption and all, so what makes it a    --
-- box on the slide moves up to it: the id (the end of an arrow), .fragment   --
-- and its timing word, anim= and group= (the step), level-N (the indent).    --
-- What is about the text inside stays: output, spot= (the marks are on its   --
-- lines), numberLines, keys... Pandoc splits a block it highlights: the id   --
-- on the <div class="sourceCode">, the classes and the rest on the <pre>     --
-- inside it, so both tags are looked at. A Rexx listing's id is the          --
-- highlighter's own (rx1, ...), not the author's: it stays.                  --
--                                                                            --
-- Returns an array: [1] ' id="x"' or "", [2] the class words that move,      --
-- [3] the attributes that move (' data-anim="..."'), [4] the block without   --
-- them, [5] 1 if it is a file box (its "file" class is taken off the block). --
::Routine HoistBox
  Use Strict Arg block

  head   = block~substr(1, block~pos(">"))
  takeId = WordPos("rx-blockwrap", TagClasses(head)) == 0
  a      = SplitTag(head, takeId, 1)
  block  = a[4] || block~substr(head~length + 1)
  id = a[1]; words = a[2]; attrs = a[3]; file = a[5]
  If head~startsWith("<div") Then Do
    at = block~pos("<pre")
    If at > 0 Then Do
      gt = block~pos(">", at)
      b  = SplitTag(block~substr(at, gt + 1 - at), 0, 1)
      block = block~left(at - 1) || b[4] || block~substr(gt + 1)
      words = words b[2]; attrs = attrs || b[3]; file = file | b[5]
    End
  End

  Return .Array~of(id, Space(words), attrs, block, file)

-- SplitTag - one opening tag, split as HoistBox says. `takeId`: the id moves   --
-- too; `dropFile`: a "file" class is taken off and reported in [5]. Same      --
-- array as HoistBox; [4] is the tag without what moves ('<img ... />' stays   --
-- self-closing).                                                              --
::Routine SplitTag
  Use Strict Arg tag, takeId, dropFile

  moveWords = "fragment" TimingClasses()
  moveAttrs = "data-anim data-group"
  close = ">"
  If tag~endsWith("/>") Then close = " />"
  body = tag~substr(2)~strip("T", ">")~strip("T", "/")~strip("T")
  Parse Var body name rest
  id = ""; words = ""; attrs = ""; keep = ""; file = 0
  Loop While rest~strip \== ""
    rest = rest~strip("L")
    Parse Var rest attr '="' value '"' rest
    Select
      When attr == "class" Then Do
        stay = ""
        Do w Over value~makeArray(" ")
          Select
            When w == "" Then Nop
            When w == "file", dropFile Then file = 1
            When WordPos(w, moveWords) > 0 | w~startsWith("level-") Then
              words = words w
            Otherwise stay = stay w
          End
        End
        If stay \== "" Then keep = keep' class="'stay~strip'"'
      End
      When attr == "id", takeId Then id = ' id="'value'"'
      When WordPos(attr, moveAttrs) > 0 Then attrs = attrs' 'attr'="'value'"'
      Otherwise keep = keep' 'attr'="'value'"'
    End
  End

  -- Nothing moves: the tag stays exactly as it was written.
  If id == "", words == "", attrs == "", \file Then Return .Array~of("", "", "", tag, 0)
  Return .Array~of(id, Space(words), attrs, "<"name || keep || close, file)

-- One caption option from ParseRexxPubYAML's table; .nil or "" is the default.
::Routine CaptionOpt
  Use Strict Arg opts, name, default
  If \opts~isA(.StringTable) Then Return default
  v = opts[name]
  If v == .Nil Then Return default
  If v == "" Then Return default
  Return v

-- "Listing" / "Figure" in the deck's language, as numberFigures.js has them.
::Routine CaptionLabel
  Use Strict Arg kind, lang
  lang = Lower(Left(lang, 2))
  If kind == "figure" Then
    list = "en Figure es Figura fr Figure de Abbildung it Figura pt Figura" -
           "nl Figuur ca Figura gl Figura"
  Else
    list = "en Listing es Listado fr Listing de Listing it Listato" -
           "pt Listagem nl Listing ca Llistat gl Listaxe"
  Loop i = 1 To Words(list) By 2
    If Word(list, i) == lang Then Return Word(list, i + 1)
  End
  Return Word(list, 2)

-- Remove one sugar attribute (name= or data-name=) from a tag.
::Routine DropSugar
  Use Strict Arg tag, name
  Do variant Over ("data-"name, name)
    needle = ' 'variant'="'
    p = tag~pos(needle)
    If p == 0 Then Iterate
    vend = tag~pos('"', p + needle~length)
    If vend == 0 Then Iterate
    tag = tag~left(p - 1) || tag~substr(vend + 1)
  End
  Return tag

-- A number greater than zero ("0.8", "1", ".5"); anything else is not one.
::Routine PositiveNumber
  Use Strict Arg value
  If \value~dataType("N") Then Return 0
  Return value > 0

-- Add one declaration to a tag's style="" (creating it if there is none).
::Routine AddStyle
  Use Strict Arg tag, decl
  sp = tag~pos('style="')
  If sp > 0 Then
    Return tag~substr(1, sp+6) || decl' ' || tag~substr(sp+7)
  gt = tag~pos(">")
  Return tag~substr(1, gt-1)' style="'decl'"'tag~substr(gt)

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

/******************************************************************************/
/*                                                                            */
/* MarkKeys - key caps in a keyboard transcript.                              */
/*                                                                            */
/* A slide that shows a terminal session has to show what the PRESENTER       */
/* typed, and a key is not text: Rony asked for the pressed keys to read as   */
/* keys, and for Enter to be showable at all -- a transcript that ends a line */
/* without it cannot say whether the command was sent.                        */
/*                                                                            */
/* The author writes <Enter> and gets a cap. That only happens in a block     */
/* that asked for it:                                                        */
/*                                                                            */
/*     ~~~output {.keys}                                                      */
/*     C:\> rexx hello.rex <Enter>                                            */
/*     ~~~                                                                    */
/*                                                                            */
/* Opt-in, and not a catalogue of key names, because an output block is a     */
/* claim -- this is what the program printed -- and <...> is ordinary text in */
/* plenty of real output. Reading every block would mean rewriting text no    */
/* one marked; a closed list of names would still have to guess whether       */
/* <Enter> in THIS block is a key or a word, and would need a second rule for */
/* every key it had not heard of. The block says it, or nothing happens.      */
/*                                                                            */
/* The price, and it is real: inside a marked block a literal < cannot be     */
/* written. A block that needs one does not ask for keys.                     */
/*                                                                            */
/* The cap carries the text as written -- no symbols. Measured in the         */
/* browser: whether the deck's fonts have a return arrow at all depends on    */
/* the machine it is shown from, and a glyph that is missing is a box on the  */
/* wall in the middle of a talk.                                              */
/*                                                                            */
/******************************************************************************/

::Routine MarkKeys Public
  Use Strict Arg html

  MARK = '<pre class="'
  out  = ""
  rest = html
  Loop Forever
    p = rest~pos(MARK)
    If p == 0 Then Do
      out = out || rest
      Leave
    End

    -- Everything up to and including this <pre ...> opening tag.
    gt = rest~pos(">", p)
    If gt == 0 Then Do
      out = out || rest
      Leave
    End
    tag   = rest~substr(p, gt - p + 1)
    out   = out || rest~substr(1, p - 1) || tag
    rest  = rest~substr(gt + 1)

    -- The block's body, to its </pre>.
    e = rest~pos("</pre>")
    If e == 0 Then Do
      out = out || rest
      Leave
    End
    body = rest~substr(1, e - 1)
    rest = rest~substr(e)

    If HasClass(tag, "keys") Then body = CapKeys(body)
    out = out || body
  End

  Return out

--------------------------------------------------------------------------------
-- HasClass - is `name` one of the WORDS of a tag's class attribute? Asked as --
-- a word and not as a substring, so a block of class "keyspress" is not a    --
-- transcript and "monkeys" never was.                                        --
--------------------------------------------------------------------------------

::Routine HasClass
  Use Strict Arg tag, name

  p = tag~pos('class="')
  If p == 0 Then Return 0
  rest = tag~substr(p + 7)
  Parse Var rest classes '"' .

  Return WordPos(name, classes) > 0

--------------------------------------------------------------------------------
-- CapKeys - turn every &lt;...&gt; in one block's text into a key cap.       --
--                                                                            --
-- Pandoc has already escaped the block, so what is looked for is the escaped --
-- form. A cap may not span a line (a stray < at the end of one line would    --
-- otherwise swallow everything down to the next >) and may not be empty (<>  --
-- is a Rexx operator, and an empty cap is nobody's intention).               --
--------------------------------------------------------------------------------

::Routine CapKeys
  Use Strict Arg text

  OPEN  = "&lt;"
  CLOSE = "&gt;"

  out  = ""
  rest = text
  Loop Forever
    p = rest~pos(OPEN)
    If p == 0 Then Do
      out = out || rest
      Leave
    End

    out  = out || rest~substr(1, p - 1)
    rest = rest~substr(p + OPEN~length)

    q = rest~pos(CLOSE)
    label = ""
    If q > 0 Then label = rest~substr(1, q - 1)

    -- Not a cap: no closing >, an empty one, or a line ended in between.
    If q == 0 | label == "" | label~pos("0a"x) > 0 | label~pos(OPEN) > 0 Then Do
      out = out || OPEN
      Iterate
    End

    out  = out || '<span class="key">' || label || '</span>'
    rest = rest~substr(q + CLOSE~length)
  End

  Return out

/******************************************************************************/
/*                                                                            */
/* MarkBlanks - visible blanks in an output block ({.blanks}).                */
/*                                                                            */
/* The other half of blanks=, and the half the parser cannot do: an output    */
/* block is not Rexx and never reaches the highlighter. It needs no rule       */
/* about WHICH blanks either -- a program's output is all data, so a marked    */
/* block marks every blank it has, trailing ones included, which are the       */
/* ones a listing can never show and a reader most often has to take on        */
/* trust.                                                                     */
/*                                                                            */
/* Same span and the same class as the highlighter emits, so one mark is       */
/* drawn by one rule whichever kind of block it came from.                     */
/*                                                                            */
/******************************************************************************/

::Routine MarkBlanks Public
  Use Strict Arg html

  MARK = '<pre class="'
  out  = ""
  rest = html
  Loop Forever
    p = rest~pos(MARK)
    If p == 0 Then Do
      out = out || rest
      Leave
    End

    gt = rest~pos(">", p)
    If gt == 0 Then Do
      out = out || rest
      Leave
    End
    tag  = rest~substr(p, gt - p + 1)
    out  = out || rest~substr(1, p - 1) || tag
    rest = rest~substr(gt + 1)

    e = rest~pos("</pre>")
    If e == 0 Then Do
      out = out || rest
      Leave
    End
    body = rest~substr(1, e - 1)
    rest = rest~substr(e)

    If WantsBlanks(tag) Then body = CapBlanks(body)
    out = out || body
  End

  -- And the same for an inline output span, `text`{.output blanks=all}. It
  -- is a <code> of its own, outside any <pre>, and was never looked at: the
  -- sentence asked for its blanks and got none. A Rexx mention is left
  -- alone: the highlighter has marked it already, and knows better.
  html = out
  out  = ""
  rest = html
  MARK = '<code class="'
  Loop Forever
    p = rest~pos(MARK)
    If p == 0 Then Do
      out = out || rest
      Leave
    End
    gt  = rest~pos(">", p)
    e   = rest~pos("</code>", p)
    If gt == 0 | e == 0 Then Do
      out = out || rest
      Leave
    End
    tag  = rest~substr(p, gt - p + 1)
    body = rest~substr(gt + 1, e - gt - 1)
    out  = out || rest~left(p - 1) || tag
    rest = rest~substr(e)
    If WantsBlanks(tag), \HasClass(tag, "rexx"), body~pos("<") == 0
      Then body = CapBlanks(body)
    out = out || body
  End

  Return out

--------------------------------------------------------------------------------
-- WantsBlanks - does this tag ask for visible blanks? `{.blanks}` arrives as  --
-- a class; `{blanks=all}` and `{blanks=data}` arrive as data-blanks, and     --
-- used to be missed. On output, which is all data, the two mean the same.    --
--------------------------------------------------------------------------------

::Routine WantsBlanks
  Use Strict Arg tag

  If HasClass(tag, "blanks") Then Return 1
  Return tag~pos('data-blanks="all"') > 0 | tag~pos('data-blanks="data"') > 0

--------------------------------------------------------------------------------
-- CapBlanks - wrap every run of blanks in one block's text.                  --
--                                                                            --
-- A run travels in ONE span: the stylesheet tiles the mark per character     --
-- cell, so three blanks draw three boxes without three spans to do it. The   --
-- blanks themselves stay in the text, so the block can still be copied.      --
--------------------------------------------------------------------------------

::Routine CapBlanks
  Use Strict Arg text

  out  = ""
  rest = text
  Loop Forever
    p = Verify(rest, " "||"09"x, "M")
    If p == 0 Then Do
      out = out || rest
      Leave
    End
    out  = out || rest~substr(1, p - 1)
    rest = rest~substr(p)
    -- A tab gets its own mark, as in a Rexx listing: an arrow to the stop.
    If rest~left(1) == "09"x Then Do
      out  = out || '<span class="rx-tab-mark">'"09"x'</span>'
      rest = rest~substr(2)
      Iterate
    End
    n = Verify(rest, " ", "N")
    If n == 0 Then n = rest~length + 1
    out  = out || '<span class="rx-blank-mark">' || Copies(" ", n - 1) || '</span>'
    rest = rest~substr(n)
  End

  Return out

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
-- MarkIncrementalItems - turn `::: incremental` into per-item fragments.     --
--                                                                            --
-- Pandoc renders                                                             --
--     ::: incremental                                                        --
--     * one                                                                  --
--       - nested                                                             --
--     * [two]{.static}                                                       --
--     :::                                                                    --
-- as <div class="incremental"> wrapping <ul class="incremental">, with every --
-- nested <ul>/<ol> tagged "incremental" too and every <li> left bare. We mark--
-- each descendant <li> as a .fragment, so the runtime reveals them one by one--
-- in document order (querySelectorAll(".fragment") is document order, and a  --
-- nested .fragment is a step of its own -- parent, then each child). One item--
-- opts out with `{.static}`, which Pandoc puts as <span class="static"> at   --
-- the item's start: that <li> is left un-fragmented and the marker span is   --
-- unwrapped, so `.static` never reaches the runtime as a live class.         --
--                                                                            --
-- Scope is the incremental block only: an <li> outside any incremental div is--
-- untouched, so a hand-marked `.fragment` bullet elsewhere still works. The  --
-- default effect/duration come from the deck's --anim-* variables (YAML), so --
-- this routine writes no data-anim: a bare .fragment inherits the            --
-- deck default.                                                              --
--------------------------------------------------------------------------------
::Routine MarkIncrementalItems
  Use Strict Arg body

  If body~pos("incremental") == 0 Then Return body

  -- Isolate each incremental block by matching its opening <div> against its
  -- own </div> (divs nest, so count depth), mark the items inside, and stitch
  -- the rewritten block back in. Text between blocks is untouched.
  --
  -- The opening tag is matched by its CLASS WORD, not as the exact string
  -- '<div class="incremental">': `::: {.incremental anim=scale-in}` arrives
  -- as '<div class="incremental" data-anim="scale-in">' and used to be
  -- skipped altogether -- nothing in it was revealed, and the animation it
  -- asked for went nowhere. Its anim= and anim-duration= now go onto every
  -- item it marks.
  out  = ""
  rest = body

  Loop
    at = IncrementalDiv(rest)
    If at == 0 Then Leave
    gt    = rest~pos(">", at)
    tag   = rest~substr(at, gt - at + 1)
    out   = out || rest~left(at - 1)
    inner = rest~substr(gt + 1)

    -- Find the </div> that closes THIS incremental div, counting nested <div>s.
    depth = 1
    scan  = inner
    block = ""
    Loop While depth > 0 & scan \== ""
      pOpen  = scan~pos("<div")
      pClose = scan~pos("</div>")
      If pClose == 0 Then Do          -- unbalanced input: bail out safely
        block = block || scan
        scan  = ""
        Leave
      End
      If pOpen \== 0 & pOpen < pClose Then Do
        Parse Var scan seg "<div" scan
        block = block || seg || "<div"
        depth = depth + 1
      End
      Else Do
        Parse Var scan seg "</div>" scan
        block = block || seg
        depth = depth - 1
        If depth > 0 Then block = block || "</div>"
      End
    End

    -- What each marked item carries: the block's own animation, if any.
    carry = ""
    Loop name Over .Array~of("data-anim", "data-anim-duration")
      v = AttrValue(tag, name)
      If v \== "" Then carry = carry' 'name'="'v'"'
    End

    -- The wrapper is dropped, as before: once every item is a fragment it has
    -- done its job, and a bare <ul> reaches WrapProse as prose (its .body and
    -- the per-level font-size cascade). Any OTHER class on it -- `.plain` on
    -- a table, say -- is a request to the stylesheet, so then a wrapper with
    -- just those classes stays. The "incremental" class Pandoc stamps on every
    -- nested <ul>/<ol> is stripped too.
    --
    -- A style on it -- which is where indent= has gone by now -- keeps the
    -- wrapper too, with the style on it. And when what it wraps is a list, the
    -- wrapper takes the .body class WrapProse would otherwise have given the
    -- bare list, so a kept wrapper does not change the list's text size.
    Parse Var tag . 'class="' classes '"'
    extras = Strip(Space(ChangeWord(classes, "incremental")))
    -- `{.incremental .afterPrevious}` / `.withPrevious` time the BLOCK against
    -- what comes before it: its first step follows the previous fragment
    -- automatically, or comes in together with it. So the class goes onto the
    -- block's first step, where the runtime reads timing -- on the wrapper it
    -- did nothing (Rony: "an incremental block following a fragment does not
    -- honor .afterPrevious or .withPrevious"). The later steps keep their own
    -- presses, and an item can still time itself: [text]{.afterPrevious}.
    timing = ""
    Loop w Over TimingClasses()~makeArray(" ")
      If WordPos(w, extras) > 0 Then Do
        timing = Strip(timing w)
        extras = Strip(Space(ChangeWord(extras, w)))
      End
    End
    style  = AttrValue(tag, "style")
    -- How a table in it is built: head= and steps= (see MarkRows). A value
    -- outside the vocabulary was reported by CheckBodyAnims, with its slide;
    -- MarkRows acts only on the non-default words, so anything else is the
    -- default.
    head  = AttrValue(tag, "data-head")
    steps = AttrValue(tag, "data-steps")
    marked = MarkItems(block, carry, head, steps)
    marked = marked~changeStr(' class="incremental"', "")
    If timing \== "" Then marked = TimeFirstStep(marked, timing)
    -- appear= times every step it made (after the block's own word has taken
    -- the first one). Done here: the wrapper that carries it is dropped.
    appear = AppearWord(AttrValue(tag, "data-appear"), tag)
    If appear \== "" Then marked = TimeEveryStep(marked, appear)
    If extras == "" & style == "" Then out = out || marked
    Else Do
      first = marked~strip("L", "0a"x)~strip("L")
      If first~startsWith("<ul") | first~startsWith("<ol") Then
        extras = Strip("body" extras)
      wrap = "<div"
      If extras \== "" Then wrap = wrap' class="'extras'"'
      If style  \== "" Then wrap = wrap' style="'style'"'
      out = out || wrap'>' || marked || '</div>'
    End
    rest = scan
  End

  Return out || rest

--------------------------------------------------------------------------------
-- IncrementalDiv - where the next <div> whose classes include "incremental"  --
-- opens, or 0.                                                               --
--------------------------------------------------------------------------------

::Routine IncrementalDiv
  Use Strict Arg html

  from = 1
  Loop Forever
    at = html~pos('<div class="', from)
    If at == 0 Then Return 0
    Parse Value html~substr(at + 12) With classes '"'
    If WordPos("incremental", classes) > 0 Then Return at
    from = at + 12
  End

--------------------------------------------------------------------------------
-- TimeFirstStep - add the timing class(es) to the first fragment in `html`,  --
-- unless it already carries its own timing (an item's own word wins).        --
--------------------------------------------------------------------------------

::Routine TimeFirstStep
  Use Strict Arg html, timing

  rest = html
  done = ""
  Loop While rest~pos('class="') > 0
    Parse Var rest pre 'class="' classes '"' rest
    done = done || pre
    If WordPos("fragment", classes) > 0 Then Do
      own = 0
      Loop w Over TimingClasses()~makeArray(" ")
        If WordPos(w, classes) > 0 Then own = 1
      End
      If \own Then classes = classes timing
      Return done || 'class="'classes'"' || rest
    End
    done = done || 'class="'classes'"'
  End
  Return html

--------------------------------------------------------------------------------
-- appear= -- one timing word for every step of a block.                      --
--                                                                            --
-- Rony (24-Sep): "sometimes all items of a fragment or an incremental should --
-- appear the same way .afterPrev or .withPrev or .afterClick". Writing the   --
-- word on every item is a lot of noise, so a block says it once:             --
--                                                                            --
--   ::: {.incremental appear=afterPrev}                                      --
--                                                                            --
-- Every step inside the block -- every item an .incremental makes, every     --
-- row or cell of its table, every .fragment in it, and the block itself if   --
-- it is a fragment -- takes the word, unless it has a timing word of its own --
-- (an item's own word wins, and so does the block's own .afterPrev on its    --
-- first step). A block inside another with its own appear= keeps its own.   --
-- The value is one of the timing words, with or without its dot, short or   --
-- long, in any case: afterPrev, .afterPrevious, withPrev, afterClick.        --
--------------------------------------------------------------------------------

-- The timing class an appear= value stands for, or "" (reported) if none.
::Routine AppearWord
  Use Strict Arg value, where = ""
  If value == "" Then Return ""
  v = value~strip("L", ".")~lower
  Select Case v
    When "afterprevious", "afterprev" Then Return "afterPrevious"
    When "withprevious",  "withprev"  Then Return "withPrevious"
    When "afterclick"                 Then Return "afterClick"
    Otherwise Nop
  End
  Call Warn where"appear="value "is not a timing word, so it times nothing." -
    "Use appear=afterPrev, appear=withPrev or appear=afterClick."
  Return ""

-- Add `timing` to every fragment in `html` that has no timing word of its own.
::Routine TimeEveryStep
  Use Strict Arg html, timing
  words = TimingClasses()~makeArray(" ")
  out  = .MutableBuffer~new
  rest = html
  Loop While rest~pos('class="') > 0
    Parse Var rest pre 'class="' classes '"' rest
    If WordPos("fragment", classes) > 0 Then Do
      own = 0
      Loop w Over words
        If WordPos(w, classes) > 0 Then own = 1
      End
      If \own Then classes = classes timing
    End
    out~append(pre, 'class="', classes, '"')
  End
  out~append(rest)
  Return out~string

-- Every block with appear= (data-appear): time its steps, innermost block
-- first so that a nested appear= is the one its own steps take.
::Routine ApplyAppear Public
  Use Strict Arg html
  If html~pos(' data-appear="') == 0 Then Return html
  s = html
  Loop Forever
    p = s~lastPos(' data-appear="')
    If p == 0 Then Leave
    open = s~lastPos("<", p)
    Parse Value s~substr(open + 1) With name " " .
    gt   = s~pos(">", p)
    Parse Value s~substr(p + 14) With value '"' .
    tag  = s~substr(open, gt - open + 1)
    newTag = tag~changeStr(' data-appear="'value'"', "")
    -- The element's extent: to its own closing tag, counting nested ones of
    -- the same name (a <div> in practice; a span has no steps inside).
    close = gt
    If name \== "" Then Do
      depth = 1
      scan  = gt + 1
      Loop While depth > 0
        o = s~pos("<"name, scan)
        c = s~pos("</"name">", scan)
        If c == 0 Then Do; close = s~length; Leave; End
        If o \== 0, o < c Then Do; depth += 1; scan = o + 1; End
        Else Do
          depth -= 1; scan = c + 1
          If depth == 0 Then close = c + name~length + 2
        End
      End
    End
    slide  = s~left(open)~countStr("<section")
    where  = ""
    If slide > 0 Then where = "slide" slide": "
    timing = AppearWord(value, where)
    inner  = s~substr(gt + 1, close - gt)
    If timing \== "" Then Do
      newTag = TimeEveryStep(newTag, timing)
      inner  = TimeEveryStep(inner, timing)
    End
    s = s~left(open - 1) || newTag || inner || s~substr(close + 1)
  End
  Return s

-- The words that time a fragment against the one before it. afterClick is
-- the default said out loud: a fragment that waits for its press. It is here
-- so it counts as a fragment's OWN timing (it beats its block's), and so a
-- word can be swapped for another in place (Rony: "replace the
-- when-to-start-animation control verb"); the runtime needs nothing for it.
::Routine TimingClasses Public
  Return "afterPrevious withPrevious afterClick"
--------------------------------------------------------------------------------
-- HoistContainerTiming - a timing word on a block that is not itself a       --
-- fragment times the block's FIRST fragment.                                 --
--                                                                            --
-- Rony wrote `::: {.contents scale=0.85 .afterPrevious}` around his first    --
-- fragment and expected the slide to start by itself: the word was on the   --
-- block he could see, not on the fragment inside it, and on a block that is  --
-- not revealed it did nothing. The incremental block already worked that way --
-- (MarkIncrementalItems); now every block does: the word moves to the first  --
-- fragment inside it, unless that fragment has a timing word of its own      --
-- (then the fragment's word wins and the block's is dropped). A block with   --
-- no fragment inside has nothing to time, and the build says so.             --
--------------------------------------------------------------------------------

::Routine HoistContainerTiming Public
  Use Strict Arg html

  words = TimingClasses()
  s   = html
  pos = 1
  Loop
    p = s~pos("<div", pos)
    If p == 0 Then Leave
    gt  = s~pos(">", p)
    If gt == 0 Then Leave
    tag = s~substr(p, gt - p + 1)
    pos = gt + 1
    cp  = tag~pos(' class="')
    If cp == 0 Then Iterate
    Parse Value tag~substr(cp + 8) With classes '"' .
    If WordPos("fragment", classes) > 0 Then Iterate
    moved = ""
    Loop w Over words~makeArray(" ")
      If WordPos(w, classes) > 0 Then moved = moved w
    End
    moved = moved~strip
    If moved == "" Then Iterate

    -- The block: from after its tag to its own </div>, counting nested divs.
    depth = 1
    scan  = gt + 1
    close = 0
    Loop While depth > 0
      o = s~pos("<div", scan)
      c = s~pos("</div>", scan)
      If c == 0 Then Leave
      If o \== 0, o < c Then Do; depth += 1; scan = o + 4; End
      Else Do; depth -= 1; scan = c + 6; If depth == 0 Then close = c; End
    End
    If close == 0 Then Iterate                      -- unbalanced: leave it

    -- Its first fragment.
    target = 0
    q = gt + 1
    Loop
      q = s~pos(' class="', q)
      If q == 0 | q > close Then Leave
      Parse Value s~substr(q + 8) With fc '"' .
      If WordPos("fragment", fc) > 0 Then Do; target = q; Leave; End
      q = q + 8
    End

    newClasses = classes
    Loop w Over moved~makeArray(" ")
      newClasses = ChangeWord(newClasses, w)
    End
    newClasses = Space(newClasses)
    newTag = tag~left(cp - 1)' class="'newClasses'"' || -
             tag~substr(cp + 8 + classes~length + 1)

    If target == 0 Then Do
      slide = s~left(p)~countStr("<section")
      If slide > 0 Then place = "slide" slide": "
      Else place = ""
      Call Warn place"."moved~changeStr(" ", " .") "is on a block with no" -
        "fragment inside, so it times nothing. Put it on a fragment, or make" -
        "the block one: ::: {.fragment ."moved~word(1)"}."
    End
    Else Do
      Parse Value s~substr(target + 8) With fc '"' .
      own = 0
      Loop w Over words~makeArray(" ")
        If WordPos(w, fc) > 0 Then own = 1
      End
      If \own Then
        s = s~left(target + 7) || fc moved || s~substr(target + 8 + fc~length)
    End
    s   = s~left(p - 1) || newTag || s~substr(gt + 1)
    pos = p + newTag~length
  End
  Return s


--------------------------------------------------------------------------------
-- TimingAliases - spell the timing words out in every class="..." of the     --
-- HTML Pandoc made.                                                          --
--                                                                            --
-- Rony uses these words on nearly every slide, and "ious" is easy to mistype --
-- without noticing: an unknown class is silently nothing, so the fragment     --
-- just waits for a key press. So the short forms are accepted, and case is   --
-- not held against the author:                                               --
--                                                                            --
--   .afterPrevious  .afterPrev   -> afterPrevious                            --
--   .withPrevious   .withPrev    -> withPrevious                             --
--   .afterClick                  -> afterClick (the default, said out loud)  --
--                                                                            --
-- Any other class that starts like one of them (.afterPrevios,              --
-- .withPreviuos) is left alone and REPORTED, with its slide.                 --
-- Class values are all this touches: text in the slides, code included, has  --
-- no class="..." of its own.                                                 --
--------------------------------------------------------------------------------

::Routine TimingAliases Public
  Use Strict Arg html

  If html~caselessPos("prev") == 0, html~caselessPos("afterclic") == 0 Then Return html
  out  = .MutableBuffer~new
  rest = html
  Loop While rest~pos('class="') > 0
    Parse Var rest pre 'class="' classes '"' rest
    out~append(pre, 'class="')
    words = ""
    Loop w Over classes~makeArray(" ")
      If w == "" Then Iterate
      Select Case w~lower
        When "afterprevious", "afterprev" Then w = "afterPrevious"
        When "withprevious",  "withprev"  Then w = "withPrevious"
        When "afterclick"                 Then w = "afterClick"
        Otherwise
          l = w~lower
          If l~startsWith("afterprev") | l~startsWith("withprev") | -
             l~startsWith("afterclic") Then Do
            slide = SlideNumberAt(html, html~length - rest~length)
            If slide > 0 Then place = "slide" slide": "
            Else place = ""
            Select
              When l~startsWith("afterclic") Then good = ".afterClick"
              When l~startsWith("after")     Then good = ".afterPrevious (or .afterPrev)"
              Otherwise                           good = ".withPrevious (or .withPrev)"
            End
            Call Warn place"unknown class ."w", so it times nothing." -
              "Did you mean" good"?"
          End
      End
      words = words w
    End
    out~append(words~strip, '"')
  End
  out~append(rest)
  Return out~string

--------------------------------------------------------------------------------
-- ChangeWord - a blank-separated list without one word.                      --
--------------------------------------------------------------------------------

::Routine ChangeWord
  Use Strict Arg list, word

  out = ""
  Loop w Over list~makeArray(" ")
    If w \== word Then out = out w
  End
  Return out

--------------------------------------------------------------------------------
-- MarkRows - reveal every table in the block one step at a time.             --
--                                                                            --
-- The TABLE is a fragment of its own, and so is every body row -- or, with   --
-- steps=cells, every cell of every body row, left to right and row by row.   --
-- With a header, the first step shows the header alone (head=before, the     --
-- default); head=with-row brings the header in together with the first      --
-- step of the body, which is then left unmarked. A table without a header    --
-- always comes in with its first step, since an empty grid shows nothing.    --
-- The table used to be always there, header and all, so a header could      --
-- stand on the slide before the text that introduces it.                     --
--------------------------------------------------------------------------------

::Routine MarkRows
  Use Strict Arg block, carry = "", head = "before", steps = "rows"

  If block~pos("<table") == 0 Then Return block

  out  = ""
  rest = block
  Loop While rest~pos("<table") > 0
    Parse Var rest pre "<table" tattrs ">" table "</table>" rest
    -- The first step of the body rides with the table itself when there is
    -- no header to show on its own, or when the author asked for that.
    ride = table~pos("<thead") == 0 | head == "with-row"
    out  = out || pre || "<table" || AddFragment(tattrs) || carry || ">"

    If table~pos("<tbody>") == 0 Then Do
      out = out || table || "</table>"
      Iterate
    End
    Parse Var table thead "<tbody>" tbody "</tbody>" tail
    marked = ""
    first  = 1
    Loop While tbody~pos("<tr") > 0
      Parse Var tbody seg "<tr" attrs ">" row "</tr>" tbody
      If steps == "cells" Then Do
        cells = ""
        Loop While row~pos("<td") > 0
          Parse Var row cseg "<td" cattrs ">" row
          -- An EMPTY cell is not a step of its own: a press that shows nothing
          -- is a press the presenter cannot explain. It comes in with the
          -- step before it (the runtime's "withPrevious"), so a statement whose
          -- result column is blank costs one press, not two. (Rony's table
          -- of statements: the result cell is empty when there is none.)
          If first & ride Then cells = cells || cseg || "<td" || cattrs || ">"
          Else If Strip(row~left(Max(row~pos("</td>") - 1, 0))) == "" Then
            cells = cells || cseg || "<td" || AddFragment(cattrs, "withPrevious") || carry || ">"
          Else cells = cells || cseg || "<td" || AddFragment(cattrs) || carry || ">"
          first = 0
        End
        marked = marked || seg || "<tr" || attrs || ">" || cells || row || "</tr>"
      End
      Else Do
        If first & ride Then
          marked = marked || seg || "<tr" || attrs || ">"
        Else
          marked = marked || seg || "<tr" || AddFragment(attrs) || carry || ">"
        marked = marked || row || "</tr>"
        first = 0
      End
    End
    out = out || thead || "<tbody>" || marked || tbody || "</tbody>" || tail
    out = out || "</table>"
  End

  Return out || rest

--------------------------------------------------------------------------------
-- TableColumns - `cols=1:5` on the ::: that holds a table: the proportions   --
-- of its columns.                                                            --
--                                                                            --
-- By default a table is as wide as its contents (see PandocOptions). Rony    --
-- then asked for the other thing too: to fix the RELATION between columns,   --
-- 1:5 say. The numbers are proportions, like col-N in a row -- not           --
-- percentages, not lengths -- and a column the author does not name counts   --
-- as 1, so `cols=1:5` on a three-column table is 1:5:1. The table then takes --
-- the full width of whatever holds it (the slide, or its col-N), since the   --
-- shares have to be shares of something; a narrower table goes in a col-N.   --
--                                                                            --
-- Pandoc leaves the attribute on the wrapper as data-cols="1:5". It is taken --
-- off the wrapper here and turned into a <colgroup> on the first table that  --
-- follows, plus the class "cols" on that table for the stylesheet. A value   --
-- that is not numbers separated by colons, or that names more columns than   --
-- the table has, is reported with its slide and left alone -- the usual      --
-- rule: if md2slides cannot do what was asked, it says so, and says where.   --
--------------------------------------------------------------------------------

::Routine TableColumns Public
  Use Strict Arg body, where

  -- Pandoc prefixes an attribute it does not know with data-; `cols` it does
  -- know (it is <textarea>'s), so it arrives bare. One spelling from here on.
  out  = ""
  rest = body~changeStr(' cols="', ' data-cols="')
  Loop While rest~pos('data-cols="') > 0
    Parse Var rest pre 'data-cols="' spec '"' post
    out  = out || pre~strip("T")          -- the blank that led the attribute
    rest = post
    shares = ColumnShares(spec)
    If shares == "" Then Do
      .Error~Say( "md2slides: warning:" 'cols="'spec'"' "on slide" '"'where'"' -
                  "is not a list of proportions like 1:5, so it is ignored." )
      Iterate
    End
    p = post~pos("<table")
    If p == 0 Then Do
      .Error~Say( "md2slides: warning:" 'cols="'spec'"' "on slide" '"'where'"' -
                  "has no table after it, so it is ignored." )
      Iterate
    End
    gt    = post~pos(">", p)
    tag   = post~substr(p, gt - p + 1)
    -- how many columns the table has: the cells of its first row
    Parse Var post =(gt) . "<tr" . ">" row "</tr>" .
    n = row~countStr("<td") + row~countStr("<th")
    If n == 0 Then n = Words(shares)
    If Words(shares) > n Then Do
      .Error~Say( "md2slides: warning:" 'cols="'spec'"' "on slide" '"'where'"' -
                  "names" Words(shares) "columns, but the table has" n", so it is ignored." )
      Iterate
    End
    Loop While Words(shares) < n
      shares = shares 1
    End
    total = 0
    Loop w Over shares~makeArray(" ")
      total = total + w
    End
    colgroup = "<colgroup>"
    Loop w Over shares~makeArray(" ")
      pct      = Format(w / total * 100, , 2)~strip("T", "0")~strip("T", ".")
      colgroup = colgroup || '<col style="width: 'pct'%" />'
    End
    colgroup = colgroup || "</colgroup>"
    If tag~pos('class="') > 0 Then tag = tag~changeStr('class="', 'class="cols ', 1)
    Else tag = tag~left(tag~length - 1)' class="cols">'
    out  = out || post~left(p - 1) || tag || colgroup
    rest = post~substr(gt + 1)
  End

  Return out || rest

-- The shares of a cols= value as a blank-separated list of positive numbers,
-- or "" when the value is not one.
::Routine ColumnShares Public
  Use Strict Arg spec
  shares = ""
  Loop part Over Strip(spec)~makeArray(":")
    part = Strip(part)
    If \part~dataType("N") Then Return ""
    If part <= 0 Then Return ""
    shares = shares part
  End
  Return Strip(shares)

--------------------------------------------------------------------------------
-- TableSteps - the values head= and steps= accept on ::: incremental.        --
--------------------------------------------------------------------------------

::Routine TableSteps
  Use Strict Arg which
  If which == "head" Then Return "before with-row"
  Return "rows cells"

--------------------------------------------------------------------------------
-- AddFragment - a tag's attributes with "fragment" added to its classes.     --
--------------------------------------------------------------------------------

::Routine AddFragment
  Use Strict Arg attrs, also = ""

  classes = Strip("fragment" also)
  If attrs~pos('class="') > 0 Then
    Return attrs~changeStr('class="', 'class="'classes' ', 1)
  Return attrs' class="'classes'"'

--------------------------------------------------------------------------------
-- ItemHead - the words written on an ITEM, found where Pandoc leaves them:   --
-- `- [text]{.afterPrev .plain}` puts a span around the item's text, and the  --
-- words mean the bullet, not the text. Three shapes:                         --
--   <span class="w...">text</span>          a tight list                     --
--   <p><span class="w...">text</span>       a loose one (blank lines between --
--                                           items: Pandoc wraps each in <p>) --
--   <p class="w...">text</p>                the same, after HoistSpans       --
-- `allowed` says which words are the item's (timing words, plain, fragment). --
-- Those are taken off; any other class stays where it was (level-2 on the    --
-- span keeps sizing its text). A span or <p> with any attribute other than   --
-- class is not ours. Returns "" or an array: [1] the item's words, [2] the   --
-- item's text without them.                                                  --
-- (Was ItemTiming, tight lists and timing words only: Rony's loose list, and --
-- .plain beside .afterPrev, left his bullet timed by the block, 27-Sep.)     --
--------------------------------------------------------------------------------

::Routine ItemHead
  Use Strict Arg after, allowed

  lead = ""
  body = after
  If after~startsWith('<p class="') Then Do
    gt  = after~pos(">")
    If gt == 0 Then Return ""
    tag = after~left(gt)
    Parse Var tag '<p class="' classes '"' tail
    If tail~pos("data-anim") > 0 | tail~pos("data-group") > 0 Then Return ""
    Parse Value ItemWords(classes, allowed) With take "," stay
    If take == "" Then Return ""
    If stay \== "" Then stay = ' class="'stay'"'
    newP = "<p"stay || tail
    Return .Array~of(take, newP || after~substr(gt + 1))
  End
  If after~startsWith("<p>") Then Do
    lead = "<p>"
    body = after~substr(4)
  End
  If \body~startsWith('<span class="') Then Return ""
  gt  = body~pos(">")
  If gt == 0 Then Return ""
  tag = body~left(gt)
  Parse Var tag '<span class="' classes '"' tail
  -- anim= and group= go with the step: such a span is HoistListItemFragments'
  If tail~pos("data-anim") > 0 | tail~pos("data-group") > 0 Then Return ""
  Parse Value ItemWords(classes, allowed) With take "," stay
  If take == "" Then Return ""
  inner = body~substr(gt + 1)
  -- Other attributes (the style level= writes) stay on the span, with the
  -- classes that are not the item's.
  If stay \== "" | tail \== ">" Then Do
    If stay \== "" Then stay = ' class="'stay'"'
    Return .Array~of(take, lead'<span'stay || tail || inner)
  End
  n = SpanBody(inner)                            -- unwrap: drop its </span>
  Return .Array~of(take, lead || inner~left(n) || inner~substr(n + 8))

-- ItemWords - "item words,other words" of a class list.
::Routine ItemWords
  Use Strict Arg classes, allowed
  take = ""; stay = ""
  Loop w Over classes~space~makeArray(" ")
    If WordPos(w, allowed) > 0 Then take = take w
    Else stay = stay w
  End
  Return Strip(take)","Strip(stay)

--------------------------------------------------------------------------------
-- HoistItemWords - the item words left on an item's text, moved to its <li>: --
-- `.plain` anywhere (no bullet for that item), and a fragment or its timing  --
-- in a loose list, which HoistListItemFragments (tight lists) does not see.  --
-- An incremental block's items have had theirs taken already (MarkItems).    --
--------------------------------------------------------------------------------

::Routine HoistItemWords
  Use Strict Arg body

  allowed = "fragment plain" TimingClasses()
  out  = .MutableBuffer~new
  rest = body
  Loop
    at = rest~pos("<li")
    If at == 0 Then Leave
    c = rest~substr(at + 3, 1)
    If c \== ">", c \== " " Then Do
      out~append(rest~left(at + 2)); rest = rest~substr(at + 3); Iterate
    End
    gt   = rest~pos(">", at)
    open = rest~substr(at, gt - at + 1)
    head = ItemHead(rest~substr(gt + 1), allowed)
    If head == "" Then Do
      out~append(rest~left(gt)); rest = rest~substr(gt + 1); Iterate
    End
    If open~pos('class="') > 0 Then Do
      Parse Var open pre 'class="' have '"' post
      words = have
      Loop w Over head[1]~makeArray(" ")
        If WordPos(w, words) == 0 Then words = words w
      End
      open = pre'class="'Strip(words)'"'post
    End
    Else open = "<li" open~substr(4, open~length - 4)' class="'head[1]'">'
    open = open~changeStr("<li  ", "<li ")~changeStr('<li ">', '<li>')
    out~append(rest~left(at - 1), open)
    rest = head[2]
  End
  out~append(rest)
  Return out~string

--------------------------------------------------------------------------------
-- SpanBody - the length of a span's content up to its own </span>, counting  --
-- nested spans (a Rexx mention inside the item is spans all the way down).   --
--------------------------------------------------------------------------------

::Routine SpanBody
  Use Strict Arg text

  depth = 1
  at    = 1
  Loop Forever
    o = text~pos("<span", at)
    c = text~pos("</span>", at)
    If c == 0 Then Return text~length
    If o \== 0, o < c Then Do
      depth = depth + 1
      at = o + 5
    End
    Else Do
      depth = depth - 1
      If depth == 0 Then Return c - 1
      at = c + 7
    End
  End

--------------------------------------------------------------------------------
-- MarkItems - within an incremental block, make each <li> a fragment. An item
-- opening with <span class="static"> opts out: it is left plain and the marker
-- span is unwrapped so `.static` never reaches the runtime. Pandoc emits bare
-- <li> (and <li><span class="static"> for the opt-out); we rewrite both forms.
--------------------------------------------------------------------------------
::Routine MarkItems
  Use Strict Arg block, carry = "", head = "before", steps = "rows"

  -- The rows of a table are items too: `::: incremental` around a table
  -- reveals it one row at a time, the header (if it has one) coming first,
  -- on a step of its own. See MarkRows.
  block = MarkRows(block, carry, head, steps)

  out  = ""
  rest = block
  Loop While rest~pos("<li>") > 0
    Parse Var rest pre "<li>" after
    out = out || pre

    head = ItemHead(after, "plain" TimingClasses())
    If head \== "" Then Do
      -- `- [text]{.afterPrevious}`: Pandoc puts the class on a span around
      -- the item's text. The item is the fragment, so the word goes onto the
      -- <li> with "fragment", and the span goes. On the span it was ignored.
      -- So does .plain (no bullet for this item), and in a loose list too.
      out  = out || '<li class="fragment' head[1]'"'carry'>'
      rest = head[2]
    End
    Else If after~pos('<span class="static">') == 1 Then Do
      -- Opt-out: item opens with the static marker. Unwrap the marker span and
      -- leave the <li> plain (no fragment class). Only this item is consumed;
      -- scanning continues on what follows its </span>.
      Parse Var after '<span class="static">' inner "</span>" after
      out  = out || "<li>" || inner
      rest = after
    End
    Else Do
      out  = out || '<li class="fragment"'carry'>'
      rest = after
    End
  End

  Return out || rest
--                                                                            --
-- Pandoc renders `- [text]{.fragment anim=X}` as                             --
--     <li><span class="fragment" data-anim="X">text</span> ...child <ul>...  --
-- The span holds the fragment, but a nested child <ul> is its SIBLING inside --
-- the <li>, so it sits outside the fragment and stays visible when the parent--
-- is hidden. We move the span's attributes onto the <li> and unwrap the span,--
-- turning the whole item (its subtree included) into the fragment.           --
--                                                                            --
-- Only a span that OPENS the <li> is hoisted (a fragment on the item itself).--
-- A span deeper in the item -- e.g. `- plain text with a [bit]{.fragment}` ----
-- is left alone: there the author marked a piece, not the bullet.            --
-- Guard: the <li> must start with the span (allowing whitespace), and the    --
-- span's class must be exactly "fragment" (so a different span-class bullet  --
-- is untouched).                                                             --
--------------------------------------------------------------------------------
::Routine HoistListItemFragments
  Use Strict Arg body

  out = ""
  Loop While body~pos("<li><span ") > 0
    Parse Var body pre "<li><span " spanAttrs ">" rest
    -- spanAttrs is the attribute text of the opening span. Hoist only when it is
    -- a fragment span (class="fragment", optionally with data-anim). Anything
    -- else (a different class, or a span not at the item's start) passes through.
    If FragmentSpanAttrs(spanAttrs) Then Do
      -- Find this span's matching </span> and drop it, keeping its inner content
      -- as direct children of the <li>. The close is the first </span> at depth 0
      -- (fragment spans do not nest spans in our output, but be safe).
      Parse Var rest inner "</span>" tail
      out  = out || pre || "<li " || spanAttrs || ">" || inner
      body = tail
    End
    Else Do
      out  = out || pre || "<li><span " || spanAttrs || ">"
      body = rest
    End
  End

  Return out || body

--------------------------------------------------------------------------------
-- True if a span's attribute text is a bare fragment marker: class exactly   --
-- "fragment", plus at most a data-anim. Keeps the hoist from grabbing spans  --
-- that merely happen to open an <li> but carry a different role.             --
--------------------------------------------------------------------------------
::Routine FragmentSpanAttrs
  Use Strict Arg attrs

  If attrs~pos('class="') == 0 Then Return 0
  Parse Var attrs before 'class="' classes '"' after
  -- "fragment", plus at most the timing words: `[text]{.fragment
  -- .afterPrevious}` times the bullet, and is hoisted like a bare one.
  If WordPos("fragment", classes) == 0 Then Return 0
  Loop w Over classes~space~makeArray(" ")
    If w \== "fragment", WordPos(w, TimingClasses()) == 0 Then Return 0
  End
  -- Strip the class and the attributes a bare fragment marker may carry
  -- (data-anim for its effect, data-group to share a reveal step); whatever
  -- remains (trimmed) must be empty, so we never hoist a span that also carries
  -- an UNRELATED attribute -- that would be a piece marked mid-item, not the
  -- bullet itself.
  rest = before || after
  Do attr Over ("data-anim", "data-group")
    Parse Var rest before (attr)'="' aval '"' after
    If aval \== "" | after \== "" Then rest = before || after
  End
  Return rest~strip == ""

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
--                                                                            --
-- A line of the card is a PARAGRAPH of the source, so lines are separated by --
-- blank lines. Consecutive source lines cannot be told apart here: Pandoc    --
-- joins them into one paragraph and re-wraps it at its own width, so by the  --
-- time the HTML arrives the author's line breaks are gone.                   --
--                                                                            --
-- A business-card slide with no card zone at all is ONE card: its prose is   --
-- the card. That is the first thing anyone writes, and it used to come out   --
-- as an ordinary slide, as if the role had been ignored.                     --
--------------------------------------------------------------------------------

::Routine Cards Public
  Use Strict Arg body

  -- In a marker-opened slide the title is a ::: title zone, and its <p> is
  -- not the first line of the card: the search starts after it.
  from = 1
  t = body~pos('<div class="title"')
  If t > 0 Then from = MatchDiv(body, t)

  If NextCard(body) = 0, body~pos("<p>", from) > 0 Then Do
    first = body~pos("<p>", from)
    last  = body~lastPos("</p>") + 4
    body  = body~left(first - 1)'<div class="card">' || -
            body~substr(first, last - first)'</div>'body~substr(last)
  End

  body = Gather(body, "card", "cards")

  out = ""
  Loop
    at = NextCard(body)
    If at = 0 Then Leave
    -- The opening tag is kept whole except for its "card" class, so a card
    -- written {.card .fragment anim=fade-up} is still revealed, and animated,
    -- as the vcard it becomes.
    pre  = body~left(at - 1)
    tagEnd = body~pos(">", at)
    tag  = body~substr(at, tagEnd - at + 1)
    card = body~substr(tagEnd + 1)
    Parse Var tag '<div class="' classes '"' attrs '>'
    extras = ""
    Loop w Over classes~makeArray(" ")
      If w \== "card", w \== "" Then extras = extras w
    End
    n    = card~pos("</div>")
    body = card~substr(n + 6)
    card = card~left(n - 1)

    inner = ""
    seq = "name role"
    -- .tight: an address, not a person -- no role, the lines close together
    -- (Rony, 27-Sep: an institution's card, whose second line is a street).
    If WordPos("tight", extras) > 0 Then seq = "name"
    k = 1
    Loop While card~pos("<p>") > 0
      Parse Var card . "<p>" text "</p>" card
      -- A paragraph broken by hard line breaks (see CardLines) is several
      -- lines of the card, not one.
      Loop part Over text~changeStr("<br />", "0"x)~makeArray("0"x)
        part = Strip(Strip(part, "B", "0a"x))
        If part == "" Then Iterate
        If k <= Words(seq) Then cls = Word(seq, k)
        Else cls = "detail"
        inner = inner'<p class="'cls'">'part'</p>'
        k = k + 1
      End
    End

    out = out || pre || '<div class="'Strip("vcard"extras)'"'attrs'>' || -
          inner || '</div>'
  End

  Return out || body


--------------------------------------------------------------------------------
-- NextCard - where the next card zone opens, or 0. A card is a div whose     --
-- classes include "card" as a WORD: {.card .fragment} arrives as             --
-- class="card fragment", and "cards", the container, is not a card.          --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- CardFields - the {fields} on a business card, before BodyFields fills them.--
--                                                                            --
-- A card is a template of a kind: the same card, with the same lines, is    --
-- written once and filled per skin, and not every house has as many address  --
-- lines as the next (Rony, 27-Sep). So, on a card, and only there:           --
--   - a field with a value is left to BodyFields, as anywhere;               --
--   - a field declared with no value (EmptyFields) leaves nothing;           --
--   - a field the deck does not declare at all is reported (a typo, most     --
--     likely), once, and leaves nothing either;                              --
--   - a line whose fields all left nothing goes, label and all: a card      --
--     does not show "**Email**" with no address after it.                    --
-- Elsewhere a {name} the deck does not declare stays as written (braces are  --
-- text in a slide), and that does not change.                               --
--                                                                            --
-- A line of the card is a paragraph, or a part of one between <br />s (see   --
-- CardLines). The card is each ::: card zone, or, with none, all the prose   --
-- after the title, as in Cards.                                              --
--------------------------------------------------------------------------------

::Routine CardFields Public
  Use Strict Arg body, fields, where = ""

  If body~pos("{") == 0, body~caselessPos("%7B") == 0 Then Return body

  If NextCard(body) == 0 Then Do
    from = 1
    t = body~pos('<div class="title"')
    If t > 0 Then from = MatchDiv(body, t)
    Return body~left(from - 1) || CardParagraphs(body~substr(from), fields, where)
  End

  out = ""
  Loop
    at = NextCard(body)
    If at == 0 Then Leave
    gt = body~pos(">", at)
    e  = MatchDiv(body, at)                     -- just past the card's </div>
    out = out || body~left(gt) || -
          CardParagraphs(body~substr(gt + 1, e - 6 - gt - 1), fields, where) || "</div>"
    body = body~substr(e)
  End

  Return out || body

-- CardParagraphs - CardFields, on each line of each <p> of one card.
::Routine CardParagraphs
  Use Strict Arg html, fields, where

  out = .MutableBuffer~new
  p = 1
  Loop
    a = html~pos("<p>", p)
    If a == 0 Then Leave
    b = html~pos("</p>", a)
    If b == 0 Then Leave
    text = html~substr(a + 3, b - a - 3)
    kept = .Array~new
    Loop part Over text~changeStr("<br />", "0"x)~makeArray("0"x)
      line = CardLine(part, fields, where)
      If line \== .Nil Then kept~append(line)
    End
    out~append(html~substr(p, a - p))
    If kept~items > 0 Then out~append("<p>"kept~makeString("L", "<br />")"</p>")
    p = b + 4
    -- a paragraph that went leaves no blank line behind
    If kept~items == 0, html~substr(p, 1) == "0a"x Then p = p + 1
  End
  out~append(html~substr(p))

  Return out~string

-- CardLine - one line of a card: its empty fields taken out, or .nil when it  --
-- had fields and all of them were empty.                                     --
::Routine CardLine
  Use Strict Arg line, fields, where

  runtime = "page pages total-pages totalpages" LiveFields()
  out = ""
  seen = 0; filled = 0
  p = 1
  Loop Forever
    b1 = line~pos("{", p)
    b2 = line~caselessPos("%7B", p)
    If b1 == 0, b2 == 0 Then Leave
    If b1 == 0 Then at = b2
    Else If b2 == 0 Then at = b1
    Else at = Min(b1, b2)
    If at == b2 Then Do; open = 3; close = "%7D"; End
    Else Do; open = 1; close = "}"; End
    e = line~caselessPos(close, at + open)
    key = ""
    If e > 0 Then key = Lower(Strip(line~substr(at + open, e - at - open)))
    ok = key \== "" & e > 0
    If ok Then ok = Verify(key, "abcdefghijklmnopqrstuvwxyz0123456789-_.") == 0
    If ok Then ok = key~left(2) \== "__"
    -- not a field, or inside code (a card may show a command): as it is
    If ok Then ok = line~lastPos("<code", at) <= line~lastPos("</code>", at)
    If \ok Then Do
      out = out || line~substr(p, at + open - p)
      p = at + open
      Iterate
    End
    seen = 1
    empty = 0
    Select
      When WordPos(key, runtime) > 0 Then Nop
      When fields~hasIndex(key) Then empty = (Strip(fields[key]) == "")
      When SkinOnlyField(fields, key) Then Do
        empty = 1
        If \.local~hasIndex("MD2SLIDES.SKINONLY."key) Then Do
          .local["MD2SLIDES.SKINONLY."key] = 1
          Call Warn "{"key"} is only declared for other skins (skin-...-"key":)" -
            "and has no value under this one; add a plain '"key":' as the" -
            "default."
        End
      End
      Otherwise Do
        empty = 1
        If \.local~hasIndex("MD2SLIDES.CARDFIELD."key) Then Do
          .local["MD2SLIDES.CARDFIELD."key] = 1
          on = ""
          If where \== "" Then on = " on slide '"where"'"
          Call Warn "the business card"on "shows {"key"}, but the deck" -
            "declares no field called '"key"', so it is left out. To fill it," -
            "set it at the top level of rexxpub: ("key": ...). If it is only" -
            "empty on some cards or skins, declare it with no value ("key":)" -
            "and this warning goes."
        End
      End
    End
    If empty Then Do
      out = out || line~substr(p, at - p)
      p = e + close~length
    End
    Else Do
      filled = 1
      out = out || line~substr(p, e + close~length - p)
      p = e + close~length
    End
  End
  out = out || line~substr(p)

  If seen, \filled Then Return .Nil
  Return out

::Routine NextCard
  Use Strict Arg body

  from = 1
  Loop Forever
    at = body~pos('<div class="', from)
    If at = 0 Then Return 0
    Parse Value body~substr(at + 12) With classes '"'
    If WordPos("card", classes) > 0 Then Return at
    from = at + 12
  End

--------------------------------------------------------------------------------
-- PandocStyle: the identity's preferred Pandoc highlighting skin, or         --
-- "pygments" if it declares none. A dark identity names a dark skin here so  --
-- its token colours sit well on its own --skin-othercode-bg.                 --
--------------------------------------------------------------------------------

::Routine PandocStyle
  Use Strict Arg css

  If css~pos("--skin-pandoc-style:") = 0 Then Return "pygments"
  Parse Var css . "--skin-pandoc-style:" value ";" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- RexxSkins: every Rexx highlighter skin, concatenated for embedding.        --
--                                                                            --
-- A deck is a single self-contained file, so it cannot lazy-load stylesheets --
-- the way the CGI does. Instead every skin is embedded, and the in-deck      --
-- chooser switches between them by rewriting the highlight-rexx-<style>      --
-- class. The skins are the project's own flattened/rexx-*.css -- read from   --
-- there, never copied -- so md2slides and md2pdf share one set. (A "thin"    --
-- deck carrying only a chosen few could be added later; for now it           --
-- embeds all.)                                                               --
--------------------------------------------------------------------------------

::Routine RexxSkins
  Use Strict Arg rootDir

  -- The nested css/rexx-*.css, NOT css/flattened/. The flattened copies exist
  -- only to work around the back-level Chromium in pagedjs-cli, which has no
  -- CSS nesting; md2pdf needs them for that reason. A deck is viewed in an
  -- ordinary browser, so it takes the canonical nested source. test1 is a
  -- development scratch skin and is not shipped.
  dir = rootDir"/css"
  files = .Array~new
  Call SysFileTree dir"/rexx-*.css", "files.", "FO"

  css = ""
  Do i = 1 To files.0
    If SkinName(files.i) == "test1" Then Iterate
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
-- SkinName: the <style> part of a .../rexx-<style>.css path.                 --
--------------------------------------------------------------------------------

::Routine SkinName
  Use Strict Arg path

  leaf = FileSpec("Name", path)             -- rexx-<style>.css
  Return leaf~substr(6, Length(leaf) - 9)   -- strip "rexx-" and ".css"

--------------------------------------------------------------------------------
-- RexxStyleData: the code-style list for the in-deck style modal (key `s`),  --
-- one entry per shipped skin, in alphabetical order, with the deck's default --
-- flagged. Emitted as a JS array literal that runtime.js reads to build the  --
-- modal's clickable item list -- the old <select> is gone, so there is no    --
-- <option> HTML any more. Kept in step with RexxSkins: same source, same     --
-- blacklist.                                                                 --
--------------------------------------------------------------------------------

::Routine RexxStyleData
  Use Strict Arg rootDir, defaultSkin

  dir = rootDir"/css"
  files = .Array~new
  Call SysFileTree dir"/rexx-*.css", "files.", "FO"

  names = .Array~new
  Do i = 1 To files.0
    style = SkinName(files.i)
    If style == "test1" Then Iterate
    names~append(style)
  End
  names~sortWith(.CaselessComparator~new)

  -- A JS array of {v:<style>, d:<isDefault>} objects. Style names come from
  -- file leaves matching rexx-*.css, so they are already safe JS identifiers
  -- (no quoting hazard); still, emit them as quoted strings for robustness.
  items = .Array~new
  Do style Over names
    def = "false"
    If style == defaultSkin Then def = "true"
    items~append('{v:"'style'",d:'def'}')
  End

  Return "[" || items~makeString("Line", ",") || "]"

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
-- FrontMatterNames -- master-pages: and img:, one name or a YAML list of     --
-- names (see the main program). Returns an Array of names, or .nil when the  --
-- value is neither: the error is reported here, and the caller stops.        --
--------------------------------------------------------------------------------

::Routine FrontMatterNames Public
  Use Strict Arg value, key

  If value~isA(.String) Then Do
    If Strip(value) == "" Then Return .Array~new
    Return .Array~of(Strip(value))
  End
  what = "a block"
  If value~isA(.Array) Then Do
    names = .Array~new
    Do i = 1 To value~items
      item = value[i]
      If \item~isA(.String) Then Do
        what = "a list or a block as item" i
        Leave
      End
      If Strip(item) == "" Then Iterate
      names~append(Strip(item))
    End
    If i > value~items Then Return names
  End
  .Error~Say("md2slides:" key": in the front matter has" what"; it takes" -
    "one name ('"key": base.css') or a list of names ('"key": [a, b]').")
  Return .Nil

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
-- FieldText - a front-matter value as the text of a {field}, or .nil when it --
-- is not one. A list is its items joined by ", ", as Pandoc's templates and  --
-- Jekyll's join do: `author: [Josep Maria Blasco, Rony G. Flatscher]`. An    --
-- item that is a mapping gives its name:, as Pandoc and Quarto write an      --
-- author with an affiliation; other items are left out. No "and" before the  --
-- last one: that is a matter of language, and a deck may be in any.          --
--------------------------------------------------------------------------------

::Routine FieldText Public
  Use Strict Arg value

  If value~isA(.String) Then Return value
  If \value~isA(.Array)  Then Return .Nil      -- a block
  items = .Array~new
  Do i = 1 To value~items
    item = value[i]
    If item~isA(.StringTable), item~hasIndex("name") Then item = item["name"]
    If \item~isA(.String) Then Iterate
    If Strip(item) == "" Then Iterate
    items~append(Strip(item))
  End
  Return items~makeString("L", ", ")

--------------------------------------------------------------------------------
-- MarginFields - the values that fill the {placeholders} in the margin boxes. --
--                                                                            --
-- In the six-box model the FIELDS and the BOXES are separate concerns, so     --
-- fields are collected from the TOP level of rexxpub: (presenter, affiliation, --
-- date, version, version-date, and anything else the author invents), NOT from --
-- inside footer: -- footer:/header: are now the box templates (left/center/    --
-- right), not a bag of values. Reserved pipeline keys (style, anim, the box    --
-- blocks themselves, ...) are skipped so they never masquerade as fields.      --
--                                                                            --
-- BACK-COMPAT: a deck written the old way, with scalar fields INSIDE footer:,  --
-- still works -- those are folded in too (the box blocks' own left/center/     --
-- right are the only footer: scalars skipped). A top-level field wins over a   --
-- same-named one inside footer:.                                              --
--                                                                            --
-- (The routine keeps the name FooterFields for its callers; it now serves both --
-- edges. Fields, not footer.)                                                 --
--------------------------------------------------------------------------------

::Routine FooterFields
  Use Strict Arg rexxpub, skinTag = ""

  fields = .StringTable~new
  If \rexxpub~isA(.StringTable) Then Return fields

  -- Keys that are pipeline machinery, never author fields.
  reserved = FooterFields.Reserved()
  boxSides = "left center right"

  -- Back-compat pass: scalar fields still sitting inside footer:/header:.
  Loop edge Over "footer header"~makeArray(" ")
    If \rexxpub~hasIndex(edge) Then Iterate
    blk = rexxpub[edge]
    If \blk~isA(.StringTable) Then Iterate
    Loop name Over blk~allIndexes
      If WordPos(Lower(name), boxSides) > 0 Then Iterate   -- a box, not a field
      If Lower(name) == "font-size" Then Iterate            -- the band's size
      value = FieldText(blk[name])
      If value == .Nil Then Iterate
      fields[Lower(name)] = value
    End
  End

  -- Primary pass: top-level scalar fields (these win over the back-compat ones).
  Loop name Over rexxpub~allIndexes
    If WordPos(Lower(name), reserved) > 0 Then Iterate
    value = FieldText(rexxpub[name])
    If value == .Nil Then Iterate             -- a nested block is not a field
    fields[Lower(name)] = value
  End

  -- Skin-specific values: `skin-mu-affiliation:` is what {affiliation} is when
  -- the deck is built with skin-mu.css, and `affiliation:` everywhere else. A
  -- deck shown under two institutions' skins carries both credits and each
  -- build picks its own; no second copy of the deck. Works for any field.
  If skinTag \== "" Then Do
    prefix = "skin-"Lower(skinTag)"-"
    Loop name Over fields~allIndexes
      If name~startsWith(prefix), name~length > prefix~length Then
        fields[name~substr(prefix~length + 1)] = fields[name]
    End
  End

  If fields~hasIndex("license") Then
    Call CheckLicence fields["license"], "in the front matter"

  Return fields

::Routine FooterFields.Reserved
  Return "docclass style skin master-pages theme csl bibliography" -
         "font-prose font-mono anim header footer figures listings" -
         "number-figures highlight pandoc-style img about timer"

--------------------------------------------------------------------------------
-- EmptyFields - the fields the deck declares with no value, as "".           --
--                                                                            --
-- `address-2:` with nothing after it says "there is such a field, and here   --
-- it is empty" (Rony, 27-Sep: one card has three address lines, another      --
-- one). The YAML reader leaves a key with no value out, as "not specified", --
-- so {address-2} was a field nobody had declared and showed as written. The  --
-- keys are found in the file itself (DeclaredEmpty) and given "", unless the --
-- field already has a value (from its skin-...- key, say). A skin key with   --
-- no value (`skin-mu-address-2:`) empties the field under that skin, even if --
-- the plain one has a value.                                                 --
--------------------------------------------------------------------------------

::Routine EmptyFields Public
  Use Strict Arg fields, source, skinTag = ""

  reserved = FooterFields.Reserved()
  prefix = ""
  If skinTag \== "" Then prefix = "skin-"Lower(skinTag)"-"
  Loop name Over DeclaredEmpty(source)
    If WordPos(name, reserved) > 0 Then Iterate
    If name~startsWith("skin-") Then Do
      If prefix \== "", name~startsWith(prefix), name~length > prefix~length Then
        fields[name~substr(prefix~length + 1)] = ""
      Iterate
    End
    If \fields~hasIndex(name) Then fields[name] = ""
  End

  Return

--------------------------------------------------------------------------------
-- DeclaredEmpty - the keys written right under rexxpub: with no value.       --
--                                                                            --
-- "No value" is nothing after the colon, a comment, ~ or null. A key with a  --
-- block under it (a mapping, or a list, which YAML allows at the key's own   --
-- indent) has a value: `timer:`, `footer:`. A light scan, like DuplicateKeys; --
-- the front matter has already been read (and checked) by YAMLFrontMatter.  --
--------------------------------------------------------------------------------

::Routine DeclaredEmpty Public
  Use Strict Arg source

  out = .Array~new
  If source~items < 3 Then Return out
  first = source[1]
  If first~startsWith("EFBBBF"x) Then first = first~substr(4)
  If Strip(first) \== "---" Then Return out
  inRexxPub = 0
  kid = -1                               -- the indent of rexxpub:'s own keys
  Loop i = 2 To source~items
    line = source[i]~changeStr("09"x, " ")
    s = Strip(line)
    If s == "---" | s == "..." Then Leave
    If s == "" | s~left(1) == "#" Then Iterate
    ind = Verify(line, " ") - 1
    If ind == 0 Then Do
      inRexxPub = Lower(s)~startsWith("rexxpub:")
      kid = -1
      Iterate
    End
    If \inRexxPub Then Iterate
    If kid < 0 Then kid = ind
    If ind \== kid Then Iterate
    c = s~pos(":")
    If c < 2 Then Iterate
    If c < s~length, s~substr(c + 1, 1) \== " " Then Iterate
    key = Lower(s~left(c - 1)~strip("B", '"')~strip("B", "'"))
    value = Strip(s~substr(c + 1))
    If value~left(1) == "#" Then value = ""
    If value \== "", WordPos(Lower(value), "~ null") == 0 Then Iterate
    -- the next line that says something: a block under this key?
    next = ""
    Loop j = i + 1 To source~items
      t  = source[j]~changeStr("09"x, " ")
      ts = Strip(t)
      If ts == "" | ts~left(1) == "#" Then Iterate
      next = t
      Leave
    End
    If next \== "", Strip(next) \== "---", Strip(next) \== "..." Then Do
      nind = Verify(next, " ") - 1
      ns   = Strip(next)
      If nind > ind Then Iterate
      If nind == ind, ns == "-" | ns~left(2) == "- " Then Iterate
    End
    out~append(key)
  End

  Return out

--------------------------------------------------------------------------------
-- SlideSkinTag - the short name of the slide skin, as a deck names it in a   --
-- skin-specific field: skin-mu.css -> "mu"; a sheet not called skin-*.css    --
-- goes by its file name without the extension (corporate.css -> corporate). --
--------------------------------------------------------------------------------

::Routine SlideSkinTag Public
  Use Strict Arg path
  leaf = FileSpec("Name", ChangeStr("\", path, "/"))
  If Lower(leaf)~endsWith(".css") Then leaf = leaf~left(leaf~length - 4)
  If Lower(leaf)~startsWith("skin-") Then leaf = leaf~substr(6)
  Return Lower(leaf)

--------------------------------------------------------------------------------
-- AutoFields - fold in the fields the build resolves by itself, so an author  --
-- can drop {today}, {file-date} or {file-time} into any margin box without     --
-- declaring a value. These are the counterpart of the runtime's {page}/{pages}:--
-- known to the machine, not the document. A field the author DID declare with  --
-- the same name is left untouched (their value wins), so `file-date: 2026-01-01`--
-- pins it and the automatic one only fills the gap.                            --
--                                                                            --
--   today          the build date, ISO YYYY-MM-DD                             --
--   now            the build time, HH:MM:SS                                   --
--   file-date      the source .md's own modification date, ISO YYYY-MM-DD     --
--   file-time      the source .md's own modification time, HH:MM:SS          --
--   file-name      the source's name, without its folder: 010_ooRexx.md      --
--   file-name-full the source's fully qualified name                         --
--   file-path      the folder the source is in (fully qualified, no final /) --
--                                                                            --
-- The names are as written on the machine that builds: a Windows build says --
-- E:\WU\...\010_ooRexx.md. {now} is when the deck was BUILT, not a live     --
-- clock: a footer that changes while you talk is a distraction, and the     --
-- build time is what tells two copies of a deck apart.                      --
--                                                                            --
-- version / version-date are NOT here: they are the AUTHOR's to state (a deck's--
-- version is not something the build can know), so they ride as ordinary       --
-- declared fields via FooterFields, and simply become available to the boxes.  --
--------------------------------------------------------------------------------

::Routine AutoFields
  Use Strict Arg fields, sourceFile

  If \fields~hasIndex("today") Then fields["today"] = ResolveToday()
  If \fields~hasIndex("now")   Then fields["now"]   = Time("Normal")

  full = .File~new(sourceFile)~absolutePath
  If \fields~hasIndex("file-name")      Then fields["file-name"]      = FileSpec("Name", full)
  If \fields~hasIndex("file-name-full") Then fields["file-name-full"] = full
  If \fields~hasIndex("file-path")      Then Do
    dir = FileSpec("Location", full)
    If dir~length > 1, (dir~right(1) == "/" | dir~right(1) == "\") Then
      dir = dir~left(dir~length - 1)
    fields["file-path"] = dir
  End

  -- The source file's own timestamp. Stream~query("TimeStamp") is
  -- "YYYY-MM-DD HH:MM:SS"; split it into date and time halves.
  ts = ""
  Signal On Any Name SkipFileStamp
  ts = .Stream~new(sourceFile)~query("TimeStamp")
SkipFileStamp:
  If ts \== "", ts \== .Nil Then Do
    Parse Var ts fdate ftime .
    If \fields~hasIndex("file-date") Then fields["file-date"] = fdate
    If \fields~hasIndex("file-time") Then fields["file-time"] = ftime
  End
  Return

--------------------------------------------------------------------------------
-- ResolveBoxes - resolve the SIX margin-box templates and stash them in       --
-- `fields` under reserved __box-<edge>-<side> keys (edge: header/footer, side: --
-- left/center/right). This is the Paged-Media model: six named boxes an author --
-- fills with whatever they like, {placeholders} and all.                       --
--                                                                            --
-- Precedence, low to high:                                                     --
--   1. skin default -- --skin-<edge>-<side> in the skin's :root (a CSS string  --
--      value, quoted). This is the CI's house layout of the margins.           --
--   2. deck override -- the front-matter header:/footer: block, side by side   --
--      (footer: {left: '...', center: '...', right: '...'}).                   --
--   3. per-slide override -- a :::header-left ... :::footer-right zone in ONE   --
--      slide, resolved later in SlideIdentity (it never comes through here).    --
--                                                                            --
-- The template itself is stored verbatim; {placeholders} are expanded per      --
-- slide (page/total differ, and a slide override may change a field). An empty  --
-- template means "this box is empty" -- and stays empty, so a skin can ship    --
-- five boxes and leave one blank.                                              --
--------------------------------------------------------------------------------

::Routine ResolveBoxes
  Use Strict Arg fields, skinCSS, rexxpub

  Loop edge Over "header footer"~makeArray(" ")
    -- The deck's override sub-block for this edge, if any.
    deckBlock = .Nil
    If rexxpub~isA(.StringTable), rexxpub~hasIndex(edge) Then Do
      cand = rexxpub[edge]
      If cand~isA(.StringTable) Then deckBlock = cand
    End

    Loop side Over "left center right"~makeArray(" ")
      -- 1. skin default from --skin-<edge>-<side>.
      tmpl = CITemplate(skinCSS, edge"-"side)
      from = "skin"

      -- 2. deck override wins if present.
      If deckBlock \== .Nil, deckBlock~hasIndex(side) Then Do
        v = deckBlock[side]
        If v~isA(.String) Then Do
          tmpl = v
          from = "deck"
        End
      End

      fields["__box-"edge"-"side] = tmpl
      fields["__from-"edge"-"side] = from      -- for CheckFooter's message
    End
  End
  Return

--------------------------------------------------------------------------------
-- The deck-level values, as attributes for the stage element.                --
--------------------------------------------------------------------------------

::Routine FooterAttrs
  Use Strict Arg fields

  out = ""
  Loop name Over fields~allIndexes
    If Left(name, 2) == "__" Then Iterate       -- resolved box templates, not fields
    out = out' data-footer-'name'="'AttrEscape(fields[name])'"'
  End

  Return out

--------------------------------------------------------------------------------
-- The identity declares the height of the band its footer sits in.           --
--------------------------------------------------------------------------------

::Routine FooterHeight
  Use Strict Arg css

  If css~pos("--skin-footer-height:") = 0 Then Return 64
  Parse Var css . "--skin-footer-height:" value "px" .

  Return Strip(value)

--------------------------------------------------------------------------------
-- CITemplate - the skin's default template for one margin box, as written.    --
-- `box` is the full box name -- "header-left", "footer-right", ... -- read     --
-- from --skin-<box> in the skin :root. Was footer-only (--skin-footer-<slot>); --
-- now that the model is six Paged-Media boxes it reads header and footer alike. --
-- Returns "" when the skin declares no template for that box (an empty box).   --
--------------------------------------------------------------------------------

::Routine CITemplate
  Use Strict Arg css, box

  marker = "--skin-"box":"
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
  builtIn = "page pages total-pages totalpages" LiveFields()

  -- Walk all six margin boxes (header + footer x left/center/right). The
  -- resolved templates ride in fields under __box-<edge>-<side> (skin default
  -- already overridden by the deck), so we validate what will actually render.
  Loop edge Over "header footer"~makeArray(" ")
    Loop slot Over "left center right"~makeArray(" ")
      -- Fields inside [ ] are optional BY DECLARATION: bracketing them is how an
      -- identity says "if there is one". Only what is left after the groups are
      -- removed is genuinely required, and only that is worth a warning.
      template = ""
      rest     = ""
      If fields~hasIndex("__box-"edge"-"slot) Then rest = fields["__box-"edge"-"slot]
      Loop While rest~pos("[") > 0
        Parse Var rest before "[" . "]" rest
        template = template || before
      End
      template = template || rest

      Loop While template~pos("{") > 0
        Parse Var template . "{" name "}" template
        name = Strip(name)
        If name == ""                       Then Iterate
        If WordPos(Lower(name), builtIn) > 0 Then Iterate
        If fields~hasIndex(Lower(name))     Then Iterate

        -- Not a failure: the deck is still built, with a gap where the value
        -- would have gone. The message says where the box's template came
        -- from and the ways out, because "asks for {footer}, which the
        -- document does not set" left Rony with nothing to act on: he had
        -- never written {footer}, the skin had.
        box  = edge"-"slot
        from = fields["__from-"box]
        If from == "deck" Then
          whose = "The" box "box you set in rexxpub: ("edge": "slot": ...)"
        Else
          whose = "The" box "box, as the skin lays it out" -
                  "(--skin-"box" in the skin sheet),"
        own = "give the box its own text in rexxpub: ("edge": then" -
              slot": '...')"
        opt = "if an empty value is fine, write the field as [{"name"}]" -
              "to mark it optional"
        If WordPos(Lower(name), FooterFields.Reserved()) == 0 Then
          Call Warn whose "shows {"name"}, but the deck sets no field called" -
            "'"Lower(name)"', so that part of the box comes out empty. To" -
            "fill it, set it at the top level of rexxpub: ("Lower(name)":" -
            "...). To show something else there," own". Or," opt"."
        Else
          Call Warn whose "shows {"name"}, but '"Lower(name)"' is a rexxpub:" -
            "keyword, not a field, so nothing can fill it and that part of the" -
            "box comes out empty. To show something there," own"."

      End
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
-- DeckName - the deck's bare name: the file, without directory and without    --
-- the .md. It is what the default .html is called, and what the browser tab   --
-- falls back to. ONE routine for both, because two spellings of "strip the    --
-- extension" drift, and then a deck writes itself to talk.html and calls the  --
-- tab talk.md.                                                               --
--------------------------------------------------------------------------------

::Routine DeckName Public
  Use Strict Arg path

  name = FileSpec("Name", path)
  If name~caselessEndsWith(".md") Then name = Left(name, Length(name) - 3)

  Return name

--------------------------------------------------------------------------------
-- DeckTitle - what the browser tab says.                                     --
--                                                                            --
-- Rony, comparing the same deck across four skins, had four tabs all reading --
-- "Slide deck": the literal says what the file IS and never which one. So    --
-- the deck's own file name is the fallback. A `title:` in the front matter   --
-- still wins -- it is the author saying it out loud -- and the literal is    --
-- left for the case where there is no name to be had at all.                 --
--                                                                            --
-- Escaped here rather than at the template, because this is the only place   --
-- that knows the value is about to become markup: a deck called "Rexx & Co"  --
-- otherwise leaves a bare & in the head of every deck it builds.             --
--------------------------------------------------------------------------------

::Routine DeckTitle Public
  Use Strict Arg rexxpub, deckName = ""

  title = "Slide deck"
  If Strip(deckName) \== "" Then title = Strip(deckName)

  /* An empty `title:` is the author having written the key and nothing after  */
  /* it, which is not a request for an empty tab -- it reads as absent, the    */
  /* same way an empty font-prose: leaves the skin's face standing.            */
  If rexxpub~hasIndex("title"), Strip(rexxpub["title"]) \== "" Then
    title = Strip(rexxpub["title"])

  Return AttrEscape(title)

--------------------------------------------------------------------------------
-- Attribute values reach the browser through HTML, so they are escaped.      --
--------------------------------------------------------------------------------

::Routine HtmlUnescape
  -- The four entities AttrEscape writes, read back. "&amp;" goes last, so
  -- that "&amp;lt;" becomes "&lt;" and not "<".
  Use Strict Arg text

  text = text~changeStr("&quot;", '"')
  text = text~changeStr("&lt;", "<")
  text = text~changeStr("&gt;", ">")
  text = text~changeStr("&amp;", "&")

  Return text

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
  -- 'skin' here is the Rexx HIGHLIGHTING style (css/rexx-<style>.css), not the
  -- slide skin -- the two words collided and this one came first. The slide
  -- skin used to arrive as a 'brand' argument that nothing ever read; it went
  -- with the brand vocabulary itself.
  Use Strict Arg stage, identityCSS, home, skin, rexxpub, fields, hlSheet, deckDir, rexxSkins, rexxStyleData, deckName = "", captionCSS = ""

  title = DeckTitle(rexxpub, deckName)

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
  -- skin sheet must supply the colours -- exactly as md2pdf loads
  -- css/pandoc/<style>.css. The sheet is read from the project's shared
  -- css/pandoc/ (hlSheet, already validated), so md2slides offers the same
  -- skin set as md2pdf without duplicating a single file. pycode.css is
  -- loaded AFTER it so the identity's --skin-othercode-bg wins the panel ground
  -- over anything the skin might set. The Rexx block is untouched by all
  -- this: it goes through the Highlighter (skins.css) and never carries a
  -- .sourceCode class.
  pandocCSS = ""
  If SysIsFile(hlSheet) Then pandocCSS = ReadFile(hlSheet)

  -- The deck's animation-duration defaults (front-matter anim:) set the SAME
  -- --skin-anim-duration-* hooks a skin sets, so like the fonts they must beat
  -- the skin sheet -- and the skin loads as identityCSS AFTER runtime.css. So
  -- this override rides at the END of identityCSS, last in the cascade. Effect
  -- defaults are applied in the body, not here.
  animOverride = DeckAnimCSS(rexxpub)
  -- The font override must beat the SKIN (which sets --skin-font-prose/mono),
  -- and the skin sheet loads as identityCSS AFTER runtime.css. So the deck
  -- fonts ride at the END of identityCSS, last in the cascade, where they win.
  fontsOverride = DeckFontsCSS(rexxpub)
  -- The margin bands' own text size (header:/footer: font-size:), also last:
  -- it must beat the master, which is where a skin's footer size lives.
  fontsOverride = fontsOverride || MarginSizeCSS(rexxpub)

  html = html~caselessChangeStr("%title%",   title)
  -- runtime.css, then the generated level-N rules right after it: they beat the
  -- .body/.body-ul outline and scale rules that a bare inline style could not.
  html = html~caselessChangeStr("%runtimeCSS%", -
                                ReadFile(home"/css/runtime.css") || "0a"x || LevelRules())
  -- The caption options (rexxpub: listings:/figures:) come last of all: they
  -- use the article pipelines' selectors, and must beat runtime.css's.
  html = html~caselessChangeStr("%identityCSS%",      identityCSS || fontsOverride -
                                             || animOverride || captionCSS)
  -- The spotlight is NOT a slides asset: it lives in the project's shared
  -- css/ and js/, beside numberFigures.js, because the same data-spot
  -- attribute is emitted by every HTML pipeline (md2html, md2pdf, md2epub,
  -- highlight), not just this one. "home" points at bin/md2slides, so the two
  -- files are reached from the project root, two levels up.
  --
  -- Both MUST be embedded: a deck is self-contained, and the runtime guards
  -- every spotlight call with "if (window.Spotlight)". Leave the script out
  -- and the feature does not fail, it simply never happens -- silently. The
  -- pens themselves need no handling here: they are declared inside the
  -- css/rexx-*.css sheets, which RexxSkins already embeds whole.
  -- Safe now that 'home' is fixed at bin/md2slides: it used to be settable
  -- with --assets, and pointing that anywhere else sent projRoot -- and with
  -- it the spotlight's sheet and script -- somewhere unrelated.
  projRoot = ChangeStr("\", .File~new(home)~parentFile~parent, "/")

  html = html~caselessChangeStr("%extraCSS%",   ReadFile(home"/css/bcard.css") -
                                             || ReadFile(home"/css/overlay.css") -
                                             || ReadFile(home"/css/anim.css") -
                                             || pandocCSS -
                                             || ReadFile(home"/css/pycode.css") -
                                             || ReadFile(projRoot"/css/spotlight.css"))
  html = html~caselessChangeStr("%skinsCSS%",  rexxSkins)
  -- runtimeJS carries the %rexxStyleData% token inside it, so the JS must be
  -- spliced in first and the data token resolved afterwards.
  html = html~caselessChangeStr("%spotlightJS%", ReadFile(projRoot"/js/spotlight.js"))
  html = html~caselessChangeStr("%runtimeJS%",  ReadFile(home"/js/runtime.js"))
  html = html~caselessChangeStr("%rexxStyleData%", rexxStyleData)
  html = html~caselessChangeStr("%stage%",      stage)
  html = html~caselessChangeStr("%stageAttrs%", stageAttrs)

  Return html

--------------------------------------------------------------------------------
-- DeckAnimCSS - a :root override for the deck's animation defaults, read from
-- the front matter's `rexxpub: anim:` block, or "" when it declares none.
-- Two independent axes, page and element, each with an effect and a duration:
--
--     rexxpub:
--       anim:
--         element: { effect: fade-up, duration: 1 }
--         page:    { effect: cut,     duration: 0 }
--
-- Durations follow the deck's time contract: seconds as a bare number (1,
-- 0.4), or an explicit "ms" suffix (400ms). They are emitted here as
-- --skin-anim-duration-elem/-page -- the same hooks a skin sets, so a deck
-- value overrides the skin (this sheet loads after the skin's). The default
-- EFFECT is not a single variable (each effect is its own geometry), so it is
-- applied as a data-anim on unmarked fragments in the body pass; see
-- DeckDefaultAnim / ApplyDefaultAnim. Emitted
-- after runtime.css so it wins the cascade.
--------------------------------------------------------------------------------

::Routine DeckAnimCSS
  Use Strict Arg rexxpub

  If \rexxpub~hasIndex("anim") Then Return ""
  anim = rexxpub["anim"]
  If \anim~isA(.StringTable) Then Return ""

  css = ""
  css = css || AnimDurationVar(anim, "element", "--skin-anim-duration-elem")
  css = css || AnimDurationVar(anim, "page",    "--skin-anim-duration-page")

  If css == "" Then Return ""
  Return "0a"x || ":root {" css " }" || "0a"x

--------------------------------------------------------------------------------
-- AnimDurationVar - one "--var: <time>;" fragment for a scope's duration, or
-- "" if the scope or its duration is absent. The value is validated with the
-- same CheckAnimDuration used for inline anim-duration, so a typo warns rather
-- than emitting bad CSS. Seconds are the unit; an explicit "ms" is honoured.
--------------------------------------------------------------------------------
::Routine AnimDurationVar
  Use Strict Arg anim, scope, varName

  If \anim~hasIndex(scope) Then Return ""
  sub = anim[scope]
  If \sub~isA(.StringTable)      Then Return ""
  If \sub~hasIndex("duration")   Then Return ""
  value = sub["duration"]
  If value == .Nil               Then Return ""

  Call CheckAnimDuration Squeeze(value), "front-matter anim:" scope

  -- Normalise to a CSS time: a bare number is seconds; a value already carrying
  -- s/ms is passed through. CheckAnimDuration has already vetted the shape.
  v = Squeeze(value)
  If v~dataType("N") Then v = v"s"
  Return " " || varName || ":" v";"

--------------------------------------------------------------------------------
-- DeckDefaultAnim - the deck's default element effect from the front matter  --
-- (rexxpub: anim: element: effect:), validated against the element catalogue,--
-- or "" when unset. Applied by ApplyDefaultAnim to fragments that carry no   --
-- data-anim of their own, so `::: incremental` items take the deck's effect. --
--------------------------------------------------------------------------------
::Routine DeckDefaultAnim
  Use Strict Arg rexxpub

  If \rexxpub~hasIndex("anim") Then Return ""
  anim = rexxpub["anim"]
  If \anim~isA(.StringTable)   Then Return ""
  If \anim~hasIndex("element") Then Return ""
  el = anim["element"]
  If \el~isA(.StringTable)     Then Return ""
  If \el~hasIndex("effect")    Then Return ""
  effect = Squeeze(el["effect"])
  If effect == "" Then Return ""

  Call CheckAnim effect, ElementAnims(), "element", "front-matter anim: element:"
  Return effect

--------------------------------------------------------------------------------
-- DeckDefaultPageAnim / ApplyDefaultPageAnim - the same for the PAGE: the    --
-- front matter's `anim: page: effect:` is the transition of every slide that --
-- names none with anim= (the manual always said so; the build never read it  --
-- -- found 26-Sep while writing the reference). A slide's own anim= wins.    --
--------------------------------------------------------------------------------
::Routine DeckDefaultPageAnim
  Use Strict Arg rexxpub

  If \rexxpub~hasIndex("anim") Then Return ""
  anim = rexxpub["anim"]
  If \anim~isA(.StringTable)   Then Return ""
  If \anim~hasIndex("page")    Then Return ""
  pg = anim["page"]
  If \pg~isA(.StringTable)     Then Return ""
  If \pg~hasIndex("effect")    Then Return ""
  effect = Squeeze(pg["effect"])
  If effect == "" Then Return ""

  Call CheckAnim effect, PageAnims(), "page", "front-matter anim: page:"
  Return effect

::Routine ApplyDefaultPageAnim Public
  Use Strict Arg stage, effect

  If effect == "" Then Return stage
  out  = .MutableBuffer~new
  rest = stage
  Loop While rest~pos("<section") > 0
    Parse Var rest pre "<section" tag ">" rest
    out~append(pre, "<section")
    classes = " "SugarValue(tag, "class")" "
    If classes~pos(" slide ") > 0, tag~pos("data-anim=") == 0 Then
      tag = tag' data-anim="'effect'"'
    out~append(tag, ">")
  End
  Return out~string || rest

--------------------------------------------------------------------------------
-- ApplyDefaultAnim - give every fragment that has no data-anim of its own the--
-- deck's default effect, so a bare `.fragment` (including every incremental  --
-- item) animates with the deck's chosen effect instead of the catalogue's    --
-- plain fade. Fragments that already name an effect are left untouched.      --
-- No-op when the deck sets no default. Runs after the fragment classes exist.--
--------------------------------------------------------------------------------
::Routine ApplyDefaultAnim
  Use Strict Arg body, effect

  If effect == "" Then Return body

  -- Every tag whose class list holds the WORD "fragment", wherever it stands
  -- in the list. The needle used to be `class="fragment` -- the class had to
  -- come first -- and level= puts its own class in front (`class="level-2
  -- fragment"`), so Rony's `{.fragment level=2}` bullets got no effect at all
  -- and popped in unanimated. A class that merely CONTAINS the letters
  -- (`fragmentary`) is not a fragment: the test is on whole words. A tag that
  -- already names its own data-anim is left as it is.
  out    = .MutableBuffer~new
  rest   = body
  needle = 'class="'
  Loop While rest~pos(needle) > 0
    Parse Var rest pre (needle) classes '"' after
    out~append(pre, needle, classes, '"')
    rest = after
    If WordPos("fragment", classes) == 0 Then Iterate
    -- The rest of this tag: up to its '>'. The class value holds no '>'.
    tagEnd = after~pos(">")
    If tagEnd == 0 Then Iterate
    If after~left(tagEnd)~pos("data-anim=") > 0 Then Iterate
    -- ...nor any attribute BEFORE class= in the same tag: look back to its '<'.
    lt = pre~lastPos("<")
    If lt > 0, pre~substr(lt)~pos("data-anim=") > 0 Then Iterate
    -- ...nor the empty trigger of a spot beat: its anim= is how the MARKS
    -- come in (fade, pen, cut; v224), and an element effect means nothing
    -- there. Its tag is <p ...> or <span ...>, with nothing inside.
    If WordPos("arrow", classes) == 0 Then Do
      tag = pre~substr(max(lt, 1)) || needle || classes || '"' || after~left(tagEnd)
      Parse Var tag "<" tname " " .
      If tag~pos('data-spot="') > 0, WordPos(Lower(tname), "p span") > 0 Then Do
        inside = after~substr(tagEnd + 1)
        If Strip(inside~left(Max(inside~pos("<") - 1, 0))~translate(" ", "0a0d09"x)) == "", -
           inside~pos("</") == inside~pos("<"), inside~pos("<") > 0 Then Iterate
      End
    End
    out~append(' data-anim="', effect, '"')
  End

  Return out~string || rest

--------------------------------------------------------------------------------
-- MarginSizeCSS - the text size of the header and footer bands, from the     --
-- front matter, as CSS that beats the master's:                              --
--                                                                            --
--     footer:                                                                --
--       font-size: 14px                                                      --
--       center: '{page} / {pages}<br>...'                                    --
--                                                                            --
-- The size is for the whole band, all three boxes. A box that still does not --
-- fit is shrunk further by the runtime (fitMargins); this sets where it      --
-- starts. A value that is not a CSS length is reported and ignored.          --
--------------------------------------------------------------------------------

::Routine MarginSizeCSS Public
  Use Strict Arg rexxpub

  css = ""
  If \rexxpub~isA(.StringTable) Then Return css
  Loop edge Over "header footer"~makeArray(" ")
    If \rexxpub~hasIndex(edge) Then Iterate
    blk = rexxpub[edge]
    If \blk~isA(.StringTable) Then Iterate
    v = .Nil
    Loop k Over blk~allIndexes
      If Lower(k) == "font-size" Then v = blk[k]
    End
    If v == .Nil Then Iterate
    If \v~isA(.String) Then Iterate
    v = Strip(v)
    If \IsCssLength(v) Then Do
      Call Warn "rexxpub: "edge": font-size: '"v"' is not a CSS length" -
        "(say 14px, 0.8em or 90%); it is ignored."
      Iterate
    End
    -- The boxes too: masters size them one by one (.m-left { font-size }),
    -- and a size on the band alone would lose to those.
    css ||= "#stage .slide .margin."edge", #stage .slide .margin."edge" > * {" -
            "font-size:" v"; }" || "0a"x
  End
  Return css

--------------------------------------------------------------------------------
-- DeckFontsCSS - a :root override setting --skin-font-prose / --skin-font-mono
-- to the deck's dominant faces (front-matter font-prose / font-mono), or "" per
-- key when absent. Emitted at the end of identityCSS so it beats the skin's own
-- --skin-font-prose/mono. The base font rides here, once per deck, instead of
-- the emitter stamping font-family on every run: prose text inherits
-- --skin-font-prose, the code registers (<pre>/<code>/.output) use
-- --skin-font-mono. Each family is quoted and given a generic fallback
-- (sans-serif / monospace) so a deck that resolves no face still renders sane,
-- and a face the machine lacks degrades to the right generic. The names are the
-- family names written in the front matter (e.g. IBM Plex Sans, Courier New).
--------------------------------------------------------------------------------

::Routine DeckFontsCSS
  Use Strict Arg rexxpub

  decls = ""
  If rexxpub~hasIndex("font-prose") Then Do
    fp = rexxpub["font-prose"]
    If fp \== "" Then decls = decls "--skin-font-prose: '"fp"', sans-serif;"
  End
  If rexxpub~hasIndex("font-mono") Then Do
    fm = rexxpub["font-mono"]
    If fm \== "" Then decls = decls "--skin-font-mono: '"fm"', monospace;"
  End
  If decls == "" Then Return ""
  Return "0a"x || ":root {" decls "}" || "0a"x

--------------------------------------------------------------------------------
-- Identity resolution: a sheet is a FILE.                                    --
--                                                                            --
-- Both -s and -mp name a path, and that is the whole of it:                  --
--                                                                            --
--   relative   skin-wu.css, ../skins/skin-wu.css                             --
--                          -> beside the deck, then the current directory    --
--   absolute   /p/skin-wu.css                                                --
--                          -> exactly there, nothing implied                 --
--                                                                            --
-- There is no brand vocabulary: no -s wu resolving to some assets/wu/, no    --
-- pool of masters to search, no per-brand default master. That scheme is     --
-- gone because the thing it indexed is gone -- md2slides ships no skins and  --
-- no masters, only its own machinery (the deck template, the five runtime    --
-- sheets, the runtime script). A bare name would have nothing to point at.   --
--                                                                            --
-- Skins and masters are the author's material and live wherever the author   --
-- keeps them, addressed by path -- which is also what lets a sheet's own     --
-- img/ folder be found beside it (see ReadSheet).                            --
--                                                                            --
-- Returns the resolved path, or "" when nothing was found; the caller turns  --
-- "" into the right complaint.                                               --
--------------------------------------------------------------------------------

::Routine ResolveSheet Public
  Use Strict Arg name, deckDir

  -- Absolute path: exactly there, nothing implied.
  If IsAbsolute(name) Then Do
    If SysIsFile(name) Then Return name
    Return ""
  End

  -- Relative: beside the deck first. A deck and the sheets it was written
  -- against usually travel together, and that reading makes `md2slides
  -- ../talks/x/deck.md` work from anywhere.
  self = deckDir || name
  If SysIsFile(self) Then Return self

  -- Then the current directory, which is what an author means by a bare name
  -- typed at the prompt.
  If SysIsFile(name) Then Return name

  Return ""

--------------------------------------------------------------------------------
-- ResolveImgDir - a folder named on --img / img:, found the way a sheet's    --
-- path is found: beside the deck first, then the current directory; an       --
-- absolute path exactly where it says. One rule for every path the author    --
-- writes, so there is nothing extra to learn for this one.                   --
--                                                                            --
-- Returns the resolved directory (with a trailing /), or "" when there is no --
-- such directory; the caller turns "" into the complaint.                    --
--------------------------------------------------------------------------------

::Routine ResolveImgDir Public
  Use Strict Arg name, deckDir

  If IsAbsolute(name) Then Do
    If SysIsFileDirectory(name) Then Return WithSlash(name)
    Return ""
  End

  self = deckDir || name
  If SysIsFileDirectory(self) Then Return WithSlash(self)

  If SysIsFileDirectory(name) Then Return WithSlash(name)

  Return ""

::Routine WithSlash Public
  Use Strict Arg dir
  If dir~right(1) == "/" Then Return dir
  Return dir"/"

--------------------------------------------------------------------------------
-- WhereLooked - the other half of a "not found": say where we looked. A      --
-- resolution error that names only what was missing sends the reader to the  --
-- documentation; one that lists the paths tried is usually self-solving.     --
--------------------------------------------------------------------------------

::Routine WhereLooked Public
  Use Strict Arg name, deckDir

  If IsAbsolute(name) Then Return "Looked at:" name
  Return "Looked beside the deck ("deckDir || name") and in the current" -
         "directory ("name")."

--------------------------------------------------------------------------------
-- The default sheet names, used when no -s / -mp is given. They are names,   --
-- resolved exactly like any other: md2slides does not ship them, it just     --
-- knows what to look for. A missing default master is not an error (a deck   --
-- may be all skin); a missing skin is.                                       --
--------------------------------------------------------------------------------

::Routine DefaultSkinName Public
  Return "skin-default.css"

::Routine DefaultMasterName Public
  Return "master-default.css"

::Routine IsAbsolute
  Use Strict Arg name
  If name~pos("/") = 1 Then Return 1          -- POSIX absolute
  If name~length >= 2, name~substr(2, 1) == ":" Then Return 1   -- Windows C:
  Return 0

--------------------------------------------------------------------------------
-- Small file helpers                                                         --
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
  Use Strict Arg html, deckDir, extraDirs = (.Array~new)

  -- Inline every <img src="img/<file>"> as a base64 data URI, so the deck
  -- carries its content pictures inside the single .html. A deck links its
  -- pictures as img/<file> from a sibling <deckDir>/img/ folder, and Pandoc
  -- passes those through as relative <img src>. We rewrite only those:
  -- a src that does not start with "img/" (an already-embedded data: URI, an
  -- absolute path, an http(s) URL) is left untouched.
  If deckDir == "" Then deckDir = "./"
  If deckDir~right(1) \== "/" Then deckDir = deckDir"/"

  -- The pool folders, normalised once. A folder named on --img IS a folder of
  -- pictures: `img/logo.svg` looks for `logo.svg` inside it, not for an img/
  -- subfolder within it. `img/` stays what it always was -- the mark that says
  -- "embed me" -- and the folder says where else the file may be.
  extras = .Array~new
  Loop extra Over extraDirs
    If extra == "" Then Iterate
    If extra~right(1) \== "/" Then extra = extra"/"
    extras~append(extra)
  End

  -- './img/foo.png' is perfectly valid Markdown and plenty of authors write it
  -- out of habit. It names exactly the same file as 'img/foo.png', but it slips
  -- past the test below -- and the deck then renders on the author's machine
  -- (where img/ is right there) and arrives broken everywhere else. A silent
  -- failure, and it gets more dangerous the moment img/ stops being a
  -- convention and becomes a contract: writing './img/' is no longer a typo,
  -- it is opting out of the rule without being told. So the leading './' is
  -- normalised away BEFORE anything is compared. (Whatever is left relative
  -- after this whole pass is reported by WarnLooseImages.)
  html = html~changeStr('src="./img/', 'src="img/')

  MARK = 'src="img/'
  out  = ""
  rest = html
  seen   = .Directory~new                   -- file -> its picture number
  copied = .Directory~new                   -- numbers used more than once
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

    -- Where this one picture may be, in order. The deck's own img/ comes
    -- first, so a picture kept beside the deck shadows one of the same name in
    -- a shared folder -- the only reading that lets a deck override a shared
    -- picture for one talk.
    tried = .Array~of(deckDir || relPath)
    Loop extra Over extras
      tried~append(extra || relPath~substr(5))   -- after the "img/" mark
    End

    -- A picture the deck has already embedded is not embedded again: a logo
    -- on ten slides used to put ten copies of its bytes into the .html (and
    -- say ten times that it was heavy). A repeat gets a 43-byte placeholder
    -- and names the first; the runtime copies the src across on load (see
    -- "Pictures used more than once" in runtime.js). The first occurrence is
    -- only marked if a repeat turns up -- see the end of this routine -- so a
    -- deck with no repeats comes out byte for byte as it did.
    dataUri = ""
    Loop candidate Over tried
      If \SysIsFile(candidate) Then Iterate
      If seen~hasIndex(candidate) Then Do
        n = seen[candidate]
        copied[n] = 1
        dataUri = PlaceholderPic()'" data-pic-copy="'n
        Leave
      End
      dataUri = DataUriFor(candidate, "the deck")
      If dataUri \== "" Then Do
        n = seen~items + 1
        seen[candidate] = n
        dataUri = dataUri'"' || PicMark(n)
        Leave
      End
    End

    If dataUri == "" Then Do
      -- Named with the right spelling, so the author meant it to be embedded.
      -- Keeping the reference is the least destructive thing to do, but it is
      -- NOT a success: say it here, and let WarnLooseImages skip img/ paths so
      -- the same picture is not reported twice.
      --
      -- With a pool, the warning names every place that was looked in. A
      -- message that named only the deck's own folder would send the author
      -- to check the one folder they had already ruled out by writing --img.
      If tried~items == 1 Then
        Call Warn "the deck names '"relPath"', but" NormalizeImgRef(deckDir || relPath) -
                  "cannot be read. The reference is left as it is and the built" -
                  "deck will not find it."
      Else
        Call Warn "the deck names '"relPath"', but it is in none of" -
                  PoolList(tried)". The reference is left as it is and" -
                  "the built deck will not find it."
      out = out || relPath || '"'
    End
    Else If dataUri~right(1) == "01"x Then out = out || dataUri  -- closed already
    Else out = out || dataUri || '"'
  End

  -- The first occurrence of every picture carries a mark. The ones that were
  -- used again become data-pic="n", which is what their copies name; the rest
  -- vanish.
  Loop n = 1 To seen~items
    If copied~hasIndex(n) Then out = out~changeStr(PicMark(n), ' data-pic="'n'"')
    Else                       out = out~changeStr(PicMark(n), "")
  End

  Return out

-- PicMark - the provisional mark after the first occurrence of picture n,
-- resolved at the end of EmbedImages. 01x never occurs in Pandoc's HTML.
::Routine PicMark Public
  Use Strict Arg n
  Return "01"x"pic"n"01"x

-- PlaceholderPic - a transparent 1x1 GIF: what a repeated picture carries
-- until the runtime gives it the src of its first occurrence.
::Routine PlaceholderPic Public
  Return "data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"

/******************************************************************************/
/* ReadSheet - a skin or master sheet, with its OWN img/ folder embedded.      */
/*                                                                            */
/* This is the whole of "img/ is relative to the file that names it" on the    */
/* CSS side: the directory a sheet resolved to IS the directory its img/ hangs */
/* off. master-rony.css writes url(img/cc-by-sa.svg) and the picture comes     */
/* from beside master-rony.css, wherever that turned out to be.                */
/*                                                                            */
/* This is why the five master-images-<skin>.css files stop existing. Their    */
/* own header said they were split off "so the geometry in master.css stays    */
/* readable" -- i.e. because hand-pasted base64 blobs made the other file      */
/* unreadable. Take the blobs out of the source and the reason evaporates,     */
/* and with it the -mp master-images-X.css -mp master-X.css pair whose order   */
/* the author had to get right.                                               */
/*                                                                            */
/* The rule is deliberately NOT extended to the styles in css/ and            */
/* css/flattened/: a style is a palette of token colours and nothing else.     */
/* That is contract, not a postponement -- it is what stops                    */
/* css/flattened/img/ from having to exist as a duplicate of css/img/, where   */
/* a picture added to one form and not the other would be lost in silence.     */
/******************************************************************************/

::Routine ReadSheet Public
  Use Strict Arg path, axis

  dir = FileSpec("Location", path)
  If dir == "" Then dir = "./"

  Return EmbedCSSImages(ReadFile(path), dir, axis "'"FileSpec("Name", path)"'")

/******************************************************************************/
/* EmbedCSSImages - inline every url(img/...) in a sheet, against sheetDir.    */
/*                                                                            */
/* Only img/ is touched. url(data:...) (already embedded), url(/abs/path),     */
/* url(https://...), url(../anything) and a font's url() all pass through      */
/* untouched -- that is the "anything else means leave me alone" half of the   */
/* contract, and it is what covers an author who WANTS an external reference.  */
/*                                                                            */
/* 'label' names the sheet for the warnings, so a missing picture says which   */
/* file asked for it.                                                         */
/******************************************************************************/

::Routine EmbedCSSImages Public
  Use Strict Arg css, sheetDir, label = "a sheet"

  If sheetDir == "" Then sheetDir = "./"
  If sheetDir~right(1) \== "/" Then sheetDir = sheetDir"/"

  out  = ""
  rest = css
  Loop Forever
    u = rest~caselessPos("url(")
    c = rest~pos("/*")

    If u == 0, c == 0 Then Do
      out = out || rest                        -- nothing left to rewrite
      Leave
    End

    -- A comment can hold a url(img/...) as documentation -- the old
    -- master-images.css header did exactly that. Embedding a picture into a
    -- comment would both bloat the sheet and warn about a file nobody asked
    -- for, so comments are copied through whole.
    If c \== 0, (u == 0 | c < u) Then Do
      e = rest~pos("*/", c + 2)
      If e == 0 Then Do                        -- unterminated: all comment
        out = out || rest
        Leave
      End
      out  = out || rest~substr(1, e + 1)
      rest = rest~substr(e + 2)
      Iterate
    End

    out  = out || rest~substr(1, u + 3)        -- everything through 'url('
    rest = rest~substr(u + 4)

    -- Whitespace inside the parens is legal CSS; keep it verbatim.
    Loop While rest \== "", rest~left(1) == " " | rest~left(1) == "09"x
      out  = out || rest~left(1)
      rest = rest~substr(2)
    End

    quote = ""
    If rest~left(1) == '"' | rest~left(1) == "'" Then Do
      quote = rest~left(1)
      rest  = rest~substr(2)
    End

    If quote == "" Then q = rest~pos(")")
                   Else q = rest~pos(quote)
    If q == 0 Then Do                          -- malformed: emit verbatim
      out = out || quote || rest
      Leave
    End

    value = rest~substr(1, q - 1)
    rest  = rest~substr(q)                     -- the closer goes with the tail

    ref = NormalizeImgRef(value~strip)
    If ref~left(4) == "img/" Then Do
      dataUri = DataUriFor(sheetDir || ref, label)
      If dataUri \== "" Then value = dataUri
      Else Call Warn label "names '"value~strip"', but" NormalizeImgRef(sheetDir || ref) -
                     "cannot be read. The reference is left as it is and the" -
                     "built deck will not find it."
    End
    Else If \IsSelfContainedRef(ref) Then
      -- Left alone, as the contract says -- and still broken, for exactly the
      -- reason a loose <img src> is: the sheet is inlined into the .html, so a
      -- relative url() resolves beside the .html, where nothing was shipped.
      -- Not rewriting it is the contract; not mentioning it would be a trap.
      Call Warn label "names '"value~strip"', which is a relative reference" -
                "and was NOT embedded -- only img/ paths are. This sheet is" -
                "inlined into a deck that travels as a single file, so that" -
                "url() will resolve to nothing."

    out = out || quote || value
  End

  Return out

/******************************************************************************/
/* NormalizeImgRef - 'img/x' and './img/x' are the same picture. See the note  */
/* in EmbedImages: the leading './' is the silent trap, so it dies here, in    */
/* one place, before any comparison is made.                                   */
/******************************************************************************/

--------------------------------------------------------------------------------
-- PoolList - the places a picture was looked for, as one readable run:       --
-- "a/img/x.png, b/img/x.png and c/img/x.png". Written out in full rather     --
-- than as folder names, because what the author needs to compare against     --
-- what is on disk is the path that was actually tried.                       --
--------------------------------------------------------------------------------

::Routine PoolList
  Use Strict Arg tried

  list = ""
  Loop i = 1 To tried~items
    path = NormalizeImgRef(tried[i])
    If i == 1                Then list = path
    Else If i == tried~items Then list = list "and" path
    Else                          list = list", "path
  End

  Return list

::Routine NormalizeImgRef Public
  Use Strict Arg ref
  If ref~left(2) == "./" Then Return ref~substr(3)
  Return ref

/******************************************************************************/
/* WarnLooseImages - report every <img> that is STILL a relative reference.    */
/*                                                                            */
/* After embedding, a relative src is a picture the browser will look for      */
/* beside the .html. The deck travels as one file, so it will not be there.    */
/* 'images/dot.png', '../shared/x.png', 'pics/y.jpg' are all valid Markdown    */
/* and all silently broken -- which is precisely the failure the contract is   */
/* meant to prevent, so it has to be said out loud at build time.              */
/*                                                                            */
/* img/ paths are skipped: one of those only survives when the file could not  */
/* be read, and EmbedImages already said so with a better message.             */
/******************************************************************************/

::Routine WarnLooseImages Public
  Use Strict Arg html

  loose = 0
  rest  = html
  Loop Forever
    p = rest~caselessPos("<img")
    If p == 0 Then Leave
    rest = rest~substr(p + 4)

    gt = rest~pos(">")
    If gt == 0 Then Leave
    tag  = rest~substr(1, gt - 1)
    rest = rest~substr(gt + 1)

    s = tag~caselessPos('src="')
    If s == 0 Then Iterate
    after = tag~substr(s + 5)
    q     = after~pos('"')
    If q == 0 Then Iterate
    src = after~substr(1, q - 1)

    If IsSelfContainedRef(src) Then Iterate
    If NormalizeImgRef(src)~left(4) == "img/" Then Iterate

    loose = loose + 1
    Call Warn "<img src="""src"""> is a relative reference and was NOT" -
              "embedded -- only img/ paths are. The deck travels as a single" -
              "file, so that picture will be missing anywhere but here."
  End

  Return loose

/******************************************************************************/
/* IsSelfContainedRef - true when a src needs nothing beside the .html: an     */
/* embedded data: URI, an absolute path, or a URL (scheme or //host).          */
/******************************************************************************/

::Routine IsSelfContainedRef Public
  Use Strict Arg src

  If src == "" Then Return 1                   -- nothing to say about it
  If src~left(1) == "#" Then Return 1          -- url(#gradient): same document
  If src~left(5)~upper == "DATA:" Then Return 1
  If src~left(2) == "//" Then Return 1
  If IsAbsolute(src) Then Return 1

  colon = src~pos(":")
  If colon > 1, src~substr(colon, 3) == "://" Then Return 1

  Return 0

/******************************************************************************/
/* The size brake.                                                            */
/*                                                                            */
/* Embedding used to hurt: you base64'd a file by hand and pasted the blob.    */
/* That pain was a size guard nobody had designed -- the MU template still     */
/* reached 25MB of bitmaps and Rony asked for the resolution to come down.     */
/* With an img/ directory, putting that into a master is dragging a file, so   */
/* the guard has to become an explicit warning or it is simply gone.           */
/*                                                                            */
/* Base64 costs about a third on top of the bytes on disk, so the warnings     */
/* quote both numbers -- what the file weighs and what the deck grows by.      */
/******************************************************************************/

::Routine ImageWarnBytes Public
  Return 1024 * 1024                           -- per picture

::Routine DeckWarnBytes Public
  Return 8 * 1024 * 1024                       -- all pictures in one deck

::Routine NoteImageSize Public
  Use Strict Arg size, path, label

  -- Once per picture: a sheet that names the same heavy picture in two rules
  -- carries it twice, and the budget below counts both, but saying so twice
  -- tells the author nothing new.
  warned = .local["MD2SLIDES.HEAVYWARNED"]
  If warned == .Nil Then Do
    warned = .Set~new
    .local["MD2SLIDES.HEAVYWARNED"] = warned
  End

  If size > ImageWarnBytes(), \warned~hasIndex(NormalizeImgRef(path)) Then Do
    warned~put(NormalizeImgRef(path))
    Call Warn label "embeds" NormalizeImgRef(path) "-" KBof(size)"KB on disk, about" -
              KBof(size * 4 % 3)"KB once base64'd into the deck." -
              "Consider resizing it."
  End

  total = .local["MD2SLIDES.IMAGEBYTES"]
  If total == .Nil Then total = 0
  .local["MD2SLIDES.IMAGEBYTES"] = total + size

  Return

::Routine CheckImageBudget Public

  total = .local["MD2SLIDES.IMAGEBYTES"]
  If total == .Nil Then Return 0
  If total <= DeckWarnBytes() Then Return total

  Call Warn "this deck embeds" KBof(total)"KB of pictures, about" -
            KBof(total * 4 % 3)"KB of the .html. A deck this heavy is slow" -
            "to open and awkward to mail; consider resizing the images."

  Return total

::Routine KBof Public
  Use Strict Arg bytes
  Return bytes % 1024

/******************************************************************************/
/* Pictures bigger than a slide can show.                                      */
/*                                                                            */
/* Rony, 26-sep: the Modul University PowerPoint master carries pictures of   */
/* a resolution no slide will ever show, "MB over MB"; "on slides it is safe  */
/* to reduce the resolution". The size brake above can only say so. This     */
/* does it: a PNG or JPEG whose longest side is over picture-size (default    */
/* 1920 pixels) is reduced to it with ImageMagick on its way into the deck.   */
/*                                                                            */
/*   - 1920 because the canvas is 1280 pixels wide, and full screen on a      */
/*     1080p screen or projector that is 1.5 times: 1920 pixels. Anything     */
/*     beyond that is never seen, and 1024 would already look soft there.     */
/*   - The originals are never touched. The reduced copy goes to a cache      */
/*     beside the deck (.md2slides-cache/), under a name that changes with    */
/*     the picture (path, size, date) and with picture-size, so only the      */
/*     first build pays for it and a changed picture is never served stale.   */
/*   - A JPEG is written again at quality 85; a PNG stays a PNG (it may be a  */
/*     screenshot, text and transparency and all). Metadata goes (-strip),    */
/*     after the camera's rotation has been applied (-auto-orient).           */
/*   - GIF (maybe animated) and SVG (no pixels) are left alone, and so is     */
/*     anything of 100KB or less. Nothing is ever enlarged, and a copy that   */
/*     comes out no smaller is not used.                                      */
/*   - ImageMagick is the only outside tool, and optional. Without it the     */
/*     build does not fail: it says, once, which pictures are too big and     */
/*     how to install it. The size is read from the file's own header, in     */
/*     Rexx, so that warning needs nothing installed.                         */
/*   - `magick` (ImageMagick 7) first. `convert` (ImageMagick 6, what many    */
/*     Linux distributions still ship) only outside Windows, where           */
/*     convert.exe is the system's FAT-to-NTFS converter.                     */
/******************************************************************************/

::Routine DefaultPictureSize Public
  Return 1920

-- Below this a picture is left alone whatever its size in pixels: a
-- screenshot of a big screen, or a flat diagram, compresses to little, and
-- reducing it would buy nothing worth a call to ImageMagick (or a warning).
::Routine PictureFloorBytes Public
  Return 100 * 1024

-- PictureSize - picture-size: or --picture-size, as a number of pixels; 0
-- means "leave every picture as it is". "" (not given) is the default.
::Routine PictureSize Public
  Use Strict Arg value
  value = Strip(value)
  If value == "" Then Return DefaultPictureSize()
  If WordPos(Lower(value), "no false off") > 0 Then Return 0
  If DataType(value, "W"), value >= 16 Then Return value + 0
  Call Warn "picture-size: '"value"' is not a number of pixels (16 or more)" -
    "or 'no'; the default," DefaultPictureSize()", is used."
  Return DefaultPictureSize()

-- PictureDims - "width height" of a PNG, JPEG or GIF, from its header; ""
-- for anything else, or anything that does not parse.
::Routine PictureDims Public
  Use Strict Arg bytes
  Numeric Digits 12
  If bytes~left(8) == "89504E470D0A1A0A"x Then Do
    If bytes~substr(13, 4) \== "IHDR" Then Return ""
    Return bytes~substr(17, 4)~c2d bytes~substr(21, 4)~c2d
  End
  If bytes~left(6) == "GIF87a" | bytes~left(6) == "GIF89a" Then
    Return bytes~substr(7, 2)~reverse~c2d bytes~substr(9, 2)~reverse~c2d
  If bytes~left(2) \== "FFD8"x Then Return ""
  -- JPEG: walk the segments to the first frame header (SOF0..SOF15, but not
  -- DHT C4, JPG C8 or DAC CC). FF xx, length (2), precision (1), height (2),
  -- width (2).
  p = 3
  n = bytes~length
  Loop While p + 8 <= n
    If bytes~substr(p, 1) \== "FF"x Then Return ""
    m = bytes~substr(p + 1, 1)~c2d
    If m == 255 Then Do; p = p + 1; Iterate; End          -- fill byte
    If m == 1 | (m >= 208 & m <= 216) Then Do; p = p + 2; Iterate; End
    If m >= 192, m <= 207, m \== 196, m \== 200, m \== 204 Then
      Return bytes~substr(p + 7, 2)~c2d bytes~substr(p + 5, 2)~c2d
    p = p + 2 + bytes~substr(p + 2, 2)~c2d
  End
  Return ""

-- PictureTool - the ImageMagick command to call, or "" if there is none.
-- Looked for once per build.
::Routine PictureTool Public
  If .local~hasIndex("MD2SLIDES.PICTURETOOL") Then
    Return .local["MD2SLIDES.PICTURETOOL"]
  Trace Off                             -- a missing command is a FAILURE,
                                        -- and Trace Normal would show it
  Parse Source os .
  candidates = "magick"
  If \Upper(os)~startsWith("WIN") Then candidates = "magick convert"
  tool = ""
  Loop c Over candidates~makeArray(" ")
    o. = 0
    Address COMMAND c "-version" With Output Stem o. Error Stem e.
    If rc == 0, o.0 > 0, o.1~pos("ImageMagick") > 0 Then Do
      tool = c
      Leave
    End
  End
  .local["MD2SLIDES.PICTURETOOL"] = tool
  Return tool

-- ShrinkPicture - the bytes to embed for the picture at `path`: its reduced
-- copy when it is bigger than picture-size and ImageMagick is there, else the
-- bytes as read. Off (0, or never set, as when a test loads the package)
-- means as read, always.
::Routine ShrinkPicture Public
  Use Strict Arg path, bytes

  max = .local["MD2SLIDES.PICTUREMAX"]
  If max == .Nil | max == 0 Then Return bytes
  ext = Lower(path~substr(path~lastPos(".") + 1))
  If WordPos(ext, "png jpg jpeg") == 0 Then Return bytes
  If bytes~length <= PictureFloorBytes() Then Return bytes
  dims = PictureDims(bytes)
  If dims == "" Then Return bytes
  Parse Var dims w h
  If Max(w, h) <= max Then Return bytes

  If PictureTool() == "" Then Do
    big = .local["MD2SLIDES.BIGPICTURES"]
    If big == .Nil Then big = .StringTable~new
    big[NormalizeImgRef(path)] = w"x"h KBof(bytes~length)
    .local["MD2SLIDES.BIGPICTURES"] = big
    Return bytes
  End

  cache = .local["MD2SLIDES.PICTURECACHE"]
  If cache == .Nil Then Return bytes
  file  = .File~new(path)
  name  = file~name
  key   = (file~absolutePath"|"bytes~length"|"file~lastModified"|"max)~hashCode~c2x
  small = cache || .File~separator || name~left(name~lastPos(".") - 1)"."key"."ext

  If \SysIsFile(small) Then Do
    If \SysIsFileDirectory(cache) Then Call SysMkDir cache
    q    = '"'
    opts = "-auto-orient -resize" q || max"x"max">" || q "-strip"
    If ext \== "png" Then opts = opts "-quality 85"
    e. = 0
    Trace Off
    Address COMMAND PictureTool() q || file~absolutePath || q opts q || small || q -
      With Output Stem o. Error Stem e.
    If rc \== 0 | \SysIsFile(small) Then Do
      why = ""
      If e.0 > 0 Then why = ":" Strip(e.1)
      Call Warn "could not reduce" NormalizeImgRef(path) "("w"x"h") with" -
        "ImageMagick"why". It goes into the deck as it is."
      If SysIsFile(small) Then Call SysFileDelete small
      Return bytes
    End
  End

  smaller = .File~readChars(small)
  If smaller == .Nil Then Return bytes
  If smaller~length == 0 | smaller~length >= bytes~length Then Return bytes

  done = .local["MD2SLIDES.SHRUNK"]
  If done == .Nil Then done = .StringTable~new
  done[NormalizeImgRef(path)] = bytes~length smaller~length
  .local["MD2SLIDES.SHRUNK"] = done
  Return smaller

-- ReportPictureSizes - at the end of the build: what was reduced (a line on
-- stdout, like the "wrote" one), and, without ImageMagick, ONE warning that
-- lists what should have been.
::Routine ReportPictureSizes Public
  max = .local["MD2SLIDES.PICTUREMAX"]

  done = .local["MD2SLIDES.SHRUNK"]
  If done \== .Nil Then Do
    before = 0
    after  = 0
    Loop pair Over done~allItems
      Parse Var pair b a
      before = before + b
      after  = after  + a
    End
    Say "md2slides: reduced" done~items "picture(s) to" max "pixels a side:" -
      KBof(before)"KB ->" KBof(after)"KB"
  End

  big = .local["MD2SLIDES.BIGPICTURES"]
  If big == .Nil Then Return 0
  list  = ""
  total = 0
  Loop ref Over big~allIndexes~sort
    Parse Value big[ref] With dims kb
    list  = list"," ref "("dims"," kb"KB)"
    total = total + kb
  End
  list = Strip(list~substr(2))
  Call Warn big~items "picture(s) are bigger than a slide shows ("max -
    "pixels a side), and make" total"KB of the deck:" list". md2slides" -
    "reduces them for you, with the best settings for slides and without" -
    "touching the originals, once ImageMagick is installed: Windows," -
    "'winget install ImageMagick.ImageMagick'; macOS, 'brew install" -
    "imagemagick'; Linux, your package manager; or https://imagemagick.org." -
    "To keep them as they are, and this warning quiet, set picture-size: no."
  Return big~items

/******************************************************************************/
/* Warn - a build-time complaint that is NOT fatal. Goes to stderr, like       */
/* Error, so a shell pipeline that captures stdout still sees it.              */
/******************************************************************************/

::Routine Warn Public
  Use Strict Arg text
  .Error~Say("md2slides: warning:" text)
  -- Kept, too, for the deck itself: the diagnose mode (d) lists them beside
  -- its own findings, so an author who builds from a script, a double click
  -- or an editor that hides the console still gets to read them.
  If \.local~hasIndex("MD2SLIDES.WARNINGS") Then .local~md2slides.warnings = .Array~new
  .local~md2slides.warnings~append(text)
  Return

--------------------------------------------------------------------------------
-- BuildWarningsJSON - the build's warnings as a JSON array of strings, safe  --
-- to sit inside a <script> element ('<' is written \u003c, so no '</script>' --
-- can end it early).                                                         --
--------------------------------------------------------------------------------

::Routine BuildWarningsJSON Public
  If \.local~hasIndex("MD2SLIDES.WARNINGS") Then Return "[]"
  out = .MutableBuffer~new("[")
  Loop w Over .local~md2slides.warnings
    If out~length > 1 Then out~append(",")
    out~append('"', JSONEscape(w), '"')
  End
  out~append("]")
  Return out~string

--------------------------------------------------------------------------------
-- AboutJSON - the facts behind the about page, as a JSON object (or null).  --
--                                                                            --
-- Rony: "all statistics about the presentation (...) creation date and time, --
-- versions of the operating system, ooRexx, Pandoc and md2slides used (...)  --
-- how this was built with links to the needed sources (...) an example       --
-- command how the slides got built", and "make this configurable (sometimes  --
-- not all infos should be communicated to the outside world)".               --
--                                                                            --
-- The facts come in groups, each on or off in the front matter:              --
--                                                                            --
--   about:                                                                   --
--     deck:    yes   file, size, dates, skin and masters used (names only)   --
--     system:  yes   operating system, ooRexx, Pandoc, Rexx Parser           --
--     command: yes   the md2slides command that built the deck               --
--     links:   yes   where to get the tools, and the md2slides manual        --
--     path:    no    folders: the full name of the file, the full paths in   --
--                    the command -- off, every name is shown without its      --
--                    folder                                                  --
--     print:   no    print the about page after the last slide               --
--                                                                            --
-- `about: no` turns the whole page off. What is off is NOT WRITTEN: a deck   --
-- sent out carries only what its author let out, whatever someone reads in   --
-- its source. The counts (slides, steps, listings...) are the runtime's to    --
-- make: they are in the deck for anyone to count anyway.                     --
--------------------------------------------------------------------------------

::Routine AboutJSON Public
  Use Strict Arg rexxpub, facts

  on = .StringTable~new
  on["deck"] = 1; on["system"] = 1; on["command"] = 1; on["links"] = 1
  on["timing"] = 1
  on["path"] = 0; on["print"]  = 0

  If rexxpub~isA(.StringTable), rexxpub~hasIndex("about") Then Do
    blk = rexxpub["about"]
    If blk~isA(.String) Then Do
      yes = AboutYesNo(blk, "about")
      If yes == 0 Then Return "null"
    End
    Else If blk~isA(.StringTable) Then Do
      Loop name Over blk~allIndexes
        key = Lower(name)
        If \on~hasIndex(key) Then Do
          Call Warn "about: has no '"name"'. It knows deck, system, command," -
            "links, timing, path and print."
          Iterate
        End
        v = blk[name]
        If \v~isA(.String) Then Iterate
        yes = AboutYesNo(v, "about: "name)
        If yes \== "" Then on[key] = yes
      End
    End
  End

  path = on["path"]
  j = .MutableBuffer~new("{")
  j~append('"print":', AboutBool(on["print"]))
  j~append(',"groups":{')
  sep = ""
  -- timing: the runtime reads the deck's own time= and .pause for it; the
  -- flag only says whether to show them.
  Loop g Over "deck system command links timing path"~makeArray(" ")
    j~append(sep, '"'g'":', AboutBool(on[g])); sep = ","
  End
  j~append("}")

  source = facts["source"]
  full   = .File~new(source)~absolutePath

  If on["deck"] Then Do
    size  = AboutQuery(source, "Size")
    stamp = AboutQuery(source, "TimeStamp")
    If path Then name = full; Else name = FileSpec("Name", full)
    sheets = AboutName(facts["skin"], path)
    masters = ""
    Loop m Over facts["masters"]
      masters = masters AboutName(m, path)
    End
    j~append(',"deck":{')
    j~append('"file":"',     JSONEscape(name), '"')
    j~append(',"size":"',    JSONEscape(size), '"')
    j~append(',"modified":"', JSONEscape(stamp), '"')
    j~append(',"built":"',   ResolveToday() Time("Normal"), '"')
    j~append(',"seconds":"', facts["seconds"], '"')
    j~append(',"skin":"',    JSONEscape(sheets), '"')
    j~append(',"masters":"', JSONEscape(masters~strip), '"')
    j~append('}')
  End

  If on["system"] Then Do
    Parse Version rexxv
    j~append(',"system":{')
    j~append('"os":"',      JSONEscape(AboutOS()), '"')
    j~append(',"oorexx":"', JSONEscape(rexxv), '"')
    j~append(',"pandoc":"', JSONEscape(facts["pandoc"]), '"')
    j~append(',"parser":"', JSONEscape(AboutParser(facts["root"])), '"')
    j~append('}')
  End

  If on["command"] Then Do
    cmd = "md2slides"
    Loop a Over facts["args"]
      If \path, (a~pos("/") > 0 | a~pos("\") > 0) Then a = AboutName(a, 0)
      If a~pos(" ") > 0 Then a = '"'a'"'
      cmd = cmd a
    End
    j~append(',"command":"', JSONEscape(cmd), '"')
  End

  If on["links"] Then Do
    j~append(',"links":[')
    j~append('["ooRexx","https://www.oorexx.org/"],')
    -- Rony: for readers who have never heard of ooRexx.
    j~append('["ooRexx on Wikipedia","https://en.wikipedia.org/wiki/Object_REXX"],')
    j~append('["ooRexx sources","https://sourceforge.net/projects/oorexx/"],')
    j~append('["Pandoc","https://pandoc.org/"],')
    j~append('["The Rexx Parser (md2slides is part of it)","https://rexx.epbcn.com/rexx-parser/"],')
    j~append('["The md2slides manual","https://rexx.epbcn.com/rexx-parser/doc/utilities/md2slides/"]')
    j~append(']')
  End

  j~append("}")
  Return j~string

-- One fact about a file (Size, TimeStamp), or "" if it cannot be had.
::Routine AboutQuery
  Use Strict Arg file, what
  Signal On Any Name AboutQueryFailed
  v = .Stream~new(file)~query(what)
  If v == .Nil Then Return ""
  Return v
AboutQueryFailed:
  Return ""

--------------------------------------------------------------------------------
-- LiveFields - margin-box fields that the runtime keeps up to date while the --
-- deck is shown (the presenter's timer). The build leaves them in place.     --
--------------------------------------------------------------------------------

::Routine LiveFields Public
  Return "clock elapsed remaining total section-remaining section-elapsed" -
    "section sections section-total"

--------------------------------------------------------------------------------
-- TimerJSON - the presenter's timer, as the runtime reads it (#deck-timer).  --
--                                                                            --
-- Rony: a live clock when presenting, that starts when the deck goes full    --
-- screen and is only reset on request; a total time and, optionally, times   --
-- per section that add up to it; warnings some minutes before the end, then  --
-- every few seconds in the last minute, and in red, with the overtime, once  --
-- the time is up.                                                            --
--                                                                            --
--   timer:                                                                   --
--     total:    45     minutes (decimals allowed: 7.5)                       --
--     warn:     5:1    minutes before the end: at 5 and at 1 (also "5 1",    --
--                      "5,1"); default 5:1, "no" for none                    --
--     popup-every: 10  in the last minute, the warning popup comes back     --
--                      every 10 seconds (over time: once a minute)           --
--     where:    footer the warnings show over the footer band (or: header)   --
--     switch-to-seconds: 3  the times on screen are whole minutes (45), and  --
--                      minutes and seconds (2:59) in the last 3 minutes and  --
--                      in the overtime; "all" always, "no" never             --
--     sound:    no     a short chime when a countdown reaches 0              --
--                                                                            --
-- (Rony, 25-Sep: interval: and seconds: were renamed popup-every: and        --
-- switch-to-seconds:; the old names still work, with a warning.)             --
--                                                                            --
-- A slide may carry a countdown: countdown=5 (minutes) or countdown=17:00    --
-- (a time of day), shown big over the slide when it is presented; and a     --
-- .pause slide a length for its pause: pause=10 or pause=15:30 (pause= alone --
-- makes the slide a pause slide). Words after the time are a message shown   --
-- with the countdown: pause="15 Coffee break" (Rony, 25-Sep).                --
--                                                                            --
-- A section's time goes on the slide that opens it: `--- {.slide time=10}`.  --
-- It runs to the next slide with a time=. They must add up to total: fewer   --
-- minutes are fine only if slides come before the first timed one (those    --
-- get what is left). No total: the sections' sum is the total.               --
--------------------------------------------------------------------------------

::Routine TimerJSON Public
  Use Strict Arg rexxpub, stage

  total = ""; warn = "5 1"; interval = 10; where = "footer"
  seconds = 3; sound = 0
  -- What a break panel, or a countdown, says when nobody typed a message
  -- (Rony, 26-Sep): `pause-message: Coffee break`. What is typed wins.
  pauseMsg = ""; countdownMsg = ""
  -- record: yes keeps each run's time per slide in the browser (key h).
  record = 0
  If rexxpub~isA(.StringTable), rexxpub~hasIndex("timer") Then Do
    blk = rexxpub["timer"]
    If \blk~isA(.StringTable) Then
      Call Warn "timer: must be a block (total:, warn:, where:...)."
    Else Loop name Over blk~allIndexes
      v = blk[name]
      If \v~isA(.String) Then Iterate
      v = Strip(v)
      Select Case Lower(name)
        When "total" Then
          If v~dataType("N"), v > 0 Then total = v
          Else Call Warn "timer: total: '"v"' is not a number of minutes."
        When "warn" Then Do
          If WordPos(Lower(v), "no none off false") > 0 Then warn = ""
          Else Do
            w = v~translate("  ", ":,")
            ok = 1
            Loop x Over w~space~makeArray(" ")
              If \x~dataType("N") Then ok = 0
              Else If x <= 0 Then ok = 0
            End
            If ok, w~space \== "" Then warn = w~space
            Else Call Warn "timer: warn: '"v"' is not a list of minutes" -
              "(like 5:1)."
          End
        End
        When "popup-every", "interval" Then Do
          If Lower(name) == "interval" Then
            Call Warn "timer: interval: is now called popup-every:."
          If v~dataType("W"), v >= 1 Then interval = v
          Else Call Warn "timer:" name": '"v"' is not a whole number of seconds."
        End
        When "where" Then
          If WordPos(Lower(v), "footer header") > 0 Then where = Lower(v)
          Else Call Warn "timer: where: '"v"' is neither footer nor header."
        When "switch-to-seconds", "seconds" Then Do
          If Lower(name) == "seconds" Then
            Call Warn "timer: seconds: is now called switch-to-seconds:."
          Select
            -- yes/on and no/off reach us as true and false: they are YAML
            -- booleans, and the front-matter reader gives those as words.
            When WordPos(Lower(v), "all always yes true") > 0 Then
              seconds = "all"
            When WordPos(Lower(v), "no none never off false 0") > 0 Then
              seconds = 0
            When v~dataType("N"), v > 0 Then seconds = v
            Otherwise Call Warn "timer:" name": '"v"' is not a number of" -
              "minutes (or all, or no)."
          End
        End
        When "sound" Then Do
          b = AboutYesNo(v, "timer: sound:")
          If b \== "" Then sound = b
        End
        When "record" Then Do
          b = AboutYesNo(v, "timer: record:")
          If b \== "" Then record = b
        End
        When "pause-message"     Then pauseMsg     = v
        When "countdown-message" Then countdownMsg = v
        Otherwise
          Call Warn "timer: has no '"name"'. It knows total, warn," -
            "popup-every, where, switch-to-seconds, sound, record," -
            "pause-message and countdown-message."
      End
    End
  End

  -- Sections: data-time on the slides, in order.
  sum = 0; n = 0; first = 0; slide = 0
  rest = stage
  Loop While rest~pos("<section") > 0
    Parse Var rest "<section" tag ">" rest
    slide += 1
    Loop a Over "countdown pause"~makeArray(" ")
      c = SugarValue(tag, a)
      -- pause="Questions": only a message, a break with no time to it. A
      -- value that starts like a number and is not one is still a mistake.
      If a == "pause", c \== "", Verify(c~left(1), "0123456789.:") > 0 Then
        Iterate
      If c \== "", \CountdownSpec(c) Then
        Call Warn "slide" slide":" a"="c "does not start with minutes (5)" -
          "or a time of day (17:00); ignored."
    End
    t = SugarValue(tag, "time")
    If t == "" Then Iterate
    If \t~dataType("N") Then ok = 0
    Else ok = (t > 0)
    If \ok Then Do
      Call Warn "slide" slide": time="t" is not a number of minutes; ignored."
      Iterate
    End
    n += 1
    If first == 0 Then first = slide
    sum += t
  End
  If n > 0 Then Do
    If total == "" Then total = sum
    Else If sum > total Then
      Call Warn "timer: the sections' time= add up to" sum "minutes, more" -
        "than the total of" total"."
    Else If sum < total, first == 1 Then
      Call Warn "timer: the sections' time= add up to" sum "minutes, less" -
        "than the total of" total", and no slide comes before the first" -
        "section to take the rest."
  End

  j = .MutableBuffer~new("{")
  If total == "" Then j~append('"total":null')
  Else j~append('"total":', Format(total * 60, , 0))
  j~append(',"warn":[')
  sep = ""
  Loop x Over warn~makeArray(" ")
    j~append(sep, Format(x * 60, , 0)); sep = ","
  End
  j~append('],"interval":', interval, ',"where":"', where, '"')
  If seconds == "all" Then j~append(',"seconds":null')
  Else j~append(',"seconds":', Format(seconds * 60, , 0))
  j~append(',"sound":', AboutBool(sound), ',"record":', AboutBool(record))
  j~append(',"pauseMessage":"', JSONEscape(pauseMsg), '"')
  j~append(',"countdownMessage":"', JSONEscape(countdownMsg), '"}')
  Return j~string

-- A countdown's value: minutes (5, 7.5), or a time of day (17:00, 9:05),
-- and then, optionally, a message: "15 Coffee break".
::Routine CountdownSpec Public
  Use Strict Arg v
  Parse Var v v .
  If v~dataType("N") Then Return v > 0
  Parse Var v h ":" m
  If \h~dataType("W") | \m~dataType("W") | m~length \== 2 Then Return 0
  Return h >= 0 & h <= 23 & m >= 0 & m <= 59 & h~length <= 2

::Routine AboutBool
  If Arg(1) Then Return "true"
  Return "false"

-- yes/no, true/false, on/off -> 1/0; anything else is reported, and "".
::Routine AboutYesNo
  Use Strict Arg value, where
  Select Case Lower(Strip(value))
    When "yes", "true", "on", "1"  Then Return 1
    When "no", "false", "off", "0" Then Return 0
    Otherwise
      Call Warn where": '"value"' is neither yes nor no; left at its default."
      Return ""
  End

-- A file's name, with its folder only when paths may be shown.
::Routine AboutName
  Use Strict Arg file, path
  If path Then Return file
  Return FileSpec("Name", ChangeStr("\", file, "/"))

-- The operating system, as the system itself names it.
::Routine AboutOS
  os = .RexxInfo~platform
  out. = ""; out.0 = 0
  Signal On Any Name AboutOSDone
  If os~upper~startsWith("WINDOWS") Then
    Address COMMAND "ver" With Output Stem out. Error Stem err.
  Else
    Address COMMAND "uname -srm" With Output Stem out. Error Stem err.
AboutOSDone:
  Loop i = 1 To out.0
    If out.i~strip \== "" Then Return out.i~strip
  End
  Return os

-- "The current release is beta 0.7, refresh 20260923." in the project readme.
::Routine AboutParser
  Use Strict Arg root
  file = root"/readme.md"
  Signal On Any Name AboutParserDone
  s = .Stream~new(file)
  Loop While s~lines > 0
    line = s~lineIn
    If line~pos("The current release is") > 0 Then Do
      Parse Var line "The current release is" release
      release = release~strip~strip("T", ".")
      s~close
      Return "Rexx Parser" release
    End
  End
  s~close
AboutParserDone:
  Return "Rexx Parser"

::Routine JSONEscape Public
  Use Strict Arg text
  out = .MutableBuffer~new
  Loop i = 1 To text~length
    c = text~substr(i, 1)
    Select
      When c == '"'  Then out~append('\"')
      When c == "\"  Then out~append("\\")
      When c == "<"  Then out~append("\u003c")
      When c~c2d < 32 Then out~append("\u00"c~c2x)
      Otherwise out~append(c)
    End
  End
  Return out~string

/******************************************************************************/
/* DataUriFor - a file's contents as a base64 data: URI, or "" if unreadable. */
/* MIME comes from the extension; unknown extensions fall back to             */
/* application/octet-stream, which browsers still render for common images.   */
/******************************************************************************/

::Routine DataUriFor Public
  Use Strict Arg path, label = "this deck"

  If \ SysIsFile(path) Then Return ""
  bytes = .File~readChars(path)             -- whole binary in one call
  If bytes == .Nil Then Return ""
  mime  = MimeForExt(path)

  bytes = ShrinkPicture(path, bytes)
  Call NoteImageSize bytes~length, path, label

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
