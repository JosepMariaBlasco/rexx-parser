# Rexx Parser / RexxPub — Project Map

This file describes the structure of the Rexx Parser project to help
AI assistants navigate it efficiently without blind exploration.

The project is written in **ooRexx 5.1+** by Josep Maria Blasco,
with contributions from other ooRexx developers.
See the project instructions for coding style and conventions.

## Top-level directories

```
bin/          Core code: parser, highlighter, pipelines, utilities
cgi/          Web CGI pipeline and support classes
css/          All stylesheets (Rexx themes, Bootstrap, print, Pandoc)
csl/          Citation Style Language files for Pandoc --citeproc
doc/          Documentation, guides, and Symposium papers
js/           Client-side JavaScript (section numbering, figures, TOC, chooser)
samples/      Sample Rexx files for testing
tests/        Test suite
```

## bin/ — Core code

### The Rexx Parser
```
Rexx.Parser.cls         The parser itself
Scanner.cls             Lexical scanner
PreClauser.cls          Pre-clauser (groups tokens into clauses)
Clauses.cls             Clause recognition
KeywordInstructions.cls Keyword instruction parsing
Directives.cls          Directive parsing
Expressions.cls         Expression parsing
Elements.cls            Element definitions
SecondPass.cls          Second-pass analysis
Globals.cls             Global definitions and environment
BaseClassesAndRoutines.cls  Base classes and shared routines (incl. File2Array)
BIFs.cls                Built-in function definitions
ANSI.ErrorText.cls      ANSI-standard error messages
UnicodeSupport.cls      Unicode/TUTOR support
```

### The Highlighter
```
Highlighter.cls         Main highlighter engine
HTMLClasses.cls         HTML output classes
HTMLColors.cls          Color definitions
StyleSheet.cls          CSS style sheet generation
StylePatch.cls          Style patching support
FencedCode.cls          Fenced code block processor (Markdown integration)
HLDrivers/              Output drivers (ANSI, HTML, LaTeX)
```

### RexxPub pipelines (the three main deliverables)

These three files share the same architecture: read Markdown, parse
YAML front matter, call FencedCode for Rexx highlighting, call Pandoc,
substitute template placeholders, generate output.

```
md2pdf.rex              Markdown → PDF (via Pandoc + pagedjs-cli)
md2html.rex             Markdown → static HTML
../cgi/CGI.markdown.rex Markdown → HTML via Apache CGI (live web,
                                   optionally print to PDF with paged.js)
```

All three require: `FencedCode.cls`, `YAMLFrontMatter.cls`,
`RexxPubOptions.cls`, `ErrorHandler.cls`.

**Shared modules** (created or updated during the March 2026 refactoring):
```
RexxPubOptions.cls      ParseRexxPubYAML(), BuildCaptionOverrides(),
                        DefaultSectionNumbers() — common option handling
ErrorHandler.cls        ErrorHandler() for standalone utilities,
                        IsAParseError() for pipeline error handling
YAMLFrontMatter.cls     Parses YAML front matter from Markdown source
```

The refactoring is complete: all YAML parsing and CSS override
generation is now centralized in `RexxPubOptions.cls`.

### Utilities
```
highlight.rex           Standalone Rexx syntax highlighter
rxcheck.rex             Rexx syntax checker
rxcomp.rex              Rexx compiler/analysis tool
elements.rex            Element listing utility
elident.rex             Element indentation utility
erexx.rex               Enhanced Rexx runner
identtest.rex           Identifier test utility
tree.rex                Parse tree display
trident.rex             Trident utility
rr2svg.rex              Railroad diagram to SVG converter
```

### Other
```
default.md2html         HTML template for md2html pipeline
md2html.custom.rex     Sample customization layer for md2html
fix_pdf_outline.py      Python helper for PDF outline fixing
EnableExperimentalFeatures.rex  Enables experimental parser features
DebugSettings.cls       Debug configuration
modules/                Parser extension modules (identity, print, experimental)
tools/                  Color tools (sRGB, W3C colors)
resources/              Embedded resources (fonts, images)
```

## cgi/ — Web CGI pipeline

```
CGI.markdown.rex                The CGI pipeline (Apache CGI handler)
Rexx.CGI.cls                    Base CGI class
HTTP.Request.cls                HTTP request handling
HTTP.Response.cls               HTTP response handling
Array.OutputStream.cls          Array-based output stream
rexx.epbcn.com.optional.cls     Site-specific optional routines
                                (breadcrumb, style chooser, print button)
inline-footnotes.lua            Pandoc Lua filter for footnotes
```

