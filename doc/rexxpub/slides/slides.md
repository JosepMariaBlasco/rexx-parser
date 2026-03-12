::::: title-page

The `slides` Document Class <small>A Self-Referencing Guide</small>
===================================================================

::: author
[Josep Maria Blasco](https://www.epbcn.com/equipo/josep-maria-blasco/)
:::

::: affiliation
Espacio Psicoanalítico de Barcelona
:::

::: event
37th International Rexx Language Symposium
:::

::: venue
Barcelona, May 3--6, 2026
:::

:::::

About this presentation {.newpage}
=======================

This slide deck documents the `slides` document class for RexxPub.

It is itself a `slides.md` file, rendered by the class it describes
--- so every slide you see is a live example of the features being
documented.

Structure of a slide deck {.part .newpage}
=========================

The title slide {.newpage}
================

The title slide uses the same `::::: title-page` fenced div as the
`article` class, so the same Markdown source works in both.

```
::::: title-page

Presentation Title <small>Subtitle</small>
==========================================

::: author       ::: affiliation
::: event        ::: venue
::: email        ::: date

:::::
```

Two new elements are available for slides: `event` and `venue`,
useful for conference presentations.

Content slides {.newpage}
===============

Each `<h1>` with `{.newpage}` starts a new slide.  The heading
becomes the slide title, rendered in blue with an underline.

```
Slide Title {.newpage}
======================

Content goes here.
```

The body text is set in Helvetica/Arial at 20pt, left-aligned,
without justification or hyphenation --- optimised for projection
readability.

Section dividers {.newpage}
=================

A section divider is an `<h1>` with both `.part` and `.newpage`:

```
Section Name {.part .newpage}
=============================
```

This produces a centred title without the underline bar, useful for
separating major parts of the presentation.

Lists on slides {.newpage}
================

Lists are the bread and butter of conference slides:

- Body text is 20pt sans-serif for projection readability
- Items are more generously spaced than in `article`
- Left margin is tighter (1.5em) to save horizontal space
- Nested lists are supported:
  - Second level
  - Also with generous spacing
- No text-indent --- block style throughout

1. Numbered lists work the same way
2. With consistent spacing
3. And compact margins

Code on slides {.newpage}
===============

Slides support both generic code blocks and Rexx-highlighted blocks.

Generic code has a subtle rounded background:

```
[rexx] md2pdf --docclass slides slides.md
```

Rexx-highlighted blocks work exactly as in `article`:

~~~rexx
/* Highlight quality is identical to articles */
Parse Arg name
Say "Hello," name"!"
~~~

The code font is 14pt --- smaller than the body text, but large
enough for projection.

Tables and blockquotes {.newpage}
=======================

Tables use the `booktabs` convention, with the accent colour:

| Feature    | Article | Letter | Slides |
|:-----------|:-------:|:------:|:------:|
| Font       |  Serif  | Serif  |  Sans  |
| Alignment  |  Just.  |  Left  |  Left  |
| Indent     |  1.5em  |  None  |  None  |
| Hyphenation|  Auto   | Manual | Manual |

Blockquotes keep a coloured left bar (useful on projection):

> This is a blockquote.  The left bar helps it stand out at a
> distance --- unlike `article`, where it is removed.

Page layout {.newpage}
============

- **Page size:** 254mm x 142.875mm (exact 16:9, FHD-compatible)
- **Margins:** 1.5cm top/bottom, 1.8cm sides
- **Slide numbers:** bottom-right, small (10pt), grey --- hidden on
  the title slide
- **Footnotes:** supported, smaller font (12pt)[^fn]

[^fn]: This is a footnote on a slide.  Useful for references or
attributions without cluttering the slide body.

YAML front matter {.newpage}
==================

Slides support [YAML front matter](../yaml/) for setting RexxPub
options directly in the Markdown source:

```
---
rexxpub:
  style: print
  number-figures: false
---
```

Structural options set in the YAML (such as `number-figures` or
`section-numbers`) take precedence over URL parameters ---
the author's intent is always respected.

The highlighting `style` is an exception: it can always be
overridden by the reader via the style chooser.

The closing slide {.newpage}
==================

Use `::::: closing-page` for a centred closing slide:

```
::::: closing-page

Thank You! {.newpage}
=====================

Questions?

name@example.com

:::::
```

::::: closing-page

Thank You!
==========

Questions?

jose.maria.blasco@gmail.com

:::::