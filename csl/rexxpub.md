# RexxPub Bibliography Style (`rexxpub.csl`)

## Overview

The RexxPub Bibliography Style is a [CSL](https://citationstyles.org/) (Citation
Style Language) style for use with Pandoc, Zotero, Mendeley, and other
CSL-compatible tools. It is designed for publications produced with
[RexxPub](https://rexx.epbcn.com/rexx-parser/doc/rexxpub/), the Rexx Publishing
Framework.

## Derivation and licence

This style is derived from the **IEEE Reference Guide** CSL style (version
11.29.2023), originally authored by Michael Berkowitz, with contributions from
Julian Onions, Rintze Zelle, Stephen Frank, Sebastian Karcher, Giuseppe Silano,
Patrick O'Brien, Brenton M. Wiernik, Oliver Couch, and Andrew Dunning.

The original IEEE style is available at
<http://www.zotero.org/styles/ieee> and is distributed under the
[Creative Commons Attribution-ShareAlike 3.0 Unported](http://creativecommons.org/licenses/by-sa/3.0/)
licence.

The RexxPub style is distributed under the same
**Creative Commons Attribution-ShareAlike 3.0 Unported** licence, in compliance
with the terms of the original.

## Changes from IEEE style

The following modifications have been made to the original IEEE CSL style.

### 1. Full author names (no initials)

The IEEE style abbreviates given names to initials (e.g. "J. M. Blasco"). The
RexxPub style displays the full given name as provided in the bibliography
database (e.g. "Josep Maria Blasco").

**Technical detail:** The `initialize-with` attribute has been removed from the
`<name>` elements in the `author`, `editor`, and `director` macros.

### 2. Family names in small caps

Author family names are rendered in small capitals. For example, "Josep Maria
Blasco" appears as "Josep Maria <span style="font-variant:small-caps">Blasco</span>"
in the rendered output.

**Technical detail:** A `<name-part name="family" font-variant="small-caps"/>`
child element has been added to each `<name>` element in the `author`, `editor`,
and `director` macros.

### 3. Bibliography sorted by author, then title

The IEEE style lists bibliography entries in the order in which they are first
cited in the text. The RexxPub style sorts them alphabetically by author family
name, then by title.

**Technical detail:** A `<sort>` element with `<key variable="author"/>` and
`<key variable="title"/>` has been added inside the `<bibliography>` element.
Using `variable="author"` (rather than `macro="author"`) ensures that sorting
is performed on the internal sort key (family name first), regardless of the
display order.

### 4. Updated metadata

The `<info>` block has been updated to reflect the new style name ("RexxPub
Bibliography Style"), a new identifier, the new author (Josep Maria Blasco),
and a `<link rel="template"/>` pointing to the original IEEE style to document
the derivation. The original author (Michael Berkowitz) and all contributors
are preserved as `<contributor>` elements.

## Usage with Pandoc

In your Markdown front matter:

```yaml
---
bibliography: references.bib
csl: path/to/rexxpub.csl
---
```

## Usage with RexxPub

RexxPub uses Pandoc internally for bibliography processing. Place `rexxpub.csl`
in your CSL directory and reference it from the document front matter as shown
above.

## BibTeX author format

For best results, use the "Family, Given" format in your `.bib` file:

```bibtex
@misc{RexxParser,
  author = {Blasco, Josep Maria},
  title  = {The Rexx Parser},
  ...
}
```

This ensures that the CSL processor correctly identifies the family name
(for small-caps rendering and for sorting) even when the given name contains
multiple words.

## Author

Josep Maria Blasco (<jose.maria.blasco@gmail.com>),
[Espacio Psicoanalítico de Barcelona](https://www.epbcn.com/).

## Acknowledgements

This style would not exist without the work of Michael Berkowitz and the many
contributors to the original IEEE CSL style. Their names are preserved in the
`<info>` section of `rexxpub.csl`.