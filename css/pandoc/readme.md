Pandoc Syntax Highlighting Styles
==================================

-------------------------------

This directory contains CSS files for
[Pandoc](https://pandoc.org/)'s built-in syntax highlighting engine
([skylighting](https://github.com/jgm/skylighting)).

These styles are used by RexxPub to highlight non-Rexx fenced code
blocks (Python, Java, SQL, etc.).  Rexx code blocks are highlighted
by the Rexx Highlighter and use a separate set of styles (the
`rexx-*.css` files in the parent directory).

Available styles
----------------

+ `pandoc-pygments.css` --- The default Pandoc style, based on the
  [Pygments](https://pygments.org/) colour scheme.  Light background,
  muted colours, good general-purpose readability.
+ `pandoc-kate.css` --- Based on the
  [Kate](https://kate-editor.org/) editor defaults.  Light background,
  slightly more saturated than Pygments.
+ `pandoc-tango.css` --- Based on the
  [Tango Desktop Project](http://tango.freedesktop.org/) palette.
  Light background, warm earth tones.
+ `pandoc-espresso.css` --- Dark background (`#2b2b2b`), warm colours.
  Pairs well with dark Rexx highlighting styles.
+ `pandoc-zenburn.css` --- Dark background (`#3f3f3f`), low-contrast
  palette designed to reduce eye strain.  Pairs well with dark Rexx
  highlighting styles.
+ `pandoc-monochrome.css` --- No colours; uses only bold, italic, and
  underline to distinguish token types.  Suitable for black-and-white
  printing.
+ `pandoc-breezeDark.css` --- Dark background (`#232629`), based on the
  KDE Breeze Dark theme.  Vivid colours on a very dark background.
+ `pandoc-haddock.css` --- Based on the
  [Haddock](https://haskell-haddock.readthedocs.io/) documentation
  tool.  Light background, restrained palette.

Usage
-----

The style is selected via the standard Pandoc `highlight-style`
metadata field in the YAML front matter (at the top level, not
under `rexxpub:`):

```
---
highlight-style: zenburn
rexxpub:
  style: dark
---
```

The default is `pygments`.  The `md2pdf` pipeline also accepts
a `--pandoc-highlighting-style` command-line option.

See the [YAML front matter documentation](../../doc/rexxpub/yaml/)
for details.

Regenerating from Pandoc
------------------------

These files were generated from Pandoc's built-in highlight themes.
To regenerate them (for example, after a Pandoc upgrade), run:

```
for style in pygments kate tango espresso zenburn monochrome breezeDark haddock; do
  echo '```python'  > /tmp/hl.md
  echo 'x = 1'     >> /tmp/hl.md
  echo '```'        >> /tmp/hl.md
  pandoc -s --highlight-style=$style /tmp/hl.md \
    | sed -n '/<style>/,/<\/style>/p' \
    | sed 's/<\/?style>//g' \
    > pandoc-$style.css
done
```

License
-------

These CSS files are derived from Pandoc's built-in themes, which are
part of the [skylighting](https://github.com/jgm/skylighting) library,
distributed under the
[GPL-2.0 license](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
or the [BSD-3-Clause license](https://opensource.org/licenses/BSD-3-Clause).
