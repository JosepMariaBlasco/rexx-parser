Exploiting CSS Paged Media
==========================

-----------

If you are looking for quick instructions to print a print-ready page,
[simply jump here](#howtoprint).

-----------

**Note**: To properly follow the contents of this page, you should
be familiar with the [CGI installation](../cgi/) architecture and details.

-----------

Introduction
------------

The CSS specification includes a little-known module called
CSS Paged Media (<https://www.w3.org/TR/css-page-3/>),
which

  > specifies how pages are generated and laid out
  > to hold fragmented content in a paged presentation.
  > It adds functionality for controlling page margins,
  > page size and orientation, and headers and footers,
  > and extends generated content to enable page numbering
  > and running headers / footers.

The module allows us to define the page size and the running
headers, footers and left and right margins, and to
put things in them, including the page number (which can
itself be tweaked); it also allows us to differentiate between
the first page and the rest, and between even and odd pages (we
normally don't want running headers or footers in the first page,
and we may want to display different running headers on even and odd pages).

The CSS Paged Media Module is defined by the World Wide Web Consortium as "Level 3",
which seems to be synchronized with the CSS3 specification,
and its history page (<https://www.w3.org/standards/history/css-page-3/>)
allows us to go back down to 23 june 1999 for the first Level 3 specification.

Old stuff, then, and still little known. How can this be?
Most probably, because the major browsers are taking their time
to implement it. Indeed, they really don't seem to be in any kind
of hurry to get it implemented.

For example, both Chrome and Firefox seem to respect
the page size (`@page{ size: ...}`), even if the results
vary depending on the output driver ("Save as PDF" respects
it on Chrome, but "Microsoft print to PDF" does not);
but running headers and footers (`@page{ @top-center{ ...}}`, etc.)
seem to work on Chrome, but not on Firefox, and so on.

This lazyness on the part of browser vendors has stimulated
the apparition of a number of companies,
like DocRaptor or PrinceXML, which offer a more
or less complete implementation of CSS Paged Media,
in some cases adding proprietary extensions,
to overcome the limitations of the current W3C definitions.
Many of these companies are commercial (and in some cases they
charge a lot of money for their services), and some others
are not, but then they offer incomplete implementations,
or the software don't seem to be actively developed.

Why should that interest us?
----------------------------

What benefit could we get from CSS Paged Media? Well,
consider for a moment a [CGI installation](../cgi/) of
[the Rexx Highlighter](..): it allows us to write
a whole web site using only Markdown (and some auxiliary
CGIs that we have to write only once and which require
very low maintenance). The proposed workflow,
[which we examined elsewhere](../cgi/#workflow), allows us
to create special Markdown files, enriched with HTML and CSS, and
which include both Unicode graphemes and Rexx code, and
have these files automatically served as nice HTML pages that
display properly in all the major browsers.

Using CSS Paged Media and some properly written CSS,
we should be able to print one of these pages, and get
a decently-looking _presentation_, or a decently-looking _article_.
Please consider what we are proposing here: our starting point
is _a single Markdown file_, which is the source for our web
page. We now want to create some slides (or an article)
_from the very same web page_, using CSS Paged Media. We are
not speaking of maintaining two separate source files,
one for the web page, and another for the presentation;
this always produces synchronization problems, one file
that gets updated and another that doesn't, etc.

No; we would like to have a single source file,
and this source file should produce both a web page,
and a presentation (or an article). We should
get the slides (or the article) by the simple expedient
of _printing_ the web page produced by this source file.

And, still more, this single source file should support
Markdown, HTML, CSS, Unicode, and Rexx fenced code blocks.
The final product, either a web page or a PDF file, should
display all variations of Unicode Text, including Emojis,
and highlighted Rexx code.

That would be no small feat. Mixing emojis and highlighted
Rexx code in LuaLaTex, for example, may be extremely cumbersome.

What have we done
-----------------

What we have done is, for sure, not everything that can be done.
We have used CSS Paged Media to produce web pages that automatically
print to slide presentations. Here are some examples:

+ Unicode and Rexx. A brief introduction to TUTOR (2025):
  [Web page](/publications/2025-05-04-Unicode-and-Rexx/),
  [Slides](https://www.epbcn.com/pdf/josep-maria-blasco/2025-05-04-Unicode-and-Rexx.pdf).
+ The Rexx Parser (2025): [Web page](/publications/2025-05-05-The-Rexx-Parser/),
  [Slides](https://www.epbcn.com/pdf/josep-maria-blasco/2025-05-05-The-Rexx-Parser.pdf).
+ The Rexx Highlighter (2025): [Web page](/publications/2025-05-06-The-Rexx-Highlighter/),
  [Slides](https://www.epbcn.com/pdf/josep-maria-blasco/2025-05-06-The-Rexx-Highlighter.pdf).

In all the cases, the slides have been produced by displaying
the corresponding web page using the Chrome browser, clicking the right
mouse button, selecting "Print...", and
[following some simple additional instructions](#howtoprint)
(presentation PDFs are frozen, as they are a publication
of the 36th RexxLA Symposium, held in Vienna, Austria, from may 4 to
may 7, 2025; web pages may have later received some updates, to correct
typos or to update broken links, but the contents should be
substantially the same).

The technical details
---------------------

When [we configured the Apache httpd web server](../cgi/), we modified
a line so that it reads

```
DirectoryIndex readme.md slides.md article.md index.html
```

This means that, when we request a URL ending with "/", we will be served
a `readme.md` file, if it exists; else, we will be served a `slides.md` file;
else, an `article.md` file; and so on. For example, the page you are
reading now ends with `paged-media/`, but what you are really being
served is `paged-media/readme.md`; your browser may mask this fact
from you or not, but you can always add `readme.md` manually at the end
of the URL and look at the results.

Please remember that we are speaking of a [CGI installation](../cgi/)
all the time. A Rexx program is serving the pages; indeed, it's the
Rexx program that orchestrates the sequence of transformations (Rexx
code block processing, Pandoc, etc.) that produce the final HTML
page. But this Rexx program _knowns the filename_ of the file
it is serving, and therefore it can produce different HTML
depending on the filename.

### Prepared web pages {#prepared}

That's the trick: when we are serving a `slides.md` page, for example,
we will include extra references to a number of CSS files that are
not loaded in the standard case (i.e., when the index file is `readme.md`;
you can take a look at [the CGI processor source](../cgi/#cgisource) for the details).
_And these CSS files contain the extra CSS Paged Media_
_definitions that will allow converting our innocent-looking web page into_
_a potentially print-ready PDF_. In such cases, we will say that
we have _prepared_ our web page.

### Another detail: Customizing Bootstrap

Bootstrap includes a set of definitions for printed media that
will not work in our case. For example, code block backgrounds
disappear in Bootstrap printed media (the software sems to be trying
to avoid sending colorful pages to the printer, to help us to save ink),
but we don't want that: we may want to produce, for example,
a PDF containing some slides that show code blocks with a dark background,
and use these PDF files _as presentations only_: we wouldn't
be wasting any ink. To achieve this effect, we will need to manage print media settings
ourselves, manually, instead of leaving them to Bootstrap. Luckyly, Bootstrap 3 has a very
complete customization system (see <https://getbootstrap.com/docs/3.4/customize/>),
and we only need to unselect the "Print media styles" checkbox, scroll
to the bottom of the page, and press "Compile and download" to get
our own, customized, version of Bootstrap.

### What to expect

As we already mentioned, the implementation of CSS Paged Media
in the major browsers is still in its infancy. You can get _decent looking_
slides, but you shouldn't expect too much. Apart from the limitations
of the CSS Paged Media implementation, we will have to deal with the
imperfections of Pandoc itself.

How to transform a web page into a set of slides {#howtoprint}
------------------------------------------------

Printing a web page [that has already been prepared](#prepared) is extremely easy.

- Open the web page using the Chrome browser.
- Click the page with your right mouse button, and select "Print...".
- Ensure that the _Destination_ is "Save as PDF", _Margins_ is
  set to "Default", _Headers and Footers_ is unselected,
  and _Background Graphics_ is selected.
- Press the "Save" button, and select a place to store
  your PDF.

That's it. Chrome will remember these settings, so that, next time,
all you will need to do is to select "Print..." and then "Save".

The resulting PDF will have a width of 263.11mm and a height of 148mm:
this is the height of a landscape DIN A5, and the width has been
adapted so that the resulting file has a 16x9 ratio and can
be displayed properly in a Full HD monitor. These dimensions
are also convenient for visibility and to avoid that the styles for
the web pages and the ones for the slides diverge too much.




