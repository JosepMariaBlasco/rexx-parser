Markdown, Pandoc and md2slides
==============================

----------------

A deck is one text file, and three programs read it in turn. Most of the
marks in it are **Markdown**, the plain-text notation for headings, lists and
emphasis. Some are **Pandoc**'s own additions to Markdown: the `:::` blocks,
the `{...}` attributes, the tables. And a few words only mean something to
**md2slides**, which reads the file before Pandoc, hands it over, and takes
the result back to turn it into slides.

This page says which is which. It is not a manual — the
[md2slides page](../) is — but it makes the manual easier to read: when you
see `::: {.fragment level=2}`, you will know that the `:::` and the braces are
Pandoc's, and that `.fragment` and `level=2` are words md2slides gave a
meaning to.

The Order of Events
-------------------

```
 deck.md ──► md2slides (before) ──► Pandoc ──► md2slides (after) ──► deck.html ──► browser
```

1. **md2slides, before Pandoc** — on the Markdown text:
   - reads the **front matter** (the `---` block at the top), and checks that
     the file is UTF-8;
   - finds every **Rexx** listing (` ```rexx `) and every Rexx mention
     (`` `say`{.rexx} ``) and replaces it with finished, highlighted HTML,
     made by the Rexx Parser — Pandoc never sees the Rexx code;
   - checks that every `:::` block is closed inside its own slide, and closes
     the ones that are not (and says so);
   - turns each slide marker, `--- {.slide ...}`, into something Pandoc lets
     through untouched.
2. **Pandoc** turns the Markdown into HTML: headings, paragraphs, lists,
   tables, emphasis, links, pictures, the `:::` blocks with their attributes,
   footnotes and citations. Everything that is not Rexx code it highlights
   itself (Python, Java, shell...).
3. **md2slides, after Pandoc** — on the HTML:
   - cuts it into **slides**, one per marker (or per level-1 heading);
   - gives meaning to its own words: `.fragment`, `.incremental`, `level=`,
     `scale=`, `indent=`, `appear=`, `.afterPrev`, the roles (`.title-slide`,
     `.business-card`...), the zones (`::: title`, `::: presenter`...);
   - fills in the `{fields}` from the front matter;
   - embeds the pictures, and puts the skin, the masters and the runtime into
     the same file, so the deck is **one** HTML file.
4. **The browser** runs the deck: the keys, the reveals, the timer, the
   fitting of titles and footers to their room.

When something looks wrong, this order is where to look. A `:::` that shows
up as text on the slide was not read by Pandoc as a block (a blank line or a
brace is missing). A `.fragment` that does not step was written where Pandoc
does not keep attributes. A `{presenter}` that stays as it is was not declared
in the front matter.

Plain Markdown
--------------

The marks every Markdown program knows. A text that uses only these reads as
well in a text editor as on a slide.

| You write | You get |
|---|---|
| `# Title` | a level-1 heading (in a heading deck, a new slide) |
| `*text*` or `_text_` | *emphasis* |
| `**text**` | **strong** |
| `` `code` `` | `code` |
| `- item` or `* item` | a bulleted list; indent by two to nest |
| `1. item` | a numbered list |
| `[text](https://...)` | a link |
| `![caption](img/picture.png)` | a picture |
| ```` ``` ```` … ```` ``` ```` | a block of code, as it is |
| a blank line | a new paragraph |
| `<br>` | a line break inside a paragraph (HTML is allowed) |

Two things surprise newcomers. A single line break in the source is **not** a
line break on the slide: the lines of a paragraph are joined. And a list
needs a blank line before it when it follows a paragraph.

Pandoc's Additions
------------------

Pandoc reads a larger Markdown than the original, and md2slides uses these
extensions throughout. Other Markdown programs (a Git host, an editor's
preview) may show them as text.

| You write | What it is |
|---|---|
| `---` … `---` at the very top | the **YAML front matter**: the deck's settings, `key: value` |
| `::: name` … `:::` | a **fenced div**: a block with a name (a class), holding anything |
| `::: {.a .b key=value}` | the same with several classes and attributes |
| `{.class key=value}` after a heading | attributes on the heading |
| `[text]{.class}` | a **bracketed span**: attributes on a few words |
| `` `code`{.rexx} `` | attributes on inline code |
| ```` ```python {.numberLines} ```` | attributes on a code block |
| lines of cells between bars, a line of dashes under the first | a **pipe table** (see below) |
| `[^1]` and `[^1]: text` | a footnote |
| `[@key]` | a citation, when the front matter names a `bibliography:` |

A pipe table looks like this; the bars need not line up:

```
| Operator | Meaning |
|----------|---------|
| `=`      | equal   |
```

The braces follow one grammar everywhere: `.name` is a class, `#name` an
identifier, and `key=value` an attribute (in quotes if the value has blanks:
`pause="15 Coffee break"`). Pandoc itself gives meaning to very few of them;
it passes them on to the HTML, and that is where md2slides finds them.

md2slides' Own Words
--------------------

These are written with Pandoc's marks — a class, an attribute, a named block —
but mean something only because md2slides looks for them. The
[Reference](../reference/) lists them all; the ones a first deck needs are:

| You write | md2slides reads it as |
|---|---|
| `--- {.slide}` on a line of its own | a new slide (the **marker**; see [Writing a Deck](../#writing-a-deck)) |
| `::: title` … `:::` | the slide's title |
| `::: fragment` … `:::` | revealed on the next key press |
| `::: incremental` around a list or a table | each item (or row) revealed in turn |
| `.afterPrev` / `.withPrev` | revealed by itself after the one before / together with it |
| `level=2` | shown as if it were a second-level bullet |
| `::: {.contents scale=0.8}` | everything inside at 80 % |
| `.plain` | a list without bullets, a table without a grid |
| `rexxpub:` in the front matter | md2slides' settings: skin, footer, timer... |
| `{presenter}` | the value of `presenter:` from the front matter |

A word md2slides does not know is not an error for Pandoc, so a misspelling
would do nothing at all, silently. md2slides checks the words that matter
most: a timing word that is almost right (`.afterPrevios`) is reported with
the right spelling, and an effect name, an `appear=`, a `level=` or an
`indent=` that it cannot use is reported with the slide it is on.

Where to Go From Here
---------------------

- The sample decks named at the top of the [md2slides page](../) show the
  features one per slide; reading one next to its HTML is the quickest way in.
- The [md2slides page](../) tells the whole story, feature by feature.
- The [Reference](../reference/) is the list to look things up in.
