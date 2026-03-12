::::: sender
Josep Maria Blasco\
Espacio Psicoanalítico de Barcelona\
Balmes, 32, 2º 1ª — 08007 Barcelona\
jose.maria.blasco@gmail.com
:::::

::::: date
Barcelona, May the 3rd, 2026
:::::

::::: recipient
The Rexx Community
:::::

::::: opening
Dear Reader,
:::::

This letter is both a demonstration and a guide to the `letter`
document class in RexxPub.  You are reading a Markdown file called
`letter.md`, rendered through the Print pipeline with paged.js
pagination --- and the letter you see *is* the documentation for the
format it uses.

## Structure of a letter

A RexxPub letter is a Markdown file that uses Pandoc fenced divs to
mark the structural elements of the letter.  The available sections, in
their expected order, are:

- **`::::: sender`** --- the sender's address block, aligned to the
  right in European style.  Use Markdown hard line breaks (`\`) to
  separate the lines of the address.
- **`::::: date`** --- the date line, also right-aligned.
- **`::::: recipient`** --- the recipient's address, left-aligned.
- **`::::: opening`** --- the salutation ("Dear...").
- The **body** of the letter follows as normal Markdown paragraphs,
  with no special wrapper.  Unlike the `article` class, the `letter`
  class uses block letter style: no first-line indent, with paragraphs
  separated by vertical space.
- **`::::: closing`** --- the valediction ("Sincerely,").
- **`::::: signature`** --- the sender's name, with generous space
  above for a handwritten signature.
- **`::::: enclosure`** --- an optional enclosure notice, set in a
  slightly smaller font.
- **`::::: cc`** --- an optional carbon copy list, also in a smaller
  font.

All sections are optional: a minimal letter needs only an opening, some
body text, and a closing.  The CSS will simply omit spacing for any
section that is not present.

## Typography

The `letter` class shares the same parametric sizing system as the
`article` class.  The default size is 12pt Times New Roman, but 10pt
and 14pt variants are available through the `size` parameter (in the
query string or on the `md2pdf` command line).

The main typographic differences from `article` are:

- **Ragged right** alignment instead of justified text, which is the
  conventional style for business correspondence.
- **No automatic hyphenation**, for the same reason.
- **No text-indent** --- paragraphs are separated by vertical space
  (block letter style), not by indentation.
- A slightly **more generous line-height** (1.30 vs. 1.25) for
  comfortable reading.
- **Narrower margins** (2.5 cm vs. 3 cm), giving more usable space on
  the page.

## Page numbers

The first page of a letter has no page number, following the standard
convention.  If the letter runs to a second page, page numbers appear
centred at the bottom, in the same font and size as the body text.

## Combining with other features

Because the body of the letter is ordinary Markdown, all the usual
RexxPub features are available: Rexx fenced code blocks with syntax
highlighting, footnotes, bibliographic references, inline code, and
links.  This makes the `letter` class suitable not only for
conventional correspondence, but also for technical communications that
need to include code samples or references.

For example, this is a Rexx fenced code block inside a letter:

~~~rexx
Say "Hello from a letter!"
~~~

## YAML front matter

Like all RexxPub document classes, the `letter` class supports
reading options from the YAML front matter block.  For example,
a letter that should always be printed at 10pt can specify this
directly in the source:

```
---
rexxpub:
  size: 10
---
```

See the [YAML front matter documentation](../yaml/) for details.

We hope you find the `letter` class useful.  If you have suggestions
for improvements, please do not hesitate to let us know.

::::: closing
Best regards,
:::::

::::: signature
Josep Maria Blasco
:::::

::::: enclosure
Encl.: `letter.css`, `letter-10pt.css`, `letter-14pt.css`
:::::