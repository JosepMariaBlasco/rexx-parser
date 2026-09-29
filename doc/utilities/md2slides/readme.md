md2slides
=========

----------------

MD2Slides ("MarkDown to Slides") is a utility that transforms a Markdown
file into an interactive slide deck, after expanding all Rexx fenced code
blocks.

Where [md2html](../md2html) produces a page and [md2pdf](../md2pdf) a
paginated document, md2slides produces a single self-contained HTML file
holding every slide, driven by a deck runtime that provides key and click
navigation, stepped reveal of fragments, clock-driven builds, a jump
overlay, screen blanking and fullscreen.

Md2slides operates in single-file mode only: its argument is one Markdown
file, and the output is one HTML deck.

This page is the complete reference: how to invoke the program, how a deck's
identity is chosen (skin and masters), and the whole authoring vocabulary —
slides, roles, zones, the grid, block scaling, animation, and inline code
mentions.

**New to Markdown, or to Pandoc?** [Markdown, Pandoc and md2slides](primer/)
explains, in a few pages, which of the marks in a deck are plain Markdown,
which are Pandoc's additions, and what md2slides does before and after Pandoc
has its turn. **Looking for one option?** The [Reference](reference/) lists
every front-matter key, every slide and block attribute, every key press and
every skin property, with its values and a line on what it is for, and links
back here for the whole story.

Terms Used on This Page
-----------------------

A few words recur throughout, with these meanings:

- **Deck** — the presentation: one Markdown file in, one HTML file out.
- **Sheet** — a CSS style sheet: a plain `.css` file.
- **Skin** — the sheet that says *who* is presenting: the institution's
  colours, typefaces and sizes. One per deck.
- **Master** — a sheet that says *where things go*: the title band, the
  footer, the logos, what a title slide looks like. A deck may stack several.
- **Chrome** — what the master puts on every slide around the content: logos,
  seals, the footer line.
- **Role** — the kind of slide (title slide, section divider, business card),
  chosen with a class on the slide.
- **Zone** — a `::: name` block inside a slide that is not shown where it is
  written, but read as data and placed by the master (a title, a presenter).
