md2slides
=========

----------------

MD2Slides ("MarkDown to Slides") is a utility
that transforms a Markdown file into an interactive slide deck, after
expanding all Rexx fenced code blocks.

Where [md2html](../md2html) produces a page and [md2pdf](../md2pdf) a
paginated document, md2slides produces a single self-contained HTML
file holding every slide, driven by a deck runtime that provides
key and click navigation, stepped reveal of fragments, clock-driven
builds, a jump overlay, screen blanking and fullscreen.

Md2slides operates in single-file mode only: its argument is one
Markdown file, and the output is one HTML deck.

Usage
-----

<pre>
[rexx] md2slides [<em>options</em>] <em>filename</em> [<em>destination</em>]
</pre>

<em>Filename</em> is a file containing Markdown.
If the file is not found and does not already have an extension,
`.md` is appended automatically.
<em>Destination</em> is the output HTML file; when omitted, it defaults
to the source name with its extension swapped for `.html`.

When called without arguments, md2slides displays help information
and exits.

Options
-------

\

------------------------------------------------- ------------------------------
<code>-t <em>name</em></code>, <code>--theme <em>name</em></code>&nbsp;&nbsp; Brand theme to build with (default: `default`)
<code>-mp <em>name</em></code>, <code>--master-pages <em>name</em></code> Presentation master to layer (repeatable)
<code>--assets <em>dir</em></code>                  md2slides home directory
<code>--csl <em>name</em>|<em>path</em></code>              Citation style (default: `rexxpub`); citations turn on via `bibliography:`
<code>--pandoc-highlight <em>name</em></code>        Pandoc style for non-Rexx code
`-h`, `--help`                                    Display help and exit
------------------------------------------------- ------------------------------

\

The two identity options, `-t` and `-mp`, are the heart of md2slides
and are described under [Theme and masters](#theme-and-masters) below.

Citations follow the document, not this flag. A deck turns them on by
declaring a `bibliography:` in its front matter: it then cites sources
inline with `[@key]` and gathers them wherever it places a
`::: {#refs} :::` block (typically a closing "References" slide). A deck
that names no bibliography is passed to Pandoc untouched.

`--csl` only chooses *which* citation style is used, exactly as in
md2pdf. It defaults to `rexxpub`; a bare name resolves to the matching
`.csl` file in the project's shared `csl/` directory (e.g. `--csl ieee`
→ `csl/ieee.csl`), and an argument containing a path separator is used
as-is. The style file is required to exist only when the deck actually
cites.

`--pandoc-highlight` sets the Pandoc style that colours non-Rexx code
tokens, read from the project's shared `css/pandoc/` directory (the same
set md2pdf offers: `pygments`, `breezeDark`, `kate`, `tango`, `zenburn`,
and others). It is used verbatim, without case-folding, because the
sheets are named as Pandoc names them (e.g. `breezeDark.css`). It
overrides the theme's own `--theme-pandoc-style`; if neither is set,
`pygments` applies.

`--assets` overrides the md2slides home directory, under which `css/`,
`assets/`, `masters/`, `js/` and `templates/` live. It defaults to
`bin/md2slides` inside the Rexx Parser installation, anchored to the
location of `md2slides.rex` rather than to the current directory, so
md2slides runs correctly from anywhere.

Prerequisites
-------------

A working installation of <a href="https://pandoc.org/">Pandoc</a> is required.
No other external tools are needed: the deck runtime is plain
JavaScript embedded in the output, so the resulting HTML file opens
in any modern browser with nothing else installed.

Theme and masters
-----------------

Md2slides separates identity into two orthogonal axes, and the program
itself emits neither: it lays out structure and never names a font, a
colour or a logo.

The **theme** (`-t`) is the brand. It carries fonts, palette, footer
layout and institutional strings, all as `--theme-*` variables in a
`:root` block. There is exactly one theme per deck. Adding an
institution is a new theme.

