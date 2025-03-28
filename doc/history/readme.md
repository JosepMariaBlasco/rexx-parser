Version history
===============

--------------------------------------------------------------------------------

\[See also [the to-do list](/rexx-parser/doc/todo/)\].

<table class="table">
  <thead><tr><th>Date<th>Version<th>Comments</thead>
  <tbody>
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
       method (thanks Jean-Louis!) (20250327).
  <li> Start refactoting for inclusion in the net-oo-rexx bundle. Rename
       main directory to rexx-parser, for consistency with GitHub
       (20250328).
<tr><td>20250128<td>0.1g<td>
<ul>
  <li> **Breaking change**: .TK.xxx variables have been renamed to .EL.xxx.
  <li> **Nomenclature change**: "tokens" are renamed to "elements". A "token"
       is now a standard Rexx token. We still speak of "the tokenizer", though:
       it now returns *elements* instead of *tokens*.
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
  <li> Create a new [Utilitites and samples](/rexx-parser/doc/utils) document.
  <li> Add `--prolog` and `--noprolog` options to [highligth.rex](/rexx-parser/doc/utils/highlight/),
       and a corresponding boolean `prolog` option to the
       [Highlighter](/rexx-parser/doc/ref/classes/highlighter/) class.
  <li> Add optional support for TUTOR-flavored Unicode Y-, P-, G-, T- and U-strings.
  <li> Make style patches work with all the highlighter modes.
       Add `--patch` and `--patchfile` options to [highligth.rex](/rexx-parser/doc/utils/highlight/),
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
  <li> New multi-modal [highligther utility program](/rexx-parser/doc/utils/highlight/).
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
