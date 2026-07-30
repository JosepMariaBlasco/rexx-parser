css2xsl
=======

----------------------------

CSS2XSL ("CSS to XSL") is a utility that reads a Rexx highlighting
CSS style (e.g. `rexx-print.css`) and generates an XSL stylesheet
with `fo:inline` templates for the `<phrase role="rx-...">` elements
that the DocBook highlighting driver emits.  The generated `.xsl`
file is meant to be `xsl:include`'d from the `pdf.xsl` customization
layer used by DocBook XSL + Apache FOP.

This utility is part of the DocBook highlighting workflow, which
allows Rexx code in DocBook `<programlisting>` blocks to be
syntax-highlighted in PDF output produced by Publican or any other
DocBook XSL + FOP toolchain.

Note that css2xsl serves the **PDF branch only**.  The HTML branch
needs no generated token templates at all: the stock DocBook XSL
already turns `<phrase role="X">` into `<span class="X">`, so the
existing `rexx-*.css` files apply directly.

### Usage

<pre>
[rexx] css2xsl [<em>options</em>] [<em>output.xsl</em>]
</pre>

If no output file is specified, the default is `rexx-highlight.xsl`.

### Options

----------------------------------------------- --------------------------------
`-s`, `--style` <code><em>STYLE</em></code>     CSS style name (default: `print`)
`--css` <code><em>FILE</em></code>              CSS file path (overrides `--style`)
`--operator` <code><em>MODE</em></code>         Operator granularity: `group`|`full`|`detail`
`--special` <code><em>MODE</em></code>          Special char granularity: `group`|`full`|`detail`
`--constant` <code><em>MODE</em></code>         Constant granularity: `group`|`full`|`detail`
`--assignment` <code><em>MODE</em></code>       Assignment granularity: `group`|`full`|`detail`
`-h`, `--help`                                  Display help and exit
----------------------------------------------- --------------------------------

\

The default granularity is `group` for all categories.

### Granularity modes

The granularity options control how much detail is preserved in the
generated XSL templates for operators, specials, constants and
assignments.  Each category can be set independently:

- **group** — All elements in a category share the same visual style,
  determined by the generic CSS class (e.g. all operators use the style
  of `rx-op`).  This is the default.
- **full** — Each element gets both generic and specific classes
  (e.g. `rx-op rx-add`), generating one template per combination.
  This is how the CSS cascade works in HTML.
- **detail** — Only elements that have their own specific CSS rules
  get individual templates.  Elements without specific rules inherit
  the group style.  This produces the fewest templates when the CSS
  style does not differentiate within a category.

### Role naming convention

The XSL templates match `<phrase>` elements by their `role` attribute.
The role **is** the highlighter's CSS class string, verbatim — the very
same string the HTML driver puts in `class=`:

- `rx-kw` → `<phrase role="rx-kw">`
- `rx-op rx-add` → `<phrase role="rx-op rx-add">`
- `rx-const rx-method rx-oquo` → `<phrase role="rx-const rx-method rx-oquo">`

No name mangling of any kind, and no style in the token markup.  The
style lives on the container instead, as
`role="highlight-rexx-<style>"` on the `<programlisting>`, which is
why one highlighted document can be restyled without being parsed
again.  This is the same markup the
[DocBook highlighting driver](../../highlighter/docbook/) emits, and
what `highlight --docbook` writes to standard output.

Before July 2026 the driver emitted invented elements with the style
baked into the name — `<rexx_print_kw>`, `<rexx_dark_op_add>` — inside
a `rexx_style_<style>` wrapper.  That markup was not valid DocBook and
tied each document to one style; it is gone.  If you have XSL generated
by an older css2xsl, regenerate it.

### Generated output

The output is a valid XSL stylesheet containing `xsl:template`
elements that match `phrase` by `@role` and emit `fo:inline` with the
appropriate visual attributes (`font-weight`, `font-style`,
`text-decoration`, `color`).  Background colour is not emitted at all:
the block background is set once for every style by the glue file that
`hldocprep` generates, which redefines DocBook's `shade.verbatim.style`
attribute set.

Each template is restricted to listings carrying its own style, so
several styles can coexist in one book:

```xml
<xsl:template match="phrase[@role='rx-kw'][ancestor::programlisting[contains(concat(' ',@role,' '),' highlight-rexx-print ')]]">
  <fo:inline font-weight="bold" color="#2b3d8f">
    <xsl:apply-templates/>
  </fo:inline>
</xsl:template>
```

The `concat`/`contains` idiom tests for a blank-delimited token rather
than a substring, which matters: `vim-dark-blue` is a prefix of
`vim-dark-blue2`, and a plain `contains` would match the wrong style.

The number of templates depends on the granularity.  With the `print`
style: `group` mode (the default) generates 153 templates, `detail`
generates 147, and `full` generates 305.

### Integration with DocBook

Normally you do not do this by hand — `hldocprep` generates the XSL
and wires it in for you.  If you are doing it manually:

1. Run `css2xsl` to generate the XSL file.
2. Copy the generated file to your DocBook customization directory.
3. Add `<xsl:include href="rexx-highlight.xsl"/>` to your `pdf.xsl`
   customization layer, **at the very end**, just before
   `</xsl:stylesheet>`.  The position matters — see below.
4. In your DocBook XML source, use `<programlisting>` blocks carrying
   `role="highlight-rexx-<style>"` and containing `<phrase role="...">`
   elements, as generated by `highlight --docbook`.  The container role
   must name the same style the XSL was generated for, or none of the
   templates will match.

On step 3: when an attribute set is defined more than once at the same
import precedence, XSLT merges the definitions and, for any attribute
defined twice, the last one in document order wins.  The generated glue
redefines `shade.verbatim.style`; if the include sits earlier in the
file than `pdf.xsl`'s own definition, that definition takes the shading
back and the per-style background silently stops working.

### Prerequisites

No external dependencies beyond the Rexx Parser itself.  The generated
XSL file is standalone and does not require css2xsl at runtime.

### Program source

~~~rexx {source=../../../bin/css2xsl.rex}
~~~