The **master** (`-mp`) is the presentation. It carries the rules that
read those variables and lay out the page — where the title band sits,
how a section divider is treated, the geometry of a two-column slide.
Masters are layered: `-mp` is repeatable, and the order in which the
flags appear *is* the CSS cascade order, so
`-mp base -mp economia -mp urgencia` applies `base` first. Adding a kind
of presentation is a new master.

Each axis resolves an argument by one distinction — is it a brand or a
`.css` file?  A bare name is a brand: `-t wu` resolves to
`assets/wu/theme.css`, and `-mp banded` resolves to `masters/banded.css`.
An argument that names a `.css` file is taken as a file, searched next
to the deck, then in the current directory, then under the md2slides
home; an absolute path is used exactly as given.

When no master is named, the theme's own `master.css` stands (the
brand's default presentation); a brand that omits one falls back to
`assets/default/`. This means "no `-mp`" reads as "no presentation
decision has been made", not a silent inheritance.

The themes and masters distributed with the Rexx Parser are:

------------- ------------------------------------------------------------
`default`     The neutral built-in theme, used when `-t` is not given.
`wu`          WU Wien institutional theme (default master: `banded`).
`modul`       MODUL University theme (default master: `flat`).
`private`     A plain personal theme (default master: `flat`).
------------- ------------------------------------------------------------

------------- ------------------------------------------------------------
`neutral`     The uncommitted master a deck gets when `-mp` is omitted.
`banded`      Strong institutional treatment: title on a solid accent band, section dividers reversed out over the deep colour.
`flat`        A quieter register: no reversed-out dividers, a lighter title band.
------------- ------------------------------------------------------------

The theme and the masters are resolved into a single ordered list of
CSS sheets — the theme first (it carries the `:root` variables every
master reads), then the masters in cascade order — and concatenated
inline into the output. The deck is always self-contained: never
`<link>`s, never `@import`.

YAML front matter
-----------------

Md2slides reads its options from the YAML front matter block of the
Markdown file. Both identity axes can be set there, and both follow the
same precedence: an explicit command-line flag beats the document, which
beats the default. The axes are independent — a deck may pin its theme
on the command line and still take its masters from the front matter, or
the reverse.

```
---
bibliography: refs.json
rexxpub:
  docclass: slides
  style: light
  theme: wu
  master-pages: banded economia
  title: Citations demo
  footer:
    presenter: Josep Maria Blasco
    course: Citations
    affiliation: EPBCN
    date: today
    license: cc-by-sa
---
```

`theme:` names the brand, exactly as `-t` does. `master-pages:` is a
**space-separated scalar on one line** (not a YAML sequence), with the
same order semantics as the flag: the first named is applied first in
the cascade. It is a scalar on purpose, because the front-matter parser
shared across the pipelines handles only scalar mappings.

`style:` sets the default Rexx highlighting theme for fenced code
blocks. `title:` and the `footer:` sub-block are deck-only notions, read
directly from the `rexxpub:` block (they are not part of the whitelist
shared with md2html, md2pdf and the CGI, none of which has a slide
footer).

The `footer:` block is an open bag of author-defined fields: whatever
names it declares become available to the theme's footer templates. A
theme declares *which* fields appear, in what order and in which slot
(left, center, right); the document declares *what they are worth*. The
runtime always supplies `page` and `total-pages`, so those are never the
document's job. A slide may override its own footer fields with
attributes on its heading — useful when one slide shows borrowed
material and needs a credit the others do not carry.

See the [YAML front matter documentation](../../rexxpub/yaml/) for the
shared specification.

Writing a deck
--------------

The deck syntax needed no invention: it is Pandoc's attribute syntax
throughout. **An h1 starts a slide** — that is the whole rule. No
`{.newpage}` marker is needed. The id, classes and attributes the author
writes on the heading move onto the `<section class="slide">` that the
h1 opens, where the runtime looks for them.

```
# Lists {#lists kicker="Sequences"}
# The Rexx angle {.section}
# Lists vs. Tuples {.two-col anim=slide}
# Example {wait-before=0.9 wait-after=0.7}
```

