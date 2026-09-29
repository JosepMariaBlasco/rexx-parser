md2slides Reference
===================

----------------

Every building block of a deck, in one place: the command line, the front
matter, the slides, the blocks, the code, the keys and the skin. One line per
item — what it is and what it takes — with a link to the
[md2slides page](../) for the whole story. New to the notation itself? See
[Markdown, Pandoc and md2slides](../primer/).

In the tables, *text* is any text, *n* a number, *min* minutes (decimals
allowed), *s* seconds (`1`, `0.4`, or `400ms`), and *length* a CSS length
(`1cm`, `2em`, `40px`, `5%`).

Command Line
------------

<pre>
[rexx] md2slides [<em>options</em>] <em>filename</em> [<em>destination</em>]
</pre>

| Option | Takes | What it does |
|---|---|---|
| `-s`, `--skin` | a sheet | The skin: who presents (colours, faces, sizes). Default `skin-default.css`, which must exist. |
| `-mp`, `--master-pages` | a sheet | A master: where things go. Repeatable; applied in order. Default `master-default.css`, if there is one. |
| `--img` | a folder | Another folder of pictures, searched after the deck's own `img/`. Repeatable. |
| `--picture-size` | pixels, or `no` | The longest side a PNG or JPEG keeps in the deck; bigger ones are reduced with ImageMagick, if installed. Default `1920`. |
| `--csl` | a name or a path | The citation style, when the deck cites (`bibliography:`). Default `rexxpub`. |
| `--pandoc-highlight` | a name | Pandoc's colours for code that is not Rexx. Default: the skin's `--skin-pandoc-style`, else `pygments`. |
| `-h`, `--help` | — | The help. |