The CGI uses `Call Requires` with explicit paths (not `::Requires`)
because `::Requires` does not handle `../` paths well.

## css/ — Stylesheets

```
css/
  bootstrap.css, bootstrap.min.css    Bootstrap 3 framework
  bootstrap-theme.css, ...            Bootstrap theme
  markdown.css                        Base markdown styling
  rexx-dark.css, rexx-light.css, ...  Rexx highlighting themes
  rexx-vim-*.css                      Vim-inspired themes
  rexx-tokio-*.css                    Tokio themes
  rexx-electric.css                   Electric theme
  readme.txt                          CSS documentation
  flattened/                          Flattened CSS (Bootstrap + theme combined)
  pandoc/                             Pandoc syntax highlighting themes
    pygments.css, kate.css, tango.css, espresso.css,
    zenburn.css, monochrome.css, breezeDark.css, haddock.css
  print/                              Print/PDF document class styles
    rexxpub-base.css                  Base print styles (Bootstrap reset, etc.)
    article.css, book.css, letter.css, slides.css, default.css
    article-10pt.css, article-11pt.css, ...  Size-specific overrides
  vim/                                Vim color scheme source data
```

## js/ — Client-side JavaScript

```
numberFigures.js        Figure/listing numbering and caption handling
numbersections.js       Section heading numbering
createToc.js            Table of contents generation
numberFigures.js reads  data-* attributes from div.content for
                        caption position, label overrides, etc.
```

On the server (not in this repo): `chooser.js` (style chooser + print
button), `bootstrap.min.js`, `paged.polyfill.js`.

## doc/ — Documentation

```
doc/
  readme.md                       Documentation index
  utilities/                      Per-utility documentation
    md2pdf/readme.md              md2pdf documentation
    md2html/readme.md             md2html documentation
    highlight/readme.md           Highlighter documentation
    rxcheck/, rxcomp/, ...        Other utilities
  rexxpub/                        RexxPub system documentation
    readme.md                     RexxPub overview and installation
    yaml/readme.md                YAML front matter specification
    article/, book/, letter/, slides/  Document class documentation
    bibliography/                 Bibliography support docs
  publications/                   Symposium papers
  highlighter/                    Highlighter internals documentation
  ref/                            Language reference notes
  guide/                          User guide
  history/                        Project history
  glossary/                       Glossary
  todo/                           TODO items
  unicode/                        Unicode support notes
  experimental/                   Experimental features docs
  executor/                       Executor support documentation
  oorexx-bugs/                    ooRexx bug reports/workarounds
```

## Key dependencies between files

```
md2pdf.rex ──requires──▶ FencedCode.cls
                         YAMLFrontMatter.cls
                         RexxPubOptions.cls
                         ErrorHandler.cls
                         BaseClassesAndRoutines.cls

md2html.rex ──requires──▶ FencedCode.cls
                          YAMLFrontMatter.cls
                          RexxPubOptions.cls
                          ErrorHandler.cls
                          BaseClassesAndRoutines.cls

CGI.markdown.rex ──Call Requires──▶ FencedCode.cls
                                    YAMLFrontMatter.cls
                                    RexxPubOptions.cls
                 ──::Requires──▶ Rexx.CGI.cls

FencedCode.cls ──requires──▶ Highlighter.cls
                             Rexx.Parser.cls
                             HTMLClasses.cls
                             (and transitively the full parser chain)

RexxPubOptions.cls ──requires──▶ ANSI.ErrorText.cls
ErrorHandler.cls ──requires──▶ ANSI.ErrorText.cls
```

## Files that change together

When modifying YAML option handling or caption/frame logic, these
files typically need coordinated changes:

- `bin/RexxPubOptions.cls` (shared option parsing and CSS generation)
- `bin/md2pdf.rex`, `bin/md2html.rex`, `cgi/CGI.markdown.rex`
  (the three pipelines that consume the options)
- `js/numberFigures.js` (reads data-* attributes set by the pipelines)
- `doc/rexxpub/yaml/readme.md` (YAML option documentation)

When modifying Rexx highlighting themes:
- `css/rexx-*.css` (the theme files)
- `css/flattened/rexx-*.css` (flattened versions for md2pdf)
- `bin/StyleSheet.cls` (generates CSS from theme definitions)

When modifying print/PDF layout:
- `css/print/*.css` (document class and size styles)
- `css/print/rexxpub-base.css` (base print styles)
- `bin/md2pdf.rex` (PDF pipeline)