A class chooses the slide's **role**. The recognised roles are
`title-slide`, `section` (a divider and navigation anchor, carrying no
logo), `two-col` and `business-card`; a heading with none of these is an
ordinary content slide. Any other class or `data-*` attribute passes
through untouched onto the section, so the runtime's vocabulary can grow
without the folder ever knowing about it.

Animations are named as attributes and checked at build time, so a
misspelling is reported at once rather than discovered on stage. Page
animations (on the heading) are `fade`, `slide`, `fade-color` and `cut`.
Element animations (on fragments in the body) are `fade`, `fade-up`,
`fade-down`, `fade-left`, `fade-right`, `scale-in`, `blur-in` and `cut`.
Durations are given in seconds (e.g. `0.4`) or with an explicit `ms`
suffix (`400ms`).

Navigating a deck
-----------------

The generated deck is driven from the keyboard and the mouse:

------------------------------- ------------------------------------------------
Right, Down, PageDown, Space    Advance (next fragment, then next slide)
Left, Up, PageUp, Backspace     Go back
Home / End                      Jump to start / end of the current slide
Ctrl+Home / Ctrl+End            Jump to the first / last slide
`g`, or any digit               Open the jump overlay (a digit pre-fills it)
`b` / `w`                       Blank the screen to black / white
`f`                             Toggle fullscreen
Escape                          Clear a blank screen or close the overlay
------------------------------- ------------------------------------------------

A click on the right seven-eighths of the slide advances, and a click on
the left eighth goes back; selecting text with the mouse does not
navigate, so deck content stays copyable. A slide may also drive its own
build from the clock (via `wait-before` / `wait-after`), but any key
press cancels the timers and hands control back to the presenter.

Program operation
-----------------

The processing pipeline shares its whole front end with md2html and
md2pdf. Md2slides first expands all the Rexx fenced code blocks using
[the Rexx Highlighter](../../highlighter), so a `~~~rexx` block in a deck
is marked up by the real parser and not an imitation of one. It then
runs <a href="https://pandoc.org/">Pandoc</a> against the result to
convert the Markdown into flat HTML, with header attributes surviving as
`id`, `class` and `data-*`. The one genuinely new step is the **fold**:
that flat sequence of headings and content is grouped into
`<section class="slide">` elements, one per h1, with the heading's
attributes moved onto the section. Finally the resolved theme and master
CSS and the deck runtime are assembled, inline, into one self-contained
HTML file.

```
                              md2slides workflow
                              ──────────────────

                       ╔═════════════════════════════╗
                       ║                             ║
                       ║ (1) Markdown deck source    ║
                       ║                             ║
                       ╚═════════════════════════════╝
                                      │
                                      │ ◀──── The Rexx Highlighter (FencedCode.cls)
                                      │
                                      ▼
                       ╔═════════════════════════════╗
                       ║                             ║
                       ║ (2) Markdown +              ║
                       ║     Rexx code expanded      ║
                       ║                             ║
                       ╚═════════════════════════════╝
                                      │
                                      │ ◀──── pandoc
                                      │
                                      ▼
                       ╔═════════════════════════════╗
                       ║                             ║
                       ║ (3) Flat HTML               ║
                       ║     (h1, content, h1, ...)  ║
                       ║                             ║
                       ╚═════════════════════════════╝
                                      │
                                      │ ◀──── the fold (one <section> per h1)
                                      │
                                      ▼
                       ╔═════════════════════════════╗
                       ║                             ║
                       ║ (4) Folded slides +         ║
                       ║     theme + master + runtime║
                       ║                             ║
                       ╚═════════════════════════════╝
```

Because the source is rewritten (fenced code) before it reaches Pandoc,
Pandoc is fed the deck on standard input and therefore does not know
which directory the deck lives in. Md2slides hands it the deck's own
directory as a resource path, so a relative `bibliography:` named in the
front matter (the normal case) is resolved correctly.

md2slides is part of the Rexx Parser package,
see <https://rexx.epbcn.com/rexx-parser/>. It is distributed under the
Apache 2.0 License (<https://www.apache.org/licenses/LICENSE-2.0>).