A sheet is a path: relative ones are looked for beside the deck, then in the
current folder. *Filename* gets `.md` when it has no extension and is not
found as given; *destination* defaults to the deck's name with `.html`, in
the current folder. The
command line wins over the front matter, which wins over the default.
→ [Usage](../#usage), [Skin and Masters](../#skin-and-masters)

Front Matter
------------

The `---` block on the **very first line** of the file. md2slides' settings
live under `rexxpub:`. It is YAML 1.2, the same Pandoc reads: blocks, lists,
the one-line forms `{ a: 1, b: 2 }` and `[a, b]`, and `#` comments. `yes`,
`no`, `on`, `off` are booleans, so a text that is one of those words goes in
quotes; so does one with a colon and a blank in it. Invalid YAML stops the
build, with its line.
→ [YAML Front Matter](../#yaml-front-matter)

### `rexxpub:` — top level

| Key | Takes | What it does |
|---|---|---|
| `skin:` | a sheet | As `-s`. |
| `master-pages:` | a sheet, or a list of sheets (`[a.css, b.css]`) | As `-mp`. A plain value is one name, blanks and all. |
| `img:` | a folder, or a list of folders | As `--img`. A plain value is one name, blanks and all. |
| `picture-size:` | pixels, or `no` | As `--picture-size`. → [Size](../#size) |
| `style:` | a Rexx style name | The Rexx colours to start with (`light`, `dark`, `tokio-day`...); `s` changes them live. Default `tokio-day`. |
| `title:` | *text* | The browser tab's label. Default: the file's name. (Also a field, `{title}`.) |
| `font-prose:` | a family name | The text face, over the skin's. |
| `font-mono:` | a family name | The code face, over the skin's. |
| `license:` | a licence name | A field, checked against `cc-by`, `cc-by-sa`, `cc-by-nc`, `cc-by-nc-sa`, `cc-by-nd`, `cc-by-nc-nd`, `cc0`, `public-domain`, `all-rights-reserved`, `gfdl`, `apache-2.0` (a `-4.0`-style version may follow). |
| `header:`, `footer:` | a block | The margin boxes: [below](#header-and-footer). |
| `anim:` | a block | Default animations: [below](#anim). |
| `timer:` | a block | The presenter's timer: [below](#timer). |
| `about:` | `yes` / `no`, or a block | The about page (`a`): [below](#about). |
| `listings:`, `figures:` | a block | How captions look, as in the other RexxPub tools: `caption-position:` (`above`/`below`), `caption-style:`, `label-style:`, `label:`; for listings, `frame:` too. → [YAML Front Matter](../../../rexxpub/yaml/) |
| `number-figures:` | `yes` / `no` | Number the captions: "Listing 1:", "Figure 1:", each through the deck. Default `no` in a deck. |
| *any other name* | *text* (HTML allowed), or a list | A **field**: [below](#fields). A list is its items joined by ", " (an item that is a block gives its `name:`). |

Outside `rexxpub:`, `bibliography:` (a file of references, beside the deck)
turns citations on: `[@key]` in the text, `::: {#refs}` where the list goes.

Outside `rexxpub:`, `lang:` names the language of the caption labels
(`Listado`, `Figura`... for `es`).

Not used by md2slides, though other RexxPub tools read them: `docclass:`,
`theme:`, `csl:` (use `--csl`), `pandoc-style:` / `highlight:` (use
`--pandoc-highlight` or the skin). The Rexx dialect
keys (`executor:`, `experimental:`, `unicode:`) do not reach the slides
either: name the dialect on the listing itself (` ```rexx {executor} `).

### `header:` and `footer:`

| Key | Takes | What it does |
|---|---|---|
| `left:`, `center:`, `right:` | *text*, HTML and `{fields}` | The template of that box, over the skin's. To empty a box the skin fills, write `' '` (an empty value leaves the skin's). |
| `font-size:` | *length* | The size of the band's three boxes. |

A box that does not fit is shrunk, down to half size, together with the other
two of its band. The header band shows only when the skin gives it a height.
→ [The margin boxes](../#the-margin-boxes-header-and-footer)

### `anim:`

| Key | Takes | What it does |
|---|---|---|
| `element:` → `effect:` | an element effect | Every fragment that names none. Default: a plain fade. |
| `element:` → `duration:` | *s* | How long a fragment takes. Default `1`. |
| `page:` → `effect:` | a page effect | Every slide that names none. Default: no transition. |
| `page:` → `duration:` | *s* | How long a page transition takes. Default `0`: give one with the effect, or it is over before it shows. |

Element effects: `fade`, `fade-up`, `fade-down`, `fade-left`, `fade-right`,
`scale-in`, `blur-in`, `cut`. Page effects: `fade`, `slide`, `fade-color`,
`cut`. → [Animation](../#animation)

### `timer:`

| Key | Takes | Default | What it does |
|---|---|---|---|
| `total:` | *min* | the sum of the `time=` | The talk's length. |
| `warn:` | *min* list (`5:1`, `5 1`, `5,1`), or `no` | `5:1` | A popup this long before the end. |
| `popup-every:` | whole *s* | `10` | In the last minute, the popup comes back this often. Over time it comes once a minute; `Esc` or `t` on a red one stops them until the timer restarts. |
| `where:` | `footer`, `header` | `footer` | Where the popups show. |
| `switch-to-seconds:` | *min*, `all`, `no` | `3` | Times on screen are whole minutes, with seconds in the last this-many minutes (and the overtime). `all`: always seconds. |
| `sound:` | `yes` / `no` | `no` | A chime when a countdown reaches zero. |
| `pause-message:` | *text* | none | What a break says when nothing is typed. |
| `countdown-message:` | *text* | none | What a countdown says when nothing is typed. |
| `record:` | `yes` / `no` | `no` | Keep the time per slide of every run, in the browser (`h`). |

(`interval:` and `seconds:` are the old names of `popup-every:` and
`switch-to-seconds:`; they still work, and the build says what they are
called now.)
→ [The Presenter's Timer](../#the-presenters-timer),
[Rehearsing](../#rehearsing-time-per-slide-m-and-h)

### `about:`

`about: no` leaves the page out. As a block, each group is `yes` or `no`:
`deck`, `system`, `command`, `links`, `timing` (all `yes`), `path` (`no`:
names without their folders) and `print` (`no`: `yes` prints the page after
the last slide). → [About This Deck](../#about-this-deck-a)

### Fields

| Kind | Names | Where they come from |
|---|---|---|
| Yours | any top-level name in `rexxpub:` — `presenter`, `affiliation`, `date` (`today` = the build date), `version`, `version-date`, `course`... A name with no value (`address-2:`) is declared, and empty. | the front matter |
| Per skin | `skin-<skin>-<name>:`, e.g. `skin-mu-affiliation:` | wins over `<name>:` when the deck is built with `skin-<skin>.css` |
| Automatic | `today`, `now`, `file-date`, `file-time`, `file-name`, `file-name-full`, `file-path` | the build (a field of yours of the same name wins) |
| Of the deck | `page`, `pages` (also `total-pages`), `total`, `section`, `sections`, `section-total` | the runtime, on every slide |
| Live | `clock`, `elapsed`, `remaining`, `section-elapsed`, `section-remaining` | the runtime, while the timer runs; blank before, not printed |

Where they work:

- **In a margin box**, every field. One nobody sets comes out empty, and the
  build warns — unless it is in an **optional group**: `[ · v{version}]` is
  all there when a field in it has a value, and gone when none has; the
  brackets never show.
- **In a slide's text and in link targets** (`[text]({regulations})`), the
  fields of the first three kinds. An unknown `{name}` stays as written, and
  code is never touched.
- **On a business card**, as in the text, but a field with no value leaves
  nothing, and a line of the card whose fields are all empty goes, label and
  all. An unknown `{name}` is left out too, and the build warns.
- **Per slide**, a zone with the field's name (`::: presenter`,
  `::: course`...) sets that field for one slide, in its boxes and in its
  text. Any field works, except the names of md2slides' own zones and blocks
  (`title`, `row`, `card`...), which keep their meaning.

→ [The margin boxes](../#the-margin-boxes-header-and-footer)

Slides
------

A slide opens with a **marker**, a line of its own, or with a **level-1
heading**; a deck uses one or the other. The braces take classes (`.name`),
an identifier (`#name`) and attributes (`key=value`, in quotes with blanks).

```
--- {.slide .logo-rexx kicker="Basics" time=10}
# The Title {.section}
```

→ [Writing a Deck](../#writing-a-deck)

### Roles

| Class | What it does |
|---|---|
| `.title-slide` | The cover: the master lays it out; no rule under the title. |
| `.section` | A section opener: listed as a section by `g`, and named after its title in the timer. |
| `.business-card` | Its text becomes a card (or one `::: card` each): name, role, details. |

Any other class (`.logo-rexx`...) goes to the `<section>` for the masters.
→ [Roles](../#roles)

### Slide attributes

| Attribute | Takes | What it does |
|---|---|---|
| `kicker=` | *text* | A small line above the title. |
| `anim=` | a page effect | How the slide arrives. |
| `anim-duration=` | *s* | How long that takes (default `0`, so give one). |
| `wait-before=`, `wait-after=`, `wait=` | *s* | Build the slide by the clock: a pause before / after / around each step. |
| `duration=` | *s* | Build it by the clock, the steps spread over this long. |
| `time=` | *min* | Open a section of the talk, this long. |
| `section=` | *text* | On a `.section` slide: the section's name in the timer and in `g`, instead of its title. On any other slide it is reported and ignored. |
| `.pause`, `.startPause` | — | Pause the timer while the slide is shown, until the talk goes on. |
| `pause=` | *min*, or a time of day `hh:mm` to count down to, and a message; or a message | A pause slide with a break countdown; with only a message, a break that counts up. |
| `countdown=` | *min*, or a time of day `hh:mm`, and a message | A big countdown when the slide is presented, once. A time of day already more than six hours past means tomorrow. |
| *any other* | *text* | Goes to the slide as `data-<name>`, for the masters (not `title=`: the title is the heading or the `::: title` zone). |

→ [Attributes at a Glance](../#attributes-at-a-glance),
[The Presenter's Timer](../#the-presenters-timer)

Zones
-----

A zone is a `:::` block that md2slides reads as data rather than showing it
where it stands. → [Zones](../#zones)

| Zone | What it does |
|---|---|
| `::: title` | The slide's title (in a marker deck). Shrunk to fit its room. |
| `::: subtitle` | The cover's subtitle. Gives way first when room is short. |
| `::: presenter`, `::: course`… (any field) | That field, for this slide. |
| `::: header-left` … `::: footer-right` | That margin box, for this slide. |
| `::: card` | One business card. `::: {.card .tight}`: an address (an institution's card) — no role, and the lines close together. |
| `::: background` | Pictures behind the slide, covering it. |
| `::: layers` | Pictures stacked: the first sets the size, the rest go over it. With `offset=`*length* [*length*], a cascade: each one that much further right and down (no `%`). |
| `::: {#refs}` | Where the list of references goes. |

Blocks
------

Everything here is written on a `:::` block — `::: {.fragment level=2}` — and
most of it on a bracketed span too.

### Revealing

| Write | What it does |
|---|---|
| `.fragment` | Shown on its own step (a block, a span, a picture, a list item `- [text]{.fragment}`). |
| `.incremental` | Each list item — or each table row — a step of its own. |
| `head=` | In an incremental table: `before` (the header first, the default) or `with-row` (with the first row). |
| `steps=` | In an incremental table: `rows` (the default) or `cells`. An empty cell comes with the one before. |
| `[text]{.static}` | An item of an incremental list that is there from the start. |
| `.afterPrevious`, `.afterPrev` | Shown by itself when the step before has finished. |
| `.withPrevious`, `.withPrev` | Shown together with the step before. |
| `.afterClick` | Shown on a press: the default, written out. |
| `appear=` | `afterPrev`, `withPrev` or `afterClick` for every step inside the block. |
| `group=` | *name*: every fragment of this name on one step. |
| `anim=` | An element effect, for this fragment. |
| `anim-duration=` | *s*, for this fragment. |
| `wait-before=`, `wait-after=`, `wait=` | *s*: a pause before this fragment, after it (before the next step that comes by itself), or both. They time the steps that come by themselves (`.afterPrevious`); a step that comes with a press comes at once, and the build warns. |
| `spot=` | *beat* or *beat*`:`*lines*: joins the spotlight. On a listing, numbered or not, the lines may be `N`, `N-M`, `[text]` (the words, wherever they are, as written) or `N[text]`. Add `caseless` to find the words in any case. |
| `[]{spot=`*beat*`}` | A cue: the beat fires on this step (with a timing word: `.afterPrevious`...). `anim=` says how the marks come in: `fade` (the default), `pen` (drawn left to right) or `cut`; `anim-duration=`, in *s*, how long. |
| `[]{.arrow from=`*id*` to=`*id*`}` | An arrow between two things of the slide, drawn by itself (horizontal, vertical or centre to centre). An end may be narrowed like a spot: *id*`[text]`, *id*`:N`. A step like any fragment; with `spot=`, it joins the beat. → [Arrows](../#arrows) |

Timing words take any case. On a block that is not a fragment they time the
first fragment inside it. → [Marking Fragments](../#marking-fragments)

### Layout

| Write | Takes | What it does |
|---|---|---|
| `.contents` + `scale=` | *n* > 0 | Everything inside at that size (`0.8`); nested scales multiply. Anything but a positive number is reported and ignored. On any other block (`::: {.fragment scale=0.8}`) it does the same. |
| `level=` | 1, 2, 3... | As if at that outline level: size, bullet and indent. Lists, paragraphs, code and tables line up with that level's text. Past 6 it is 6. |
| `indent=` | *length* | Pushed in from the left. |
| `.plain` | — | A list without bullets; a table without its grid (or header tint). On one item, `- [text]{.plain}`, that item's bullet. |
| `.tight` | — | Table rows close together; on a `.row`, no space above it. |
| `cols=` | `1:5`... | The proportions of the columns of the table that follows. |
| `flow=` | 2, 3... | The list in it flowed into that many columns, column by column. With `fill=rows`, row by row. |
| `::: row` + `::: col-N` | N = 1…12 | Columns side by side, in the proportions of their N. |
| `.ruled` | — | On a `.row`: a line between its columns. Ruled rows one under another make one line. |
| `[text]{.label}` | — | A small bold caption, as a paragraph of its own (`Output:`). |

→ [The Grid](../#the-grid-rows-and-columns), [Scaling a Block](../#scaling-a-block),
[Indenting a Block](../#indenting-a-block)

Code
----

| Write | What it does |
|---|---|
| ```` ```rexx ```` | A Rexx listing, highlighted by the Rexx Parser. |
| ```` ```rexx {program=name} ```` | Pieces of one program, spread over slides, highlighted as one. |
| ```` ```rexx {blanks=all} ```` | Every blank shown. `blanks=data` (or just `blanks`): the blanks that are data — in strings, and the blank that concatenates. |
| ```` ```rexx {.numberLines startFrom=10} ```` | Line numbers. |
| ```` ```rexx {executor} ```` | A dialect: `executor` (or ```` ```executor ````), `experimental`, `unicode` (or `tutor`), `cms`. |
| ```` ```output ```` | What a program printed: not highlighted. |
| ```` ```output {.keys} ```` | `<Enter>` and the like drawn as key caps. |
| ```` ```output {.blanks} ```` | Every blank shown. |
| ```` ```output {.file caption="name"} ```` | Data kept in a file: a yellow box with the file name inside, on top. The `#id`, the step and its timing belong to the whole box. → [File Boxes](../#file-boxes) |
| ```` ```python ```` (any other) | Highlighted by Pandoc. |
| ```` ```rexx {caption="Text"} ```` | A caption above the listing (any language); see `listings:` and `number-figures:`. A picture's caption is its `![text](img/...)`. The `#id`, the step and its timing belong to the caption and its listing or picture together. |
| `` `say "hi"`{.rexx} `` | Rexx in a sentence, highlighted. |
| `` `3 4`{.output} `` | Output in a sentence (`{.output blanks=all}` shows its blanks). |
| `[Enter]{.key}` | A key cap in a sentence. |

The Rexx listings take the options of the Rexx highlighter (`size=`, `pad=`,
`style=`...), and only those: a class on a Rexx fence (`.fragment`) is dropped,
with a warning; put the listing inside `::: fragment` instead. A listing with its own `style=` keeps it when `s` changes the
others. → [Rexx Code, and Rexx in Prose](../#rexx-code-and-rexx-in-prose),
[Captions](../#captions)

Keys
----

| Key | What it does |
|---|---|
| → ↓ PageDown Space | Next step, then next slide |
| ← ↑ PageUp Backspace | Back |
| Alt+PageDown / Alt+PageUp | The next / previous slide, complete, at once |
| Home / End | Start / end of this slide |
| Ctrl+Home / Ctrl+End | First / last slide |
| `g`, or a digit | Go to a slide: pick, type its number, or search |
| `s` | The Rexx colours |
| `d` | Diagnose: the deck's problems |
| `a` | About this deck |
| `t` | The timer: time elapsed and left |
| `r` | Start the timer; twice, restart it |
| `p` | Pause (how long? minutes, a time, a message, or nothing), or resume |
| `c` | A countdown over the slide, or none |
| `m` | The time on this slide, top left |
| `h` | Time per slide and section; runs compared; export and import |
| `b` / `w` | Black / white screen |
| `f` | Full screen (starts the timer) |
| Esc | Clear the screen, close what is open |
| F1 | The keys, on screen |

A click goes on (on the left eighth of the screen, back); a drag selects text
instead. → [Navigating a Deck](../#navigating-a-deck)

Skin Properties
---------------

A skin is a style sheet that sets these on `:root`. All are optional; the
deck has a default for each.

| Property | Default | What it sets |
|---|---|---|
| `--skin-font-prose` | Helvetica Neue, Helvetica, Arial, sans-serif | The text face |
| `--skin-font-mono` | Consolas, Courier New, monospace | The code face |
| `--skin-font-title` | — | The face of a business card's name |
| `--skin-body-size` | — (the browser's size; code is figured from 34px) | The text size, from which the others follow: every skin should set it |
| `--skin-code-ratio` | `0.7` | Code size against text size |
| `--skin-code-size` | text size × ratio | Code size, fixed |
| `--skin-inline-mono-scale` | `1` | Code in text (mentions, code spans, output mentions) against the text around it |
| `--skin-fg`, `--skin-bg` | `#1a1a1a`, `#ffffff` | Text and ground |
| `--skin-accent` | `#00529B` | The house colour: rule, progress bar, table header tint |
| `--skin-rule` | the accent | The line under the title and the table header |
| `--skin-deep` | — | Labels on a business card |
| `--skin-title-weight` | `700` | The title's weight |
| `--skin-output-bg` | `#e8e8e8` | Behind output |
| `--skin-othercode-bg` | transparent | Behind code that is not Rexx |
| `--skin-table-rule` | the text colour, faint | A table's grid |
| `--skin-table-head-bg`, `--skin-table-head-fg` | the accent, faint; the text colour | A table's header row |
| `--skin-plain-table-head-bg` | transparent | The header row of a `.plain` table |
| `--skin-key-border`, `--skin-key-bg` | the text colour; transparent | Key caps |
| `--skin-pad-top`, `--skin-pad-x` | `42px`, `56px` | The slide's inner margins |
| `--skin-header-height`, `--skin-footer-height` | `0px`, `64px` | The margin bands |
| `--skin-margin-size`, `--skin-footer-muted` | `15px`, `#808080` | Text in the margin boxes |
| `--skin-header-left` … `--skin-footer-right` | — | Default box templates, as quoted strings |
| `--skin-kicker-top` | `14px` | Where the kicker sits |
| `--skin-anim-duration-page`, `--skin-anim-duration-elem` | `0s`, `1s` | Default tempos |
| `--skin-arrow-color`, `--skin-arrow-width`, `--skin-arrow-gap` | the accent, `3px`, `4px` | Arrows: colour, stroke (the head grows with it), and how far short of each end they stop |
| `--skin-column-rule`, `--skin-column-rule-width` | the text colour, `2px` | The line between the columns of a `.ruled` row |
| `--skin-file-bg`, `--skin-file-name` | `rgba(255,204,51,0.25)`, `#8c8c8c` | File boxes: the box, and the file name inside it |
| `--skin-pandoc-style` | `pygments` | Pandoc's colours for other code |

→ [Skin and Masters](../#skin-and-masters)
