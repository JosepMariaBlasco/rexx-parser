CGI installation
================

-----------

This site is distributed as a zipfile which contains
all the programs to run [the Rexx Parser](/rexx-parser/)
and its child project programs, such as
[the Rexx Highlighter](/rexx-parser/doc/highlighter/),
as well as the related documentation: the file you
are reading now, for example, is part of this documentation.

The documentation consists of a set of
[Markdown](https://daringfireball.net/projects/markdown/) files.
On the reference distribution site,
<https://rexx.epbcn.com/rexx-parser/>, Markdown
is translated on-the-fly and then served as HTML
by a Rexx CGI program, `CGI.markdown.rex`,
reproduced [at the end of this page](#cgisource).

\[CGI stands for [Common Gateway Interface](https://en.wikipedia.org/wiki/Common_Gateway_Interface),
and it is a language-neutral specification that allows the development of
dynamic web pages using any computer language --- including Rexx! You can read more
about CGI in [this Apache tutorial](https://httpd.apache.org/docs/trunk/en/howto/cgi.html).\]

<pre>
                                       <u>How does CGI.markdown.rex work?</u>

                                   ┌────────────────────────────────────────┐
                                   │  <b><a href="https://daringfireball.net/projects/markdown/">Markdown</a> source file</b>                  │
                                   │    May also contain:                   │
                              (1)  │      • Standard HTML/CSS/JavaScript    │
                                   │      • Bootstrap HTML and CSS          │
                                   │      • Rexx fenced code blocks         │
                                   └───────────────────┬────────────────────┘
                                                       ▼
                                   ╔═══════════════════╧════════════════════╗
                                   ║  <b><i><a href="/rexx-parser/bin/FencedCode.cls">bin/FencedCode.cls</a></i></b>                    ║
                              (2)  ║    • Processes Rexx  code blocks       ║
                                   ║    • Produces standard Markdown        ║
                                   ╚═══════════════════╤════════════════════╝
                                                       ▼
                                   ╔═══════════════════╧════════════════════╗
                                   ║  <b><i><a href="https://pandoc.org/">Pandoc</a></i></b>                                ║
                              (3)  ║    • Processes Markdown file           ║
                                   ║    • Produces standard HTML            ║
                                   ╚═══════════════════╤════════════════════╝
                                                       ▼
                                   ╔═══════════════════╧════════════════════╗
                                   ║  <b><i><a href="/rexx-parser/cgi/rexx.epbcn.com.optional.cls">cgi/rexx.epbcn.com.optional.cls</a></i></b>       ║
                              (4)  ║    Adds <a href="https://rexx.epbcn.com/">rexx.epbcn.com</a> localisms:      ║
                                   ║    headers, footers, sidebars, etc.    ║
                                   ╚═══════════════════╤════════════════════╝
                                                       ▼
                                   ┌───────────────────┴────────────────────┐
                                   │  <b>Final HTML file</b>                       │
                              (5)  │    → <a href="/rexx-parser/cgi/CGI.markdown.rex">cgi/CGI.markdown.rex</a> sends the    │
                                   │      resulting HTML to the browser     │
                                   └────────────────────────────────────────┘
</pre>

Such a workflow has a number of advantages:

+ Your web pages are written in Markdown. Markdown is much easier to write,
  learn, teach, remember and maintain than HTML/CSS + a framework like Bootstrap.
+ Nevertheless, Since we are using Bootstrap as the underlying framework
  plus Pandoc to translate the Markdown sources to HTML, we can always resort to
  use Bootstrap-enriched HTML+CSS in our Markdown files when we really need it,
  almost without limitations (GitHub Markdown, on the other hand, is very aggresive
  and limiting regarding which subsets of HTML and CSS you can use
  in your Markdown pages)
+ Our CGI makes automatic use of the Rexx Highlighter, as it highlights
  all Rexx fenced code blocks. We can use all the possible customizations
  that the Highlighter allows (like extra letters, selectable styles, style patches,
  etc.) on a fenced block-by-fenced block basis.
+ If we are using a minimally decent Unicode-supporting text editor (something relatively
  simple like Notepad++ will do), we can generate web pages containing highlighted Rexx
  mixed with non-latin alphabets, as well as emojis, with absolute ease.

`CGI.markdown.rex` and the accompanying files were specifically designed
to support the <https://rexx.epbcn.com/> site only,
but they are provided as a reference, since you may want to install
them locally, to play and to experiment with them,
and then eventually adapt them for your own use.

Installing a local copy of the `rexx-parser` tree: a Windows tutorial
---------------------------------------------------------------------

We will learn how to install a working copy of the whole `rexx-parser` subtree of <https://rexx.epbcn.com/>
on a Windows machine; installing under Linux or Mac should be similar.
Everything should work as in the original site, except for the logo (you can always substitute it by one of your own instead).

### Prerequisites

We will need:

- **Bootstrap 3**, which you can download at <https://getbootstrap.com/docs/3.4/>.

  _Bootstrap defines a set of CSS classes and Javascript procedures that allow_
  _the easy development of mobile-first, responsive web pages._

- **Pandoc**, which you can download at <https://pandoc.org/>.

  _We will use Pandoc to dynamically produce HTML files from Markdown sources._

- A version of the <a href="https://httpd.apache.org/">**Apache httpd**</a> web server. In this readme, we will
  be using <a href="https://www.apachelounge.com/">Apache Lounge</a>, which you can download at
  <https://www.apachelounge.com/download/>, but other distributions should also work.

- The **Visual C++ Redistributable** installation files. You can find download links in
   [the Apache Lounge download page](https://www.apachelounge.com/download/).

- **The Rexx Parser** distribution itself. You can download it [here](/rexx-parser/#download).

- And of course <a href="https://sourceforge.net/projects/oorexx/">**ooRexx**</a>.


### Step-by-step instructions

1. Install Visual C++ Redistributable Visual Studio 2015-2022.

   _This is needed to run Apache Lounge; other distributions of Apache httpd may not_
   _have this dependency. You may also find that the redistributables are already installed,_
   _as they are a prerequisite of many other programs._

2. Install the Apache httpd web server.

   a. Open the zipped Apache httpd distribution, and copy the `Apache24` directory to your `C:` disk:
      this will create a `C:\Apache24` directory (the included readme contains instructions that
      you can follow if you prefer to install it in a different directory).
   b. Execute `C:\Apache24\bin\httpd.exe`. You will get a prompt
      from the Windows firewall. Allow net access.
   c. Open a web browser, and point to `localhost`. You should see a page that
      contains the words "It works!". You cna now close the Apache window you opened in the previous step.\

3. Install Pandoc.

4. Create your new local server directory.

   You will need to create or select a directory to store the copy of
   the Rexx Parser distribution that will be served by your newly installed
   Apache web server. In this tutorial, we will assume that this directory is `C:\Parser`.

5. Install Bootstrap

   a. Open the Bootstrap zip file.
   b. Create `C:\Parser\css` and copy `css\bootstrap.min.css`
      and `css\bootstrap.theme.min.css` from the Bootstrap zip file.
   c. Create `C:\Parser\js` and copy `js\bootstrap.min.js`.
   d. Create `C:\Parser\fonts` and copy all the content of the
      `fonts` subdirectory.

6. Install the Rexx Parser files.

   Create `C:\Parser\rexx-parser`, and copy all the contents
   of the zipped Rexx Parser distribution there.

7. Customize the Apache httpd configuration file.

   a. Open `C:\Apache24\conf\httpd.conf` with a text editor.

   b. Locate the "DocumentRoot" line. You will find two lines that read

      ```
      DocumentRoot "${SRVROOT}/htdocs"
      <Directory "${SRVROOT}/htdocs">
      ```

      Substitute `${SRVROOT}/htdocs` by the server directory you just created:

      ```
      DocumentRoot "C:/Parser"
      <Directory "C:/Parser">
      ```

      \[Note the forward slashes, and beware of the quotes.\]

      _The "document root" is where our served files will reside._

   c. Just after the `DocumentRoot "C:/Parser"` line, add the following lines:

      ~~~
      Action RexxCGIMarkdown "/cgi-bin/cgi.rex"
      <Files *.md>
        SetHandler RexxCGIMarkdown
      </Files>
      ~~~

      <em>
        This defines an ["Action"](https://httpd.apache.org/docs/2.4/mod/mod_actions.html),
        and associates it with a ["Handler"](https://httpd.apache.org/docs/2.4/handler.html).
        The handler is fired whenever a Markdown file ("*.md") is requested;
        the handler then invokes the corresponding action, which is our "cgi.rex" Rexx program.
      </em>

   d. We must now create the `cgi.rex` program file.

      Locate the `C:\Apache24\cgi-bin` directory, and create a `cgi.rex` file containing
      exactly the following two lines:

      ```
      #!rexx
      Call "C:\Parser\rexx-parser\cgi\CGI.markdown.rex"
      ```

      _The first line ensures that the ooRexx interpreter will be called. The second one_
      _delegates the work to `cgi\CGI.markdown.rex`. This indirection mechanism greatly simplifies_
      _setup of the httpd server, and it allows us to distribute `CGI.markdown.rex` as part of the
      Rexx Parser tree._

   e. Locate a line that reads `DirectoryIndex index.html`. Change that line so that it reads

      ```
      DirectoryIndex readme.md slides.md article.md index.html
      ```

      <em>
        When a URL that refers to a directory (that is, a URL ending with "/", like the root directory) is requested,
        we will automatically serve a `readme.md` file, if one is found; if not, we will try to serve a `slides.md` file;
        and so on.
      </em>

8. Start the Apache httpd server we just configured.

9. Point your browser to <http://localhost/rexx-parser/>. You should see a copy of the
   Rexx Parser web page (without the EPBCN logo, which is not included).

You can find a copy of an updated `httpd.conf` file [here](httpd.conf)
for your reference. Please note that this was generated on 20250510 against the
`Apache 2.4.63-250207 Win64` version of Apache Lounge, and may not work
in your installation, depending on your choices and on the versions used.

CGI.markdown.rex {#cgisource}
----------------

Location: `[installation directory]/cgi/CGI.markdown.rex`.

~~~rexx {source=../../../cgi/CGI.markdown.rex}
~~~