- **Fragment** — a part of a slide that appears on a later key press.
- **Beat** — a named step that several things on a slide share, so that they
  happen on the same key press (see [The Spotlight](#the-spotlight)).
- **Attribute** — what is written inside `{...}` after a heading, a marker,
  a block or a span: `.name` is a class, `#name` an id, `name=value` an
  attribute. In the HTML, Pandoc writes `name=value` as `data-name="value"`
  — a **`data-*` attribute**, HTML's standard way of carrying values that
  are not part of HTML itself. The deck's scripts and sheets read them there.
- **Pipeline** — one of the RexxPub tools that turn Markdown into something
  else: md2html, md2pdf, md2epub, md2slides, and the web server. They share
  the Rexx highlighting and the front matter.

Usage
-----

<pre>
[rexx] md2slides [<em>options</em>] <em>filename</em> [<em>destination</em>]
</pre>

<em>Filename</em> is a file containing Markdown. If the file is not found
and does not already have an extension, `.md` is appended automatically.
<em>Destination</em> is the output HTML file; when omitted, it defaults to
the source name with its extension swapped for `.html`.

Called without arguments, md2slides says that no input file was given and
points to `--help`, which displays the help information.

Options
-------

\

------------------------------------------------------------------------------------- ------------------------------
<code>-s <em>path</em></code>, <code>--skin <em>path</em></code>                      Skin sheet: colours, fonts, metrics (default: `skin-default.css`)
<code>-mp <em>path</em></code>, <code>--master-pages <em>path</em></code>&nbsp;&nbsp; Master sheet: geometry and chrome (repeatable)
<code>--img <em>path</em></code>                                                      Another folder of pictures for this deck (repeatable)
<code>--csl <em>name</em>|<em>path</em></code>                                        Citation style (default: `rexxpub`); citations turn on via `bibliography:`
<code>--pandoc-highlight <em>name</em></code>                                         Pandoc style for non-Rexx code
`-h`, `--help`                                                                        Display help and exit
------------------------------------------------------------------------------------- ------------------------------

\

The two identity options, `-s` and `-mp`, are the heart of md2slides and are
described under [Skin and masters](#skin-and-masters) below.

Citations follow the document, not the `--csl` flag. A deck turns them on by
declaring a `bibliography:` in its front matter: it then cites sources inline
with `[@key]` and gathers them wherever it places a `::: {#refs} :::` block
(typically a closing "References" slide). A deck that names no bibliography is
passed to Pandoc untouched.

`--csl` only chooses *which* citation style is used. It
defaults to `rexxpub`; a bare name resolves to the matching `.csl` file in the
project's shared `csl/` directory (e.g. `--csl ieee` -> `csl/ieee.csl`), and
an argument containing a path separator is used as-is. The style file is
required to exist only when the deck actually uses citations.

`--pandoc-highlight` sets the Pandoc style that colours non-Rexx code tokens,
read from the project's shared `css/pandoc/` directory (the same set md2pdf
offers: `pygments`, `breezeDark`, `kate`, `tango`, `zenburn`, and others). It
is used verbatim, without case-folding, because the sheets are named as Pandoc
names them (e.g. `breezeDark.css`). It overrides the skin's own
`--skin-pandoc-style`; if neither is set, `pygments` applies.

Md2slides' own parts — the deck template, the runtime sheets and the runtime
script — live in `bin/md2slides` inside the Rexx Parser installation, anchored
to the location of `md2slides.rex` rather than to the current directory, so
md2slides runs correctly from anywhere. There is no option to move them: a
program's own machinery is not something the caller relocates.

Prerequisites
-------------

A working installation of <a href="https://pandoc.org/">Pandoc</a> is
required. No other external tools are needed: the deck runtime is plain
JavaScript embedded in the output, so the resulting HTML file opens in any
modern browser with nothing else installed.

Skin and Masters
----------------

How a deck looks is decided by two independent settings, the **skin** and
the **master**, and the program itself decides neither: it lays out the
structure and never names a font, a colour or a logo. (This page sometimes
calls them the two *identity axes*: two settings that vary independently, so
that any skin can be combined with any master.)

The **skin** (`-s`) carries the identity: fonts, palette, footer layout and
institutional strings, all as `--skin-*` variables in a `:root` block. There
is exactly one skin per deck. Adding an institution is a new skin.

The **master** (`-mp`) is the presentation. It carries the rules that read
those variables and lay out the page — where the title band sits, how a
section divider is treated, how a business card is set, and which
pictures make up the chrome. Masters are layered: `-mp` is repeatable, and the
order in which the flags appear *is* the CSS cascade order, so `-mp base.css
-mp accent.css` applies `base.css` first. Adding a kind of presentation is a
new master.

A master can also offer **choices a slide makes**. The sample masters place a
logo box at the top right but put nothing in it: a slide asks for a logo by
class, and one that asks for none shows none.

```
# Classic Rexx {.logo-rexx}
```

What the master offers is one line of CSS per logo, with its picture in the
master's `img/`. In `default`, `rony` and `mu` the lines read as below; `wu`
places the logo to the left of its wordmark, so its selector differs:

```css
.slide.logo-rexx       .chrome::before{ background-image:url(img/rexx-logo.png); }
.slide.logo-oorexx     .chrome::before{ background-image:url(img/oorexx-logo.gif); }
.slide.logo-bsf4oorexx .chrome::before{ background-image:url(img/bsf4oorexx-logo.png); }
```

All four sample masters offer these three. The lines need not be in the master
itself, though: a small sheet of your own,
stacked with a second `-mp`, can add logos to a master you did not write. The
class goes on every slide that wants the logo. There is deliberately no "from
this slide on": a slide looks the same wherever it sits, so moving it, or
lending it to another deck, never changes its logo.

Both axes name a **file**, by path, and that is the whole of the rule. A
relative path is looked for beside the deck first, then in the current
directory; an absolute path is used exactly as given. Skins and masters are
your material and live wherever you keep them:

```
md2slides --skin ../skins/skin-wu.css -mp ../skins/master-wu.css deck.md
```

Md2slides ships no skins and no masters — only its own machinery — so there
is no catalogue of names to learn and nothing to install a sheet *into*.
Naming sheets by path is also what lets each one find its own `img/` folder
beside it (see [Pictures](#pictures) below).

With no `-s`, md2slides looks for `skin-default.css`; with no `-mp`, for
`master-default.css` — both by the same rule, beside the deck and then in the
current directory. A missing default master is not an error, since a deck may
be all skin and no master; a missing skin is.

The skin and the masters are resolved into a single ordered list of CSS
sheets — the skin first (it carries the `:root` variables every master
reads), then the masters in cascade order — and concatenated inline into the
output. The deck is always self-contained: never `<link>`s, never `@import`.

Pictures
--------

A deck travels as **one file**, so a picture that is to travel *with* it has
to be found and embedded at build time. Not every picture is: one that lives
on the web, or on a machine the deck will only ever be shown from, is meant
to stay where it is, and a deck is free to point at it. Which pictures come
along and which stay put is the author's decision, and two sentences are how
it is expressed:

> **`img/` is always relative to the file that names it.**
>
> **`img/` means *embed me*; anything else means *leave me alone*.**

A deck's Markdown writes `![Architecture](img/architecture.png)` and the
picture is looked for in an `img/` folder beside the **`.md`**. A master or
skin writes `background-image:url(img/logo.svg)` and the picture is looked
for in an `img/` folder beside the **`.css`**. Nothing else is implied: no
namespace and no prefixes. It is how `url()` works in ordinary CSS, so it
should surprise nobody.

That is where a picture is looked for; a deck may name further folders to look
in after that, with [`--img`](#sharing-one-picture-between-decks---img), which
is how several talks share one logo.

Two files in two folders may therefore name `img/rexx.svg` and mean different
pictures, with no risk of collision:

```
~/talks/
├── skins/rony/
│   ├── skin-rony.css
│   ├── master-rony.css        ->  url(img/…)
│   └── img/
│       ├── cc-by-sa.svg            chrome: the master paints it, always there
│       └── oorexx-logo.gif         chrome too, but a slide asks for it
├── 2026-09-21-bsf4oorexx/
│   ├── deck.md                ->  ![](img/…)
│   └── img/
│       ├── rexx.svg                content: the subject of section 1
│       ├── oorexx.svg              …of section 2
│       └── architecture.png
└── 2026-10-05-parser/
    ├── deck.md
    └── img/
        └── rexx.svg                same name, other file, no conflict
```

```
cd 2026-09-21-bsf4oorexx
md2slides --skin ../skins/rony/skin-rony.css \
          -mp    ../skins/rony/master-rony.css  deck.md deck.html
```

The output is a single `deck.html` with the skin's two pictures and the
deck's four inside it.

The distinction the tree draws is worth keeping: `skins/rony/img/cc-by-sa.svg`
is **chrome** — the master puts it there and it is on every slide — while
`2026-09-21…/img/rexx.svg` is **content** — it is what the slide is about, and
it changes as the talk moves on. Different owners, so different folders.

The rule cuts the other way too, and it is worth knowing: sheets that sit in
the *same* directory share its `img/`. Two masters that both want the same
logo need not each keep a copy — put them side by side and one picture serves
both. For sheets that is the only way to share one: a `url(../shared/logo.svg)`
is not an `img/` path, so it is left alone rather than embedded. A deck has
`--img` as well; a sheet does not.

### What Is *Not* Embedded

Anything whose reference does not begin with `img/` is passed through exactly
as written. That is how a deck keeps a picture where it already lives — an
image served from a web site, a shared asset reached by absolute path — and it
needs no flag and no syntax of its own: not saying `img/` is the whole of it.

\

The test is on the **start** of the reference: it either begins with `img/` or
it does not. An `img/` further along the path is not the rule being met, and
neither is a folder that merely contains one.

\

---------------------------------- --------------------------------------------
`img/dot.png`                      embedded
`img/sub/dot.png`                  embedded — subfolders work
`./img/dot.png`                    embedded — the `./` names the same file
`../talk/img/dot.png`              left alone — reported; `img/`, but not first
`img\dot.png`                      left alone — reported; write the `/` instead
`https://…/dot.png`                left alone
`/absolute/path/dot.png`           left alone
`pictures/dot.png`                 left alone — **and reported**, see below
---------------------------------- --------------------------------------------

\

Because a deck is one file, a *relative* reference that is left alone will
resolve beside the `.html`, where nothing was shipped. That renders perfectly
on the machine it was built on and arrives blank everywhere else, so md2slides
says so at build time rather than letting you find out in front of an
audience:

```
md2slides: warning: <img src="pictures/dot.png"> is a relative reference and
was NOT embedded -- only img/ paths are. The deck travels as a single file, so
that picture will be missing anywhere but here.
```

The same warning covers a relative `url()` in a skin or master, for the same
reason — those sheets are inlined too. A `url(#gradient)` points inside the
document and is not a file, so it is never mentioned.

### Sharing One Picture Between Decks — `--img`

A logo used by every talk you give should exist once. `--img` names another
folder to take pictures from:

```
md2slides --img ../shared/img  deck.md deck.html
```

`img/logo.svg` is then looked for in the deck's own `img/` first, and after
that in `../shared/img/`. The first one found is the one embedded.

The named folder **is** the folder of pictures: `img/logo.svg` asks for
`logo.svg` inside it, not for another `img/` within it. Subfolders work as
they do beside the deck, so `img/sub/dot.png` is `../shared/img/sub/dot.png`.

The flag is repeatable, and the order is the search order:

```
md2slides --img ../shared/img --img ~/pictures  deck.md deck.html
```

Two things follow from "first one found":

* A picture the deck keeps in its own `img/` **shadows** one of the same name
  in a shared folder. That is how one talk overrides the common logo without
  disturbing the others.
* A folder named on `--img` must exist. A deck built against a folder that is
  not there would silently be a deck without those pictures, so it is an error
  instead.

The same folders can be named in the front matter, which is what lets `deck.md`
rebuild the same deck on its own:

```
---
rexxpub:
  img: [../shared/img, ~/pictures]
---
```

As with the other axes, a flag on the command line beats the document. Like
`master-pages:`, the value is one folder (`img: ../shared/img`) or a YAML list
of them, in the order they are searched. A plain value is a single name, blanks
and all: `img: My Pictures` is one folder.

`--img` is for decks. A skin or a master keeps its own `img/` beside itself and
does not see the deck's folders; sheets that sit in the same directory already
share that directory's `img/`, which is how two masters use one logo.

And if a picture should *not* travel inside the deck at all, name it by
absolute path or by URL: those are passed through untouched, by contract. The
deck then needs that path or that network to be there when it is shown, which
is the trade being made.

### Size

A picture straight from a camera, or from a PowerPoint template, can be many
times bigger than anything a slide will show, and a deck carries every byte
of it. So a PNG or JPEG whose longest side is over **1920 pixels** is reduced
to 1920 on its way into the deck. The slide is 1280 pixels wide, and full
screen on a 1080p screen or projector that is 1.5 times as much, 1920 pixels:
more is never seen.

The reducing is done by [ImageMagick](https://imagemagick.org), if it is
installed:

- **Windows**: `winget install ImageMagick.ImageMagick`
- **macOS**: `brew install imagemagick`
- **Linux**: your package manager (`imagemagick`)

Nothing else is needed: md2slides finds it and uses the best settings for
slides. A JPEG is written again at a quality that looks the same on a screen;
a PNG stays a PNG, so a screenshot keeps its sharp text and its transparency.
Your pictures are never touched: the reduced copies are kept beside the deck,
in a `.md2slides-cache` folder, so only the first build takes the time, and a
picture that changes is reduced again. The folder can be deleted whenever you
like. The build says what it saved:

```
md2slides: reduced 2 picture(s) to 1920 pixels a side: 6064KB -> 586KB
```

Without ImageMagick the pictures go in as they are, and the build says which
of them are too big, and how much of the deck they make.

GIFs (they may be animated), SVGs (they have no pixels) and pictures of 100 KB
or less are left alone, and nothing is ever enlarged. To choose another limit,
or to keep every picture as it is:

```
---
rexxpub:
  picture-size: 1280     # or: no
---
```

or `--picture-size 1280` (or `no`) on the command line, which beats the front
matter.

Whatever is embedded, md2slides also warns when one picture goes over 1 MB,
and when all of a deck's pictures together go over 8 MB. Base64 adds about a
third on top, so both warnings quote the file size and what the `.html`
actually grows by.

A picture that the deck shows more than once — the same logo on every
section's first slide, say — is embedded only once, however many slides it is
on, and counts once towards those 8 MB. (This is for the pictures in the
deck; a skin or master that names the same picture in two rules carries it
twice.)

### Backgrounds

A picture can lie behind a whole slide, with everything else on top of it:
the title, the prose, and the master's bands and chrome. Put it in a
`::: background` zone:

```
# Welcome {.title-slide}

::: background
![](img/campus.jpg)
:::
```

The picture fills the slide, cropped rather than squashed if its shape is not
the slide's. A zone may hold more than one picture; they are drawn in the
order written, each over the one before.

When the picture belongs to a *kind* of slide rather than to one slide — the
institution's photo on every title slide, say — it is the master's to paint,
and it takes one line of CSS:

```css
.slide.title-slide { background: url(img/campus.jpg) center / cover; }
```

Several masters can each carry their own, which is how the same deck opens
with a WU photo under one master and a Modul one under another.

### A Picture Built Up in Layers

A diagram is often explained a part at a time: first the classes, then the
arrows between them, then the labels. Cut it into transparent pictures of the
same size, one per step, and stack them in a `::: layers` zone:

```
::: layers
![](img/tree.png)

![](img/amphibian.png){.fragment}

![](img/arrows.png){.fragment}
:::
```

The first picture sits in the slide like any other and gives the stack its
size; every later one is drawn exactly over it.

For screenshots that pile up — each window a little to the right of and
below the one before — give the stack an **offset**:

```
::: {.layers offset="60px 40px"}
![](img/first.png){width=600px}

![](img/second.png){width=600px .fragment .afterPrevious}

![](img/third.png){width=600px .fragment .afterPrevious}
:::
```

Each picture after the first is moved that much further right and down than
the one before it; one length (`offset=1.5em`) moves it that much both ways.
Any length works but a percentage. The block is as big as the whole pile, so
what comes after it comes after the last picture. `offset=` works on
`::: layers` only, and the build says so if it finds it anywhere else. Each `.fragment` arrives on a
key press, so the diagram grows under the audience's eyes, and the explanation
for each step can arrive with it.

Pictures in either zone are pictures like any other: `.fragment` reveals them,
an animation can bring them in, and they take their turn **in the order they
are written** among the slide's other fragments. A background written after
the first bullet builds after that bullet.

YAML Front Matter
-----------------

Md2slides reads its options from the YAML front matter block of the Markdown
file. The block must **start on the very first line** of the file, with its
`---`: nothing may come before it, not even a comment or a blank line. A block
anywhere else is ignored, and md2slides warns when it finds one. It also
warns when the block opens or closes with some other line of dashes (`--`,
`----`, a dash an editor made long), and when a key is set twice in the same
block: the front matter keeps the last value, so the first one is lost. Both identity axes can be set there, and both follow the same
precedence: an explicit command-line flag beats the document, which beats the
default. The axes are independent — a deck may pin its skin on the command
line and still take its masters from the front matter, or the reverse.

```
---
bibliography: refs.json
rexxpub:
  docclass: slides
  style: light
  skin: ../skins/skin-wu.css
  master-pages: base.css accent.css
  font-prose: IBM Plex Sans
  font-mono: IBM Plex Mono
  title: Citations demo
  img: ../shared/img
  presenter: Josep Maria Blasco
  affiliation: EPBCN
  version: '0.7'
  version-date: '2026-09-22'
  date: today
  license: cc-by-sa
  footer:
    left: '{presenter}'
    center: '{file-name}'
    right: '{page} / {pages}'
  header:
    right: 'v{version} · {version-date}'
  anim:
    element:
      effect: fade-up
      duration: 1
    page:
      effect: cut
      duration: 0
---
```

(A block may also be written on one line, in YAML's flow style:
`page: { effect: cut, duration: 0 }`.)

`skin:` names the skin sheet, exactly as `-s` does. `master-pages:` names the
masters: one sheet (`master-pages: base.css`), or a YAML list of them, in
block style (one `- name` per line) or in flow style
(`master-pages: [base.css, accent.css]`). The order is the flag's: the first
named is applied first. A plain value is always **one** name, blanks and all:
`master-pages: base.css accent.css` is a single sheet with a blank in its
name, not two — write the list.

`style:` sets the default Rexx highlighting theme for fenced code blocks.
`title:`, `img:`, the `footer:` sub-block and the `anim:` sub-block are
deck-only notions, read directly from the `rexxpub:` block (they are not part
of the whitelist shared with md2html, md2pdf and the CGI, none of which has
slides).

`img:` names further folders of pictures, exactly as `--img` does, and is
described under [Sharing one picture between
decks](#sharing-one-picture-between-decks---img).

`title:` is the name used as the **label of the browser's tab**, and nothing
else: no slide shows it, and the deck's own title slide is written like any
other slide. A deck that names none is labelled after its file, without the
`.md` — the same name its `.html` gets — so several decks open at once can be
told apart in the tab bar whether or not anyone wrote a title.

`font-prose:` and `font-mono:` name the deck's two dominant typefaces —
`font-prose:` for flowing text, `font-mono:` for the code registers (`<pre>`,
`<code>` and `.output`). Each is a bare family name written as it appears in the
source (`IBM Plex Sans`, `Tahoma`, `Courier New`; no quotes, no fallback list —
the program adds the quoting and a generic fallback, `sans-serif` for prose and
`monospace` for code, so a face the reader's machine lacks degrades sanely).
Their point is precedence: a deck typically takes its fonts from the skin, but
when these keys are present they **override the skin's own** `--skin-font-prose`
/ `--skin-font-mono`. That is the seam for a deck that wants an institution's
brand — its palette, footer and logo from the skin — carried in a different
typeface, without forking the skin to change it. A key that is absent, or set
empty, leaves the skin's face standing; the two are independent, so a deck may
override the prose face and inherit the mono, or the reverse.

### The margin boxes (header and footer)

A slide has six **margin boxes**, three along the top and three along the
bottom, exactly like CSS Paged Media: `header-left`, `header-center`,
`header-right`, `footer-left`, `footer-center`, `footer-right`. You fill each
with whatever you like — a template of plain text and `{placeholders}`.

**Fields** are the values the placeholders stand for. Write them at the top of
the `rexxpub:` block:

- `presenter:` — who gives the talk;
- `affiliation:` — the institution, department or chair they speak for;
- `date:` — a date as written, or `today` for the day the deck is built;
- `version:` / `version-date:` — a deck's version string and date, so a printed
  handout says which one it is;
- any other name you invent (`course:`, `semester:`) — all are available to the
  boxes.

A field may also be a YAML list: `{author}` for `author: [Ann, Bob]` is
"Ann, Bob". An item that is itself a block gives its `name:`, which is how
Pandoc writes an author with an affiliation:

```
  author:
    - name: Josep Maria Blasco
      affiliation: EPBCN
    - Rony G. Flatscher
```

These placeholders the build fills for you, so you never declare them:

- `{page}` / `{pages}` — the slide number and how many slides the deck has
  (the runtime counts the slides; a hand-written number would drift);
- `{today}` / `{now}` — the build date, ISO `YYYY-MM-DD`, and the build time,
  `HH:MM:SS`. `{now}` is when the deck was *built*, not a clock that runs
  during the talk: it is what tells two copies of a deck apart;
- `{file-date}` / `{file-time}` — the deck **file's** own modification date and
  time, for "last edited" stamps;
- `{file-name}` / `{file-name-full}` / `{file-path}` — the deck file's name
  (`010_ooRexx.md`), its fully qualified name, and the folder it is in, as
  written on the machine that builds the deck.

And these the runtime keeps **live** while the deck is shown, from the moment
the presenter's timer starts (see [The Presenter's Timer](#the-presenters-timer));
until then they are blank, and on paper they are never printed:

- `{clock}` — the time of day, `HH:MM`;
- `{elapsed}` — the time since the timer started;
- `{remaining}` — the time left of the talk's `total:`; once it is over, the
  overtime, as `+2:10`, in red;
- `{section-remaining}` — the same for the section the slide is in: the
  time left until that section is planned to end;
- `{section-elapsed}` — the time since the talk first reached the section the
  slide is in; in red once it is more than the section's `time=`.

While the timer is paused they stand still (all but `{clock}`, which is the
time of day), and each carries the class `paused`, for a skin that wants to
show it.

Four more describe the plan of the talk. They do not tick, so they are
filled in from the start, and printed:

- `{total}` — the talk's length, the `timer:` block's `total:` (blank if it has
  none);
- `{section}` — the number of the section the slide is in, from 1 (blank on
  the slides before the first section);
- `{sections}` — how many sections the talk has;
- `{section-total}` — the section's `time=`.

A talk with a `total:` and no `time=` anywhere is **one section**, the whole
of it: `{section}` and `{sections}` are 1, `{section-total}` is `{total}`, and
`{section-elapsed}` and `{section-remaining}` are `{elapsed}` and
`{remaining}`. So a footer written for sections works in any talk.

Times are shown in **whole minutes** — `20`, `87` — and in minutes and seconds,
`2:59`, only at the end (see *Seconds* under
[The Presenter's Timer](#the-presenters-timer)). So
`Section {section}/{sections}: {section-elapsed} of {section-total}` reads
"Section 2/5: 3 of 20", and `{elapsed} of {total}` reads "87 of 90".

A field declared in the front matter wins over the automatic one of the same
name, so `file-date: 2026-01-01` pins it.

**A field per skin.** A deck built under more than one institution's skin can
carry a value for each: `skin-mu-affiliation:` is what `{affiliation}` means
when the deck is built with `skin-mu.css`, and `affiliation:` everywhere else.
It works for any field — `skin-wu-presenter:`, `skin-rony-course:`,
`skin-mu-regulations:` — and the name after `skin-` is the skin sheet's own
name without `skin-` and `.css`. Give the plain field too (`regulations:`) as
the value for every other skin: a field set only for other skins is reported
when the deck is built under one that has none.

**Fields in the slides themselves.** The fields are not only for the margins.
`{regulations}` in the text of a slide is the field's value, and so is a link
target: `[the regulations]({regulations})` links to whatever `regulations:`
says under the skin the deck is built with. Only the fields the deck declares
(and the ones the build knows: `{today}`, `{file-name}`...) are replaced —
braces are ordinary text on a slide, so `{niX }` in a string stays exactly as
written — and code is never touched: a listing or a code mention shows the
program, braces and all. The live fields (`{page}`, `{elapsed}`...) belong to
the margin boxes and stay as written in the text. On a
[business card](#the-business-card) a field with no value leaves nothing, and
its line goes.

**A field with no value.** `address-2:`, with nothing after it, declares a
field that is empty: in a margin box it shows nothing and the build does not
warn. So does `skin-mu-address-2:` under that skin, whatever `address-2:`
says.

**Boxes** are the templates. Set them in the `header:` and `footer:` blocks, one
of `left` / `center` / `right` each:

```
footer:
  left: '{presenter}'
  center: '{file-name} · {now}'
  right: '{page} / {pages}'
header:
  right: 'v{version} · {version-date}'
```

A box may carry markup, so a two-line footer is `{presenter}<br>{affiliation}`.
A placeholder whose field is not set expands to nothing, so a template can name
`{version}` and simply come out blank in a deck that has no version.

What goes *with* a field can be made optional too: put it in brackets.
`{presenter}[ · v{version}]` is "Rony · v1.2" in a deck with a version and just
"Rony" in one without — the whole bracketed group goes when none of its fields
has a value, and the brackets themselves never show. The build does not warn
about a field in brackets that nobody sets. Brackets with no field inside are
ordinary text.

**Precedence.** Each box has a default from the **skin** (its
`--skin-{header,footer}-{left,center,right}`); your `header:`/`footer:` blocks
override the skin per box; and a single slide can override one box for itself
with a zone — `::: footer-center` / your text / `:::` (see [Zones](#zones)) —
useful for a one-off note, a guest credit, or borrowed material. A zone is
written like a template: `{page}/{pages}<br>Cf. rexxref.pdf` is two lines,
and so are two paragraphs in it. The classic
`::: presenter` / `::: affiliation` / `::: date` zones still work too: they set
that **field** for the slide, so every box that uses `{presenter}` follows.

The header band is hidden until a skin (or a deck, via the skin) gives it a
height (`--skin-header-height`), so a deck that uses only the footer loses no
content room.

**When a box says more than fits.** A box whose text does not fit its band —
a long credit, three lines where the band holds two — is **shrunk until it
fits**, on screen and on paper, down to half its size. A box that still does
not fit at half size is reported by the diagnose mode (`d`, see [Navigating a
Deck](#navigating-a-deck)). To set the size yourself, give the block a
`font-size:` — for all three boxes of that band:

```
footer:
  font-size: 14px
  center: '{page} / {pages}<br>(created {today})'
```

The value is a CSS length (`14px`, `0.8em`, `90%`); anything else is reported
and ignored. Shrinking, if still needed, starts from it. The boxes of a band
are always shrunk **together**: if one of them has to go down to 80%, all three
do, so a footer never mixes sizes.

If the build warns that a box shows a `{field}` the deck does not set, the
message says whether the box came from the skin or from your `header:` /
`footer:` block, and how to fill it, replace it, or mark it optional
(`[{field}]`, an optional group: see above).

**Titles that say more than fits.** The same holds for the slide's title: a
title with more lines than its zone was drawn for is shrunk until it fits the
zone and clears the kicker (and, on a cover, the subtitle, which gives way
first). The zone itself does not move, so the rule under it stays where every
other slide has it. The floor is again half size, and a title that still does
not fit is reported by `d`: at that point the fix is a shorter title.

`license:` is checked at build time against the known licence names.

The `anim:` block sets the deck's default animation and is described under
[Animation](#animation) below.

The `rexxpub:` block is the shared front-matter namespace for all the
pipelines; see the [YAML front matter documentation](../../rexxpub/yaml/) for
the keys common to all of them (`style`, `docclass`, `section-numbers`, and so
on). `title:`, `header:`, `footer:`, `anim:`, `about:` and `timer:` are
md2slides' own additions to that block and are documented here.

Writing a Deck
--------------

There are two ways to open a slide. The most usual one is _by heading_: **an h1 starts a slide**.
The id, classes and attributes the author writes on the heading move onto the `<section class="slide">` that the
h1 opens, where the runtime looks for them.

```
# Lists {#lists kicker="Sequences"}
# The Rexx angle {.section}
# Lists vs. Tuples {anim=slide}
# Example {wait-before=0.9 wait-after=0.7}
```

The other way is _by marker_: a slide break written as a fenced `---`
attribute line on its own,

```
--- {.slide}
```

opens a slide that carries **no heading**. Everything from one marker to the
next becomes one slide; the slide's title, if it has one, is then a zone the
author places in the body (see [Zones](#zones)), not an `<h1>`. This form suits
a deck whose slides are composed from zones rather than led by a title band —
the title itself becomes a `::: title` zone the master places. A marker `---`
carries a trailing attribute so Pandoc does not mistake it for a horizontal
rule; a plain `---` an author draws inside a slide is left alone. A deck that
opens its slides with `<h1>` simply has no such markers, and folds exactly as
before.

**Why two ways.** A heading is the shortest way to write a slide, and it is
enough whenever a slide's title is one line of plain text. A marker leaves the
title free to be anything a zone can hold — two lines, a coloured code
mention, nothing at all — and suits slides that are composed rather than led
by a title.

**Why not both.** Each form is a rule for where a slide *ends*: at the next
heading, or at the next marker. In a deck that used both, a heading between
two markers could be a new slide or a large heading inside the current one,
and there would be no way to tell which was meant. So a deck uses one or the
other. In a deck opened by markers, a `# heading` opens nothing — it would
show up inside the slide above it — and md2slides warns when it finds one.

Whatever a heading can carry, a marker carries too, written the same way:
`--- {.slide .section anim=fade wait-before=1}` is the marker twin of
`# Title {.section anim=fade wait-before=1}`. A value with blanks in it goes
in double quotes, as on a heading: `--- {.slide kicker="Part One"}`.

Every slide has a name, which the address bar shows as the deck moves on, so
that reloading the page — or sending someone the link — lands on the same
slide. A heading-opened slide is named after its heading, as Pandoc names any
heading; a marker-opened slide is named after its `::: title` the same way, or
`slide-N` if it has none. To choose the name yourself, write it on the
marker: `--- {.slide #intro}`. A name cannot contain blanks — HTML does not
allow them — so write `#part-two`, not `#part two`.

### Roles

A class on the slide chooses its **role**. The recognised roles are
`title-slide`, `section` (a divider and navigation anchor, carrying no logo;
`section="Short name"` on it names the section in the timer and in the go
dialog, when the title is too long for them) and `business-card`; a slide
with none of these is an ordinary
content slide. In a deck opened by markers the role goes on the marker, and
works the same way: `--- {.slide .title-slide}`, `--- {.slide .section}`.
Every other class and attribute on the slide is kept on it as well, as
written: md2slides does not need to know what it means. That is how a slide
asks a master for something the master offers — a logo, say
(`.logo-oorexx`) — and how it gives the deck runtime a value such as
`wait-before=1`, which reaches the HTML as the `data-*` attribute
`data-wait-before="1"`. A new class in a master, or a new setting in the
runtime, needs no change to md2slides.

A `kicker="..."` attribute sets a small line above the title (an eyebrow, or
overline); the master styles and places it. It goes on the heading, or on the
marker:

```
# Lists {kicker="Sequences"}

--- {.slide kicker="Sequences"}
```

#### The Business Card

A `business-card` slide is the closing contact page. Its prose **is** the
card: the first line is the name, the second the role, and every one after
that a detail line.

```
# Thank you {.business-card}

Rony G. Flatscher
Professor, WU Vienna
**Email** rony.flatscher@wu.ac.at
**Web** wi.wu.ac.at/rgf
```

In a deck opened by markers the same slide is `--- {.slide .business-card}`
followed by a `::: title` zone. That zone is shown as the slide's title, as
on any other slide — it does *not* become the first line of the card, which
starts with the first paragraph after it.

**Each line you type is a line of the card**, whether or not you leave a
blank line between them — write the card the way it would be printed. (Elsewhere
in a deck, Markdown joins lines that have no blank line between them into one
paragraph; on a business card it does not.) A bold word opening a detail is its
label, and is set apart from the value by the skin.

For more than one person, write one `::: card` per person; they are laid out
side by side, in the same name / role / details order:

```
# Contact {.business-card}

::: card
Rony G. Flatscher

WU Vienna

**Email** rony.flatscher@wu.ac.at
:::

::: {.card .fragment}
Josep Maria Blasco

EPBCN

**Web** rexx.epbcn.com
:::
```

A card takes the same classes as any other block: the `.fragment` above makes
the second card arrive on the next key press.

**The same card for every skin.** The lines of a card can be fields, so one
card serves every institution the deck is built for. A field with no value
leaves nothing, and a line whose fields are all empty is not shown, label and
all: declare every field the card uses, and give each skin the ones it has.

```
rexxpub:
  name-of-institution:
  address-1:
  address-2:
  email:
  skin-mu-name-of-institution: Modul University
  skin-mu-address-1: Am Kahlenberg 1
  skin-mu-email: rony.flatscher@modul.ac.at
  skin-wu-name-of-institution: WU
  skin-wu-address-1: Welthandelsplatz 1
```

```
::: {.card .tight}
**{name-of-institution}**
{address-1}
{address-2}
**Email** {email}
:::
```

Built with `skin-wu.css`, that card has no email line; with neither skin,
only the lines that have something in them. A field the deck does not declare
at all (a typo, most likely) is left out, and the build says so.

**`.tight`** makes a card an address: there is no role (every line after the
name is a detail), and the lines sit close together, as in a printed address
— the card of an institution rather than of a person.

Zones
-----

A **zone** is a Pandoc fenced div, `::: name ... :::`, that the author places
in a slide's body and the master positions and styles. Zones are read as data,
not shown as prose: once md2slides has consumed a zone, it is removed from the
flowing content.

A slide may carry a zone named after any field: `presenter`, `affiliation`,
`date`, or one the deck invents (`::: course`, `::: version`). Each overrides,
for this one slide, the field of the same name set at the top of the
`rexxpub:` block (and every box or text on the slide that uses it follows) —
so a guest inserting a single slide into someone else's deck writes their own
`::: presenter` / their name / `:::` on that slide and it wins locally,
without touching the host's front matter. `presenter`, `affiliation` and
`date` work even when the deck does not declare them. The one exception is a
field named like one of md2slides' own zones or blocks (`title`, `subtitle`,
`card`, `row`, `contents`...): that block keeps its own meaning.

```
::: presenter
Josep Maria Blasco
:::
```

In a marker-opened (headingless) slide, the **title** is a zone too:
`::: title ... :::`. A title zone may hold more than one line, and a word
inside it can be coloured with an inline mention (see [Code mentions in
prose](#code-mentions-in-prose)).

**Every `:::` block belongs to the slide it is opened in.** A block that is
still open when the next slide starts is closed there, at the end of its own
slide, and the build says so, with the line of its opener: it will not reach
into the slides after it. A bare `:::` with nothing open to close is dropped,
and reported too. (Left to itself, Pandoc would show the fence as text in some
versions, and in others close the block only at the end of the file, pulling
every later slide into it — the same deck came out differently on two
machines.)

The Grid — Rows and Columns
---------------------------

For two-up layouts (code beside its explanation, a figure beside a caption)
there is a lightweight grid: a **row** holding **columns**.

```
::: row
::: col-8
...main content...
:::
::: col-4
...sidebar...
:::
:::
```

The number in `col-N` is a **proportion**, not a percentage or a fixed width —
`col-8` next to `col-4` splits the space two-to-one. Because it is
proportional, **the numbers need not add up to 12**: `col-1 / col-4 / col-1`
centres a block just as well as `col-2 / col-8 / col-2`. The gutter between
columns is always subtracted first, so columns never spill off the right edge.

This gives positioning by **composition** rather than by special rules: full
width is no row at all; centred is an empty column, your content, an empty
column; pushed right is an empty column then your content; left with breathing
room is your content then an empty column. An empty column is a real,
legitimate column — it reserves its share of the space.

Two practical rules, learned the hard way:

- **Inside a row, everything lives in a `col-N`.** No loose prose directly
  under a row — Pandoc mis-parses a row that has bare prose stuck to a column.
- To pass an attribute to a row (such as a scale, below), write the name
  inside braces with the attribute — `::: {.row scale=0.9}` — rather than
  the short `::: row`, which has no room for one. The same holds for every
  block: `::: {.incremental anim=scale-in}`, never `::: incremental
  {anim=scale-in}`. Pandoc does not read the second form as a block at all,
  but as a line of text; md2slides warns when it finds one.

If a direct child of a row is not a `col-N`, the rendered deck shows a **red
diagnostic**: the offending child is outlined with a warning label. That is on
purpose — a visible mistake beats a silent misplacement.

### A Long List in Columns — `flow=`

A row is for blocks you place side by side. A long list — all the built-in
functions, say — is something else: one list that should simply run on into
the next column. Give its `:::` the number of columns with `flow=`:

```
::: {.plain flow=5 scale=0.6}
- `ABBREV()`
- `ABS()`
- `ADDRESS()`
- ...
:::
```

The list fills **column by column**, top to bottom and then on to the next,
and the columns come out as even as they can: 67 items in five columns are
15, 15, 15, 15 and 12. With `fill=rows` it fills **row by row** instead: the
first item of each column, then the second...

```
::: {.incremental .plain flow=3 fill=rows}
```

It works with everything a list takes: `.plain` for no bullets, `scale=` to
fit more in, `.incremental` — the items then come in the order they are read
in, down the columns or along the rows. An item is never split between two
columns, and a nested list stays with its item.

(`cols=` is something else: the proportions of a table's columns.)

Scaling a Block
---------------

Sometimes a slide has a little too much on it. Instead of hand-tuning several
font sizes and keeping them in proportion, wrap the content and give it a
**scale**:

```
::: {.contents scale=0.85}
...prose and code...
:::
```

`scale=0.85` shrinks everything inside — prose, code, and output together,
each from its own base — so the internal proportions are preserved.
`scale=1.2` enlarges, symmetrically; there is no built-in bias toward
shrinking. The slide's title and footer are not affected: they are the
master's chrome, not part of the flowing content.

Two things make this one knob go a long way. It **composes**: to shrink the
code but not the prose, wrap only the code block in its own `:::contents` and
scale that — there is no separate "code size" control because a smaller
wrapper is one. And it **nests, multiplicatively**: a `scale=0.9` inside a
`scale=0.8` yields an effective `0.72`. You write what you mean at each level;
the multiplication is worked out for you.

A row is really "a `contents` that also makes columns", so it takes the same
`scale=` knob, written in braces: `::: {.row scale=0.9}`. So does any other
block: `::: {.fragment scale=0.85}` is a fragment whose content is scaled —
and, inside a `scale=0.85` group, scaled again, to `0.72`.

Rows stacked one under another are a paragraph apart. When they are the lines
of a small table instead, add `.tight` to each row after the first, and it
sits right under the one before: `::: {.row .tight}`. (For real tabular
material, a Markdown table is shorter to write: see [Marking
Fragments](#marking-fragments).)

A comparison — two languages, two approaches — reads best with a **line
between the columns**. Add `.ruled` to the row, and write one row per topic,
so that each topic starts at the same height on both sides:

```
::: {.row .ruled}
::: col-6
- Message operator
  - `~` (Tilde)
:::
::: col-6
- "Message" (dereference) operator
  - `.` (dot)
:::
:::

::: {.row .ruled}
...the next topic, on both sides...
:::
```

Ruled rows one under another make one unbroken line, as long as their
columns line up (the same `col-N`). The line belongs to the row, not to its
content, so it is there from the start even when everything in the columns
comes in steps; to reveal both sides of a topic on one press, make the right
side `.withPrevious`. The skin sets its colour and width,
`--skin-column-rule` (the text colour) and `--skin-column-rule-width` (`2px`).

Indenting a Block
-----------------

`indent=` pushes a block in from the left edge, with no empty column needed:

```
::: {.incremental indent=1cm}
| Operator | Meaning |
|----------|---------|
| `=`      | equal   |
:::
```

It works on any `:::` block (`::: {.contents scale=0.7 indent=2em}`, say).
The value is a CSS length: a number and a unit, such as `1cm`, `2em`, `40px`,
or `5%`. A bare number has no unit, so the browser would ignore it. md2slides
warns about it at build time and names the slide.

Animation
---------

Animation has two independent axes: the **page** transition between slides,
and the **element** reveal of fragments within a slide. They are genuinely
separate — a deck may use no page transition at all yet a full second on every
fragment. With nothing set, a slide arrives with **no transition** and a
fragment **fades in** (a plain `fade`) over **1 second**; the deck's `anim:`
block (below) changes both, for every slide and every fragment that names no
effect of its own.

A slide sets its own page animation with `anim=` on the heading; a fragment
sets its own element animation with `anim=` on the fragment. Effect names are
checked at build time, so a misspelling is reported at once rather than
discovered on stage:

- **Page** effects: `fade`, `slide`, `fade-color`, `cut`.
- **Element** effects: `fade`, `fade-up`, `fade-down`, `fade-left`,
  `fade-right`, `scale-in`, `blur-in`, `cut`.

Durations are seconds — a bare number (`1`, `0.4`) — or a number with an
explicit `ms` suffix (`400ms`). Write `1`, not `1s`: the `s` suffix is not
part of the deck's vocabulary, and the build warns about it.

### Attributes at a Glance

Every animation setting is an attribute, written in the braces of a slide (its
heading or its marker), of a fragment, or of an `::: incremental` block:

| Attribute | Where | What it does |
|---|---|---|
| `anim=` | slide | How the slide arrives: a page effect |
| `anim-duration=` | slide | How long that takes |
| `anim=` | fragment | How the fragment appears: an element effect |
| `anim-duration=` | fragment | How long that takes |
| `wait-before=` | slide | Build the slide by the clock: pause before each fragment |
| `wait-after=` | slide | ... and after each one |
| `wait=` | slide | Shorthand for both of the above |
| `duration=` | slide | Build the slide by the clock, spreading its fragments evenly over this many seconds |
| `head=` | incremental block | A table's header: on its own step, or with the first row |
| `steps=` | incremental block | A table built row by row, or cell by cell |
| `cols=` | any `:::` holding a table | The proportions of the table's columns, `1:5` |
| `flow=` | any `:::` holding a list | The list flowed into that many columns; `fill=rows` fills row by row |
| `group=` | fragment | Reveal every fragment of this name on one press, contiguous or not |
| `.withPrevious` | fragment | Reveal this fragment **together with** the one right before it (same press, same moment) |
| `.afterPrevious` | fragment | Reveal this fragment **automatically after** the one before it finishes animating — no press of its own; a run of them cascades from a single press |
| `.afterClick` | fragment | Reveal this fragment on a press — the default, written out, so it can take the place of `.afterPrevious` or `.withPrevious` without rewriting the line |
| `appear=` | any `:::` | One timing word for every step inside the block: `appear=afterPrev`, `appear=withPrev`, `appear=afterClick` |
| `time=` | slide | Open a section of the talk with this many minutes (see [The Presenter's Timer](#the-presenters-timer)) |
| `.pause` | slide | Pause the presenter's timer when this slide is shown, until the talk goes on (also `.startPause`) |

`.withPrevious` and `.afterPrevious` may be written short, as `.withPrev` and
`.afterPrev`, and case does not matter. A class that is *almost* one of them
(`.afterPrevios`) would do nothing at all, so the build reports it, with its
slide and the right spelling.

A timing word on a block that is not itself a fragment —
`::: {.contents scale=0.85 .afterPrevious}` — times the **first fragment
inside it**, unless that fragment has a timing word of its own. A block with no
fragment inside has nothing to time, and the build says so.

`appear=` gives **every step of a block** the same timing, written once
instead of on every item:

```
::: {.incremental appear=afterPrev}
- one press shows this
- and then this, by itself
- and then this
:::
```

It reaches every step inside the block: each item an `.incremental` makes,
each row or cell of its table, every `.fragment` in it, and the block itself
if it is a fragment. A step with a timing word of its own keeps it, and so
does the first step of a block that has one (`{.incremental .afterPrev
appear=withPrev}` starts by itself and brings the rest along with its first
item). A block nested inside with its own `appear=` wins inside it. The value
is a timing word, with or without its dot, short or long, in any case; any
other value is reported at build time.

A slide or a fragment with no `anim=` takes the deck's default, set in the
front matter (below).

### Key Presses and the Clock

A slide builds **on key presses** unless it says otherwise: each press of
the space bar, `→` or `PageDown` reveals the next fragment.

A slide that carries `wait-before=`, `wait-after=`, `wait=` or `duration=`
builds **by the clock** instead: its fragments appear one after another, on
their own, as soon as the slide is shown.

```
# The Evaluation Order {wait-before=1.5}
--- {.slide wait-before=1.5}
```

On a slide, the clock (`wait-`/`duration=`) makes every fragment wait the
same. To time a SINGLE fragment relative to the one before it, use
`.withPrevious` (same moment) or `.afterPrevious` (once the previous one has
finished animating) — these are per-fragment and compose with an ordinary
key-driven slide. An `.afterPrevious` fragment can wait longer:
`wait-before=2` on it adds two seconds before it comes, `wait-after=2` on the
fragment before it adds them after that one, and `wait=` is both. They time
the steps that come by themselves; a step that comes with a press comes at
once, so md2slides warns about a `wait-before=` there, and about any wait on
something that is not a step at all. Any key press
stops the clock, and forces the next step of an `.afterPrevious` cascade
immediately, handing the slide back to the presenter: a build that runs too
fast or too slow for the room is never a trap.

`{.static}` is not a timing: it marks one item inside a `::: incremental`
list that is shown from the start instead of being revealed (see [Marking
Fragments](#marking-fragments)).

### Deck Defaults: The `anim:` Front Matter

Rather than annotate every slide and every fragment, set the deck's defaults
once in the front matter:

```
rexxpub:
  anim:
    element:
      effect: fade-up
      duration: 1
    page:
      effect: fade
      duration: 0.5
```

Each of the two axes takes an `effect` and a `duration`. The `element` effect
becomes the default for every fragment that does not name its own, and the
`page` effect the transition of every slide that does not; the durations set
the deck-wide element and page tempos. A per-slide or
per-fragment `anim=` / `anim-duration=` still overrides the default on the
element it is set on.

### Marking Fragments

A fragment is a piece of a slide revealed on its own step. The verbose way is
to tag each one, `{.fragment}`; but for the common case of "reveal this list
one item at a time", there are two conveniences.

`::: incremental` wraps a block and marks every list item inside it as a
fragment, in document order, each with the deck's default element effect — one
marker instead of one tag per bullet:

```
::: incremental

- first
- second
- third

:::
```

The block can carry an animation for all its items, written in braces with
the name inside them: `::: {.incremental anim=scale-in}`.

A **table** inside `::: incremental` is revealed one row at a time. The
first press shows the header, and each press after it adds a row, so the
table does not stand on the slide before the text that introduces it. A table
without a header, written with an empty first row, arrives with its first row
instead:

```
::: incremental
|        |         |
|--------|---------|
| `=`    | equal   |
| `<>`   | unequal |
:::
```

Two attributes on the block choose how a table is built, one table at a time:

| Attribute | Values | What it does |
|---|---|---|
| `head=` | `before` (default), `with-row` | The header on a step of its own, or together with the first row |
| `steps=` | `rows` (default), `cells` | Each press adds a whole row, or one cell, left to right and row by row |

```
::: {.incremental steps=cells head=with-row}
| Operator | Meaning |
|----------|---------|
| `=`      | equal   |
| `<>`     | unequal |
:::
```

With `steps=cells` and `head=with-row`, the header comes in with the first
cell. A value md2slides does not know is reported at build time, with its
slide, and the default is used.

With `steps=cells`, an **empty cell is not a step**: it comes in together with
the cell before it, so a press never shows nothing. A table of statements whose
result column is blank when there is no result costs one press per statement,
not two. Nothing to write for this; it is what an empty cell means.

Tables are drawn with a thin grid and a firmer line under the header, and the
header row stands on a light tint of the skin's accent colour, so it follows
the house colours without anyone choosing one. A skin that wants another sets
`--skin-table-head-bg` (and `--skin-table-head-fg` for the text on it). For a
table that is really two aligned columns, add `.plain` to drop the grid — and
the tint with it, unless the skin gives plain tables one on purpose
(`--skin-plain-table-head-bg`):
`::: {.incremental .plain}`. Add `.tight` as well and the rows close up, like
the lines of a list — the same word, with the same meaning, as on a
`::: {.row .tight}`. `.tight` works on a gridded table too, though it suits a
plain one best.

A table is as wide as its contents: each column takes the room its widest cell
needs, and no more. Only a table that would not fit is capped at the width of
whatever holds it (the slide, or its `col-N`), and then its cells wrap. The
length of a row in the *source* plays no part in this — write the cells as long
as you like on one line.

To fix the **proportions** between columns instead, put `cols=` on the `:::`
that holds the table, with one number per column, separated by colons:

```
::: {.incremental cols=1:5}
| Operator | Meaning |
|----------|---------|
| `&`      | "and" (*true* if both arguments are *true*) |
:::
```

The numbers are proportions, as in `col-N` — not percentages, not lengths —
and a column you do not name counts as 1, so `cols=2` on a two-column table is
2:1. A table with `cols=` takes the full width of whatever holds it (the slide,
or its `col-N`), since the shares have to be shares of something; for a
narrower table, put it in a `col-N`. `cols=` goes on any `:::` — `incremental`,
`contents`, `fragment`, a `col-N` — and applies to the first table inside it. A
value that is not numbers and colons, or that names more columns than the table
has, is reported at build time with its slide, and the table is left as it was.

`.plain` on a block that holds a **list** drops the bullets — the same word as
on a table, where it drops the grid. Only the marker goes; the text stays where
it was, level with the text of its bulleted neighbours. It combines with
`indent=`, and with `.fragment` or `.incremental`:

```
::: {.fragment .plain indent=2em}
- `IF test_expression THEN statement;`{.rexx}
:::
```

For **one item** of a list, put `.plain` on the item: `- [text]{.plain}`
drops that bullet only (a list nested in it keeps its own). The item's timing
word goes the same way, and both work in a loose list too (one with blank
lines between the items):

```
- Variant 1
  * Invocation: the name, immediately followed by parentheses
- [`today=DATE()`{.rexx}]{.afterPrev .plain}
```

A list that opens inside its own `:::` block is always a new, first-level
list, however far its `-` is indented (Markdown ignores up to three leading
spaces, and there is no parent list for it to belong to). To show one line as
if it stood at a deeper level, use `level=`.

`level=N` renders a block **as if it sat at outline level N**, without nesting
it inside a real list. It reproduces the three things a nested level carries:
the outline font-size cascade (level 2 is 82 % of level 1, level 3 about 73 %,
matching the sizes an imported deck uses), the indent for that level, and that
level's bullet (disc, then circle, then square). So instead of guessing an
indent, name the level:

```
::: {.contents level=2}
- reads as a second-level bullet
:::
```

Levels past 4 stay at the level-4 size, where the source decks stop stepping,
and from level 3 down the bullet is a square, as in a real nested list. A list
nested *inside* a `level=N` block is level N+1 (and so on down), with that
level's size and bullet — just as if the whole block sat at level N.
`level=` pairs with `.plain` for a syntax line that should read as a deeper
level but carry no bullet — the same "indented line, no marker" as before, now
in one attribute rather than a hand-tuned `indent=`:

```
::: {.contents .plain level=2}
- `IF test_expression THEN statement;`{.rexx}
:::
```

`level=` works on paragraphs, code and tables too. A paragraph, a Rexx
listing, an `output` block or a table at `level=N` starts where the text of a
level-N bullet starts, which is where it would sit inside a real level-N item.
Code and tables keep their own size; only their position changes:

````
::: {.fragment level=2}
```rexx
DO 3
   SAY "Aua!"
END
```
:::

::: {.fragment .plain level=2}
Output:

```output
Aua!
```
:::
````

The line they start on is measured **outside** the block. A block with
`scale=` of its own still lines up with the bullets around it, which are not
scaled: `{.incremental level=1 .plain .contents scale=0.7}` under a bullet
puts a smaller table where that bullet's text starts. Inside a scaled group
(`::: {.contents scale=0.8}` around the lot) everything is measured at that
group's scale, bullets and blocks alike.

A listing can also open on the line of its bullet. Put **one** blank after
the marker, and line the code and the closing fence up with the opening one:

````
* A block can be executed repeatedly
  - ```rexx
    DO 3
       SAY "Aua!"
    END
    ```
````

Markdown allows one to four blanks after a list marker. With five or more,
the item becomes an indented code block: the backticks and the word `rexx`
show on the slide as code, unhighlighted. md2slides warns about it at build
time.

For an ad-hoc nudge that is not an outline level, `indent=` still moves a block
in by any CSS length.

`{.static}` is the opt-out for a single item inside an incremental: the marked
item is left un-fragmented and shown from the start, while its siblings still
reveal in turn.

```
::: incremental

- revealed first
- [always visible]{.static}
- revealed next

:::
```

#### Revealing Several Fragments Together — `group=` and `.withPrevious`

By default one fragment is one step: one press reveals it. Two markers let
several fragments share a step, so one press reveals them all.

`group=NAME` ties fragments together by name. Every fragment with the same name
is revealed on **one** press, whether or not they sit next to each other. The
step lands at the group's **first** member: the press that would have shown it
shows the whole group at once, and the later members cost no press of their own.

This is how you show two headings together and then fill each one in: give the
headings a shared group, leave their sub-items ungrouped.

```
::: {.fragment group=intro}
Approach A
:::
::: {.fragment group=intro}
Approach B
:::

::: incremental
- A's first point
- A's second point
:::
```

The first press brings up A and B together; the next presses add the points one
at a time. Because the group is anchored at its first member, a member written
lower down appears *early*, before something above it — that is the point of
declaring them simultaneous, and it is the author's call.

`group=` works on any fragment, including one marked on a list item:
`- [text]{.fragment group=g1}`.

For the common case of "reveal this together with the one right before it",
`.withPrevious` is the shorthand: a `.fragment.withPrevious` joins the step of
the fragment immediately before it, no name needed. (It is the anonymous case of
a group; an empty cell in `steps=cells` is marked this way for you.)

```
::: fragment
First
:::
::: {.fragment .withPrevious}
…and this, on the same press
:::
```

`.afterPrevious` is its partner in time: the fragment is revealed
**automatically once the one before it has finished animating**, with no press
of its own, so a run of them cascades from a single press. A press during a
cascade shows the next step at once — the presenter is never kept waiting. A
`group=` whose members are all `.afterPrevious` is revealed one member after the
other instead of all at once.

When the **first** fragment of a slide is `.afterPrevious`, there is nothing
before it but the slide itself, so it follows the slide: the slide comes up with
its title and margins, and a moment later the fragment animates in, without a
press — and the cascade, if one follows, runs on from there.

Both words work on a whole `::: incremental` block, and on one of its items:

```
::: {.incremental .afterPrevious}
- A's first point
- [A's second point]{.afterPrevious}
- A's third point
- [A's fourth point]{.withPrevious}
:::
```

On the block, the word times the block against what came before it: its
**first** item follows the previous fragment by itself (or, with
`.withPrevious`, comes in together with it). The other items keep their own
presses, unless they say otherwise: here the second item follows the first by
itself, the third takes a press, and the fourth arrives with the third.

### The Spotlight

The **spotlight** is a highlighter pen for listings: it strikes across whole
lines of a code or output block, the way one marks a printed listing before
talking about it. Add `spot=` to the fence, naming which of its lines light
up:

```
~~~rexx {.numberLines spot="init:2"}
```

`init` there is not a line, a colour or a position: it is the name of a
**beat**. A beat is a group of things that happen on the same step, and
anything on the slide may join one. That is what the feature is really for,
because two listings that share a beat light up **together, in the same
colour**:

```
~~~rexx   {.numberLines spot="init:2"}
~~~output {.numberLines spot="init:1"}
```

One key press, and line 2 of the program and line 1 of its output are struck
in the same pen. It says *this line produces that line* without the presenter
having to say it, and it keeps saying it while the audience looks away. The
two blocks need not be Rexx: an `output`, `python` or plain-text fence
carries `spot=` with exactly the same spelling.

A prose fragment can join the beat too, and then the sentence and the marks
arrive on the same key press:

```
::: {.fragment spot=init}
This line builds the object...
:::
```

So "synchronise a fragment with a highlight" is not a separate feature to
learn: the fragment simply joins the beat. Note the consequence, though — a
beat waits until the last of its participants has appeared, so **where you
write that fragment decides when the pen strikes**. Writing it below the
listings is usually what you want, since the sentence is the moment; writing
it above will fire the beat earlier than you expect.

Beats accumulate: striking a second one leaves the first lit, which is what
lets two correspondences stand side by side in two colours. Their order comes
from their position in the deck, never from their names — `init` does not
mean "first" — so renaming a beat never reorders anything, and reordering a
slide never surprises you. Case does not matter either, as in Rexx: `Init`
and `init` are the same beat.

Lines may be given singly, as a range, or as a list of both, and several
beats may be named at once, separated by blanks or by semicolons. A block
need not show its line numbers to have its lines marked: in one that shows
none, the lines count from 1, the first line of the block.

```
~~~rexx {.numberLines spot="init:2; salary:5-7,9"}
```

#### Marking Words

The pen can also go over **a few words** instead of a whole line: write the
text between square brackets.

```
~~~rexx {spot="trap:[NOVALUE NAME ANY],[ANY:]"}
SIGNAL ON NOVALUE NAME ANY
...
ANY:
~~~
```

The text is the address. Copy from the listing what you want marked; there
is nothing to count, and if the code around it changes, the mark follows the
text. It is marked everywhere it appears in the block; to mark it on one line
only, put the line number in front: `trap:5[ANY:]`. Lines and texts mix
freely, `trap:2,[ANY:]`.

- **Whole words, as written**: `[ANY]` is not found inside `MANY`, `[say]`
  not inside `say2stderr`, and `[date]` does not mark `DATE`. To mark a word
  in any case — every `say` of a listing, `SAY` and `Say` too — add the word
  `caseless` to the spot: `spot="trap:[say] caseless"`.
- **Within one line.** A mark does not run on into the next line; that is
  what a whole-line mark is for.
- **Any block**: `rexx`, `output`, anything, numbered or not.
- Brackets inside the text pair up, so `[a[1]]` marks `a[1]`.
- A text that is not there is reported by `d`, with its slide.

A word mark is the same pen as a line, drawn tight around the text: a beat
that marks a line of the program and two words of the output shows all
three in one colour.

#### When a Beat Fires: Cues

A beat of lines and words fires on a press of its own, after the last
listing it touches. To fire it **as the slide opens**, or **after the step
before**, write a *cue*: an empty span with the beat's name and a timing
word.

```
[]{spot=trap .afterPrevious}
```

A cue has nothing to show, so it is only a moment: the beat fires when the
cue's step comes, by the ordinary rules. With no timing word, that is a
press. With `.afterPrevious` as the first step of a slide, it is as the
slide opens. And **where you write the cue** decides where its step falls
among the others, as for any fragment. Give each cue a paragraph of its own
(a blank line before and after).

A cue also says **how the marks come in**. `anim=` names the way — `fade`,
the wash fading in (the default); `pen`, drawn from left to right like a
highlighter, through all the pieces of a text in order; or `cut`, at once —
and `anim-duration=` how long it takes, in seconds. `wait-before=` waits
before the beat, like on any `.afterPrevious` step:

```
[]{spot=trap .afterPrev wait-before=2 anim=pen anim-duration=1.5}
```

The pens belong to the deck's style, which declares four of them, so a beat
reads correctly on a light ground and on a dark one. The full attribute
reference is in
[the fenced code block documentation](../../highlighter/fencedcode/#spot).

### Arrows

An arrow goes from one thing on the slide to another: write an empty span
that says where it leaves and where it lands.

```
[]{.arrow .fragment from=cmd to=errors}
```

`from=` and `to=` are **ids** of things on the same slide: an `output` block
(`` ```output {#cmd} ``), a [file box](#file-boxes)
(`` ```output {#errors .file caption=...} ``), a block (`::: {#b}`), a picture
(`![](x.png){#logo}`). A Rexx listing takes no id on its fence, so wrap it:
`::: {#prog}` around it. An id is matched as written, or else ignoring case.

**The arrow draws itself.** There are no coordinates to give:

- If the two things are **side by side** (their heights overlap), the arrow
  is horizontal, at the middle of the overlap: between a command and the
  file box next to it, that is the height of the command.
- If one is **above the other** (their widths overlap), it is vertical, in
  the same way.
- Otherwise it runs from centre to centre, cut where it leaves each box.

A thing with a background or a border (an `output` block, a picture) is its
box. A thing without one, such as a block holding a word, is the text you
see, so an arrow reaches the word and not the edge of its column.

**An end can be a piece of a block**, with the addresses of the
[spotlight](#marking-words): `to="cmd[2>myerrors.txt]"` points at that text
of `#cmd`, `from=out:3` at its third line.

**An arrow is a step like any other.** Where you write it decides when it
appears, never where it is drawn: `.fragment`, `.afterPrevious`,
`.withPrevious`, `group=`, `anim=` and `anim-duration=` all work as on any
fragment. With `spot=`, it joins a beat and appears with its marks:

```
[]{.arrow from=input to=win spot=redir}
```

Without `.fragment` (or `spot=`), it is there from the start. Give each
arrow a paragraph of its own (a blank line before and after): two spans on
consecutive lines are one paragraph, and work too, but read worse.

The skin sets the look: `--skin-arrow-color` (by default the accent),
`--skin-arrow-width` (the stroke; the head grows with it, 3px by default)
and `--skin-arrow-gap` (how far short of each box the arrow stops, 4px).
Arrows print. An id that is not on the slide, a text that is not found, or
two ends that overlap (so there is no room for an arrow) are reported by
`d`, with the slide.

Rexx Code, and Rexx in Prose
----------------------------

A fenced Rexx block is highlighted automatically by
[the Rexx Highlighter](../../highlighter), so a `~~~rexx` block in a deck is
marked up by the real parser, not an imitation of one. What you write in the
deck:

    ```rexx
    ::CLASS Vehicle PUBLIC
    ::METHOD init
      Say "Started engine of" self~class~id
    ```

and what the audience sees:

```rexx
::CLASS Vehicle PUBLIC
::METHOD init
  Say "Started engine of" self~class~id
```

A program's output goes in an `output` block, shown plainly (no highlighting),
styled to read as output. What you write:

    ```output
    Started engine of Vehicle
    ```

and what the audience sees:

```output
Started engine of Vehicle
```

A Rexx listing is made by the highlighter, not by Pandoc, so the braces on its
fence take the highlighter's options and nothing else: a class written there,
`` ```rexx {.fragment} ``, never reaches the slide, and the build says so. To
reveal a listing on a step of its own, put it inside a fragment:

    ::: fragment
    ```rexx
    say "Now you see me"
    ```
    :::

An `output` block (or any other language) is Pandoc's, and takes a class on its
fence as usual: `` ```output {.fragment} `` works.

### Captions

A listing takes a caption as in the other RexxPub tools, with `caption=` on its
fence, whatever its language:

    ```rexx {caption="Starting the engine"}
    Say "Started engine of" self~class~id
    ```

The caption goes above the code, and a picture's caption (the text of
`![...](img/...)`) below the picture.

A caption and what it names are one box on the slide. Everything written on
the fence (or after the picture) that is about the box goes to all of it: the
`#id` (so an [arrow](#arrows) reaches the whole box, caption included),
`.fragment` and its timing word, `anim=`, `group=`. So the caption comes in
with its listing or its picture, never a step before them:

    ```output {#result .fragment caption="What it prints"}
    Hello, world
    ```

    ![The engine, started](img/engine.png){.fragment .afterPrev}

`spot=` stays with the code, the only place it can mark. A Rexx listing does
not take these on its fence (it only takes the highlighter's own options):
put it inside a block, `::: {#id .fragment}`, and it arrives with its caption
just the same.

Where captions go and how they look is set in the front matter, with the same
keys as for an article:

```
lang: es
rexxpub:
  number-figures: yes
  listings:
    caption-position: below
    caption-style: italic
  figures:
    caption-position: above
```

`number-figures: yes` numbers them, listings and figures each on their own
through the deck ("Listado 1:" with `lang: es`; `label:` in `listings:` or
`figures:` chooses another word). Unlike an article, a deck does not number
unless asked: a slide is seen one at a time, and "Listing 7" says little on
it. The keys are those of [YAML Front Matter](../../rexxpub/yaml/).

### File Boxes

What a program reads from a file, or writes to one, is data, and it should
look like data kept in a file, not like what the program printed. Give the
output block the class `.file`, and the file name as its caption:

    ```output {#input .file caption="myinput.txt:"}
    Max
    und
    Moritz
    ```

It comes out as a translucent yellow box with the file name inside it, on
top, in grey italics. It looks the same in every skin, so a file reads as a
file wherever it is shown; the skin may change its two colours,
`--skin-file-bg` and `--skin-file-name`.

The name and the contents are one box, as a caption and its listing are (see
[Captions](#captions)): the `#id`, `.fragment` and its timing word, `anim=`
and `group=` go to the whole box, name included, and `spot=` stays with the
contents. A file box is
not a listing: it takes no number with `number-figures:`, and the name is
always on top, whatever `caption-position:` says. Without a caption, it is
the same box without a name.

### Keys the Audience Should See Pressed

A transcript has to show what was *typed*, and a key is not text: a line that
ends without `Enter` cannot say whether the command was ever sent. A **key cap**
is a key drawn as a key.

In prose, mark the key as a span:

```
Press [Ctrl]{.key} and then [Enter]{.key}.
```

In a block, say `.keys` on the fence and write the keys between angle
brackets:

    ~~~output {.keys}
    C:\> rexx hello.rex <Enter>
    Hello from ooRexx
    C:\> <Ctrl+C>
    ~~~

A block that does not say `.keys` is left exactly as it is, angle brackets and
all — most output has some, and no deck grows key caps it did not ask for.

The cap carries **the text as written**: `<Enter>` is a cap reading *Enter*,
and `<Ctrl+C>` is one cap reading *Ctrl+C*. There is no list of key names to
learn and no symbol substitution — a return arrow is not in every typeface,
and a glyph the machine lacks is a hollow box on the wall.

Two limits, both by design. Inside a marked block a **literal `<` cannot be
written**: a block that needs one does not ask for keys. And a cap runs from
`<` to the next `>` **on the same line**, so a stray `<` costs that line and
nothing more. `<>` on its own is not a cap — it is the operator.

Key caps belong to `output` and other plain fences. A `rexx` block is a
program, not a keyboard session, and goes to the highlighter untouched.

### The Style Chooser

The rendered deck carries a live style picker: `s` opens a list of the
shipped palettes, and the one chosen re-colours every Rexx block on the page
at once (the browser remembers the choice). The palettes are
the same colour schemes that ship with the Rexx Parser documentation.
Nothing to configure — pick the deck's default in the front matter
(`style: light`, the name without any prefix; `tokio-day` when none is named),
and the reader can explore the rest.

### Colour and HTML in Text

HTML can be written straight into a slide, and reaches it as written:

```
* Some are specific to <span style="color: blue">strings</span>,
  some to <span style="color: red">files</span>.
```

A Pandoc span does the same without HTML, `[strings]{style="color: blue"}`.
When the same colour means the same thing on many slides, give it a name
in the master, `.str { color: blue; }`, and write `[LEFT()]{.str}`: the
colour then lives in one place, and the deck says what it means.

Two slips are forgiven by the browser without a word, so md2slides warns
about them: a `style` that is not CSS (`style="color=blue"`: a declaration
is `name: value`, with a colon, and one without is dropped), and a
`<span>` never closed in its paragraph (often `</span>` with the slash
missing), which the browser closes at the end of the paragraph, so its
colour reaches every word after it.

### Code Mentions in Prose

A **code mention** drops a coloured Rexx token into ordinary prose, taking its
colour from the same system as the fenced blocks — and following the live
picker too. Write it as a backtick span carrying a `.rexx*` class and possibly
some optional modifier:

```
The `::CLASS`{.rexx directive} directive defines `Vehicle`{.rexx class},
whose `init`{.rexx method} method runs on creation.
```

and the audience reads:

> The `::CLASS`{.rexx directive} directive defines `Vehicle`{.rexx class},
> whose `init`{.rexx method} method runs on creation.

A mention gets the exact class a fenced block would give that element, so
`::CLASS` in a sentence and `::CLASS` in a listing are the same colour and
move together when the reader changes the palette.

Code in text — a mention, a plain `` `code` `` span, an output mention — is the
size of the text around it, times the skin's `--skin-inline-mono-scale` (1
unless the skin changes it). A wide mono face such as IBM Plex Mono looks
bigger than the prose at the same size; its skin can take it down a little
(the sample skins use 0.9). Code blocks are not affected: their size is
`--skin-code-size`.

The full vocabulary of `.rexx-*` names is shared with the rest of the Rexx
Parser documentation and is not specific to slides; it is catalogued in the
[inline highlighting reference](../../highlighter/inline/).

Navigating a Deck
-----------------

The generated deck is driven from the keyboard and the mouse:

------------------------------- ------------------------------------------------
Right, Down, PageDown, Space    Advance (next fragment, then next slide)
Left, Up, PageUp, Backspace     Go back
Home / End                      Jump to start / end of the current slide
Ctrl+Home / Ctrl+End            Jump to the first / last slide
Alt+PageDown / Alt+PageUp       Next / previous slide at once, complete, no animations
`g`, or any digit               Open the go overlay (a digit pre-fills it)
`s`                             Pick the Rexx highlighting style
`d`                             Diagnose: list the deck's problems
`a`                             About this deck (also from the foot of `F1`)
`t`                             The timer: time elapsed and left
`r`                             Restart the timer (press twice)
`Esc` / `t` on a red popup      Over time: no more overtime popups until a restart
`p`                             Pause the timer (it asks for how long), or resume it
`c`                             A countdown over the slide, or none
`m`                             The time on this slide, top left (rehearsing)
`h`                             How the time went: per slide, per section, runs compared
`b` / `w`                       Blank the screen to black / white
`f`                             Toggle fullscreen
`F1`                            Show this list on screen
Escape                          Clear a blank screen or close what is open
------------------------------- ------------------------------------------------

These keys act on the deck, and the deck only listens while no overlay holds
the keyboard. Inside an overlay you are typing, so the only keys that mean
anything there are the overlay's own -- the go overlay's are listed under
[Finding a slide](#finding-a-slide) below.

`F1` is the exception, and deliberately so. It is not a character anyone
types, so it is the one key that can mean the same thing wherever the
keyboard happens to be: it shows the list above from a slide, and equally
from inside an overlay -- which is where somebody is most likely to wonder
what the keys are. It opens over whatever is already there and Escape gives
that back, so asking in the middle of a search does not cost the search.

### Finding a Slide

The go overlay (`g`) lists every page, and its field takes either a page
number or words to look for. A page number behaves as it always did: type it,
press Enter, and you are there. Anything else is a search, and the list
narrows to the slides that hold it, each one showing the passage that matched.

The unit of a match is the **slide**: `abc def` finds the slides that hold
both words, wherever in the page they fall and in whatever order. One word on
one page and the other on the next is not a match. Quote them --
`"abc def"` -- to ask for the two together, in that order, as a phrase.

The search reads the whole slide: its title, its prose, its listings and its
output blocks, and whatever the slide's own `::: footer` says. What it does
not read is the presenter, affiliation and date that the deck's front matter
supplies, because those are identical on every page -- searching the
presenter's own name would otherwise return the entire deck.

Case and accents are ignored, so `funcion` finds *función* and `muller`
finds *Müller*; what the extract shows in bold is the text as the slide
spells it. Only combining accents fold, which leaves letters that are not an
accented base alone: `strasse` does not find *Straße*.

#### Moving Around the List

A deck of fifty slides makes a list too long to arrow through, so the list
has keys of its own. They are the dialog's and not the deck's: in here,
PageDown is a listful of entries rather than a slide.

\

------------------------------- ------------------------------------------------
Up / Down                       Select the previous / next entry
PageUp / PageDown               A listful at a time, as many entries as fit
Home / End                      First / last entry (Ctrl with them does the same)
Ctrl+Left / Ctrl+Right          Previous / next section entry
Enter                           Go to the selected entry, or to the number typed
Escape                          Close the dialog
------------------------------- ------------------------------------------------

\

Ctrl+Left and Ctrl+Right step between the section pages alone, which is the
quickest way across a long deck: the sections are its table of contents, and
the list already marks them. They stop at the first and the last rather than
wrapping round, and so does a page.

The keys act on the list as it stands, so with a search typed they walk the
matches and nothing else -- and a search that turned up no section page has
no section to step to.

`F1` shows all of them, the deck's keys and the dialog's, side by side.

A click on the right seven-eighths of the slide advances, and a click on the
left eighth goes back; selecting text with the mouse does not navigate, so
deck content stays copyable. A slide may also drive its own build from the
clock, with `wait-before` / `wait-after` on the heading, but any key press
cancels the timers and hands control back to the presenter.

### Deck Health — `d`

Among the build's warnings, a bracket left open gets its own message: a
`::: {.fragment` whose `{` is never closed is not a block at all (Pandoc shows
it as text), and the `:::` meant to close it is reported as closing nothing
*because of* that line; `[text]{.name` and `[text{.name}` are reported too.

`d` opens a panel that lists what is wrong with the deck, slide by slide: a
slide whose content runs into the footer band or off the slide, a margin box
or a title whose text does not fit even at half size, and **every warning the build
printed** — a `:::` block left open, a field a box asks for, a line that is not
UTF-8 — so an author who builds from a script or a double click, and never sees
the console, reads them too. A click on an entry goes to its slide. The panel
and its marks are never printed, and the mode is forgotten when the deck is
closed.

### Leafing Through — Alt+PageDown / Alt+PageUp

To go through a deck quickly — to find your place, or to show someone what is
in it — Alt+PageDown and Alt+PageUp show the next and previous slide
**complete**, every fragment revealed, with no page transition and no
animation. A plain key after that goes on from the end of the slide you are
on.

### About This Deck — `a`

`a` (or the link at the foot of the `F1` list) shows what the deck is and how
it was made: the file, its size and dates, when it was built and with which
skin and masters; how many slides, steps, listings, pictures and tables it
has; the operating system, ooRexx, Pandoc and Rexx Parser versions it was built
with; the plan of the talk, if the deck has one (the timer's total and
warnings, each section with its minutes and its slides, and the `.pause`
slides); the md2slides command that built it; and where to get all of it
(with a link to ooRexx on Wikipedia, for readers new to it).

Not everything should always be told. The `about:` block turns each group on
or off:

```
about:
  deck: yes       # the file, its size and dates, skin and masters
  system: yes     # the operating system and the versions of the tools
  command: yes    # the command that built the deck
  links: yes      # where to get ooRexx, Pandoc, the Rexx Parser, this manual
  timing: yes     # the timer's total, the sections and the pauses, if any
  path: no        # folders: the file's full name, the full paths in the command
  print: no       # print this page after the last slide
```

Those are the defaults. `about: no` turns the page off altogether. What is off
is **not written into the deck**: it is not hidden, it is absent, so a deck
sent out carries only what you let out. With `path: no` every name is shown
without its folder, in the command too. The counts are made in the browser,
from the deck itself.

### The Presenter's Timer

The timer **starts the first time the deck goes full screen** (`f`, or the
browser's own F11) — or, if a countdown is on the screen then, when the talk
goes on after it (see *Countdowns* below) — and then it runs: leaving full screen, blanking the
screen, going back and forth do not touch it. Only `r` restarts it from
`0:00`, and it asks to be pressed twice, so a stray key cannot cost you the
timing of the talk. (Before the timer has started, one `r` starts it.) It
survives reloading the page — which is what you want in the middle of a talk,
and what you may not expect while you edit a deck and reload it to look: if
you once went full screen in that tab, the timer is still running, and after
the talk's `total:` it is over time. Press `r` twice, or open the deck in a
new tab.

`t` shows where the talk stands — the time elapsed, the time left, and the
same for the section you are in — until the next key.

Give the talk a length, and warnings, in the `timer:` block:

```
timer:
  total: 45        # minutes
  warn: 5:1        # warn at 5 minutes and at 1 minute before the end
  popup-every: 10  # in the last minute, a popup every 10 seconds
  where: footer    # the warnings show over the footer band (or: header)
  switch-to-seconds: 3  # minutes and seconds on screen in the last 3 minutes
  sound: no        # a chime when a countdown reaches 0
  pause-message: Coffee break      # what a break says, if you type nothing
  countdown-message: We start soon # the same for a countdown
  record: no       # yes: keep the time per slide of every run (see Rehearsing)
```

The comments after `#` are only there to explain the example; you can copy
them or leave them out.

`warn:` lists minutes before the end (`5:1`, or `5 1`, or `5,1`; `0.5` is half
a minute; `no` for none); the default is `5:1`. At each mark a popup says how
many minutes are left. In the last minute it comes back every `popup-every:`
seconds (10 by default) with the seconds left. When the time is up it turns
**red**: "Time is up", and then the overtime once a minute ("1:00 over", "2:00
over"…) for as long as you go on. A popup goes away with the next key or
click — which still does what it always does. (`popup-every:` is only about
the last minute's popups: the times in the header and footer follow
`switch-to-seconds:`, below.)

Going over time on purpose — the questions went on, say — you can tell the
deck you know: `Esc` or `t` on a red popup, and no more of them come until the
timer restarts. `t` also shows where the talk stands, and keeps you in full
screen; `Esc` takes the deck out of full screen if you went into it with `f`
(that is the browser's doing). The overtime is still there for you to look
at: with `t`, and in the header or footer if they show `{remaining}`.

**Sections.** A slide opens a section of the talk with `time=`, in minutes:

```
--- {.slide .section time=10}
```

The section runs to the next slide with a `time=`. The sections must add up
to `total:`; if they add up to less, the slides before the first section take
the rest, and if there are none, the build says so. With no `total:`, the
sections' sum is the total.

**Pausing.** For an intermission, or questions that should not count, `p`
pauses the timer, and the talk going on resumes it: the next press or click,
forward or back, a jump to another slide — or `p` again. `p` asks how long the
break is:

- minutes (`10`) or the time it ends (`15:30`) put a countdown on the screen
  (see below), and anything you write after it is a message shown above the
  countdown (`15 Coffee break`); with nothing after it, the break says what
  `pause-message:` in `timer:` says, if anything;
- a message alone (`Questions`) puts up a break with no end: it shows the
  message and counts **up**, from the moment you pressed `p`;
- Enter alone pauses without putting anything on the screen, and Esc does not
  pause at all.

A break on the screen also says when it began and how long it has lasted so
far: "paused at 11:42:05 · 3:12 so far". When the talk goes on, the break,
its panel and the pause end together. Or let a slide do it, so there is
nothing to remember:

```
--- {.slide .pause}
--- {.slide .pause pause=10}
--- {.slide pause="15:30 Coffee break"}
```

(`.startPause` means the same as `.pause`; `pause=10` or `pause=15:30` alone
makes the slide a pause slide too, with a countdown, and `pause="Questions"`
one with a message and no end. With blanks in it, the value goes in quotes.) When that slide is shown
the timer stops, and it starts again as soon as the talk goes on — the next
press or click, forward or back. While paused, every time on screen stands
still, visible; no warning comes; `t` says "Paused". A reload keeps the pause.

**Countdowns.** For an audience waiting — before the talk, or in a break — a
big countdown can stand over the middle of the slide. Put it on a slide:

```
--- {.slide countdown=5}
--- {.slide countdown=17:00}
--- {.slide countdown="5 We start in a moment"}
```

or press `c` on any slide and type the same (Enter alone takes a countdown
away). With minutes, it shows the time left, in **blue**; with a time of day,
it shows the clock, in blue, and the time left under it. A message, if there
is one, goes above. When the time comes
it turns **red**: minutes show the overtime (`+1:30`), a time of day shows the
clock with the overtime under it. With `sound: yes` in `timer:`, a short chime
sounds at that moment.

A slide's countdown comes up when the slide is presented — shown in full
screen — once. It goes away when the talk goes on (the next press or click);
a break's countdown goes when the break ends. A countdown on the screen before
the timer has started holds the timer back: the talk starts, and the timer
with it, when the presenter goes on from the countdown, not when the deck went
full screen five minutes earlier.

**Seconds.** A figure that changes every second draws the eye while you
explain something, so the times on screen are **whole minutes** and move
once a minute: the time left is rounded up (`13` while 12 minutes and some
seconds remain), the time used is rounded down, and there are no hours (`87`,
not `1:27`). In the last `switch-to-seconds:` minutes (3 by default) — of the
talk, or of the section, for the section's fields — and in the overtime they
switch to minutes and seconds (`2:59`, `87:01`) and move every second.
`switch-to-seconds: all` shows the seconds always — handy while rehearsing,
to see where the time goes — and `switch-to-seconds: no` never (except in the
overtime). A countdown follows the same rule. `t` and the warning popups always
give the exact time.

To keep an eye on the time without pressing `t`, put the live fields
`{clock}`, `{elapsed}`, `{remaining}`, `{section-remaining}` or
`{section-elapsed}` in a header or footer box, and perhaps `{total}`,
`{section}`, `{sections}` and `{section-total}` (see
[The margin boxes](#the-margin-boxes-header-and-footer)).

### Rehearsing: Time per Slide — `m` and `h`

While the timer runs, the deck writes down every visit to a slide: which
slide, when it came up and when it went. A pause ends a visit, and coming back
to a slide adds another. One go at the talk, from the timer's start to its
restart (`r`, twice), is a **run**.

`m` puts the time on the current slide in the top left corner, counting from
`0:00` each time the slide comes up, with the slide's total beside it when it
has been shown before ("1:12 · 3:40 in all"). It is for rehearsing, and `m`
again takes it away.

`h` shows what a run adds up to:

- the time on each slide, how many visits it had, and its share of the talk
  and of the planned `total:`;
- the same for each section (`time=`), against the section's plan;
- the time on a slide on average, and the five slides that took the most time
  and the five that took the least (a button makes it ten);
- another run beside it, **Compare with**, slide by slide, with the
  difference.

Each run can be labelled with the **audience** it was given to (beginners,
Python programmers...), so that the runs can be told apart and compared.

The run in progress survives a reload of the page. To keep the runs from one
talk to the next, give the deck `record: yes` in `timer:`: they are then kept
by the browser, for this deck file, and `h` lists them all. **Export runs**
saves them all as a JSON file, and **Import runs** reads such a file back, so
runs move between browsers and machines; **Delete this run** (pressed twice)
forgets one.

### Printing a Deck

Printing (or "Save as PDF") gives **one slide per page, every fragment
revealed**, each page a picture of the slide as it is on screen: the same
1280 × 720 canvas, the same line breaks, the footer where it belongs. The deck
asks for pages of exactly that size, so the browser's paper and scale settings
do not change the result; on a different sheet, choose the browser's *fit*
setting ("Fit to page width" in Firefox, "Fit to printable area" in Chrome) and
the page is scaled whole. Tick *Background graphics* (Chrome) or *Print
backgrounds* (Firefox), or the skin's colours and pictures stay off the paper.
With `about: print: yes` the about page is printed after the last slide.

### Characters: UTF-8 Only

A deck is read as **UTF-8**, and only UTF-8. A line that is not — a file saved
as Windows-1252, say — is reported with its line number and the character the
odd byte most likely was (`'85'x`, an ellipsis), and so is a line that shows
the signs of a character already lost (the replacement character `�`) or read
twice in the wrong encoding (`â€“` for an en dash). md2slides reports; it does
not guess and repair. Save the deck as UTF-8 and retype what still looks wrong.

Program Operation
-----------------

The processing pipeline shares its whole front end with md2html and md2pdf.
Md2slides first expands all the Rexx fenced code blocks using
[the Rexx Highlighter](../../highlighter), so a `~~~rexx` block is marked up
by the real parser. It then runs <a href="https://pandoc.org/">Pandoc</a>
against the result to convert the Markdown into flat HTML, with header
attributes surviving as `id`, `class` and `data-*`. The one genuinely new step
is the **fold**: that flat sequence of headings and content is grouped into
`<section class="slide">` elements, one per slide, with the heading's (or the
marker's) attributes moved onto the section. Finally the resolved skin and
master CSS and the deck runtime are assembled, inline, into one
self-contained HTML file.

**Why the fold is needed.** Pandoc knows nothing of slides: what it returns is
one long page, a heading followed by its paragraphs, then the next heading,
and so on, all at the same level. A deck needs each slide to be one box that
can be shown or hidden as a whole, and that carries the slide's own settings
— its role, its animation, its timing, its name. The fold draws those boxes:
it cuts the page at every heading (or marker) and wraps each piece in its
own `<section>`. Everything else a deck does rests on that: the runtime shows
one section at a time, the masters style a section by its role, and the go
dialog lists the sections.

```
                              md2slides workflow
                              --------------------

                       +-----------------------------+
                       |                             |
                       | (1) Markdown deck source    |
                       |                             |
                       +-----------------------------+
                                      |
                                      | <---- The Rexx Highlighter (FencedCode.cls)
                                      v
                       +-----------------------------+
                       |                             |
                       | (2) Markdown +              |
                       |     Rexx code expanded      |
                       |                             |
                       +-----------------------------+
                                      |
                                      | <---- pandoc
                                      v
                       +-----------------------------+
                       |                             |
                       | (3) Flat HTML               |
                       |     (h1, content, h1, ...)  |
                       |                             |
                       +-----------------------------+
                                      |
                                      | <---- the fold (one <section> per slide)
                                      v
                       +-----------------------------+
                       |                             |
                       | (4) Folded slides +         |
                       |     skin + master + runtime|
                       |                             |
                       +-----------------------------+
```

Because the source is rewritten (fenced code) before it reaches Pandoc, Pandoc
is fed the deck on standard input and therefore does not know which directory
the deck lives in. Md2slides hands it the deck's own directory as a resource
path, so a relative `bibliography:` named in the front matter (the normal
case) is resolved correctly.

md2slides is part of the Rexx Parser package, see
<https://rexx.epbcn.com/rexx-parser/>. It is distributed under the Apache 2.0
License (<https://www.apache.org/licenses/LICENSE-2.0>).
