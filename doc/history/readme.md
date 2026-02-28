Version history
===============

--------------------------------------------------------------------------------

\[See also [the to-do list](/rexx-parser/doc/todo/)\].

<table class="table">
  <thead><tr><th>Date<th>Version<th>Comments</thead>
  <tbody>
<tr><td>20251215<td>0.4a<td>
<ul>
  <li> Jump release level to mark full Executor support (20251215).
  <li> Rename `xtrtest.rex` to `identtest.rex`, and extend it so that it
       can self-check the Rexx Parser, the Executor sources, and the
       ooRexx tests. This program contains a superset of the older
       utility `idents.rex`, which has been removed from this release
       (20251215).
  <li> Improve the parser so that it recognizes message instructions
       starting with an instruction keyword (20251218).
  <li> Enhance `identtest.res` so that it processes all the files
       in the net-oo-rexx distribution (20251218).
  <li> `highlight.rex`: disallow `-xtr`, `-exp` and `-u` for
       fenced code blocks (20251220).
  <li> Improve error reporting (20251221).
  <li> Allow ```` ```executor ```` in fenced code blocks, as an equivalent to
       ```` ```rexx ```` with an attribute of `{executor}` (20251222).
  <li> New [md2html](../utilities/md2html/) utility (20251224).
  <li> Send error messages to .error, not .output (<https://github.com/JosepMariaBlasco/rexx-parser/issues/27>) (20251226).
  <li> Unify searches for `default.md2html` and `md2html.custom.rex` (20251226).
  <li> Add `--path` option to `md2html` (<https://github.com/JosepMariaBlasco/rexx-parser/issues/27>) (20251226).
  <li> Use .SysCArgs when available (20251227).
  <li> Add a palette of predefined highlighter styles (thanks Rony and JLF!) (20251227).
  <li> [Executor] Allow `"="` and `"=="` at the end of expressions occurring
       in command instructions (20251228).
  <li> New `--default` option for `highlight.rex` and `md2html.rex` (20251228).
  <li> **Breaking change**: Options which have values in `highligh.rex`
       now use `-option value` instead of `-option=value` (20251228).
  <li> Add `--continue` option to `highlight.rex` and `md2html.rex` (20251231).
  <li> Update `markdown.css` to display horizontal scroll bars when necessary (20251231).
  <li> **Breaking change**: Change `[*STYLES*]` -> `%usedStyles%` when transforming
       Markdown to HTML (20260101).
  <li> Allow `<div class="img-scroll">` in generated HTML (thanks, JLF!) (20260102).
  <li> **Breaking change**: Standardize on `-h` and `--html` to display help
       for all utils (and no arguments too: now, to start `identtest`, you
       should now use `identtest start`) -- following a suggestion from JLF (20260101).
  <li> New `rxcomp` utility (20260118).
  <li> Add support for `paged.js` and `print=pdf` (20260215).
  <li> Add support for `style=styleName` in URLs (20260219).
  <li> New `md2pdf` utility (20260224).
  <li> Create flattened versions of CSS because `pagedjs-cli` bundles an
       old version of Chromium that doesn't understand nesting (20260226).
  <li> Add support for `--outline` and `--fix-outline` in `md2pdf` (20260226).
<tr><td>20251111<td>0.3a<td>
<ul>
  <li> Add a series of CSS files inspired by the highlighting
       styles used by [the vim editor](https://en.wikipedia.org/wiki/Vim_(text_editor)):
       please refer to the `css/vim` subdir for details.
       This is a contribution from Rony Flatscher: thank you!
  <li> Add support for [Experimental features](../experimental/). Implement an Experimental
       [class extension mechanism](../experimental/classextensions/) based on Gil's syntax suggestions (20251114).
  <li> Add support for the new GC BIF (20251116).
  <li> The identity compiler is practically finished (20251125).
  <li> Start to implement support for JLF's Executor (20251125).
  <li> (Executor) Support constructs like `2i` (20251126).
  <li> (Executor) Support instructions starting with `var ==` (20251127).
  <li> (Executor) Support instructions starting with `keyword(` (20251127).
  <li> (Executor) Support `::OPTIONS [NO]COMMAND` and `[NO]MACROSPACE` (20251127).
  <li> (Executor) Support `X =; -- Assigns ''` (20251127).
  <li> (Executor) Support `UPPER` instructions (20251128).
  <li> Add basic Unicode support to the scanner (20251128).
  <li> (Executor) Support `/==` and `/=` operators (20251128).
  <li> (Executor) Support `^` and `¬` as a negator (20251128).
  <li> (Executor) Allow `#@$` in identifiers (20251128).
  <li> (Executor) Add support for `::EXTENSION` directive (20251128).
  <li> `rxcheck -e` now works without quotes (20251129).
  <li> (Executor) Allow `¢` in identifiers (20251129).
  <li> (Executor) The message name can be omitted in message terms (20251129).
  <li> (Executor) Implement `USE [STRICT] [AUTO] NAMED` and `FORWARD NAMEDARGUMENTS` (20251130).
  <li> (Executor) Implement source literals (trailing blocks are still missing) (20251201).
  <li> Support Latin-1 encodings for `"¬"` and `"¢"` (20251202).
  <li> **Breaking change**. `IsIgnorable` and `SetIgnorable` are substituted by a boolean
       `ignored` attribute in the `Element` class.
  <li> (Executor) Implement trailing blocks (20251208).
  <li> (Executor) Instruction() is a function call, not an instruction (20251208).
  <li> (Executor) Correctly handle methods attached to an `::EXTENSION` (20251209).
  <li> (Executor) Allow source literals as default values in `USE ARG` (20251209).
  <li> Make error messages placement more accurate (20251209).
  <li> (Executor) Implement named arguments (20251210).
  <li> Add Executor support to elident.rex, move it to the `bin` subdirectory (20251211).
  <li> All `.cls` files in the Executor distribution pass the `elident` test (20251211).
  <li> All `.cls` files in the Executor distribution pass the `trident` test (20251213).
  <li> (Executor) Add a new `xtrtest` utility (20251213).
  <li> Document the `elident`, `trident` and `xtrtest` utilities (20251213).
  <li> Start documenting [Executor](../executor/) support (20251213).
  <li> Finish documenting [Executor](../executor/) support. Executor support
       should be complete at this point (20251214).
  <li> Add `"AA"X` and `"AC"X` as negators (see rexxref 1.10.4.6. Operator Characters) (20251214).
<tr><td>20250831<td>0.2e<td>
<ul>
  <li> Continue refactoring to refine the Tree API.
  <li> Add [early check support for LEAVE and ITERATE](../ref/classes/rexx.parser/early-check/).
  <li> Fix bug in stylesheet.cls (thanks, Rony!) (20250907).
  <li> An expression list as the rhs of an assignment is an array term (20250909).
  <li> Collect all local variables in the 'locals' attribute of code bodies (20250916).
  <li> "elements.rex" now automatically adds ".rex" to the filename when needed (20250928).
  <li> "rxcheck.rex" now automatically adds ".rex" to the filename when needed (20250929).
  <li> Bug fix: option EARLYCHECK SIGNAL not working (<https://github.com/JosepMariaBlasco/rexx-parser/issues/18>, 20251009).
  <li> Add support for `::OPTIONS NUMERIC [NO]INHERIT` (20251027).
  <li> Update .ALL.SYMBOLS_AND_KEYWORDS so that it has .ALL.DIRECTIVE_KEYWORDS
       as a subset, following a reflection by Rony (20251029).
  <li> **Breaking change** Rename "makeIgnorable" to "setIgnorable" to make
       the API more homogeneous (20251029).
  <li> Add the "isInserted" method to the Element class, following a suggestions
       by Rony (thanks!) (20251029).
  <li> Fix <https://github.com/JosepMariaBlasco/rexx-parser/issues/20> (20251031)
  <li> Miscelaneous improvements to the ANSI highlighter driver after
       some suggestions by Rony (thanks! - 20251111).
<tr><td>20250622<td>0.2d<td>
<ul>
  <li> **Breaking change**: The character used to separate foreground
       and background colors in style patches is now ":" (was "/").
  <li> Colors in CSS now accept alpha values,
       in the forms `#rgba` and `#rrggbbaa`.
  <li> `.rex` and `.cls` files are now automatically highlighted, but only when
       `"view=highlight"` is added to the URL as a query string.
  <li> Major rewrite of [the CSS parsing algorithms](../highlighter/css/) (20250629).
  <li> **Breaking change**: the `rx-doc-cm` class has been renamed
       to `rx-doc-comment`, and `rx-doc-lncm` to `rx-doc-comment-markdown` (20250706).
  <li> Add support for [detailed highlighting of doc-comments](../highlighter/features/doc-comments/) (20250706).
  <li> Add Set.Directive.SubKeyword, .EL.DIRECTIVE_SUBKEYWORD, .ALL.DIRECTIVE_KEYWORDS and rx-dskw (20220725).
  <li> Begin extensive refactoring to test and fix the Tree API (20250725).
  <li> Add support for array terms (20250803).
  <li> Add support for length positional patterns (20250808).
  <li> Add a "signature" attribute to the Code.Body class. This is an aid
       for compiler and transpiler writers. If a USE ARG instruction is the first
       instruction in the body (or the second, if this is a method body with
       an EXPOSE instruction), and additionally 1) the body makes no use of the
       ARG BIF, and 2) there are no other USE ARG, ARG, or PARSE ARG instructions
       in the body, then "signature" is that first USE ARG instruction. Otherwise,
       "signature" is .Nil (20250820).
  <li> Fix https://github.com/JosepMariaBlasco/rexx-parser/issues/14 (20250828).
<tr><td>20250427<td>0.2c<td>
<ul>
  <li> **Breaking change**: Continuation chars "-" and "," are
       now assigned a category of .EL.CONTINUATION. A new
       set .ALL.WHITESPACE_LIKE has been created that includes
       .EL.WHITESPACE and this new category.
  <li> Fix <https://github.com/JosepMariaBlasco/rexx-parser/issues/11>.
  <li> Update css/rgflight.css, add rgfdark.css (Rony) (20250528).
  <li> Add support for detailed string highlighing (20250529).
  <li> Add support for detailed number highlighing (20250531).
  <li> Add a new rexx-test1 CSS file (20250531).
  <li> Allow symbolic color names in CSS files (20250531).
  <li> Fix <https://github.com/JosepMariaBlasco/rexx-parser/issues/13> (20250531).
  <li> Relax doc-comment requirements: now they can be placed anywhere (20250531).
  <li> **Breaking change**: Remove the compound= highlighting option. Anyone wanting homogeneus
       highlighting can design his own style (20250531).
  <li> **Breaking change**: Make detailed string and number highlighting mandatory, for the same reason (20250531).
  <li> Document [string](/rexx-parser/doc/highlighter/features/strings/) and
       [number](/rexx-parser/doc/highlighter/features/numbers/) highlighting,
       and add a page showing some [examples](/rexx-parser/doc/highlighter/examples/) (20250531).
  <li> Added [Related ooRexx bugs](/rexx-parser/doc/oorexx-bugs/) page (20250602).
  <li> Add --from and --to options to elements.rex. Create a /bin/tools subdirectory,
       and add a new cielab.cls utility and Rony Flatscher's w3c_colors.cls (20250606).
  <li> Substitute cielab.cls for sRGB.cls, which is more accurate (20250621).
  <li> CGI: Add support for .rex and .cls files (20250621).
<tr><td>20250421<td>0.2b<td>
<ul>
  <li> (Almost) complete early-checking of BIFs.
  <li> Start to write a unit test program (will document later).
  <li> Major refactoring of BIF early checking.
  <li> Add -extraletters and -emptyassignments options to rxcheck utility.
  <li> Update internal InternalError routine so that it raises HALT instead
       of SYNTAX to avoid some loops and stack exhaustion.
  <li> Add GenErrorText.rex utility (in bin/resources). It generates
       ANSI.ErrorText.cls, which provides an enhanced ANSI ErrorText
       routine with support for secondary messges and substitutions.
       Update rxchech to use this routine, and add a toggle
       to display an internal trace (off by default) (20250426).
  <li> Update --prolog option in highlight utility so that it does not
       emit the HTML classes (20250502).
  <li> Fix typo in rxcheck.rex ([GitHub issue no. 10](https://github.com/JosepMariaBlasco/rexx-parser/issues/10) - Thanks Geoff!) (20250508).
  <li> Add a "publications" section to the main documentation page (20250510).
  <li> Document [CGI installation](../highlighter/cgi/)
       and [CSS Paged Media](../highlighter/paged-media/) usage
       thoroughly (20250511).
  <li> Move publications to a subdirectory under docs (20250512).
  <li> Fix error in Highlighter.cls (20250519, reported by Rony).
  <li> Ensure that the options arg to the Highlighter class has a 0 default value (20250520).
  <li> Allow specifying style patches as strings or arrays of strings when
       invoking the parse method of the Highlighter class (20250520).
  <li> Clarify the docs on how to use a style patch to modify only the background
       of a color combination (20250523, thanks to an observation by Rony).
  <li> Add experimental rgflight style (thanks, Rony!). Restrict style
       specifications to allow only ASCII letters, numbers, and a choice
       of ".", "-" and "_". Automatically detect styles used by the
       page and dynamically update the list of included CSS files (20250525).
  <li> Add --css option to the highlight utility, and "-" as a last
       option to select standard input, following suggestions by Rony (20250526).
<tr><td>20250416<td>0.2a<td>
<ul>
  <li> Add optional BIF argument checking.
  <li> Document the EARLYCHECK parser option.
  <li> Add the `check` utility.
  <li> Move BIF info to a new classfile, `BIFs.cls`, copy BIF arg checking information
       from the ANSI standard, create a new update section for ooRexx, and add
       optional TUTOR support.
  <li> Add many test cases for most BIFs.
  <li> Document the [early check](../ref/classes/rexx.parser/early-check/) options.
  <li> Create the [utilities](../utilities/) page.
  <li> Document the `RxCheck` utility, move `elements` and `highlight` to the
       utilities page.
  <li> Document the [early check](../ref/classes/rexx.parser/early-check/) for BIFs to
       also check one-letter options (20250417).
  <li> Early check now checks all literal whole numbers, including literal
       strings containing a number, and prefix expressions, to allow for
       negative literals. Numbers that are not required to be whole
       are also checked. Literal arguments to XRANGE are also checked (20250418).
  <li> Add "debug" toggle to rxcheck utility. Early check for
       D2C and D2X (20250419).
  <li> Add '-e' option to rxcheck (20250420).
<tr><td>20250215<td>0.2<td>
<ul>
  <li> First version published simultaneously in rexx.epbcn.com and GitHub.
  <li> Ensure that CGIs work under windows, when the Apache drive is
       different from the installation drive (20250222).
  <li> Call pandoc with Address COMMAND instead of Address PATH (20250222).
  <li> Enhance CGI support so that it allows a single query of the form
       style=dark (the default) or styke=light. This may come handy when
       using CSS for print: web versions may look better with style=dark,
       but printed versions should normally use style=light, as dark versions
       tend to look awful and consume too much ink (20250317).
  <li> Change module method syntax from "class:newmethod" to
      "class::newmethod", a la C++ (20250318).
  <li> Add WARNING.md file and modify root readme.md (20250325).
  <li> Raise an error when a module tries to redefine an already-defined
       method (thanks Jean Louis!) (20250327).
  <li> Refactor for inclusion in the net-oo-rexx bundle: rename
       main directory to rexx-parser, for consistency with GitHub;
       rename the main binary directory to "bin" instead of "cls";
       move the "modules" and "resources" directories inside "bin";
       and rename "utils" to "samples".
       (20250329).
  <li> Move "highlight.rex" and "elements.rex" to the "bin" directory so that
       they can be used directly after setenv (or from ooRexxShell, etc)
       (20250403).
  <li> Add references to the net-oo-rexx distribution and to ooRexxShell
       in the appropriate places. Fix some broken breakcrumbs (20250405).
  <li> Rename fractional numbers to decimal (20250406).
<tr><td>20250128<td>0.1g<td>
<ul>
  <li> **Breaking change**: .TK.xxx variables have been renamed to .EL.xxx.
  <li> **Nomenclature change**: "tokens" are renamed to "elements". A "token"
       is now a standard Rexx token. We still speak of "the tokenizer", though:
       it now returns *elements* instead of *tokens*. (20251206: the "tokenizer"
       has been substituted by the "scanner").
  <li> **Breaking change**: Class `Token` renamed to `Element`.
  <li> Add the `<<` method to the `Element` class.
  <li> Rename "utils/tokenizer.rex" to "utils/elements.rex".
<tr><td>20250102<td>0.1f<td>
<ul>
  <li> **Breaking change**: inline patches inside HTML Comments
       are no longer accepted in fenced code blocks. Use the
       new `patch="styles"` attribute instead.
  <li> Highlighting [HTML](/rexx-parser/doc/highlighter/html/),
       [ANSI terminals](/rexx-parser/doc/highlighter/ansi/),
       and [(Lua)LaTeX](/rexx-parser/doc/highlighter/latex/).
  <li> Document the [Highlighter](/rexx-parser/doc/ref/classes/highlighter/) class.
  <li> Create a new [Utilitites and samples](/rexx-parser/doc/samples) document.
  <li> Add `--prolog` and `--noprolog` options to [highligth.rex](/rexx-parser/doc/utilities/highlight/),
       and a corresponding boolean `prolog` option to the
       [Highlighter](/rexx-parser/doc/ref/classes/highlighter/) class.
  <li> Add optional support for TUTOR-flavored Unicode Y-, P-, G-, T- and U-strings.
  <li> Make style patches work with all the highlighter modes.
       Add `--patch` and `--patchfile` options to [highligth.rex](/rexx-parser/doc/utilities/highlight/),
       and `patch` and `patchfile` attributes to fenced code blocks.
       Change `-t` and `--term` to `-a` and `--ansi`; add `--pad`.
  <li> Add the set of 147 HTML standard colors (see <https://www.w3.org/TR/css-color-4/#named-colors>),
       and update the style patch class so that it understands these colors.
  <li> Move Rexx.Highlighter to cls and rename it to Highlighter.
  <li> Move Style.Patch to cls and rename it to StylePatch.
  <li> Move Highlighter.Drivers to cls/HLDrivers and rename it to Drivers.
  <li> Move Process.Rexx.Fenced.Code.Blocks to cls and rename to FencedCode.
  <li> Move category2HTMLClass to cls and rename it to HTMLClasses.
  <li> Rename "token class" to "token category", and "token subclass" to
       "token subcategory".
  <li> Added "taken constant" to the [glossary](/rexx-parser/doc/glossary/#taken-constant).
  <li> Document [the Driver class](/rexx-parser/doc/ref/classes/driver/).
  <li> Mutate `.EL.PERIOD` -> `.EL.PARSE_PERIOD` in parsing templates.
  <li> Mark assignment targets, USE ARG arguments, and PARSE target variables
       as "assigned".
  <li> Add `size` attribute to fenced code blocks.
<tr><td>20241229<td>0.1e<td>
<ul>
  <li> Initial version of the ANSI highlighter.
  <li> New multi-modal [highligther utility program](/rexx-parser/doc/utilities/highlight/).
  <li> Strengthen self-integrity tests again (check `highlighter/` subdir too).
  <li> Move highlighter software to the `highlighter/` directory (from `utils/`).
  <li> Implement a highlighting driver system (see the `highlighter/drivers` subdirectory).
  <li> We provide three drivers by default: one for HTML,
       one for ANSI SGR terminal codes, and one for LaTex.
</ul>
<tr><td>20241223<td>0.1d<td>
<ul>
  <li> Implement [doc-comments](/rexx-parser/doc/highlighter/features/doc-comments/),
    and extend [padding](/rexx-parser/doc/highlighter/FencedCode/#pad)
    to support doc-comments.
  <li> Start working on
    a [User Guide](/rexx-parser/doc/guide/)
    and a [Reference](/rexx-parser/doc/ref/).
  <li>Document the [Rexx.Parser](/rexx-parser/doc/ref/classes/rexx.parser)
    and [Token](/rexx-parser/doc/ref/classes/element) classes.
  <li> Strengthen self-integrity tests (check `utils/` subdir too).
  <li> Extensive documentation refactoring.
  <li> Start working on the Terminal and LaTeX highlighters
</ul>
<tr><td>20241217<td>0.1c<td>
<ul>
  <li> Migrate documentation to markdown and make it
    downloadable as part of the installation file.
  <li> Allow `~~~rexx` blocks inside foreign blocks
  <li> Move root to <https://rexx.epbcn.com/rexx-parser/>
  <li> Relativize `source=` and `patch=` to the current
    file when processing fenced code blocks
  <li> Add support for `.numberLines`, `numberWidth`, `startFrom`
    and `pad` fenced code block options.
  <li> Implement a `pad=n` option in fenced code blocks.
   `::RESOURCE` data will be padded to n columns.
  <li> Started [a glossary](/rexx-parser/doc/glossary/).
</ul>
<tr><td>20241209<td>0.1b<td>
<ul>
  <li> Add support for shebangs
  <li> New function and procedure call system
</ul>
<tr><td>20241208<td>0.1a<td>
<ul>
  <li> Add support for the extraletters option
  <li> c/TK.CLASSIC_COMMENT/TK.STANDARD_COMMENT/
  <li> Create the page for the Tree API
</ul>
<tr><td>20241206<td>0.1<td>
<ul>
  <li> Initial limited release
</ul>
  </tbody>
</table>
